# UniFi OS Server Installer (Universal)

A single, unattended installer for **UniFi OS Server** on **Debian-based Linux** (e.g., **Ubuntu**, **Raspberry Pi OS**).  
The script auto-detects CPU architecture and installs the correct package for:

- **ARM64** → Raspberry Pi / ARM servers  
- **x86_64** → Intel/AMD servers & VMs  

---

## What the script does
- Updates & upgrades the OS  
- Installs Podman  
- Downloads the correct UniFi OS Server binary  
- Verifies integrity via MD5 checksum  
- Runs the installer **without prompts** (auto-confirm)  
- Adds the invoking user to the `uosserver` group  

> ⚠️ macOS is **not supported**. This installer is intended for **Debian-based distros** only.  

---

## Installation Methods (pick ONE)

### 1) One-liner (recommended, uses your domain shortcut)
curl -fsSL https://davidgodibadze.com/uos | sudo bash

### 2) One-liner with wget (if curl is missing)
wget -qO- https://davidgodibadze.com/uos | sudo bash
