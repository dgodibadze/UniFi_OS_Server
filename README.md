# UniFi OS Server Installer

This repository provides unattended installer scripts for deploying **UniFi OS Server** on Ubuntu/Debian Linux.  
Two variants are included:

- **`install_arm64.sh`** → for Raspberry Pi and other ARM64 devices  
- **`install_x64.sh`** → for standard Intel/AMD x86_64 servers and VMs  

Each script will:
- Install Podman runtime  
- Update and upgrade the OS (handled inside the script)  
- Download and verify the UniFi OS Server binary (with checksum validation)  
- Run the installer (auto-confirming prompts)  
- Add the invoking user to the `uosserver` group  

---

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/<YOUR-USERNAME>/unifi-os-installer.git
   cd unifi-os-installer
