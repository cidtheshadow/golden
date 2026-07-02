#!/bin/bash
# Download and install Flutter for Vercel build
echo "Downloading Flutter SDK..."
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.2-stable.tar.xz | tar xJ
export PATH="$PATH:`pwd`/flutter/bin"

echo "Configuring Git to fix dubious ownership on Vercel..."
git config --global --add safe.directory '*'

echo "Enabling Flutter Web..."
flutter config --enable-web

echo "Getting packages..."
flutter pub get

echo "Building web app..."
flutter build web --release
