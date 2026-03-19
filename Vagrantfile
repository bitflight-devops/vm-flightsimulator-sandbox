# -*- mode: ruby -*-
# vi: set ft=ruby :

# Box vault — single permanent copy of each base box.
# If the vault file exists, Vagrant uses it as source (no download).
# If pruned from ~/.vagrant.d/boxes/, reimport takes seconds from the vault.
# If vault file is absent, Vagrant falls back to Vagrant Cloud (downloads once).
# To populate the vault: bash scripts/download-boxes.sh
BOX_VAULT = File.expand_path("~/vagrant-box-vault")
UBUNTU_BOX_FILE  = "ubuntu-jammy64-20240301.0.0.box"
WINDOWS_BOX_FILE = "windows-server-2022-standard-2601.0.0.box"

Vagrant.configure("2") do |config|
  # ──────────────────────────────────────────────
  # Ubuntu VM — petpoll-db (PostgreSQL)
  # ──────────────────────────────────────────────
  config.vm.define "ubuntu" do |ubuntu|
    # ubuntu/jammy64 (22.04 LTS) is intentional — Canonical stopped publishing
    # official Vagrant boxes from Ubuntu 24.04 onwards. Jammy is the newest
    # official Ubuntu Vagrant box and remains supported until April 2027.
    ubuntu_vault = "#{BOX_VAULT}/#{UBUNTU_BOX_FILE}"
    ubuntu.vm.box              = "ubuntu/jammy64"
    ubuntu.vm.box_check_update = false
    if File.exist?(ubuntu_vault)
      ubuntu.vm.box_url = "file://#{ubuntu_vault}"
    else
      ubuntu.vm.box_version = "20240301.0.0"
    end
    ubuntu.vm.hostname    = "petpoll-db"

    ubuntu.vm.network "private_network", ip: "192.168.56.10"

    ubuntu.vm.provider "virtualbox" do |vb|
      vb.name   = "petpoll-db"
      vb.memory = 1024
      vb.cpus   = 1
    end

    ubuntu.vm.provision "shell", path: "vagrant/scripts/provision-postgres.sh"
  end

  # ──────────────────────────────────────────────
  # Windows VM — petpoll-app (Java + Tomcat)
  # ──────────────────────────────────────────────
  config.vm.define "windows" do |windows|
    windows_vault = "#{BOX_VAULT}/#{WINDOWS_BOX_FILE}"
    windows.vm.box              = "gusztavvargadr/windows-server-2022-standard"
    windows.vm.box_check_update = false
    if File.exist?(windows_vault)
      windows.vm.box_url = "file://#{windows_vault}"
    else
      windows.vm.box_version = "2601.0.0"
    end
    windows.vm.hostname    = "petpoll-app"

    windows.vm.network "private_network", ip: "192.168.56.11"

    windows.vm.network "forwarded_port",
      guest:    8595,
      host:     8595,
      host_ip:  "127.0.0.1"

    windows.vm.synced_folder ".", "/vagrant",
      type: "virtualbox"

    # gusztavvargadr boxes ship with WinRM configured
    windows.vm.communicator = "winrm"
    windows.winrm.username  = "vagrant"
    windows.winrm.password  = "vagrant"

    windows.vm.provider "virtualbox" do |vb|
      vb.name   = "petpoll-app"
      vb.memory = 4096
      vb.cpus   = 2
    end

    windows.vm.provision "shell",
      path:       "vagrant/scripts/provision-tomcat.ps1",
      privileged: true,
      powershell_elevated_interactive: false
  end
end
