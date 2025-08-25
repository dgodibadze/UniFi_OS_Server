#!/usr/bin/env bash
set -euo pipefail

# ===== Detect architecture (Debian/Ubuntu naming) =====
detect_arch() {
  local arch=""
  if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
  else
    case "$(uname -m)" in
      aarch64) arch="arm64" ;;
      x86_64)  arch="amd64" ;;
      *) arch="$(uname -m)" ;;
    esac
  fi
  printf '%s\n' "$arch"
}

ARCH="$(detect_arch)"
WORKDIR="$(pwd)"

# ===== Per-arch defaults =====
# ARM64 (Raspberry Pi / ARM servers)
UNIFI_URL_ARM64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/f791-linux-arm64-4.2.23-59b2566d-15db-4831-81bf-d070a37a3717.23-arm64"
MD5_ARM64_DEFAULT="f30706d128495781f1fb8af355eaaa78"

# x86_64 (Intel/AMD)
UNIFI_URL_AMD64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/8b93-linux-x64-4.2.23-158fa00b-6b2c-4cd8-94ea-e92bc4a81369.23-x64"
MD5_AMD64_DEFAULT="d0242f7bd9ca40f119df0ba90e97d72b"

# Allow overrides via env if needed
UNIFI_URL_ARM64="${UNIFI_URL_ARM64:-$UNIFI_URL_ARM64_DEFAULT}"
MD5_ARM64="${MD5_ARM64:-$MD5_ARM64_DEFAULT}"
UNIFI_URL_AMD64="${UNIFI_URL_AMD64:-$UNIFI_URL_AMD64_DEFAULT}"
MD5_AMD64="${MD5_AMD64:-$MD5_AMD64_DEFAULT}"

# ===== Choose URL/MD5 for this host =====
case "$ARCH" in
  arm64)
    UNIFI_URL="$UNIFI_URL_ARM64"
    EXPECTED_MD5="$MD5_ARM64"
    ;;
  amd64)
    UNIFI_URL="$UNIFI_URL_AMD64"
    EXPECTED_MD5="$MD5_AMD64"
    ;;
  *)
    echo "[x] Unsupported or unknown architecture: $ARCH" >&2
    echo "    Supported: arm64, amd64" >&2
    exit 1
    ;;
esac

# ===== Tasks =====
update_os() {
  echo "[+] Updating OS packages…" >&2
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt upgrade -y
}

install_podman() {
  echo "[+] Installing Podman…" >&2
  apt install -y podman
}

cleanup_autoremove() {
  echo "[+] Cleaning up unused packages…" >&2
  apt autoremove -y || true
  apt autoclean -y || true
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

  echo "[+] Downloading UniFi OS Server:" >&2
  echo "    $UNIFI_URL" >&2
  curl -fL -o "$file" "$UNIFI_URL"
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
echo "[i] Detected architecture: $ARCH" >&2
update_os
install_podman
cleanup_autoremove
unifi_file="$(download_unifi)"
run_installer "$unifi_file"
add_user_to_group
echo "[+] UniFi OS Server installation complete." >&2
