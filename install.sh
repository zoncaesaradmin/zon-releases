#!/usr/bin/env bash

set -eu

PRODUCT="${PRODUCT:-agent}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERIFY_CHECKSUMS="${VERIFY_CHECKSUMS:-1}"
INSTALL_SERVICE="${INSTALL_SERVICE:-0}"
START_SERVICE="${START_SERVICE:-0}"
REPO_OWNER="${REPO_OWNER:-zoncaesaradmin}"
REPO_NAME="${REPO_NAME:-zon-releases}"
REPO_REF="${REPO_REF:-main}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}/releases}"
SERVICE_NAME="${SERVICE_NAME:-zon-agentd}"
SERVICE_ADDR="${SERVICE_ADDR:-:8080}"
SERVICE_LOG_FILE="${SERVICE_LOG_FILE:-/var/log/zon/zon-agentd.log}"
SERVICE_WORK_DIR="${SERVICE_WORK_DIR:-/var/lib/zon}"
SYSTEMD_UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

warn() {
  printf 'Warning: %s\n' "$1" >&2
}

section() {
  printf '\n== %s ==\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

bool_true() {
  case "${1:-0}" in
    1 | true | TRUE | yes | YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Linux)
      printf 'linux\n'
      ;;
    Darwin)
      printf 'darwin\n'
      ;;
    MINGW* | MSYS* | CYGWIN*)
      printf 'windows\n'
      ;;
    *)
      fail "Unsupported operating system: $(uname -s)"
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      printf 'amd64\n'
      ;;
    arm64 | aarch64)
      printf 'arm64\n'
      ;;
    *)
      fail "Unsupported architecture: $(uname -m)"
      ;;
  esac
}

resolve_install_name() {
  if [ -n "${BINARY_NAME:-}" ]; then
    printf '%s\n' "$BINARY_NAME"
    return
  fi

  case "$PRODUCT" in
    agent)
      printf 'zon-agentd\n'
      ;;
    *)
      fail "Unsupported PRODUCT '$PRODUCT'. Set BINARY_NAME explicitly for new products."
      ;;
  esac
}

resolve_artifact_stem() {
  case "$PRODUCT" in
    agent)
      printf 'zon-agentd\n'
      ;;
    *)
      fail "Unsupported PRODUCT '$PRODUCT'. Add artifact mapping for this product."
      ;;
  esac
}

checksums_enabled() {
  bool_true "$VERIFY_CHECKSUMS"
}

download() {
  url="$1"
  destination="$2"
  curl -fsSL "$url" -o "$destination" || fail "Download failed: $url"
}

sha256_file() {
  file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file_path" | awk '{print $NF}'
  else
    fail "No SHA-256 tool available. Install sha256sum, shasum, or openssl."
  fi
}

verify_checksum() {
  checksums_file="$1"
  artifact_file="$2"
  artifact_name="$3"

  expected_sum="$(awk -v name="$artifact_name" '$2 == name { print $1 }' "$checksums_file")"
  [ -n "$expected_sum" ] || fail "No checksum entry found for $artifact_name"
  actual_sum="$(sha256_file "$artifact_file")"

  [ "$expected_sum" = "$actual_sum" ] || fail "Checksum verification failed for $artifact_name"
}

manual_start_command() {
  case "$os" in
    windows)
      printf '"%s" -addr "%s" -log-file "%s"\n' "$target_path" "$SERVICE_ADDR" "$SERVICE_LOG_FILE"
      ;;
    *)
      printf '"%s" -addr "%s" -log-file "%s"\n' "$target_path" "$SERVICE_ADDR" "$SERVICE_LOG_FILE"
      ;;
  esac
}

manual_stop_command() {
  case "$os" in
    windows)
      printf 'taskkill /IM "%s" /F\n' "${install_name}${artifact_suffix}"
      ;;
    *)
      printf "pkill -f '%s'\n" "$target_path"
      ;;
  esac
}

print_manual_run_instructions() {
  info "Automatic service management: not configured."
  info "Start manually:"
  info "  $(manual_start_command)"
  info "Stop manually:"
  if [ "$os" = 'windows' ]; then
    info "  Close the process window, or run: $(manual_stop_command)"
  else
    info "  Press Ctrl-C if running in the foreground, or run: $(manual_stop_command)"
  fi
}

