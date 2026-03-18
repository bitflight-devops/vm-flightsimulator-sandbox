# vm-flightsimulator-sandbox

## Purpose

This repository is a **plugin verification harness** for the [vm-blackbox Claude Code plugin](https://github.com/bitflight-devops/vm-flightsimulator). It is not simply a sample application — it exists to exercise the full breadth of the `mcp__vm-blackbox__*` tool surface: VM lifecycle (`vagrant_up`, `vagrant_destroy`), GUI interaction (`vm_screenshot`, `vm_type`, `vm_key`, `vm_mouse_click`), WinRM remote execution (`vm_powershell`), infrastructure provisioning (`infra_provision_postgres`, `infra_destroy_postgres`), and end-to-end scenario orchestration (`vm_run_scenario`). The scenario is a two-VM web application stack — a Spring Boot poll app on Windows connecting to PostgreSQL on Ubuntu — chosen because it exercises cross-VM networking, service provisioning, WAR deployment, and database state verification through observable UI and SQL checkpoints.

---

## Constants

| Constant | Value | Source |
|----------|-------|--------|
| Ubuntu base box | `ubuntu/jammy64` v20240301.0.0 | [Vagrant Cloud](https://app.vagrantup.com/ubuntu/boxes/jammy64) |
| Windows base box | `gusztavvargadr/windows-server-2022-standard` v2202.0.2402 | [Vagrant Cloud](https://app.vagrantup.com/gusztavvargadr/boxes/windows-server-2022-standard) |
| Private network subnet | `192.168.56.0/24` | Host-only adapter |
| Ubuntu VM IP | `192.168.56.10` | Static, host-only |
| Windows VM IP | `192.168.56.11` | Static, host-only |
| PostgreSQL version | 16 | Ubuntu APT |
| PostgreSQL database | `petpoll` | Application config |
| PostgreSQL user | `petpoll_user` | Application config |
| PostgreSQL password | `petpoll_pass` | Application config |
| Java distribution | Eclipse Temurin 21 LTS | [Adoptium](https://adoptium.net/) |
| Tomcat version | 10.1 | [Apache Tomcat](https://tomcat.apache.org/) |
| Spring Boot version | 3.3 | [Spring Initializr](https://start.spring.io/) |
| Application port | `8595` | Tomcat connector |
| Host forwarded port | `8595` | Vagrantfile port forward |

---

## Milestones

### Milestone 1 — Repository structure

All source files, Packer templates, Vagrantfile, provisioning scripts, and web application skeleton are committed to the repository. The repository can be cloned to a machine with VirtualBox and Vagrant installed and used immediately — no manual file creation is required before running any provisioning step.

### Milestone 2 — Ubuntu base VM

A VirtualBox VM named `ubuntu` is running, reporting Ubuntu 22.04, assigned the static IP `192.168.56.10` on the host-only network, and accessible via SSH. No application software (PostgreSQL, Java, Tomcat) has been installed.

### Milestone 3 — Windows base VM

A VirtualBox VM named `windows` is running, reporting Windows Server 2022, assigned the static IP `192.168.56.11` on the host-only network, and accessible via WinRM. Microsoft Edge launches directly to any given URL without displaying first-run setup, privacy prompt, default-browser nag, or any other interstitial dialog. No application software (Java, Tomcat) has been installed.

### Milestone 4 — Network connectivity

The Ubuntu VM at `192.168.56.10` can reach the Windows VM at `192.168.56.11` via ICMP ping, and the Windows VM at `192.168.56.11` can reach the Ubuntu VM at `192.168.56.10` via ICMP ping. Both directions succeed without packet loss.

### Milestone 5 — PostgreSQL provisioned

PostgreSQL 16 is installed and running on the Ubuntu VM. A database named `petpoll` exists. A user `petpoll_user` exists with password `petpoll_pass` and full privileges on the `petpoll` database. A table named `votes` exists in the `petpoll` database with columns `pet_name VARCHAR(50) PRIMARY KEY` and `count INTEGER NOT NULL DEFAULT 0`. All 20 pet names are present as rows with `count = 0`. PostgreSQL is configured to accept TCP connections from `192.168.56.11` on port `5432` using password authentication.

### Milestone 6 — Java and Tomcat provisioned

Eclipse Temurin 21 JDK is installed on the Windows VM and `java -version` reports a 21.x build. Apache Tomcat 10.1 is installed as a Windows service named `Tomcat10`, configured to start automatically on boot, is currently in the running state, and its default page is accessible at `http://192.168.56.11:8595/`.

### Milestone 7 — Web application built

The `petpoll` Spring Boot 3.3 application in the `webapp/` directory compiles cleanly with Maven (`mvn package -DskipTests` exits 0). A deployable WAR file exists at `webapp/target/petpoll.war`.

### Milestone 8 — Web application deployed

`petpoll.war` is deployed to Tomcat on the Windows VM under the context path `/petpoll`. The application has established a JDBC connection to PostgreSQL at `192.168.56.10:5432` using the `petpoll_user` credentials. A GET request to `http://192.168.56.11:8595/petpoll/` returns HTTP 200 and the response body contains all 20 pet names and their vote counts.

### Milestone 9 — End-to-end verification

Submitting a vote for any pet name via POST to `http://192.168.56.11:8595/petpoll/vote` increments that name's `count` column in the PostgreSQL `votes` table by exactly 1. A subsequent GET to `http://192.168.56.11:8595/petpoll/` reflects the updated count. Port `8595` on the host machine (forwarded from the Windows VM) serves the same poll page. The environment can be fully torn down (`vagrant destroy -f`) and re-provisioned (`vagrant up`) on a fresh branch, reaching Milestone 8 state again with all vote counts reset to 0.

---

## Verification checklist

- **Milestone 1**: `git clone` the repository to a directory that did not previously exist; confirm no `git status` untracked files appear and the directory tree matches the scaffold defined in this plan.
- **Milestone 2**: `vagrant ssh ubuntu -- hostname -I` includes `192.168.56.10`; `vagrant status ubuntu` shows `running`; `vm_screenshot` of the Ubuntu VM shows a login prompt or shell.
- **Milestone 3**: `vm_powershell` on the Windows VM runs `(Get-WmiObject Win32_OperatingSystem).Caption` and the result contains `Windows Server 2022`; `vm_screenshot` after launching Edge with a URL argument shows the target page with no setup dialogs visible.
- **Milestone 4**: `vm_powershell` runs `Test-Connection -ComputerName 192.168.56.10 -Count 1` and `StatusCode` is `0`; SSH on Ubuntu runs `ping -c1 192.168.56.11` and reports `1 received`.
- **Milestone 5**: `vm_powershell` runs `Invoke-WebRequest` equivalent or SSH on Ubuntu runs `psql -U petpoll_user -d petpoll -c "SELECT COUNT(*) FROM votes WHERE count = 0;"` and returns `20`.
- **Milestone 6**: `vm_powershell` runs `java -version` and the output contains `21`; `(Invoke-WebRequest http://192.168.56.11:8595/).StatusCode` returns `200`.
- **Milestone 7**: `webapp/target/petpoll.war` exists in the repository working copy after running `mvn package -DskipTests`; no compilation errors appear in Maven output.
- **Milestone 8**: `(Invoke-WebRequest http://192.168.56.11:8595/petpoll/).StatusCode` returns `200` and the response content contains `Luna`.
- **Milestone 9**: SSH on Ubuntu runs `psql -U petpoll_user -d petpoll -c "SELECT count FROM votes WHERE pet_name = 'Luna';"` before and after a POST vote to `Luna`; count increases by exactly 1. `curl http://localhost:8595/petpoll/` on the host returns the same page.

---

## Pet names

The 20 pet names pre-seeded in the `votes` table:

Luna, Bella, Max, Charlie, Cooper, Buddy, Daisy, Bailey, Milo, Molly, Cleo, Oliver, Leo, Lola, Zeus, Nala, Simba, Rocky, Rosie, Biscuit
