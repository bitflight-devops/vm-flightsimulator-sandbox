# CLAUDE.md — vm-flightsimulator-sandbox

This file is the primary instruction source for any AI working in this repository.
It contains everything needed to understand and operate the sandbox without reading external docs.

---

## Purpose

This repository is a **plugin verification harness** for the [vm-blackbox Claude Code plugin](https://github.com/bitflight-devops/vm-flightsimulator). Its job is to be cloneable at any time and produce a running petpoll web application via AI orchestration. The scenario exercises the full tool surface of the `mcp__vm-blackbox__*` tool set: VM lifecycle (`vagrant_up`, `vagrant_destroy`), GUI interaction (`vm_screenshot`, `vm_type`, `vm_key`, `vm_mouse_click`), WinRM remote execution (`vm_powershell`), infrastructure provisioning (`infra_provision_postgres`, `infra_destroy_postgres`), job tracking (`vm_job_start`, `vm_job_step`, `vm_job_complete`), recording (`vm_recording_start`, `vm_recording_stop`), and end-to-end scenario orchestration (`vm_run_scenario`). The scenario is a two-VM web application stack — a Spring Boot poll app on Windows connecting to PostgreSQL on Ubuntu — chosen because it exercises cross-VM networking, service provisioning, WAR deployment, and database state verification through observable UI and SQL checkpoints.

---

## Stack (constants)

| Constant | Value | Source |
|----------|-------|--------|
| Ubuntu base box | `ubuntu/jammy64` v20240301.0.0 | [Vagrant Cloud](https://app.vagrantup.com/ubuntu/boxes/jammy64) |
| Windows base box | `gusztavvargadr/windows-server-2022-standard` v2601.0.0 | [Vagrant Cloud](https://app.vagrantup.com/gusztavvargadr/boxes/windows-server-2022-standard) |
| Ubuntu VirtualBox VM name | `petpoll-db` | Vagrantfile `vb.name`; pass as `vm_name` to all `mcp__vm-blackbox__*` tools |
| Windows VirtualBox VM name | `petpoll-app` | Vagrantfile `vb.name`; pass as `vm_name` to all `mcp__vm-blackbox__*` tools |
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
| Ubuntu box vault filename | `ubuntu-jammy64-20240301.0.0.box` | Box vault |
| Windows box vault filename | `windows-server-2022-standard-2601.0.0.box` | Box vault |

---

## Box Vault

### Two-tier storage model

**Tier 1 — Box vault** (`~/vagrant-box-vault/`):
Permanent single copy of each base box on this machine. Never auto-cleaned. Downloaded once, reused across all evaluation runs. If this directory is lost, boxes must be re-downloaded (hours on a slow connection).

**Tier 2 — Vagrant working cache** (`~/.vagrant.d/boxes/`):
Vagrant's internal cache. Freely prunable at any time. If pruned, Vagrant reimports from the vault in seconds using the local `file://` URL — no network download needed.

### Vault filenames

| Box | Vault filename |
|-----|----------------|
| Ubuntu 22.04 | `ubuntu-jammy64-20240301.0.0.box` |
| Windows Server 2022 | `windows-server-2022-standard-2601.0.0.box` |

### How Vagrant uses the vault

The `Vagrantfile` detects `~/vagrant-box-vault/<filename>` at startup. If the file exists, it sets `box_url = "file://..."` so Vagrant imports from the local copy. If the vault file is absent, Vagrant falls back to Vagrant Cloud and downloads the box (once — the download goes into `~/.vagrant.d/boxes/`, not back into the vault).

After a `vagrant destroy` or box cache prune, re-running `vagrant up` reimports from the vault instantly.

### Populate the vault on a fresh machine

```bash
bash scripts/download-boxes.sh
```

This downloads both boxes from Vagrant Cloud into `~/vagrant-box-vault/` and skips any file that already exists.

---

## Evaluation Runs (Worktrees)

Each evaluation run is one git worktree, one numbered feature branch, and one entry in `runs/`.

### State lifecycle

```
active → completed | abandoned → cleaned
```

- **active**: worktree exists, VM may be running
- **completed**: scenario finished (pass or fail), evidence committed to the evaluation branch
- **abandoned**: run stopped early, documented in `notes:`
- **cleaned**: worktree removed, VM destroyed, `runs/vN.yaml` updated

### Start a new run

1. Check `runs/v*.yaml` for the highest N. Increment to get the new N.
2. `git switch main && git pull`
3. `git switch -c feature/evaluate-sandbox-vN && git push -u origin feature/evaluate-sandbox-vN`
4. `git worktree add ../sandbox-eval-vN feature/evaluate-sandbox-vN`
5. Create `runs/vN.yaml` with `status: active` (see schema below). Commit to main, push.
6. Work inside `../sandbox-eval-vN/`. Follow `scenario/SETUP.md` for the execution sequence.

### During a run — two categories of change

| Change type | Where to commit |
|-------------|----------------|
| Fixture bug (Vagrantfile, scripts, webapp code) | Fix in worktree → PR to main → rebase evaluation branch onto updated main |
| Run evidence (screenshots, logs, issue entries) | Commit to evaluation branch only — never to main |

### Cleanup a run (only when status is completed or abandoned)

1. Confirm `runs/vN.yaml` has `status: completed` or `status: abandoned` — never clean an active run.
2. `cd ../sandbox-eval-vN && vagrant destroy -f`
3. `cd /path/to/sandbox && git worktree remove ../sandbox-eval-vN --force`
4. Update `runs/vN.yaml`: set `status: cleaned`, set `cleaned_at` to current ISO-8601 timestamp, commit to main, push.
5. Optional: `git branch -d feature/evaluate-sandbox-vN` (keep the remote branch as history).

### Inspect state

```bash
# All runs and their current status
grep -h "status:" runs/v*.yaml

# Local worktrees
git worktree list

# Storage usage across all tiers and worktrees
du -sh ~/vagrant-box-vault/* ~/.vagrant.d/boxes/ ../sandbox-eval-*/
```

---

## Storage Tiers

| Asset | Location | Auto-clean? | Recovery cost |
|-------|----------|-------------|---------------|
| Box vault files | `~/vagrant-box-vault/` | NEVER | Re-download (hours) |
| Vagrant box cache | `~/.vagrant.d/boxes/` | YES — prune freely | Seconds (local copy from vault) |
| VirtualBox VM disks | VirtualBox storage | YES — vagrant destroy | Minutes (vagrant up) |
| Built WAR | `webapp/target/` | YES — always | Seconds (mvn package) |
| Run screenshots/logs | `../sandbox-eval-vN/` | After cleaned status | Permanent loss — archive first |
| Packer cache | `packer_cache/` | YES | Re-download ISO (hours) |
| Packer box output | `packer/*/output/` | YES | Re-run Packer (hours) |

**Before cleaning box cache**: confirm `~/vagrant-box-vault/` has both `.box` files (`ls -lh ~/vagrant-box-vault/`).

**Before removing a worktree**: commit or archive any screenshots, logs, or evidence you want to keep. Once the worktree directory is removed, that data is gone.

---

## `runs/vN.yaml` Schema

```yaml
version: N
branch: feature/evaluate-sandbox-vN
worktree_path: ../sandbox-eval-vN
status: active  # active | completed | abandoned | cleaned
created_at: "ISO-8601"
completed_at: null
cleaned_at: null
notes: ""
milestones_passed: []    # e.g. [1, 2, 3, 4, 5]
fixture_bugs_found: []   # commit SHAs of fixes merged to main during this run
evidence_archived: false # set to true once screenshots/logs are compressed and committed
```

### Field definitions

- `version`: integer N matching the filename `vN.yaml`
- `branch`: the feature branch for this evaluation run
- `worktree_path`: path to the git worktree, relative to the sandbox repo root
- `status`: current lifecycle state (see state lifecycle above)
- `created_at`: ISO-8601 timestamp when this run was started
- `completed_at`: ISO-8601 timestamp when status moved to completed or abandoned; null if active
- `cleaned_at`: ISO-8601 timestamp when worktree was removed; null until cleaned
- `notes`: free-text observations about this run
- `milestones_passed`: list of integer milestone numbers that were verified during this run
- `fixture_bugs_found`: list of commit SHAs (in the main branch) for bugs found and fixed during this run
- `evidence_archived`: boolean; set to true once screenshots and logs are committed or compressed

---

## MCP Tool Conventions

- All vagrant, VBoxManage, podman, and WinRM operations go through `mcp__vm-blackbox__*` tools. Never use raw Bash for these.
- Pass `vm_name` values exactly as defined in the constants table (`petpoll-db`, `petpoll-app`).
- Take a `vm_screenshot` before and after each milestone to produce evidence.
- Use `vm_job_start` at the beginning of a run, `vm_job_step` at each milestone, and `vm_job_complete` at the end.
- `vm_recording_start` / `vm_recording_stop` wraps the full run to produce a video artifact.
