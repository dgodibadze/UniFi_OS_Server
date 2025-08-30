# UniFi OS Server Installer

This repository provides a modular, cross-distro installation workflow for **UniFi OS Server** on Debian/Ubuntu, Fedora, CentOS, Rocky Linux, AlmaLinux, and similar distributions.  
It supports both **arm64** (e.g. Raspberry Pi) and **amd64/x86_64** architectures.

---

## Structure

The installation is split into three modular scripts:

1. **`00-deps.sh`**  
   - Detects OS family and package manager.  
   - Updates OS and installs required dependencies (`curl`, `wget`, `podman`).  
   - On Fedora/RHEL: ensures `slirp4netns` and `fuse-overlayfs` are present.  
   - Chains into `10-install-uos.sh`.

2. **`10-install-uos.sh`**  
   - Detects system architecture.  
   - Downloads the appropriate UniFi OS Server binary (arm64 or amd64).  
   - Verifies the download via **MD5 checksum**.  
   - Uses `pv` (if installed) for a throttled progress bar (1s refresh).  
   - Skips installation if the same version is already installed.  
   - Adds the invoking user to the `uosserver` group.  
   - Chains into `20-firewall-uos.sh`.

3. **`20-firewall-uos.sh`**  
   - Asks the user whether to open UniFi OS Server ports.  
   - If confirmed, adds **IPv4-only** rules at the top of the firewall stack using:  
     - `firewalld` (rich rules, priority -100)  
     - `ufw` (insert at rule 1)  
     - `iptables` (insert at INPUT 1)  
   - Ports opened:  
     - UDP: `3478`  
     - TCP: `5005, 5514, 6789, 8080, 8444, 8880, 8881, 8882, 9543, 10003, 11443`

---

## Usage

### One-liner (using curl)
```bash
curl -fsSL https://yourdomain.com/uos | sudo bash
