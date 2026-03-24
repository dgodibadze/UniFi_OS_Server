#!/usr/bin/env bash
set -euo pipefail

# ===== UniFi OS Server — Universal Linux Installer =====
# Supports: Debian/Ubuntu, RHEL/Fedora/CentOS, Arch, openSUSE
# Architectures: ARM64, AMD64

# ===== Detect architecture =====
detect_arch() {
  case "$(uname -m)" in
    aarch64) printf 'arm64\n' ;;
    x86_64)  printf 'amd64\n' ;;
    *)
      echo "[x] Unsupported architecture: $(uname -m)" >&2
      echo "    Supported: arm64 (aarch64), amd64 (x86_64)" >&2
      exit 1
      ;;
  esac
}

# ===== Detect package manager =====
detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt\n'
  elif command -v dnf >/dev/null 2>&1; then
    printf 'dnf\n'
  elif command -v yum >/dev/null 2>&1; then
    printf 'yum\n'
  elif command -v pacman >/dev/null 2>&1; then
    printf 'pacman\n'
  elif command -v zypper >/dev/null 2>&1; then
    printf 'zypper\n'
  else
    echo "[x] No supported package manager found." >&2
    echo "    Supported: apt, dnf, yum, pacman, zypper" >&2
    exit 1
  fi
}

ARCH="$(detect_arch)"
PKG_MGR="$(detect_pkg_manager)"
WORKDIR="$(pwd)"

# ===== Per-arch download URLs and checksums (v5.0.6) =====
UNIFI_URL_ARM64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/df5b-linux-arm64-5.0.6-f35e944c-f4b6-4190-93a8-be61b96c58f4.6-arm64"
MD5_ARM64_DEFAULT="ebf8b6d9d0f12ab40ade1df88017ddbc"

UNIFI_URL_AMD64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/1856-linux-x64-5.0.6-33f4990f-6c68-4e72-9d9c-477496c22450.6-x64"
MD5_AMD64_DEFAULT="610b385c834bad7c4db00c29e2b8a9f1"

# Allow overrides via environment variables
UNIFI_URL_ARM64="${UNIFI_URL_ARM64:-$UNIFI_URL_ARM64_DEFAULT}"
MD5_ARM64="${MD5_ARM64:-$MD5_ARM64_DEFAULT}"
UNIFI_URL_AMD64="${UNIFI_URL_AMD64:-$UNIFI_URL_AMD64_DEFAULT}"
MD5_AMD64="${MD5_AMD64:-$MD5_AMD64_DEFAULT}"

case "$ARCH" in
  arm64) UNIFI_URL="$UNIFI_URL_ARM64"; EXPECTED_MD5="$MD5_ARM64" ;;
  amd64) UNIFI_URL="$UNIFI_URL_AMD64"; EXPECTED_MD5="$MD5_AMD64" ;;
esac

# ===== Package manager helpers =====
pkg_update() {
  echo "[+] Updating package index…" >&2
  case "$PKG_MGR" in
    apt)     export DEBIAN_FRONTEND=noninteractive; apt-get update ;;
    dnf)     dnf check-update || true ;;
    yum)     yum check-update || true ;;
    pacman)  pacman -Sy --noconfirm ;;
    zypper)  zypper --non-interactive refresh ;;
  esac
}

pkg_upgrade() {
  echo "[+] Upgrading system packages…" >&2
  case "$PKG_MGR" in
    apt)     apt-get upgrade -y ;;
    dnf)     dnf upgrade -y ;;
    yum)     yum upgrade -y ;;
    pacman)  pacman -Syu --noconfirm ;;
    zypper)  zypper --non-interactive update ;;
  esac
}

pkg_install() {
  local pkg="$1"
  echo "[+] Installing $pkg…" >&2
  case "$PKG_MGR" in
    apt)     apt-get install -y "$pkg" ;;
    dnf)     dnf install -y "$pkg" ;;
    yum)     yum install -y "$pkg" ;;
    pacman)  pacman -S --noconfirm --needed "$pkg" ;;
    zypper)  zypper --non-interactive install "$pkg" ;;
  esac
}

# ===== Tasks =====
update_system() {
  pkg_update
  pkg_upgrade
}

