# Orchestration Guide — petpoll-e2e

This document tells an AI orchestrator (using the vm-blackbox plugin) how to
execute the petpoll end-to-end scenario. Each phase specifies what to verify,
not the exact commands — derive those from the checks in `goal-state.yaml` and
the vm-blackbox tool surface.

---

## Pre-flight

Before starting any VM, confirm all host prerequisites are satisfied:

- VirtualBox is installed and `VBoxManage --version` reports a version ≥ 7.0.
- Vagrant is installed and `vagrant --version` reports a version ≥ 2.3.
- The repository is fully cloned — no untracked files should appear that are
  required by the Vagrantfile or provisioning scripts.
- At least 20 GB of free disk space is available on the host volume that holds
  the VirtualBox VM storage location.
- The `192.168.56.0/24` host-only network adapter exists in VirtualBox, or
  VirtualBox is configured to create it automatically.
- If a previous run left VMs running or in a failed state, destroy them with
  `vagrant destroy -f` before proceeding.

If any pre-flight check fails, stop and report the failure before bringing up
any VM.

---

## Phase 1 — Base VMs

**Goal**: Both VMs are running and reachable, with no application software yet.

1. Bring up both VMs simultaneously. The Vagrantfile defines them as
   `petpoll-db` (Ubuntu) and `petpoll-app` (Windows).
2. Wait until both VMs report a running state from `vagrant_status`.
3. Confirm SSH connectivity to `petpoll-db`: run a trivial command (e.g.,
   `hostname`) via SSH and verify it succeeds.
4. Confirm WinRM connectivity to `petpoll-app`: run a trivial PowerShell
   command (e.g., `$env:COMPUTERNAME`) via `vm_powershell` and verify it
   returns output.
5. Take a baseline screenshot of each VM. These screenshots confirm the VMs
   are at a clean OS login/desktop state before provisioning begins.

Milestone satisfied: Milestones 2 and 3.

---

## Phase 2 — Database provisioning

**Goal**: PostgreSQL 16 is running on `petpoll-db`, the `petpoll` database
exists, `petpoll_user` has access, the `votes` table is present, and all 20
pet names are seeded with `count = 0`.

1. Trigger Vagrant provisioning on `petpoll-db` (`vagrant provision petpoll-db`
   or the equivalent `vagrant_provision` tool call).
2. Wait for provisioning to complete without error.
3. Verify all `petpoll-db` checks from `goal-state.yaml`:
   - `postgres_running` → `active`
   - `postgres_version` → `16`
   - `petpoll_db_exists` → `petpoll`
   - `votes_row_count` → `20`
4. Take a screenshot that shows the result of:
   `SELECT pet_name, count FROM votes ORDER BY pet_name;`
   run inside `psql` on the Ubuntu VM. This screenshot is evidence that the
   database was seeded correctly.
5. Confirm the `ping_windows` check passes from `petpoll-db`. If it fails,
   stop — network connectivity is required before proceeding to Phase 3.

Milestone satisfied: Milestones 4 (Ubuntu → Windows direction) and 5.

---

## Phase 3 — App server provisioning

**Goal**: Eclipse Temurin 21 JDK is installed on `petpoll-app`, Tomcat 10.1
is running as a Windows service named `Tomcat10`, and the Tomcat default page
is accessible on port 8595.

1. Trigger Vagrant provisioning on `petpoll-app` (`vagrant provision
   petpoll-app` or the equivalent `vagrant_provision` tool call). This step
   typically takes 10–15 minutes due to the JDK and Tomcat downloads.
2. Wait for provisioning to complete without error.
3. Verify the `petpoll-app` checks from `goal-state.yaml` that apply to this
   phase:
   - `os_version` → `Windows Server 2022`
   - `ip_address` → `192.168.56.11`
   - `java_version` → `21`
   - `tomcat_service_running` → `Running`
   - `tomcat_port_open` → `200`
   - `ping_ubuntu` → `True`
4. Open Microsoft Edge on the Windows VM and navigate to
   `http://localhost:8595/`. Take a screenshot showing the Tomcat default page.
   This confirms Tomcat is serving HTTP and Edge has no setup dialogs blocking
   the view.

