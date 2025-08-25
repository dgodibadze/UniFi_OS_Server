#!/usr/bin/env bash
set -euo pipefail

# ----- config -----
UNIFI_URL="https://fw-download.ubnt.com/data/unifi-os-server/f791-linux-arm64-4.2.23-59b2566d-15db-4831-81bf-d070a37a3717.23-arm64"
EXPECTED_MD5="f30706d128495781f1fb8af355eaaa78"
DOWNLOAD_DIR="$(pwd)"

# ----- tasks -----
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

download_unifi_os_server() {
  local file="${DOWNLOAD_DIR}/$(basename "${UNIFI_URL}")"

  if [[ -s "${file}" ]]; then
    local current_md5
    current_md5="$(md5sum "${file}" | awk '{print $1}')"
    if [[ "${current_md5}" == "${EXPECTED_MD5}" ]]; then
      echo "[+] File already exists with matching MD5: ${file}" >&2
      chmod +x "${file}"   # ensure executable even when reusing
      printf '%s\n' "${file}"
      return
    else
      echo "[!] Existing file MD5 mismatch (expected ${EXPECTED_MD5}, got ${current_md5}); re-downloading…" >&2
    fi
  fi

  echo "[+] Downloading UniFi OS Server from:" >&2
  echo "    ${UNIFI_URL}" >&2
  curl -fL -o "${file}" "${UNIFI_URL}"
  chmod +x "${file}"

  local new_md5
  new_md5="$(md5sum "${file}" | awk '{print $1}')"
  if [[ "${new_md5}" != "${EXPECTED_MD5}" ]]; then
    echo "[x] Download failed: MD5 mismatch (expected ${EXPECTED_MD5}, got ${new_md5})" >&2
    exit 1
  fi

  echo "[+] Downloaded and verified: ${file}" >&2
  printf '%s\n' "${file}"
}

run_unifi_os_installer() {
  local file="$1"
  echo "[+] Running UniFi OS Server installer…" >&2
  # Automatically answer "yes" to the installer prompt(s)
  yes y | "${file}" install
}

add_user_to_group() {
  # Determine the human that invoked sudo (if any), else fallback to current user
  local invoking_user="${SUDO_USER:-$USER}"

  # Print detection info
  if [[ -n "${SUDO_USER-}" ]]; then
    echo "[+] Detected sudo-invoking user: ${SUDO_USER}" >&2
  else
    echo "[!] Script appears to have been run without sudo; current user: ${USER}" >&2
  fi

  if [[ "${invoking_user}" == "root" ]]; then
    echo "[!] Running as root with no sudo-invoking user; skipping add-to-group step." >&2
    return
  fi

  echo "[+] Adding '${invoking_user}' to 'uosserver' group…" >&2
  usermod -aG uosserver "${invoking_user}" || {
    echo "[!] Could not add '${invoking_user}' to 'uosserver' (group may not exist yet?)." >&2
    return
  }
  echo "[+] Added. '${invoking_user}' must log out and back in for group changes to apply." >&2
}

# ----- main -----
update_os
install_podman
cleanup_autoremove
unifi_file="$(download_unifi_os_server)"
run_unifi_os_installer "${unifi_file}"
add_user_to_group
echo "[+] UniFi OS Server installation complete. You can run 'uosserver help' after re-login if added to group." >&2
