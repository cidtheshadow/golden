#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Deploy all helper: builds web (if flutter present), deploys functions, then hosting.
# Usage: deploy_all.sh --project <project> [--skip-build] [--ensure-secret-access] [--yes]

PROJECT=""
SKIP_BUILD=false
ENSURE_SECRET_ACCESS=false
ASSUME_YES=false

usage() {
  cat <<EOF
Usage: $0 --project PROJECT [--skip-build] [--ensure-secret-access] [--yes]

Options:
  --project PROJECT           Firebase/GCP project id (or set FIREBASE_PROJECT env)
  --skip-build               Skip web build step
  --ensure-secret-access     Grant Secret Manager accessor role to functions' SA (passed to functions deploy)
  --yes                      Auto-confirm sensitive actions
  -h, --help                 Show this message
EOF
  exit 1
}

log() { echo "[deploy_all] $*"; }
err() { echo "[deploy_all][ERROR] $*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) PROJECT="$2"; shift 2 ;;
      --skip-build) SKIP_BUILD=true; shift 1 ;;
      --ensure-secret-access) ENSURE_SECRET_ACCESS=true; shift 1 ;;
      --yes) ASSUME_YES=true; shift 1 ;;
      -h|--help) usage ;;
      *) err "Unknown arg: $1"; usage ;;
    esac
  done

  if [[ -z "$PROJECT" ]]; then
    if [[ -n "${FIREBASE_PROJECT:-}" ]]; then
      PROJECT="$FIREBASE_PROJECT"
    else
      err "Project not specified. Use --project or set FIREBASE_PROJECT env."
      usage
    fi
  fi
}

build_web() {
  if [[ "$SKIP_BUILD" == true ]]; then
    log "Skipping web build as requested."
    return 0
  fi

  if command -v flutter >/dev/null 2>&1; then
    log "Found flutter; running flutter pub get and flutter build web --release"
    flutter pub get
    flutter build web --release
    log "Flutter web build finished."
  else
    log "Flutter not found; skipping web build. Ensure your web assets are built if needed."
  fi
}

deploy_hosting() {
  local retries=2
  local backoff=5
  local i=1
  while [[ $i -le $retries ]]; do
    log "Deploying hosting (attempt $i/$retries)"
    if firebase deploy --only hosting --project "$PROJECT"; then
      log "Hosting deployed successfully."
      return 0
    fi
    if [[ $i -lt $retries ]]; then
      sleep $((backoff * i))
    fi
    i=$((i+1))
  done
  err "Hosting deploy failed after $retries attempts."
  return 1
}

main() {
  parse_args "$@"

  build_web

  # Deploy functions using the functions deploy helper in this repo
  if [[ ! -x ./scripts/deploy_functions.sh ]]; then
    if [[ -f ./scripts/deploy_functions.sh ]]; then
      log "Making ./scripts/deploy_functions.sh executable"
      chmod +x ./scripts/deploy_functions.sh || true
    else
      err "Missing ./scripts/deploy_functions.sh. Create it before running this script."
      exit 2
    fi
  fi

  args=(--project "$PROJECT")
  if [[ "$ENSURE_SECRET_ACCESS" == true ]]; then
    args+=(--ensure-secret-access)
  fi
  if [[ "$ASSUME_YES" == true ]]; then
    args+=(--yes)
  fi

  log "Starting functions deploy..."
  if ! ./scripts/deploy_functions.sh "${args[@]}"; then
    err "Functions deploy failed. Aborting full deploy."
    exit 3
  fi

  log "Starting hosting deploy..."
  if ! deploy_hosting; then
    err "Hosting deploy failed."
    exit 4
  fi

  log "Full deploy completed."
}

main "$@"
