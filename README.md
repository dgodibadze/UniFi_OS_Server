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

### 3) Direct from GitHub Raw (fallback if domain is unavailable)
curl -fsSL https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh | sudo bash
# or
wget -qO-  https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh | sudo bash

### 4) Download script locally, then run
wget https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh -O install_uosserver.sh
sudo bash install_uosserver.sh

### 5) Git clone (works even if curl/wget are missing but git is installed)
git clone https://github.com/dgodibadze/UniFi_OS_Server.git
cd UniFi_OS_Server
sudo bash install_uosserver.sh

ℹ️ If you truly have none of curl, wget, or git, install one first:
sudo apt update && sudo apt install -y curl
