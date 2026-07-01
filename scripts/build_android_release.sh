#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE_SCRIPT="${ROOT_DIR}/scripts/generate_android_keystore.sh"
KEYSTORE_PATH="${ROOT_DIR}/goldencare-release.jks"
KEY_PROPERTIES_PATH="${ROOT_DIR}/key.properties"

CLEAN=false
BUILD_APK=true
BUILD_AAB=true

usage() {
  cat <<EOF
Usage: $0 [--clean] [--apk-only | --aab-only]

Options:
  --clean     Run flutter clean before building
  --apk-only  Build only release APK
  --aab-only  Build only release AAB
  -h, --help  Show this message
EOF
}

log() { echo "[build_android_release] $*"; }
err() { echo "[build_android_release][ERROR] $*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --clean)
        CLEAN=true
        shift 1
        ;;
      --apk-only)
        BUILD_APK=true
        BUILD_AAB=false
        shift 1
        ;;
      --aab-only)
        BUILD_APK=false
        BUILD_AAB=true
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

ensure_signing() {
  if [[ ! -f "${KEYSTORE_PATH}" || ! -f "${KEY_PROPERTIES_PATH}" ]]; then
    log "Signing files missing; generating keystore"
    "${KEYSTORE_SCRIPT}"
  fi
}

main() {
  parse_args "$@"
  cd "${ROOT_DIR}"

  if ! command -v flutter >/dev/null 2>&1; then
    err "flutter is required but not found on PATH."
    exit 2
  fi

  if [[ ! -x "${KEYSTORE_SCRIPT}" ]]; then
    chmod +x "${KEYSTORE_SCRIPT}" || true
  fi

  ensure_signing

  if [[ "${CLEAN}" == "true" ]]; then
    log "Running flutter clean"
    flutter clean
  fi

  log "Running flutter pub get"
  flutter pub get

  if [[ "${BUILD_APK}" == "true" ]]; then
    log "Building release APK"
    flutter build apk --release
    log "Release APK generated at build/app/outputs/flutter-apk/app-release.apk"
  fi

  if [[ "${BUILD_AAB}" == "true" ]]; then
    log "Building release App Bundle"
    flutter build appbundle --release
    log "Release AAB generated at build/app/outputs/bundle/release/app-release.aab"
  fi
}

main "$@"
