
# Ubuntu 22.04 LTS (Jammy) custom base box builder
#
# OPTIONAL — The Vagrantfile uses the public `ubuntu/jammy64` v20240301.0.0 box
# from Vagrant Cloud by default. Build this template only when:
#   - Public Vagrant Cloud is unavailable (air-gapped environments)
#   - Custom packages or configuration must be baked into the base image
#
# Prerequisites: Packer 1.10+, VirtualBox 7.0+
#
# Build:
#   cd packer/ubuntu
#   packer init .
#   packer build ubuntu.pkr.hcl
#
# The output box is written to packer/ubuntu/output/ubuntu-jammy64-custom.box
# Add to Vagrant:
#   vagrant box add ubuntu-jammy64-custom output/ubuntu-jammy64-custom.box

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

variable "ubuntu_version" {
  type        = string
  default     = "22.04.4"
  description = "Ubuntu release version (major.minor.patch)."
}

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso"
  description = "URL of the Ubuntu 22.04 server ISO. Override for local mirrors."
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:45f873de9f8cb637345d6e66a583762730bbea30277ef7b32c9c3bd6700a32b2"
  description = "SHA-256 checksum of the ISO (prefixed with 'sha256:')."
}

variable "ssh_username" {
  type    = string
  default = "vagrant"
}

variable "ssh_password" {
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
  default = 2048
}

variable "disk_size_mb" {
  type    = number
  default = 40960
}

variable "output_directory" {
  type    = string
  default = "output"
}

variable "box_name" {
  type    = string
  default = "ubuntu-jammy64-custom"
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

source "virtualbox-iso" "ubuntu" {
  # VM identity
  vm_name     = "ubuntu-jammy64-custom"
  guest_os_type = "Ubuntu_64"

  # ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Resources
  cpus      = var.cpus
  memory    = var.memory_mb
  disk_size = var.disk_size_mb

  # VirtualBox settings
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
    ["modifyvm", "{{.Name}}", "--audio", "none"],
  ]

  # HTTP server — serves the cloud-init autoinstall files
  http_directory = "http"

  # Boot command: tells the Ubuntu live-server installer where to find
  # the autoinstall configuration served by Packer's built-in HTTP server.
  boot_wait = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

  # SSH communicator
  communicator         = "ssh"
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = "60m"
  ssh_handshake_attempts = 100

  # Shutdown
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Output
  output_directory = "${var.output_directory}/ubuntu-jammy64-custom"

  # Export settings
  format = "ovf"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "ubuntu-jammy64-custom"
  sources = ["source.virtualbox-iso.ubuntu"]

  # Install VirtualBox Guest Additions dependencies and tidy up
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S apt-get update -q",
      "echo '${var.ssh_password}' | sudo -S apt-get install -y -q virtualbox-guest-utils virtualbox-guest-dkms build-essential dkms linux-headers-$(uname -r)",
      "echo '${var.ssh_password}' | sudo -S apt-get clean",
      "echo '${var.ssh_password}' | sudo -S rm -rf /var/lib/apt/lists/*",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} bash '{{ .Path }}'"
  }

  # Install the standard Vagrant insecure SSH public key so `vagrant ssh` works
  provisioner "shell" {
    inline = [
      "mkdir -p /home/${var.ssh_username}/.ssh",
      "chmod 700 /home/${var.ssh_username}/.ssh",
      "curl -fsSL https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub >> /home/${var.ssh_username}/.ssh/authorized_keys",
      "chmod 600 /home/${var.ssh_username}/.ssh/authorized_keys",
      "chown -R ${var.ssh_username}:${var.ssh_username} /home/${var.ssh_username}/.ssh",
    ]
  }

  # Configure passwordless sudo for the vagrant user (Vagrant requirement)
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_username} ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/vagrant",
      "sudo chmod 0440 /etc/sudoers.d/vagrant",
    ]
  }

  # Zero free space to shrink the exported box
  provisioner "shell" {
    inline = [
      "sudo dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true",
      "sudo rm -f /EMPTY",
      "sync",
    ]
  }

  # Package as a Vagrant box
  post-processor "vagrant" {
    output               = "${var.output_directory}/${var.box_name}.box"
    vagrantfile_template = null
    keep_input_artifact  = false
  }
}