install_binary() {
  source_file="$1"
  target_file="$2"
  target_dir="$(dirname "$target_file")"
  temp_target="${target_file}.tmp.$$"

  mkdir -p "$target_dir" 2>/dev/null || fail "Cannot create $target_dir. Try INSTALL_DIR=\$HOME/.local/bin."

  if [ -f "$target_file" ] && [ "$(sha256_file "$source_file")" = "$(sha256_file "$target_file")" ]; then
    binary_changed=0
    binary_action='unchanged'
    info "Binary already up to date at ${target_file}"
    return
  fi

  if [ -f "$target_file" ]; then
    binary_action='updated'
  else
    binary_action='installed'
  fi

  cp "$source_file" "$temp_target" 2>/dev/null || fail "Cannot write to $target_file. Try INSTALL_DIR=\$HOME/.local/bin."
  chmod 0755 "$temp_target" || fail "Failed to set executable permissions on $temp_target"
  mv -f "$temp_target" "$target_file" || fail "Failed to replace $target_file"
  binary_changed=1
  info "Binary ${binary_action} at ${target_file}"
}

is_root() {
  [ "$(id -u)" -eq 0 ]
}

systemd_is_available() {
  [ "$os" = 'linux' ] && command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

systemd_service_exists() {
  [ -f "$systemd_unit_path" ]
}

systemd_service_is_active() {
  systemctl is-active --quiet "$systemd_unit_name"
}

ensure_systemd_service_dirs() {
  mkdir -p "$(dirname "$SERVICE_LOG_FILE")" "$SERVICE_WORK_DIR" || fail "Failed to create service directories"
}

write_systemd_unit() {
  cat > "$systemd_unit_path" <<EOF
[Unit]
Description=Zon Agent Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${SERVICE_WORK_DIR}
ExecStart=${target_path} -addr ${SERVICE_ADDR} -log-file ${SERVICE_LOG_FILE}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

manage_linux_service() {
  service_requested=0
  service_exists=0
  service_was_active=0
  service_definition_updated=0
  service_available=0
  service_mode='manual'
  service_status='not configured'
  service_reason=''

  if bool_true "$INSTALL_SERVICE" || bool_true "$START_SERVICE"; then
    service_requested=1
  fi

  if [ "$os" != 'linux' ]; then
    service_reason="automatic service installation is only implemented on Linux systems with systemd"
    if [ "$service_requested" -eq 1 ]; then
      warn "Service installation is only implemented for Linux systems with systemd. Skipping service setup."
    fi
    return
  fi

  if ! systemd_is_available; then
    service_reason="systemd was not detected"
    if [ "$service_requested" -eq 1 ]; then
      warn "systemd was not detected. The binary was installed, but no service was configured."
    fi
    return
  fi

  service_available=1
  service_mode='systemd'

  if systemd_service_exists; then
    service_exists=1
    service_status='installed'
    if systemd_service_is_active; then
      service_was_active=1
      service_status='running'
    fi
  fi

  if [ "$service_requested" -eq 0 ] && [ "$service_exists" -eq 0 ]; then
    service_reason="systemd is available, but INSTALL_SERVICE was not requested"
    return
  fi

  if ! is_root; then
    if [ "$service_exists" -eq 1 ] && [ "$service_was_active" -eq 1 ] && [ "$binary_changed" -eq 1 ]; then
      service_reason="service restart requires root privileges"
      warn "An active ${systemd_unit_name} service was detected, but this installer is not running as root, so it could not be restarted."
      return
    fi

    if [ "$service_requested" -eq 1 ]; then
      service_reason="service setup requires root privileges"
      warn "Service setup was requested, but root privileges are required. Re-run with sudo to install or manage the service."
    fi
    return
  fi

  if bool_true "$INSTALL_SERVICE"; then
    info "Installing systemd service definition: ${systemd_unit_name}"
    ensure_systemd_service_dirs
    write_systemd_unit
    systemctl daemon-reload
    systemctl enable "$systemd_unit_name" >/dev/null
    service_exists=1
    service_definition_updated=1
    service_status='installed'
    info "Installed systemd service: ${systemd_unit_name}"
  fi

  if [ "$service_exists" -eq 1 ] && [ "$service_was_active" -eq 1 ] && { [ "$binary_changed" -eq 1 ] || [ "$service_definition_updated" -eq 1 ]; }; then
    info "Stopping active service: ${systemd_unit_name}"
    systemctl stop "$systemd_unit_name"
    info "Starting service: ${systemd_unit_name}"
    systemctl start "$systemd_unit_name"
    service_status='running'
    info "Started service: ${systemd_unit_name}"
    return
  fi

  if bool_true "$START_SERVICE"; then
    if [ "$service_exists" -eq 0 ]; then
      service_reason="START_SERVICE was requested, but no systemd service is installed"
      warn "START_SERVICE was requested, but no ${systemd_unit_name} service is installed."
      return
    fi

    info "Starting service: ${systemd_unit_name}"
    systemctl start "$systemd_unit_name"
    service_status='running'
    info "Started service: ${systemd_unit_name}"
    return
  fi

  if [ "$service_exists" -eq 1 ]; then
    if [ "$service_status" = 'installed' ]; then
      info "Service is installed but not started: ${systemd_unit_name}"
    fi
    info "Manage the service with: systemctl {start|stop|restart|status} ${systemd_unit_name}"
  fi
}

require_command curl
require_command uname
require_command awk
require_command mktemp
require_command mkdir
require_command cp
require_command chmod
require_command mv
require_command dirname
require_command id

os="$(detect_os)"
arch="$(detect_arch)"
install_name="$(resolve_install_name)"
artifact_stem="$(resolve_artifact_stem)"
artifact_suffix=''

if [ "$os" = 'windows' ]; then
  artifact_suffix='.exe'
fi

artifact_name="${artifact_stem}_${os}_${arch}${artifact_suffix}"
release_url="${BASE_URL%/}/${PRODUCT}/${VERSION}"
checksums_url="${release_url}/SHA256SUMS"
artifact_url="${release_url}/${artifact_name}"
target_path="${INSTALL_DIR%/}/${install_name}${artifact_suffix}"
systemd_unit_name="${SERVICE_NAME}.service"
systemd_unit_path="${SYSTEMD_UNIT_DIR%/}/${systemd_unit_name}"
binary_changed=0
binary_action='unknown'

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

checksums_file="${tmp_dir}/SHA256SUMS"
artifact_file="${tmp_dir}/${artifact_name}"

section "Zon Agent Installer"
info "Product: ${PRODUCT}"
info "Version: ${VERSION}"
info "Platform: ${os}/${arch}"
info "Install path: ${target_path}"
info "Resolved artifact: ${artifact_name}"
info "Download source: ${artifact_url}"

download "$checksums_url" "$checksums_file"
download "$artifact_url" "$artifact_file"

if checksums_enabled; then
  verify_checksum "$checksums_file" "$artifact_file" "$artifact_name"
  info "Checksum verified."
else
  info "Checksum verification skipped."
fi

section "Binary"
install_binary "$artifact_file" "$target_path"

section "Service"
manage_linux_service

section "Summary"
info "Binary status: ${binary_action}"
info "Binary path: ${target_path}"

if [ "$service_mode" = 'systemd' ] && [ "$service_available" -eq 1 ]; then
  info "Service manager: systemd"
  info "Service unit: ${systemd_unit_name}"
  info "Service status: ${service_status}"
  info "Start command: sudo systemctl start ${systemd_unit_name}"
  info "Stop command: sudo systemctl stop ${systemd_unit_name}"
  info "Restart command: sudo systemctl restart ${systemd_unit_name}"
  info "Status command: sudo systemctl status ${systemd_unit_name}"
else
  if [ -n "$service_reason" ]; then
    info "Service setup note: ${service_reason}"
  fi
  print_manual_run_instructions
fi

info "Help command: ${install_name}${artifact_suffix} --help"
info "Logs: direct runs write to your terminal; service-managed runs write to service logs."