ensure_dependencies() {
  for dep in curl wget; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      pkg_install "$dep"
    fi
  done
}

install_podman() {
  if command -v podman >/dev/null 2>&1; then
    echo "[+] Podman is already installed: $(podman --version)" >&2
    return
  fi

  echo "[+] Installing Podman…" >&2
  case "$PKG_MGR" in
    apt)
      if ! apt-get install -y podman 2>/dev/null; then
        echo "[!] Podman not in default repos. Adding upstream libcontainers repo…" >&2
        if [ -f /etc/os-release ]; then . /etc/os-release; fi
        local version_id="${VERSION_ID:-22.04}"
        echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${version_id}/ /" \
          | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list >/dev/null
        curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${version_id}/Release.key" \
          | apt-key add - >/dev/null 2>&1 || true
        apt-get update
        apt-get install -y podman
      fi
      ;;
    dnf|yum)
      pkg_install podman
      ;;
    pacman)
      pkg_install podman
      ;;
    zypper)
      pkg_install podman
      ;;
  esac
}

cleanup_packages() {
  echo "[+] Cleaning up unused packages…" >&2
  case "$PKG_MGR" in
    apt)     apt-get autoremove -y || true; apt-get autoclean -y || true ;;
    dnf)     dnf autoremove -y || true ;;
    yum)     yum autoremove -y || true ;;
    pacman)  pacman -Sc --noconfirm || true ;;
    zypper)  zypper --non-interactive clean ;;
  esac
}

download_unifi() {
  local file="${WORKDIR}/$(basename "${UNIFI_URL}")"

  if [[ -s "$file" ]]; then
    local current_md5
    current_md5="$(md5sum "$file" | awk '{print $1}')"
    if [[ "$current_md5" == "$EXPECTED_MD5" ]]; then
      echo "[+] Using existing verified file: $file" >&2
      chmod +x "$file"
      printf '%s\n' "$file"
      return
    else
      echo "[!] Existing file MD5 mismatch (expected $EXPECTED_MD5, got $current_md5). Re-downloading…" >&2
    fi
  fi

  echo "[+] Downloading UniFi OS Server v5.0.6 ($ARCH):" >&2
  echo "    $UNIFI_URL" >&2
  curl -fsSL -o "$file" "$UNIFI_URL"
  chmod +x "$file"

  local new_md5
  new_md5="$(md5sum "$file" | awk '{print $1}')"
  if [[ "$new_md5" != "$EXPECTED_MD5" ]]; then
    echo "[x] Download failed: MD5 mismatch (expected $EXPECTED_MD5, got $new_md5)" >&2
    exit 1
  fi

  echo "[+] Downloaded and verified: $file" >&2
  printf '%s\n' "$file"
}

run_installer() {
  local file="$1"
  echo "[+] Running UniFi OS Server installer (auto-confirm)…" >&2
  yes y | "$file" install
}

add_user_to_group() {
  local invoking_user="${SUDO_USER:-$USER}"

  if [[ -n "${SUDO_USER-}" ]]; then
    echo "[+] Detected sudo-invoking user: $SUDO_USER" >&2
  else
    echo "[!] Script appears to be running without sudo; current user: $USER" >&2
  fi

  if [[ "$invoking_user" == "root" ]]; then
    echo "[!] Running as root without a sudo-invoking user; skipping group assignment." >&2
    return
  fi

  echo "[+] Adding '$invoking_user' to 'uosserver' group…" >&2
  usermod -aG uosserver "$invoking_user" || {
    echo "[!] Could not add '$invoking_user' to 'uosserver' (group may not exist yet?)." >&2
    return
  }
  echo "[+] Added. User must log out/in (or reboot) for membership to apply." >&2
}

# ===== Main =====
echo "========================================" >&2
echo " UniFi OS Server — Universal Installer" >&2
echo "========================================" >&2
echo "[i] Architecture : $ARCH" >&2
echo "[i] Package mgr  : $PKG_MGR" >&2
echo "" >&2

update_system
ensure_dependencies
install_podman
cleanup_packages
unifi_file="$(download_unifi)"
run_installer "$unifi_file"
add_user_to_group

echo "" >&2
echo "[+] UniFi OS Server installation complete." >&2
echo "[i] Log out and back in for group changes to take effect." >&2
