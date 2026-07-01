#!/bin/bash

# Vercel Build Script for Flutter Web

echo "Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

echo "Checking Flutter version..."
flutter --version

echo "Building Flutter Web App..."
flutter build web --release

echo "Build complete."
