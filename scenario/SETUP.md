# Pre-Run Setup Guide — petpoll-e2e

Complete every step in this guide BEFORE calling `vm_run_scenario`.
Skipping any step causes `vm_run_scenario` to raise a ToolError.

---

## Step 1 — Clone and enter the repository

The repository must be fully cloned on a host with the following installed:

| Tool | Minimum version | Install (Ubuntu/Debian) |
|------|----------------|------------------------|
| VirtualBox | 7.0 | `sudo apt install virtualbox` |
| Vagrant | 2.3 | https://developer.hashicorp.com/vagrant/downloads |
| Java JDK | 21 | `sudo apt install openjdk-21-jdk` |
| Maven | 3.8 | `sudo apt install maven` |

After cloning, all paths below are relative to the repository root.

**Outcome**: The working directory contains `Vagrantfile`, `webapp/`, `vagrant/`,
and `scenario/`. Running `mvn -version` reports Maven 3.8+ and Java 21.

---

## Step 2 — Build the WAR on the host

The WAR must exist on the host before `vagrant up` runs, because the Windows VM
mounts the repository root as a shared folder (`/vagrant` on the guest). If the
WAR is not present at provision time, the deployment step will fail.

Build command (run from the repository root):

```
cd webapp && mvn package -DskipTests
```

**Outcome**: `webapp/target/petpoll.war` exists and is non-empty.

**Requirements**: JDK 21 and Maven 3.9 must be installed on the host. If
`mvn package` fails, resolve the build error before continuing — do not proceed
with a missing or empty WAR.

---

## Step 3 — Start the VMs

Bring up both VMs from the repository root:

```
vagrant up
```

Both VMs start and provision in parallel. The Ubuntu VM (PostgreSQL) typically
finishes in 3–5 minutes. The Windows VM (Java + Tomcat) typically takes
10–15 minutes due to JDK and Tomcat downloads.

**Outcome**: `vagrant_status` reports both `petpoll-db` and `petpoll-app` as
`running`. SSH to `petpoll-db` succeeds. WinRM to `petpoll-app` succeeds.

If provisioning fails on either VM, inspect the error output before continuing.
Do not proceed to Step 4 with a VM in an error state.

---

## Step 4 — Confirm VirtualBox VM names

After `vagrant up` completes, call `vm_list()` to confirm the VirtualBox names
assigned to the VMs.

**Expected names**:

| Vagrant machine | VirtualBox VM name | IP |
|-----------------|--------------------|----|
| `ubuntu`        | `petpoll-db`       | `192.168.56.10` |
| `windows`       | `petpoll-app`      | `192.168.56.11` |

The Vagrantfile sets `vb.name` explicitly for both VMs, so these names should
match exactly. If `vm_list()` shows different names (e.g. Vagrant added a
directory prefix), use the actual names returned by `vm_list()` for all
subsequent `vm_name` arguments — including Steps 5 and 6.

**Outcome**: The exact VirtualBox names to pass to all `mcp__vm-blackbox__*`
tools are confirmed.

---

## Step 5 — Commit goal state for both VMs

`vm_run_scenario` checks whether committed goal criteria exist for the
`vm_name` / `scenario_name` pair before proceeding. If no criteria are
committed, it raises a ToolError immediately. This step registers the criteria.

Call `vm_goal_interview` once for each VM:

```python
mcp__vm-blackbox__vm_goal_interview(
    vm_name="petpoll-db",
    scenario_name="petpoll-e2e",
)

mcp__vm-blackbox__vm_goal_interview(
    vm_name="petpoll-app",
    scenario_name="petpoll-e2e",
)
```

When prompted by `vm_goal_interview`, provide the checks from
`scenario/goal-state.yaml` as the goal criteria for each VM. The checks for
`petpoll-db` and `petpoll-app` are listed under their respective `vm_name`
keys in that file.

**Outcome**: The plugin's goal state store contains committed criteria for
both `petpoll-db / petpoll-e2e` and `petpoll-app / petpoll-e2e`. Subsequent
calls to `vm_run_scenario` will pass the goal gate.

---

## Step 6 — Run the scenario

With goal state committed for both VMs, run the scenario:

```python
mcp__vm-blackbox__vm_run_scenario(
    vm_name="petpoll-db",
    scenario_name="petpoll-e2e",
)

mcp__vm-blackbox__vm_run_scenario(
    vm_name="petpoll-app",
    scenario_name="petpoll-e2e",
)
```

Follow the `orchestration-guide.md` phases for the full execution sequence.

**Outcome**: Both scenario runs return a dispatch receipt. The orchestrator then
dispatches `vm-pilot` for each VM per the `vm-scenario-runner` skill, stores
the agent task IDs, and waits for completion.
