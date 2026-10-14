#!/usr/bin/env bash
set -Eeuo pipefail

# QEMU + VNC + noVNC launcher for Bliss OS.
# The default ISO source is the Bliss OS x86 SourceForge project.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${BLISS_STATE_DIR:-${SCRIPT_DIR}/.bliss-state}"
ISO_PATH="${BLISS_ISO:-${STATE_DIR}/bliss-os.iso}"
ISO_URL="${BLISS_ISO_URL:-https://sourceforge.net/projects/blissos-x86/files/latest/download}"
DISK_PATH="${BLISS_DISK:-${STATE_DIR}/bliss-os.qcow2}"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
MEMORY="${BLISS_MEMORY:-4G}"
CPUS="${BLISS_CPUS:-2}"
VNC_PORT="${BLISS_VNC_PORT:-5901}"
NOVNC_PORT="${BLISS_NOVNC_PORT:-6080}"
DISK_SIZE="${BLISS_DISK_SIZE:-32G}"
NOVNC_DIR="${STATE_DIR}/noVNC"
WEBSOCKIFY_VENV="${STATE_DIR}/websockify-venv"
QEMU_PID=""
WEBSOCKIFY_PID=""
APT_UPDATED=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Boot Bliss OS in QEMU and expose its display through noVNC at:
  http://127.0.0.1:${NOVNC_PORT}/vnc.html?autoconnect=true&resize=remote

Options:
  --iso PATH          ISO destination/path (or set BLISS_ISO)
  --download-url URL  SourceForge ISO URL (or set BLISS_ISO_URL)
  --disk PATH         qcow2 disk path (default: ${DISK_PATH})
  --memory SIZE       QEMU RAM, e.g. 4G (default: ${MEMORY})
  --cpus COUNT        QEMU CPU count (default: ${CPUS})
  --vnc-port PORT     QEMU VNC TCP port (default: ${VNC_PORT})
  --novnc-port PORT   noVNC HTTP port (default: ${NOVNC_PORT})
  --disk-size SIZE    New disk size, e.g. 32G (default: ${DISK_SIZE})
  --no-browser        Do not open a browser automatically
  -h, --help          Show this help

First boot: install Bliss OS onto the virtual disk. Later boots reuse the disk.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

