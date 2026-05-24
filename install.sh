#!/usr/bin/env bash

set -eu

PRODUCT="${PRODUCT:-agent}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERIFY_CHECKSUMS="${VERIFY_CHECKSUMS:-1}"
REPO_OWNER="${REPO_OWNER:-zoncaesaradmin}"
REPO_NAME="${REPO_NAME:-zon-releases}"
REPO_REF="${REPO_REF:-main}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}/releases}"

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
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
  case "$VERIFY_CHECKSUMS" in
    0 | false | FALSE | no | NO)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

download() {
  url="$1"
  destination="$2"
  curl -fsSL "$url" -o "$destination" || fail "Download failed: $url"
}

verify_checksum() {
  checksums_file="$1"
  artifact_file="$2"
  artifact_name="$3"

  expected_sum="$(awk -v name="$artifact_name" '$2 == name { print $1 }' "$checksums_file")"
  [ -n "$expected_sum" ] || fail "No checksum entry found for $artifact_name"

  if command -v sha256sum >/dev/null 2>&1; then
    actual_sum="$(sha256sum "$artifact_file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual_sum="$(shasum -a 256 "$artifact_file" | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    actual_sum="$(openssl dgst -sha256 "$artifact_file" | awk '{print $NF}')"
  else
    fail "No SHA-256 tool available. Install sha256sum, shasum, or openssl."
  fi

  [ "$expected_sum" = "$actual_sum" ] || fail "Checksum verification failed for $artifact_name"
}

install_binary() {
  source_file="$1"
  target_file="$2"

  mkdir -p "$INSTALL_DIR" 2>/dev/null || fail "Cannot create $INSTALL_DIR. Try INSTALL_DIR=\$HOME/.local/bin."
  cp "$source_file" "$target_file" 2>/dev/null || fail "Cannot write to $target_file. Try INSTALL_DIR=\$HOME/.local/bin."
  chmod 0755 "$target_file" || fail "Failed to set executable permissions on $target_file"
}

require_command curl
require_command uname
require_command awk
require_command mktemp
require_command mkdir
require_command cp
require_command chmod

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

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

checksums_file="${tmp_dir}/SHA256SUMS"
artifact_file="${tmp_dir}/${artifact_name}"

info "Installing ${PRODUCT}:${VERSION}"
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

install_binary "$artifact_file" "$target_path"

info "Installed to ${target_path}"
info "Example run: ${install_name}${artifact_suffix} --help"
info "Logs: direct runs write to your terminal; service-managed runs write to service logs."
