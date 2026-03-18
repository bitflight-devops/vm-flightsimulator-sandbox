# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # ──────────────────────────────────────────────
  # Ubuntu VM — petpoll-db (PostgreSQL)
  # ──────────────────────────────────────────────
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box         = "ubuntu/jammy64"
    ubuntu.vm.box_version = "20240301.0.0"
    ubuntu.vm.hostname    = "petpoll-db"

    ubuntu.vm.network "private_network", ip: "192.168.56.10"

    ubuntu.vm.provider "virtualbox" do |vb|
      vb.name   = "ubuntu"
      vb.memory = 1024
      vb.cpus   = 1
    end

    ubuntu.vm.provision "shell", path: "vagrant/scripts/provision-postgres.sh"
  end

  # ──────────────────────────────────────────────
  # Windows VM — petpoll-app (Java + Tomcat)
  # ──────────────────────────────────────────────
  config.vm.define "windows" do |windows|
    windows.vm.box         = "gusztavvargadr/windows-server-2022-standard"
    windows.vm.box_version = "2202.0.2402"
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
      vb.name   = "windows"
      vb.memory = 4096
      vb.cpus   = 2
    end

    windows.vm.provision "shell",
      path:       "vagrant/scripts/provision-tomcat.ps1",
      privileged: true,
      powershell_elevated_interactive: false
  end
end
