#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEAN=false

usage() {
  cat <<EOF
Usage: $0 [--clean]

Options:
  --clean    Run flutter clean before building
  -h, --help Show this message
EOF
}

log() { echo "[build_android_debug] $*"; }
err() { echo "[build_android_debug][ERROR] $*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --clean) CLEAN=true; shift 1 ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown argument: $1"; usage; exit 1 ;;
    esac
  done
}

main() {
  parse_args "$@"
  cd "${ROOT_DIR}"

  if ! command -v flutter >/dev/null 2>&1; then
    err "flutter is required but not found on PATH."
    exit 2
  fi

  if [[ "${CLEAN}" == "true" ]]; then
    log "Running flutter clean"
    flutter clean
  fi

  log "Running flutter pub get"
  flutter pub get

  log "Building debug APK"
  flutter build apk --debug

  log "Debug APK generated at build/app/outputs/flutter-apk/app-debug.apk"
}

main "$@"
