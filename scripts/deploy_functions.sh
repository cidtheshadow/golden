#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Robust Firebase Functions deploy helper
# Usage: deploy_functions.sh --project <project> [--ensure-secret-access] [--yes] [--retries N]

PROJECT=""
ENSURE_SECRET_ACCESS=false
ASSUME_YES=false
RETRIES=3
BACKOFF=6

usage() {
  cat <<EOF
Usage: $0 --project PROJECT [--ensure-secret-access] [--yes] [--retries N]

Options:
  --project PROJECT           Firebase/GCP project id (or set FIREBASE_PROJECT env)
  --ensure-secret-access     Grant Secret Manager accessor role to functions' SA (requires gcloud)
  --yes                      Auto-confirm sensitive actions
  --retries N                Number of deploy retries (default: ${RETRIES})
  -h, --help                 Show this message
EOF
  exit 1
}

log() { echo "[deploy_functions] $*"; }
err() { echo "[deploy_functions][ERROR] $*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) PROJECT="$2"; shift 2 ;;
      --ensure-secret-access) ENSURE_SECRET_ACCESS=true; shift 1 ;;
      --yes) ASSUME_YES=true; shift 1 ;;
      --retries) RETRIES="$2"; shift 2 ;;
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

assert_cmds() {
  for c in firebase gcloud; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err "Required command not found: $c. Install it and retry."
      exit 2
    fi
  done
}

grant_secret_accessor() {
  log "Ensuring functions service account has Secret Manager accessor role..."
  PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)') || return 1
  SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

  if [[ "$ASSUME_YES" != true ]]; then
    read -r -p "About to grant roles/secretmanager.secretAccessor to $SA on project $PROJECT. Continue? [y/N] " resp
    if [[ ! "$resp" =~ ^[Yy]$ ]]; then
      log "Aborting role grant."
      return 2
    fi
  fi

  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$SA" \
    --role="roles/secretmanager.secretAccessor" || return 1

  log "Role granted to $SA."
}

attempt_deploy() {
  local attempt=$1
  log "Deploy attempt $attempt/$RETRIES"
  if firebase deploy --only functions --project "$PROJECT"; then
    log "Functions deployed successfully."
    return 0
  else
    return 1
  fi
}

main() {
  parse_args "$@"
  assert_cmds

  # Quick secret manager check (non-fatal)
  # Older firebase CLI versions may not implement `functions:secrets:list`.
  # Prefer firebase if available and supported, otherwise fall back to gcloud.
  if command -v firebase >/dev/null 2>&1 && firebase --help 2>/dev/null | grep -q 'functions:secrets:list'; then
    CHECK_CMD=(firebase functions:secrets:list --project "$PROJECT")
  else
    CHECK_CMD=(gcloud secrets list --project "$PROJECT")
  fi

  if ! "${CHECK_CMD[@]}" >/dev/null 2>&1; then
    log "Warning: could not list secrets for project $PROJECT. Ensure Secret Manager API is enabled and you have permissions."
  fi

  if [[ "$ENSURE_SECRET_ACCESS" == true ]]; then
    if ! grant_secret_accessor; then
      err "Failed to grant secret accessor role. Use --yes to run non-interactively or ensure you have sufficient permissions."
      exit 3
    fi
    # short pause to allow IAM to propagate
    sleep 3
  fi

  local i=1
  while [[ $i -le $RETRIES ]]; do
    if attempt_deploy $i; then
      return 0
    fi

    if [[ $i -lt $RETRIES ]]; then
      sleep $((BACKOFF * i))
      log "Retrying deploy (attempt $((i+1))/$RETRIES)..."
    fi
    i=$((i+1))
  done

  err "Functions deploy failed after $RETRIES attempts."
  err "Common causes: missing Secret Manager access for runtime SA, syntax/runtime errors in functions, or missing APIs."
  err "Suggested remedial commands:"
  echo
  echo "  # List function logs (adjust name/project as needed)" 
  echo "  firebase functions:log --project $PROJECT"
  echo
  echo "  # Ensure functions' service account has Secret Manager access (requires IAM permissions):"
  echo "  $0 --project $PROJECT --ensure-secret-access --yes"
  echo
  exit 4
}

main "$@"
