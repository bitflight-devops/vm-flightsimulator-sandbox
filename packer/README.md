# Packer Templates

## These templates are optional

The `Vagrantfile` in the repository root uses publicly available boxes from
Vagrant Cloud by default:

| VM | Box | Version |
|----|-----|---------|
| ubuntu | `ubuntu/jammy64` | 20240301.0.0 |
| windows | `gusztavvargadr/windows-server-2022-standard` | 2202.0.2402 |

`vagrant up` downloads these boxes automatically. No Packer build is needed
for the primary workflow.

## When to use these templates

Build a custom box when:

- **Air-gapped environment** — Vagrant Cloud is unreachable and you need to
  host boxes on an internal server.
- **Custom base image** — you want packages, configuration, or OS hardening
  baked into the base image rather than applied at `vagrant up` time.
- **Pinned ISO** — you need to reproduce a build from a specific ISO image
  rather than whatever Vagrant Cloud serves.

## Prerequisites

| Tool | Minimum version |
|------|-----------------|
| [Packer](https://developer.hashicorp.com/packer/install) | 1.10.0 |
| [VirtualBox](https://www.virtualbox.org/wiki/Downloads) | 7.0 |

## Building the Ubuntu box

```sh
cd packer/ubuntu
packer init .
packer build ubuntu.pkr.hcl
```

Output: `packer/ubuntu/output/ubuntu-jammy64-custom.box`

The ISO (~1.6 GB) is downloaded from `releases.ubuntu.com`. Build time is
roughly 15–25 minutes depending on hardware and network speed.

### Ubuntu build variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ubuntu_version` | `22.04.4` | Release version string (informational). |
| `iso_url` | Ubuntu CDN URL | Override for a local ISO mirror. |
| `iso_checksum` | SHA-256 of 22.04.4 | Update when using a different ISO. |
| `cpus` | `2` | vCPUs allocated during build. |
| `memory_mb` | `2048` | RAM in MiB allocated during build. |
| `disk_size_mb` | `40960` | Disk size in MiB (40 GiB). |

Example with a local mirror:

```sh
packer build \
  -var "iso_url=http://mirror.example.com/ubuntu-22.04.4-live-server-amd64.iso" \
  -var "iso_checksum=sha256:<your-checksum>" \
  ubuntu.pkr.hcl
```

## Building the Windows box

> **ISO checksum required.** Microsoft refreshes the evaluation ISO at the
> same URL without changing the filename. Always compute the checksum from
> your downloaded file and pass it explicitly.

### Step 1 — Download the ISO

The template uses the official Microsoft evaluation redirect:

```
https://go.microsoft.com/fwlink/p/?LinkID=2195280
```

Download it with your browser or `curl -L -o windows-server-2022-eval.iso "<url>"`.

### Step 2 — Compute the checksum

```sh
sha256sum windows-server-2022-eval.iso
# example output:
# 3e4fa961b3a1a...  windows-server-2022-eval.iso
```

### Step 3 — Build

```sh
cd packer/windows
packer init .
packer build \
  -var "windows_iso_url=/path/to/windows-server-2022-eval.iso" \
  -var "windows_iso_checksum=sha256:<output-from-step-2>" \
  windows.pkr.hcl
```

Output: `packer/windows/output/windows-server-2022-custom.box`

Build time is roughly 30–60 minutes. The Windows installer takes most of
that time.

### Windows build variables

| Variable | Default | Description |
|----------|---------|-------------|
| `windows_iso_url` | Microsoft redirect URL | Override with a local ISO path. |
| `windows_iso_checksum` | `none` (required) | `sha256:<hex>` of the ISO file. |
| `cpus` | `2` | vCPUs allocated during build. |
| `memory_mb` | `4096` | RAM in MiB allocated during build. |
| `disk_size_mb` | `61440` | Disk size in MiB (60 GiB). |

## Adding a built box to Vagrant

After a successful build, register the box with Vagrant so the Vagrantfile
can reference it by name:

```sh
# Ubuntu
vagrant box add ubuntu-jammy64-custom packer/ubuntu/output/ubuntu-jammy64-custom.box

# Windows
vagrant box add windows-server-2022-custom packer/windows/output/windows-server-2022-custom.box
```

Then update the `config.vm.box` values in the `Vagrantfile` to match the
names you registered:

```ruby
# Ubuntu VM
ubuntu.vm.box = "ubuntu-jammy64-custom"

# Windows VM
windows.vm.box = "windows-server-2022-custom"
```

## Directory structure

```
packer/
├── README.md                  ← this file
├── ubuntu/
│   ├── ubuntu.pkr.hcl         ← Packer template
│   └── http/
│       ├── user-data          ← cloud-init autoinstall configuration
│       └── meta-data          ← required companion file (empty)
└── windows/
    ├── windows.pkr.hcl        ← Packer template
    └── autounattend.xml       ← Windows unattended install answer file
```
