#!/usr/bin/env bash
set -euo pipefail

# check-storage.sh — report storage state across all tiers used by the sandbox.
# Run at any time to see what is taking space and what is safe to prune.

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # no colour

echo "============================================================"
echo "  vm-flightsimulator-sandbox — storage report"
echo "  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"

# ── Disk free ────────────────────────────────────────────────────────────────
echo ""
echo "── Disk free (home partition) ──────────────────────────────"
df -h ~

# Warn if disk free < 10 GB (10485760 KB)
FREE_KB=$(df ~ | awk 'NR==2 {print $4}')
if [[ "${FREE_KB}" -lt 10485760 ]]; then
	echo -e "${RED}WARNING: less than 10 GB free on home partition — risk of provisioning failure${NC}"
fi

# ── Box vault ────────────────────────────────────────────────────────────────
echo ""
echo "── Box vault (~/vagrant-box-vault/) — NEVER auto-clean ────"
VAULT_DIR="${HOME}/vagrant-box-vault"
if [[ -d "${VAULT_DIR}" ]]; then
	du -sh "${VAULT_DIR}" 2>/dev/null || echo "  (empty or inaccessible)"
	echo "  Files:"
	find "${VAULT_DIR}" -maxdepth 1 -type f -printf '    %-50f %s bytes\n' 2>/dev/null || echo "    (none)"
else
	echo -e "${YELLOW}  ~/vagrant-box-vault/ does not exist — run: bash scripts/download-boxes.sh${NC}"
fi

# ── Vagrant box cache ────────────────────────────────────────────────────────
echo ""
echo "── Vagrant box cache (~/.vagrant.d/boxes/) — safe to prune ─"
VAGRANT_BOXES="${HOME}/.vagrant.d/boxes"
if [[ -d "${VAGRANT_BOXES}" ]]; then
	du -sh "${VAGRANT_BOXES}" 2>/dev/null || echo "  (empty)"
	echo "  Boxes:"
	find "${VAGRANT_BOXES}" -maxdepth 1 -mindepth 1 -printf '    %f\n' 2>/dev/null || echo "    (none)"
else
	echo "  ~/.vagrant.d/boxes/ does not exist"
fi

# ── VirtualBox VMs ───────────────────────────────────────────────────────────
echo ""
echo "── VirtualBox VMs (~/VirtualBox VMs/) ─────────────────────"
VBOX_VMS="${HOME}/VirtualBox VMs"
if [[ -d "${VBOX_VMS}" ]]; then
	du -sh "${VBOX_VMS}" 2>/dev/null || echo "  (empty)"
else
	echo "  ~/VirtualBox VMs/ does not exist"
fi

# ── Sandbox worktrees ────────────────────────────────────────────────────────
echo ""
echo "── Sandbox evaluation worktrees (../sandbox-eval-*/) ──────"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
PARENT_DIR="$(dirname "${REPO_DIR}")"
WORKTREES=("${PARENT_DIR}"/sandbox-eval-*)
FOUND_WORKTREES=false
for WT in "${WORKTREES[@]}"; do
	if [[ -d "${WT}" ]]; then
		FOUND_WORKTREES=true
		du -sh "${WT}" 2>/dev/null | awk '{printf "  %-50s %s\n", $2, $1}'
	fi
done
if [[ "${FOUND_WORKTREES}" == "false" ]]; then
	echo "  (no sandbox-eval-* worktrees found)"
fi

# ── Packer artifacts ─────────────────────────────────────────────────────────
echo ""
echo "── Packer artifacts ────────────────────────────────────────"
PACKER_CACHE="${REPO_DIR}/packer_cache"
if [[ -d "${PACKER_CACHE}" ]]; then
	du -sh "${PACKER_CACHE}" 2>/dev/null | awk '{printf "  packer_cache/: %s\n", $1}'
else
	echo "  packer_cache/: not present"
fi
for OUTPUT_DIR in "${REPO_DIR}"/packer/*/output; do
	if [[ -d "${OUTPUT_DIR}" ]]; then
		RELATIVE="${OUTPUT_DIR##"${REPO_DIR}"/}"
		du -sh "${OUTPUT_DIR}" 2>/dev/null | awk -v d="${RELATIVE}" '{printf "  %s: %s\n", d, $1}'
	fi
done

# ── Maven build output ───────────────────────────────────────────────────────
echo ""
echo "── Maven build output (webapp/target/) ─────────────────────"
TARGET_DIR="${REPO_DIR}/webapp/target"
if [[ -d "${TARGET_DIR}" ]]; then
	du -sh "${TARGET_DIR}" 2>/dev/null | awk '{printf "  webapp/target/: %s\n", $1}'
	if [[ -f "${TARGET_DIR}/petpoll.war" ]]; then
		find "${TARGET_DIR}" -maxdepth 1 -name 'petpoll.war' -printf '  petpoll.war: %s bytes\n'
	fi
else
	echo "  webapp/target/: not present (run: cd webapp && mvn package -DskipTests)"
fi

echo ""
echo "============================================================"
echo "  Prune safely: ~/.vagrant.d/boxes/ (vault reimports in seconds)"
echo "  Never prune:  ~/vagrant-box-vault/ (requires re-download)"
echo "============================================================"
