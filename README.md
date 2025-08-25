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
```bash
curl -fsSL https://davidgodibadze.com/uos | sudo bash
```

### 2) One-liner with `wget` (if `curl` is missing)
```bash
wget -qO- https://davidgodibadze.com/uos | sudo bash
```

### 3) Direct from GitHub Raw (fallback if domain is unavailable)
```bash
curl -fsSL https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh | sudo bash
# or
wget -qO-  https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh | sudo bash
```

### 4) Download script locally, then run
```bash
wget https://raw.githubusercontent.com/dgodibadze/UniFi_OS_Server/main/install_uosserver.sh -O install_uosserver.sh
sudo bash install_uosserver.sh
```

### 5) Git clone (works even if curl/wget are missing but git is installed)
```bash
git clone https://github.com/dgodibadze/UniFi_OS_Server.git
cd UniFi_OS_Server
sudo bash install_uosserver.sh
```

> ℹ️ If you truly have none of `curl`, `wget`, or `git`, install one first:
> ```bash
> sudo apt update && sudo apt install -y curl
> ```
> then use Method #1.  

---

## Post-installation

- Your user is automatically added to the `uosserver` group.  
- You must **log out and back in** (or reboot) for group changes to apply.  

Verify membership:
```bash
id <your-username>
# look for ... groups=...,<gid>(uosserver)
```

---

## Troubleshooting

- **APT lock held / unattended-upgrades running**  
  If you see:
  ```
  Could not get lock /var/lib/dpkg/lock-frontend
  ```
  it means background updates are running.  
  Wait a few minutes and re-run, or stop the service:
  ```bash
  sudo systemctl stop unattended-upgrades
  sudo dpkg --configure -a
  ```

- **Podman not found (Ubuntu 20.04 or older)**  
  Podman may not be in default repos. Either:
  - Upgrade to **Ubuntu 22.04+**, or  
  - Enable the official Podman repository before running the installer.  

---

## Notes

- Supported architectures: **arm64**, **amd64**  
- Tested on: **Ubuntu Server**, **Raspberry Pi OS (Debian-based)**  
- You can override the download URLs/MD5 manually with env vars:
  ```bash
  sudo UNIFI_URL_ARM64="<url>" MD5_ARM64="<md5>"        UNIFI_URL_AMD64="<url>" MD5_AMD64="<md5>"        bash -c "$(curl -fsSL https://davidgodibadze.com/uos)"
  ```

---

## License
MIT — use at your own risk.
