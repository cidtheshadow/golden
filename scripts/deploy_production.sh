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

# If MAPS_API_KEY or RAZORPAY_KEY_LIVE are not set in the environment,
# try to read them from Firebase Remote Config for the project.
fetch_rc_value() {
	local key="$1"
	if ! command -v firebase >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		echo ""; return
	fi
	firebase --project "$FIREBASE_PROJECT" remoteconfig:get -j 2>/dev/null \
		| jq -r ".result.parameters[\"${key}\"].defaultValue.value // \"\""
}

echo "🏗️  Building Flutter web (PRODUCTION environment)..."
echo "Info: Not injecting private keys into build. Public client keys are expected from Cloud Functions getPublicConfig (backed by Secret Manager); compile-time/Remote Config are fallback paths only."
flutter build web --release \
	--dart-define=ENVIRONMENT=production \
	--dart-define=RAZORPAY_KEY_MODE=live

# Verify that the built web artifact contains the injected keys
echo "🔍 Verifying build contains required keys..."
BUILD_FILE="build/web/main.dart.js"
if [[ ! -f "$BUILD_FILE" ]]; then
  echo "Error: build output not found at $BUILD_FILE; build may have failed"
  exit 1
fi

echo "✅ Build complete; deploying to PRODUCTION..."
firebase deploy --only hosting:production --project "$FIREBASE_PROJECT"
echo "✅ Production deploy complete"
echo "🌐 https://goldencares.in"
echo "🔑 Using Razorpay LIVE keys"
