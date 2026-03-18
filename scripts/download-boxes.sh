#!/usr/bin/env bash
set -euo pipefail

# download-boxes.sh — populate ~/vagrant-box-vault/ with the two base boxes.
# Downloads each box only if it is not already present.
# Re-run at any time; existing files are skipped.
#
# Box vault is permanent storage — never auto-cleaned.
# Vagrant uses vault files via file:// URL so subsequent vagrant up requires no download.

VAULT_DIR="${HOME}/vagrant-box-vault"

UBUNTU_URL="https://vagrantcloud.com/ubuntu/boxes/jammy64/versions/20240301.0.0/providers/virtualbox/amd64/vagrant.box"
UBUNTU_FILE="ubuntu-jammy64-20240301.0.0.box"
UBUNTU_SIZE_HINT="~700 MB"

WINDOWS_URL="https://vagrantcloud.com/gusztavvargadr/boxes/windows-server-2022-standard/versions/2202.0.2402/providers/virtualbox/amd64/vagrant.box"
WINDOWS_FILE="windows-server-2022-standard-2202.0.2402.box"
WINDOWS_SIZE_HINT="~6 GB"

echo "==> Box vault: ${VAULT_DIR}"
mkdir -p "${VAULT_DIR}"

# ── Ubuntu box ──────────────────────────────────────────────────────────────
echo ""
echo "==> Ubuntu box: ${UBUNTU_FILE}"
if [[ -f "${VAULT_DIR}/${UBUNTU_FILE}" ]]; then
	echo "    already cached — skipping download"
else
	echo "    estimated size: ${UBUNTU_SIZE_HINT}"
	echo "    downloading from Vagrant Cloud..."
	curl -L --progress-bar \
		-o "${VAULT_DIR}/${UBUNTU_FILE}.tmp" \
		"${UBUNTU_URL}"
	mv "${VAULT_DIR}/${UBUNTU_FILE}.tmp" "${VAULT_DIR}/${UBUNTU_FILE}"
	echo "    download complete"
	echo -n "    sha256: "
	sha256sum "${VAULT_DIR}/${UBUNTU_FILE}" | awk '{print $1}'
fi

# ── Windows box ─────────────────────────────────────────────────────────────
echo ""
echo "==> Windows box: ${WINDOWS_FILE}"
if [[ -f "${VAULT_DIR}/${WINDOWS_FILE}" ]]; then
	echo "    already cached — skipping download"
else
	echo "    estimated size: ${WINDOWS_SIZE_HINT}"
	echo "    downloading from Vagrant Cloud..."
	curl -L --progress-bar \
		-o "${VAULT_DIR}/${WINDOWS_FILE}.tmp" \
		"${WINDOWS_URL}"
	mv "${VAULT_DIR}/${WINDOWS_FILE}.tmp" "${VAULT_DIR}/${WINDOWS_FILE}"
	echo "    download complete"
	echo -n "    sha256: "
	sha256sum "${VAULT_DIR}/${WINDOWS_FILE}" | awk '{print $1}'
fi

# ── Storage report ───────────────────────────────────────────────────────────
echo ""
echo "==> Box vault contents:"
du -sh "${VAULT_DIR}"/*
