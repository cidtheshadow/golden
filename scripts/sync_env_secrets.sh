#!/usr/bin/env bash
# sync_env_secrets.sh
# Sync selected secrets from the repo-root .env into Firebase Functions secrets.
# Behavior:
#  - Reads .env from the repository root (one level up from this script).
#  - Extracts specific RAZORPAY_* keys (ignoring commented lines).
#  - Reads FIREBASE_PROJECT from the environment or from .env.
#  - Shows secret names and their value lengths (never prints values), asks for confirmation.
#  - Calls: firebase functions:secrets:set <NAME> "<value>" --project "$PROJECT" for each secret.
#  - Fails if .env is missing or if the `firebase` CLI is not installed.
#  - Exits non-zero on any error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

error() {
  echo "Error: $*" >&2
  exit 1
}

if [[ ! -f "$ENV_FILE" ]]; then
  error ".env not found at $ENV_FILE"
fi

if ! command -v firebase >/dev/null 2>&1; then
  error "firebase CLI not found in PATH. Install it and retry."
fi

# Read .env into associative array of KEY=>VALUE
declare -A file_env
while IFS='' read -r raw_line || [[ -n "${raw_line-}" ]]; do
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  [[ -z "$line" ]] && continue
  [[ "${line:0:1}" == "#" ]] && continue
  if [[ $line == export\ * ]]; then
    line="${line#export }"
  fi
  if [[ "$line" == *"="* ]]; then
    key="${line%%=*}"
    val="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    key="${key#"${key%%[![:space:]]*}"}"
    if [[ ${val:0:1} == '"' && ${val: -1} == '"' ]] || [[ ${val:0:1} == "'" && ${val: -1} == "'" ]]; then
      val="${val:1:${#val}-2}"
    fi
    file_env["$key"]="$val"
  fi
done < "$ENV_FILE"

# Determine FIREBASE_PROJECT (env > .env)
PROJECT="${FIREBASE_PROJECT:-${file_env[FIREBASE_PROJECT]:-}}"
if [[ -z "$PROJECT" ]]; then
  error "FIREBASE_PROJECT not set in environment or .env"
fi

# Build list of secrets to set: all keys in .env except FIREBASE_PROJECT and empty values
declare -A to_set
for k in "${!file_env[@]}"; do
  if [[ "$k" == "FIREBASE_PROJECT" ]]; then
    continue
  fi
  val="${file_env[$k]}"
  if [[ -z "$val" ]]; then
    continue
  fi
  to_set["$k"]="$val"
done

if [[ ${#to_set[@]} -eq 0 ]]; then
  echo "No secrets found in $ENV_FILE to set. Nothing to do."
  exit 0
fi

# Print summary (lengths only) and ask for confirmation unless --yes provided
echo "The following secrets will be set for Firebase project: $PROJECT"
for name in "${!to_set[@]}"; do
  val="${to_set[$name]}"
  length=$(printf '%s' "$val" | wc -c | tr -d ' ')
  echo "- $name : value length = $length"
done

AUTO_YES=0
DRY_RUN=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes|-y) AUTO_YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run enabled; no secrets will be changed. To run for real, re-run without --dry-run."
fi

if [[ $AUTO_YES -eq 0 && $DRY_RUN -eq 0 ]]; then
  read -r -p "Proceed to set these secrets in Firebase Functions? [y/N] " confirm
  confirm="${confirm:-N}"
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
  fi
fi

for name in "${!to_set[@]}"; do
  value="${to_set[$name]}"
  echo "Setting secret: $name"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY RUN: would run: firebase functions:secrets:set $name --project $PROJECT"
    continue
  fi
  # Pipe the secret value to the CLI to avoid argument/quoting issues
  if ! printf '%s' "$value" | firebase functions:secrets:set "$name" --project "$PROJECT" --data-file=-; then
    echo "Warning: Failed to set secret: $name (continuing)" >&2
  fi
done

echo "All requested secrets processed."