Milestone satisfied: Milestones 4 (Windows → Ubuntu direction) and 6.

---

## Phase 4 — Application deployment

**Goal**: `petpoll.war` is built on the host, copied to `petpoll-app`, and
deployed under the `/petpoll` context path. The application connects to
PostgreSQL on `petpoll-db` and serves the poll page.

1. On the host, build the WAR from the `webapp/` directory:
   `mvn package -DskipTests` inside `webapp/`. Confirm `webapp/target/petpoll.war`
   exists and is non-empty after the build.
2. Copy `petpoll.war` into Tomcat's `webapps/` directory on `petpoll-app`. Use
   `vm_copy_from_guest` in reverse (host → guest) or the WinRM file-transfer
   path — whichever the current vm-blackbox tool surface supports.
3. Wait for Tomcat to deploy the WAR. Poll `http://localhost:8595/petpoll/`
   via `vm_powershell` until it returns HTTP 200, or until 60 seconds elapse.
   If 60 seconds elapse without a 200 response, capture the Tomcat logs via
   `vm_powershell` and stop with a failure report.
4. Verify the remaining `petpoll-app` checks from `goal-state.yaml`:
   - `petpoll_deployed` → `200`
   - `petpoll_shows_luna` → `True`
5. Open Edge on `petpoll-app` and navigate to `http://localhost:8595/petpoll/`.
   Take a screenshot showing the poll page with all pet names visible.

Milestone satisfied: Milestones 7 and 8.

---

## Phase 5 — Functional verification

**Goal**: A vote cast via HTTP POST increments the correct row in PostgreSQL
by exactly 1, and the updated count appears on the poll page.

1. On `petpoll-db`, record the current `count` for `Luna` in the `votes`
   table:
   `SELECT count FROM votes WHERE pet_name = 'Luna';`
   Store this value as the baseline.
2. On `petpoll-app`, cast a vote for `Luna` via PowerShell:
   `Invoke-WebRequest -Uri http://localhost:8595/petpoll/vote -Method POST
   -Body "petName=Luna" -UseBasicParsing`
   Confirm the response status code is 200 or 302 (redirect after POST).
3. On `petpoll-db`, query the `count` for `Luna` again and confirm it equals
   baseline + 1.
4. On `petpoll-app`, reload `http://localhost:8595/petpoll/` and confirm the
   displayed count for `Luna` matches the database value.
5. Confirm the forwarded port on the host: `curl -s -o /dev/null -w "%{http_code}"
   http://localhost:8595/petpoll/` should return `200`.
6. Take a final screenshot of the poll page on `petpoll-app` showing the
   incremented count for `Luna`.

Milestone satisfied: Milestone 9.

---

## Evidence collection

The following artifacts constitute proof that the scenario passed. Collect all
of them before declaring success:

| Artifact | Source | What it proves |
|----------|--------|----------------|
| Screenshot: Ubuntu baseline | `petpoll-db`, Phase 1 | Clean OS state before provisioning |
| Screenshot: Windows baseline | `petpoll-app`, Phase 1 | Clean OS state, no setup dialogs |
| Screenshot: psql votes table | `petpoll-db`, Phase 2 | Database seeded with 20 pet names |
| Screenshot: Tomcat default page | `petpoll-app`, Phase 3 | Tomcat serving HTTP on port 8595 |
| Screenshot: petpoll poll page | `petpoll-app`, Phase 4 | App deployed, all 20 names visible |
| Screenshot: petpoll after vote | `petpoll-app`, Phase 5 | Luna count incremented in UI |
| `goal-state.yaml` check results | All VMs, Phases 2–5 | All structured checks passed |
| PostgreSQL count delta | `petpoll-db`, Phase 5 | Database persistence confirmed |

If any check in `goal-state.yaml` returns a value that does not match
`expected`, or if any screenshot cannot be taken because the VM is
unresponsive, the scenario has failed. Record the failing check key, the
actual value returned, and the phase in which it failed, then stop.
