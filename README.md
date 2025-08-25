# UniFi OS Server Installer (Universal)

A single, unattended installer for **UniFi OS Server** on **Debian-based Linux** (e.g., **Ubuntu**, **Raspberry Pi OS**).  
The script auto-detects the CPU architecture and installs the correct UniFi OS Server package:

- **ARM64** (Raspberry Pi / ARM servers)
- **x86_64** (Intel/AMD servers & VMs)

What the script does:
- Updates and upgrades the OS
- Installs Podman runtime
- Downloads the correct UniFi OS Server binary for your architecture
- Verifies integrity via MD5 checksum
- Runs the installer **without prompts** (auto-confirm)
- Adds the invoking user to the `uosserver` group

> **Note:** macOS is **not supported**. This is intended for **Debian-based** distributions only.

---

## Usage

Clone this repository and run:

```bash
sudo ./install.sh
