
# Windows Server 2022 Standard (Evaluation) custom base box builder
#
# OPTIONAL — The Vagrantfile uses the public
# `gusztavvargadr/windows-server-2022-standard` v2202.0.2402 box from Vagrant
# Cloud by default. Build this template only when:
#   - Public Vagrant Cloud is unavailable (air-gapped environments)
#   - Custom packages or configuration must be baked into the base image
#
# Prerequisites: Packer 1.10+, VirtualBox 7.0+
#
# The Windows Server 2022 evaluation ISO (~5 GB) is downloaded from Microsoft's
# official evaluation centre. The ISO checksum is NOT embedded here because
# Microsoft occasionally refreshes the evaluation ISO at the same URL without
# changing the filename. Supply the checksum explicitly on the command line:
#
#   cd packer/windows
#   packer init .
#   packer build \
#     -var "windows_iso_checksum=sha256:<actual-sha256-of-downloaded-iso>" \
#     windows.pkr.hcl
#
# To obtain the checksum:
#   sha256sum <path-to-downloaded.iso>
#
# The output box is written to packer/windows/output/windows-server-2022-custom.box
# Add to Vagrant:
#   vagrant box add windows-server-2022-custom output/windows-server-2022-custom.box

packer {
  required_version = ">= 1.10.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "windows_iso_url" {
  type        = string
  default     = "https://go.microsoft.com/fwlink/p/?LinkID=2195280"
  description = "URL of the Windows Server 2022 evaluation ISO. Override with a local path for air-gapped builds."
}

variable "windows_iso_checksum" {
  type        = string
  default     = "none"
  description = "SHA-256 checksum of the ISO, prefixed with 'sha256:'. Required. Microsoft refreshes evaluation ISOs; always compute the checksum from the downloaded file."
}

variable "winrm_username" {
  type    = string
  default = "vagrant"
}

variable "winrm_password" {
  type      = string
  default   = "vagrant"
  sensitive = true
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "disk_size_mb" {
  type    = number
  default = 61440
}

variable "output_directory" {
  type    = string
  default = "output"
}

variable "box_name" {
  type    = string
  default = "windows-server-2022-custom"
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "virtualbox-iso" "windows" {
  # VM identity
  vm_name       = "windows-server-2022-custom"
  guest_os_type = "Windows2022_64"

  # ISO
  iso_url      = var.windows_iso_url
  iso_checksum = var.windows_iso_checksum

  # Resources
  cpus      = var.cpus
  memory    = var.memory_mb
  disk_size = var.disk_size_mb

  # VirtualBox settings
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
    ["modifyvm", "{{.Name}}", "--clipboard", "disabled"],
    ["modifyvm", "{{.Name}}", "--draganddrop", "disabled"],
    # Windows benefits from APIC
    ["modifyvm", "{{.Name}}", "--apic", "on"],
    # RDP disabled — Packer communicates via WinRM only
    ["modifyvm", "{{.Name}}", "--vrde", "off"],
  ]

  # Floppy carries autounattend.xml — Windows Setup reads A:\ automatically
  floppy_files = [
    "autounattend.xml",
  ]

  # WinRM communicator — enabled by autounattend.xml FirstLogonCommands
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "120m"
  winrm_use_ssl  = false
  winrm_insecure = true

  # Boot — no special boot command needed; the floppy autounattend.xml drives setup
  boot_wait    = "3s"
  boot_command = ["<spacebar>"]

  # Shutdown
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout = "15m"

  # Output
  output_directory = "${var.output_directory}/windows-server-2022-custom"
  format           = "ovf"

  # Guest additions — mount and install during provisioning
  guest_additions_mode = "upload"
  guest_additions_path = "C:/Windows/Temp/VBoxGuestAdditions.iso"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "windows-server-2022-custom"
  sources = ["source.virtualbox-iso.windows"]

  # Install VirtualBox Guest Additions
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "Write-Host 'Installing VirtualBox Guest Additions...'",
      "Start-Process -FilePath 'D:\\VBoxWindowsAdditions-amd64.exe' -ArgumentList '/S' -Wait",
      "Write-Host 'Guest Additions installed.'",
    ]
  }

  # Mount and install Guest Additions from the uploaded ISO
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      # Mount the uploaded ISO
      "$iso = 'C:\\Windows\\Temp\\VBoxGuestAdditions.iso'",
      "if (Test-Path $iso) {",
      "  $mount = Mount-DiskImage -ImagePath $iso -PassThru",
      "  $drive = ($mount | Get-Volume).DriveLetter + ':'",
      "  Start-Process -FilePath \"$drive\\VBoxWindowsAdditions-amd64.exe\" -ArgumentList '/S' -Wait",
      "  Dismount-DiskImage -ImagePath $iso",
      "  Write-Host 'Guest Additions installed from uploaded ISO.'",
      "} else {",
      "  Write-Host 'Uploaded ISO not found; skipping Guest Additions install.'",
      "}",
    ]
  }

  # Set vagrant user password and configure WinRM for Vagrant
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      # Ensure vagrant user exists with correct password
      "net user vagrant '${var.winrm_password}' /add /y 2>$null; $LASTEXITCODE=0",
      "net localgroup Administrators vagrant /add 2>$null; $LASTEXITCODE=0",
      # Configure WinRM for Vagrant
      "Set-Item WSMan:\\localhost\\Service\\Auth\\Basic -Value $true",
      "Set-Item WSMan:\\localhost\\Service\\AllowUnencrypted -Value $true",
      "Set-Item WSMan:\\localhost\\MaxTimeoutms -Value 7200000",
      "Set-Item WSMan:\\localhost\\Shell\\MaxMemoryPerShellMB -Value 512",
      # Ensure WinRM service is set to auto-start
      "Set-Service -Name WinRM -StartupType Automatic",
      "Write-Host 'WinRM configured for Vagrant.'",
    ]
  }

  # Disable Windows Update and configure for minimal footprint
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      # Disable Windows Update service to prevent background downloads bloating the box
      "Set-Service -Name wuauserv -StartupType Disabled",
      "Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue",
      # Clean up Windows Update cache
      "Remove-Item -Path 'C:\\Windows\\SoftwareDistribution\\Download\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Write-Host 'Windows Update disabled and cache cleared.'",
    ]
  }

  # Compact the disk to reduce box size
  provisioner "powershell" {
    inline = [
      "Write-Host 'Defragmenting and zeroing free space for smaller box...'",
      "Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue",
      # SDelete-style zero fill using built-in cipher
      "cipher /w:C:",
      "Write-Host 'Disk compaction complete.'",
    ]
  }

  # Package as a Vagrant box
  post-processor "vagrant" {
    output               = "${var.output_directory}/${var.box_name}.box"
    vagrantfile_template = null
    keep_input_artifact  = false
  }
}