apt_install() {
  command -v apt-get >/dev/null || die "Missing dependency and apt-get is unavailable to install it automatically."
  command -v sudo >/dev/null || die "Missing dependency and sudo is unavailable to install it automatically."
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    sudo apt-get update
    APT_UPDATED=1
  fi
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

require_command() {
  local cmd="$1"
  shift
  command -v "$cmd" >/dev/null && return 0
  echo "Installing missing dependency for '$cmd': $*"
  apt_install "$@"
  command -v "$cmd" >/dev/null || die "Failed to install dependency for '$cmd'."
}

cleanup() {
  trap - EXIT INT TERM
  [[ -n "${WEBSOCKIFY_PID}" ]] && kill "${WEBSOCKIFY_PID}" 2>/dev/null || true
  [[ -n "${QEMU_PID}" ]] && kill "${QEMU_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

NO_BROWSER=0
while (($#)); do
  case "$1" in
    --iso) [[ $# -ge 2 ]] || die "--iso requires a path"; ISO_PATH="$2"; shift 2 ;;
    --download-url) [[ $# -ge 2 ]] || die "--download-url requires a URL"; ISO_URL="$2"; shift 2 ;;
    --disk) [[ $# -ge 2 ]] || die "--disk requires a path"; DISK_PATH="$2"; shift 2 ;;
    --memory) [[ $# -ge 2 ]] || die "--memory requires a value"; MEMORY="$2"; shift 2 ;;
    --cpus) [[ $# -ge 2 ]] || die "--cpus requires a value"; CPUS="$2"; shift 2 ;;
    --vnc-port) [[ $# -ge 2 ]] || die "--vnc-port requires a value"; VNC_PORT="$2"; shift 2 ;;
    --novnc-port) [[ $# -ge 2 ]] || die "--novnc-port requires a value"; NOVNC_PORT="$2"; shift 2 ;;
    --disk-size) [[ $# -ge 2 ]] || die "--disk-size requires a value"; DISK_SIZE="$2"; shift 2 ;;
    --no-browser) NO_BROWSER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

require_command python3 python3 python3-venv
require_command git git
require_command curl curl ca-certificates
require_command qemu-img qemu-utils
if ! command -v "$QEMU_BIN" >/dev/null; then
  [[ "$QEMU_BIN" == "qemu-system-x86_64" ]] || die "QEMU binary '$QEMU_BIN' is missing. Install it or set QEMU_BIN to a valid binary."
  require_command qemu-system-x86_64 qemu-system-x86
fi
[[ "$VNC_PORT" =~ ^[0-9]+$ ]] || die "--vnc-port must be a number."
(( VNC_PORT >= 5900 )) || die "--vnc-port must be >= 5900."
mkdir -p "$STATE_DIR"

if [[ ! -s "$ISO_PATH" ]]; then
  command -v curl >/dev/null || die "curl is required to download Bliss OS from SourceForge."
  echo "Downloading Bliss OS from SourceForge to ${ISO_PATH}"
  curl --fail --location --progress-bar --retry 3 --user-agent "bliss-qemu-launcher" \
    --output "$ISO_PATH.part" "$ISO_URL"
  mv -- "$ISO_PATH.part" "$ISO_PATH"
fi

if [[ ! -f "$DISK_PATH" ]]; then
  command -v qemu-img >/dev/null || die "qemu-img is missing; install the QEMU utilities package."
  echo "Creating ${DISK_SIZE} virtual disk at ${DISK_PATH}"
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

if [[ ! -d "$NOVNC_DIR" ]]; then
  echo "Fetching noVNC into ${NOVNC_DIR}"
  git clone --depth 1 https://github.com/novnc/noVNC.git "$NOVNC_DIR"
fi

if [[ ! -x "${WEBSOCKIFY_VENV}/bin/websockify" ]]; then
  command -v python3 >/dev/null || die "python3 is required to install websockify."
  echo "Installing websockify into ${WEBSOCKIFY_VENV}"
  python3 -m venv "$WEBSOCKIFY_VENV"
  "${WEBSOCKIFY_VENV}/bin/pip" install --upgrade pip websockify
fi

echo "Starting websockify on 127.0.0.1:${NOVNC_PORT} -> 127.0.0.1:${VNC_PORT}"
"${WEBSOCKIFY_VENV}/bin/websockify" --web "$NOVNC_DIR" --heartbeat 30 \
  "127.0.0.1:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" &
WEBSOCKIFY_PID=$!

echo "Starting QEMU with ${MEMORY} RAM and ${CPUS} CPUs"
NOVNC_URL="http://127.0.0.1:${NOVNC_PORT}/vnc.html?autoconnect=true&resize=remote"
if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
  NOVNC_URL="https://${CODESPACE_NAME}-${NOVNC_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html?autoconnect=true&resize=remote"
fi
echo "Open: ${NOVNC_URL}"
[[ "$NO_BROWSER" -eq 1 ]] || { command -v xdg-open >/dev/null && xdg-open "${NOVNC_URL}" >/dev/null 2>&1 || true; }

"$QEMU_BIN" \
  -name bliss-os \
  -machine q35,accel=kvm:tcg \
  -cpu max \
  -smp "$CPUS" \
  -m "$MEMORY" \
  -drive "file=${DISK_PATH},format=qcow2,if=virtio" \
  -cdrom "$ISO_PATH" \
  -boot order=d,menu=on \
  -vnc "127.0.0.1:$((VNC_PORT - 5900))" \
  -device virtio-vga \
  -nic user,model=virtio \
  -rtc base=localtime \
  -no-reboot
