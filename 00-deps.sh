#!/usr/bin/env bash
set -euo pipefail

# ----- Utils -----
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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

detect_os() {
  # Outputs: OS_FAMILY (debian|rhel|fedora), PKG_MGR (apt|dnf|yum), ID, VERSION_ID, MAJOR
  local id version_id like major pkg
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"; version_id="${VERSION_ID:-}"; like="${ID_LIKE:-}"
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

  if command -v apt >/dev/null 2>&1;   then echo "debian apt $id $version_id $major"; return; fi
  if command -v dnf >/dev/null 2>&1;   then echo "rhel dnf $id $version_id $major"; return; fi
  if command -v yum >/dev/null 2>&1;   then echo "rhel yum $id $version_id $major"; return; fi

  echo "[x] Unsupported or unknown Linux distribution: ID=$id VERSION_ID=$version_id" >&2
  exit 1
}

ARCH="$(detect_arch)"
read -r OS_FAMILY PKG_MGR OS_ID OS_VERSION_ID OS_MAJOR <<<"$(detect_os)"

echo "[i] Deps: arch=$ARCH distro=$OS_ID $OS_VERSION_ID ($OS_FAMILY via $PKG_MGR)"

# ----- Update OS & ensure curl/wget -----
case "$PKG_MGR" in
  apt)
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt -y upgrade
    apt install -y curl wget
    ;;
  dnf)
    dnf -y upgrade --refresh || dnf -y upgrade
    dnf install -y curl wget
    ;;
  yum)
    yum -y update
    yum install -y curl wget
    ;;
esac

# ----- Install Podman (with libcontainers fallback if needed) -----
install_podman() {
  case "$PKG_MGR" in
    apt) apt-get install -y podman && return 0 ;;
    dnf) dnf install -y podman && return 0 ;;
    yum) yum install -y podman && return 0 ;;
  esac

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
      local repo_path
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
      echo "[i] Adding libcontainers repo: $repo_url"
      curl -fsSL "$repo_url" -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo
      case "$PKG_MGR" in
        dnf) dnf clean all; dnf -y makecache; dnf install -y podman ;;
        yum) yum clean all; yum -y makecache; yum install -y podman ;;
      esac
      ;;
    *) echo "[x] Unsupported OS family for Podman fallback: $OS_FAMILY" >&2; exit 1 ;;
  esac
}
install_podman

# ----- Fedora/RHEL rootless helpers ONLY if missing -----
if [[ "$OS_FAMILY" == "rhel" || "$OS_FAMILY" == "fedora" ]]; then
  if ! command -v slirp4netns >/dev/null 2>&1; then
    case "$PKG_MGR" in dnf) dnf install -y slirp4netns || true ;; yum) yum install -y slirp4netns || true ;; esac
  fi
  if ! command -v fuse-overlayfs >/dev/null 2>&1; then
    case "$PKG_MGR" in dnf) dnf install -y fuse-overlayfs || true ;; yum) yum install -y fuse-overlayfs || true ;; esac
  fi
fi

echo "[+] Dependencies OK."

# ----- Chain to installer -----
exec "${SCRIPT_DIR}/10-install-uos.sh"
