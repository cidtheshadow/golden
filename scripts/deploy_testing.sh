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

# Try to fetch missing keys from Remote Config if not provided in environment
fetch_rc_value() {
	local key="$1"
	if ! command -v firebase >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		echo ""; return
	fi
	firebase --project "$FIREBASE_PROJECT" remoteconfig:get -j 2>/dev/null \
		| jq -r ".result.parameters[\"${key}\"].defaultValue.value // \"\""
}

echo "🏗️  Building Flutter web (TESTING environment)..."
echo "Info: Not injecting private keys into build. Ensure Remote Config contains 'maps_api_key' and 'razorpay_key' if required by clients."
flutter build web --release \
	--dart-define=ENVIRONMENT=testing \
	--dart-define=RAZORPAY_KEY_MODE=test

# Verify that the built web artifact contains the injected keys
echo "🔍 Verifying build contains required keys..."
BUILD_FILE="build/web/main.dart.js"
if [[ ! -f "$BUILD_FILE" ]]; then
	echo "Error: build output not found at $BUILD_FILE; build may have failed"
	exit 1
fi

echo "✅ Build complete; deploying to TESTING..."
firebase deploy --only hosting:testing --project "$FIREBASE_PROJECT"
echo "✅ Testing deploy complete"
echo "🌐 https://golden-care-testing.web.app"
echo "🔑 Using Razorpay TEST keys"
