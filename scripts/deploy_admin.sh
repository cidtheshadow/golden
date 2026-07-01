#!/bin/bash
set -euo pipefail

read_dotenv_var() {
  local key="$1"
  if [[ ! -f .env ]]; then
    echo ""
    return
  fi
  local line
  line=$(grep -m1 "^${key}=" .env || true)
  line="${line#${key}=}"
  line="${line%\"}"
  line="${line#\"}"
  line="${line%\'}"
  line="${line#\'}"
  echo "$line"
}

FIREBASE_PROJECT="${FIREBASE_PROJECT:-golden-care-d4863}"

echo "🏗️  Building Admin dashboard (PRODUCTION)..."
pushd admin >/dev/null
flutter build web --release \
  --dart-define=ENVIRONMENT=production
popd >/dev/null

BUILD_FILE="admin/build/web/main.dart.js"
if [[ ! -f "$BUILD_FILE" ]]; then
  echo "Error: admin build output not found at $BUILD_FILE; build may have failed"
  exit 1
fi

echo "✅ Admin build complete; deploying Admin dashboard..."
firebase deploy --only hosting:golden-care-admin --project "$FIREBASE_PROJECT"
echo "✅ Admin dashboard deploy complete"
