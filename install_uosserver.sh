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

# ===== Detect OS family / pkg manager =====
detect_os() {
  # Outputs: OS_FAMILY (debian|rhel|fedora), PKG_MGR (apt|dnf|yum), ID, VERSION_ID, MAJOR
  local id version_id like major pkg
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    version_id="${VERSION_ID:-}"
    like="${ID_LIKE:-}"
  else
    echo "[x] Cannot detect OS (missing /etc/os-release)." >&2
    exit 1
  fi

  major="${version_id%%.*}"

  if [[ "$id" == "ubuntu" || "$id" == "debian" || "$like" =~ (ubuntu|debian) ]]; then
    echo "debian apt $id $version_id $major"; return
  fi

  if [[ "$id" == "fedora" ]]; then
    echo "fedora dnf $id $version_id $major"; return
  fi

  if [[ "$id" == "centos" || "$id" == "rocky" || "$id" == "almalinux" || "$id" == "rhel" || "$like" =~ (rhel|centos|fedora) ]]; then
    if command -v dnf >/dev/null 2>&1; then pkg="dnf"; else pkg="yum"; fi
    echo "rhel $pkg $id $version_id $major"; return
  fi

  if command -v apt >/dev/null 2>&1; then echo "debian apt $id $version_id $major"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "rhel dnf $id $version_id $major"; return; fi
  if command -v yum >/dev/null 2>&1; then echo "rhel yum $id $version_id $major"; return; fi

  echo "[x] Unsupported or unknown Linux distribution: ID=$id VERSION_ID=$version_id" >&2
  exit 1
}

ARCH="$(detect_arch)"
read -r OS_FAMILY PKG_MGR OS_ID OS_VERSION_ID OS_MAJOR <<<"$(detect_os)"
WORKDIR="$(pwd)"

echo "[i] Detected architecture: $ARCH" >&2
echo "[i] Detected distro: $OS_ID $OS_VERSION_ID ($OS_FAMILY via $PKG_MGR)" >&2

# ===== Per-arch defaults =====
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

# ===== Tasks (OS-aware) =====
update_os() {
  echo "[+] Updating OS packages…" >&2
  case "$PKG_MGR" in
    apt) export DEBIAN_FRONTEND=noninteractive; apt update; apt -y upgrade ;;
    dnf) dnf -y upgrade --refresh || dnf -y upgrade ;;
    yum) yum -y update ;;
  esac
}

ensure_net_utils() {
  echo "[+] Ensuring curl and wget are installed…" >&2
  case "$PKG_MGR" in
    apt) apt install -y curl wget ;;
    dnf) dnf install -y curl wget ;;
    yum) yum install -y curl wget ;;
  esac
}

install_podman() {
  echo "[+] Installing Podman…" >&2
  if case "$PKG_MGR" in
       apt) apt-get install -y podman ;;
       dnf) dnf install -y podman ;;
       yum) yum install -y podman ;;
     esac
  then
    :
  else
    echo "[!] Podman not in base repos; enabling upstream libcontainers…" >&2
    case "$OS_FAMILY" in
      debian)
        . /etc/os-release || true
        echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${OS_VERSION_ID:-22.04}/ /" \
          | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list >/dev/null
        curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${OS_VERSION_ID:-22.04}/Release.key" \
          | apt-key add - >/dev/null 2>&1 || true
        apt update
        apt install -y podman
        ;;
      rhel|fedora)
        local repo_path=""
        if [[ "$OS_ID" == "fedora" ]]; then
          repo_path="Fedora_${OS_MAJOR}"
        else
          case "$OS_MAJOR" in
            7) repo_path="CentOS_7" ;;
            8) repo_path="CentOS_8_Stream" ;;
            9) repo_path="CentOS_9_Stream" ;;
            *) repo_path="CentOS_9_Stream" ;;
          esac
        fi
        local repo_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${repo_path}/devel:kubic:libcontainers:stable.repo"
        echo "[i] Adding libcontainers repo: $repo_url" >&2
        curl -fsSL "$repo_url" -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo
        case "$PKG_MGR" in
          dnf) dnf clean all; dnf -y makecache; dnf install -y podman ;;
          yum) yum clean all; yum -y makecache; yum install -y podman ;;
        esac
        ;;
      *) echo "[x] Unsupported OS family for Podman fallback: $OS_FAMILY" >&2; exit 1 ;;
    esac
  fi

  # --- Extra helpers for rootless networking/storage on RHEL/Fedora family ---
  if [[ "$OS_FAMILY" == "rhel" || "$OS_FAMILY" == "fedora" ]]; then
    echo "[+] Installing slirp4netns and fuse-overlayfs (rootless support)…" >&2
    case "$PKG_MGR" in
      dnf) dnf install -y slirp4netns fuse-overlayfs || true ;;
      yum) yum install -y slirp4netns fuse-overlayfs || true ;;
    esac
  fi
}

cleanup_autoremove() {
  echo "[+] Cleaning up unused packages…" >&2
  case "$PKG_MGR" in
    apt) apt -y autoremove || true; apt -y autoclean || true ;;
    dnf) dnf -y autoremove || true; dnf -y clean all || true ;;
    yum) yum -y clean all || true ;;
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

  echo "[+] Downloading UniFi OS Server:" >&2
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
update_os
ensure_net_utils
install_podman
cleanup_autoremove
unifi_file="$(download_unifi)"
run_installer "$unifi_file"
add_user_to_group
echo "[+] UniFi OS Server installation complete." >&2
