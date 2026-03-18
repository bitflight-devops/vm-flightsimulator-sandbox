# Scenario: petpoll-e2e

## What this scenario proves

The petpoll-e2e scenario is a verification harness for the
[vm-blackbox Claude Code plugin](https://github.com/bitflight-devops/vm-flightsimulator).
It is not a sample application — it exists to exercise the full breadth of the
`mcp__vm-blackbox__*` tool surface in a realistic, two-VM topology:

- **VM lifecycle**: `vagrant_up`, `vagrant_provision`, `vagrant_destroy`
- **Remote execution**: `vm_powershell` for Windows commands, SSH for Linux
- **GUI observation**: `vm_screenshot` at each milestone to produce evidence
- **Cross-VM networking**: IPv4 reachability checks in both directions
- **Service provisioning**: PostgreSQL on Ubuntu, Java + Tomcat on Windows
- **Application deployment**: WAR built on host, deployed to Tomcat, served at a context path
- **Database persistence**: Vote cast via HTTP POST, count verified in PostgreSQL

A passing run proves that an AI orchestrator using the vm-blackbox plugin can
take two blank VMs from zero to a working web application stack, with
structured goal-state checks confirming each milestone and screenshots
providing human-verifiable evidence at each phase.

---

## Prerequisites

The following must be installed on the host machine before running this
scenario:

| Requirement | Minimum version | Notes |
|-------------|----------------|-------|
| VirtualBox | 7.0 | Required by Vagrant |
| Vagrant | 2.3 | Manages both VMs |
| Java (JDK) | 21 | Needed on host to build the WAR |
| Maven | 3.9 | Builds `webapp/` into `petpoll.war` |
| 20 GB free disk | — | VirtualBox VM storage |

The vm-blackbox Claude Code plugin must be installed and the MCP server must
be running. Install via:

```
claude plugin marketplace add bitflight-devops/vm-flightsimulator
```

---

## The two VMs

| VM name | OS | IP | Role |
|---------|----|----|------|
| `petpoll-db` | Ubuntu 22.04 (`ubuntu/jammy64`) | `192.168.56.10` | PostgreSQL 16 database backend |
| `petpoll-app` | Windows Server 2022 (`gusztavvargadr/windows-server-2022-standard`) | `192.168.56.11` | Eclipse Temurin 21 JDK + Apache Tomcat 10.1 + petpoll WAR |

Both VMs communicate over the `192.168.56.0/24` host-only network. The
Windows VM also forwards port `8595` to the host, so the poll page is
reachable at `http://localhost:8595/petpoll/` from the host machine.

---

## Scenario definition files

- **[`goal-state.yaml`](goal-state.yaml)** — Machine-readable end state.
  Defines the exact checks the vm-blackbox plugin runs against each VM, with
  expected values and the commands used to verify them. An AI orchestrator
  reads this file to know what "done" looks like for each milestone.

- **[`orchestration-guide.md`](orchestration-guide.md)** — Human and AI
  execution instructions. Describes the five ordered phases (pre-flight, base
  VMs, database, app server, deployment), what to observe at each step, and
  the evidence artifacts that constitute proof the scenario passed.

---

## Estimated runtime

Running the full scenario from scratch on a host with a cold cache takes
approximately **30 minutes**:

| Phase | Estimated time |
|-------|----------------|
| Pre-flight checks | 1 minute |
| Phase 1: Base VMs (`vagrant up`) | 5 minutes |
| Phase 2: Database provisioning | 3 minutes |
| Phase 3: App server provisioning | 15 minutes (JDK + Tomcat download) |
| Phase 4: WAR build + deployment | 3 minutes |
| Phase 5: Functional verification | 2 minutes |
| Evidence collection | 1 minute |

Subsequent runs after the base boxes are cached locally are significantly
faster (10–15 minutes total).
