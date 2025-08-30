#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WORKDIR="$(pwd)"

# ===== Arch detection (Debian naming for consistency) =====
detect_arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
  else
    case "$(uname -m)" in
      aarch64) echo "arm64" ;;
      x86_64)  echo "amd64" ;;
      *)       echo "$(uname -m)" ;;
    esac
  fi
}

ARCH="$(detect_arch)"
echo "[i] Installer: arch=$ARCH"

# ===== Per-arch defaults & env overrides =====
UNIFI_URL_ARM64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/f791-linux-arm64-4.2.23-59b2566d-15db-4831-81bf-d070a37a3717.23-arm64"
MD5_ARM64_DEFAULT="f30706d128495781f1fb8af355eaaa78"

UNIFI_URL_AMD64_DEFAULT="https://fw-download.ubnt.com/data/unifi-os-server/8b93-linux-x64-4.2.23-158fa00b-6b2c-4cd8-94ea-e92bc4a81369.23-x64"
MD5_AMD64_DEFAULT="d0242f7bd9ca40f119df0ba90e97d72b"

UNIFI_URL_ARM64="${UNIFI_URL_ARM64:-$UNIFI_URL_ARM64_DEFAULT}"
MD5_ARM64="${MD5_ARM64:-$MD5_ARM64_DEFAULT}"
UNIFI_URL_AMD64="${UNIFI_URL_AMD64:-$UNIFI_URL_AMD64_DEFAULT}"
MD5_AMD64="${MD5_AMD64:-$MD5_AMD64_DEFAULT}"

case "$ARCH" in
  arm64) UNIFI_URL="$UNIFI_URL_ARM64"; EXPECTED_MD5="$MD5_ARM64" ;;
  amd64) UNIFI_URL="$UNIFI_URL_AMD64"; EXPECTED_MD5="$MD5_AMD64" ;;
  *) echo "[x] Unsupported architecture: $ARCH (supported: arm64, amd64)" >&2; exit 1 ;;
esac

# ===== Helpers =====
extract_target_version() {
  # First x.y.z occurrence in the URL
  printf '%s\n' "$UNIFI_URL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
}

detect_installed_version() {
  if command -v uosserver >/dev/null 2>&1; then
    (uosserver version 2>/dev/null || true)     | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 && return 0
    (uosserver --version 2>/dev/null || true)   | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 && return 0
  fi
  echo ""
}

download_unifi() {
  local file="${WORKDIR}/$(basename "${UNIFI_URL}")"

  if [[ -s "$file" ]]; then
    local cur
    cur="$(md5sum "$file" | awk '{print $1}')"
    if [[ "$cur" == "$EXPECTED_MD5" ]]; then
      echo "[+] Using existing verified file: $file"
      chmod +x "$file"
      printf '%s\n' "$file"
      return
    else
      echo "[!] Existing file MD5 mismatch (expected $EXPECTED_MD5, got $cur). Re-downloading…"
    fi
  fi

  echo "[+] Downloading UniFi OS Server:"
  echo "    $UNIFI_URL"

  if command -v pv >/dev/null 2>&1; then
    # Try to get Content-Length for pv sizing (optional)
    size="$(curl -sI "$UNIFI_URL" | awk 'tolower($1)=="content-length:" {print $2}' | tr -d '\r')"
    if [[ -n "${size:-}" ]]; then
      # Progress (refresh ~1s) with known size
      curl -fsSL "$UNIFI_URL" | pv -s "$size" -i 1 > "$file"
    else
      # Progress (refresh ~1s) without known size
      curl -fsSL "$UNIFI_URL" | pv -i 1 > "$file"
    fi
  else
    # Fallback to curl's progress bar
    curl -# -L -o "$file" "$UNIFI_URL"
  fi

  chmod +x "$file"

  local new
  new="$(md5sum "$file" | awk '{print $1}')"
  if [[ "$new" != "$EXPECTED_MD5" ]]; then
    echo "[x] MD5 mismatch (expected $EXPECTED_MD5, got $new)"; exit 1
  fi
  echo "[+] Downloaded and verified: $file"
  printf '%s\n' "$file"
}

add_user_to_group() {
  local invoking_user="${SUDO_USER:-$USER}"
  if [[ -z "$invoking_user" || "$invoking_user" == "root" ]]; then
    echo "[!] Running as root (no sudo-invoking user); skipping group assignment."
    return
  fi
  echo "[+] Adding '$invoking_user' to 'uosserver' group…"
  usermod -aG uosserver "$invoking_user" || {
    echo "[!] Could not add '$invoking_user' to 'uosserver' (group may not exist yet?)."
    return
  }
  echo "[+] Added. User must log out/in (or reboot) for membership to apply."
}

run_installer() {
  local file="$1"
  local target_ver installed_ver
  target_ver="$(extract_target_version)"
  installed_ver="$(detect_installed_version || true)"

  if [[ -n "$installed_ver" && -n "$target_ver" && "$installed_ver" == "$target_ver" ]]; then
    echo "[i] UniFi OS Server $installed_ver already installed. Skipping installer."
    return 0
  fi

  echo "[+] Running UniFi OS Server installer (auto-confirm)…"
  set +e
  local out; out="$(yes y | "$file" install 2>&1)"; local rc=$?
  set -e
  if (( rc != 0 )); then
    if printf '%s\n' "$out" | grep -qi 'same as installed'; then
      echo "[i] Installer reports same version already installed; continuing."
      return 0
    fi
    echo "$out" >&2
    echo "[x] Installer failed (rc=$rc)."; exit $rc
  fi
}

# ===== Flow =====
uos_file="$(download_unifi)"
run_installer "$uos_file"
add_user_to_group

# Offer firewall changes (IPv4 only) as a separate step
exec "${SCRIPT_DIR}/20-firewall-uos.sh"
