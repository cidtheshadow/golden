#!/bin/bash
echo "Downloading latest Flutter SDK (stable)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Configuring Git to fix dubious ownership on Vercel..."
git config --global --add safe.directory '*'

echo "Enabling Flutter Web..."
flutter config --enable-web

echo "Getting packages..."
flutter pub get

echo "Building web app..."
flutter build web --release
