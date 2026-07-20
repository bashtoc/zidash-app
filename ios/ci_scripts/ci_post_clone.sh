#!/bin/sh

set -eu

echo "===== Zidash Xcode Cloud setup started ====="
echo "Current directory: $(pwd)"
echo "Repository path: ${CI_PRIMARY_REPOSITORY_PATH:-not-set}"
echo "Home: $HOME"

REPO_PATH="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"

echo "Using repository path: $REPO_PATH"
cd "$REPO_PATH"

echo "Repository contents:"
ls -la

FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter stable..."
  rm -rf "$FLUTTER_DIR"

  git clone \
    --depth 1 \
    --branch stable \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Flutter path:"
command -v flutter

echo "Flutter version:"
flutter --version

echo "Disabling Flutter analytics..."
flutter config --no-analytics

echo "Downloading iOS artifacts..."
flutter precache --ios

echo "Installing Dart dependencies..."
flutter pub get

echo "Generating iOS configuration..."
flutter build ios --config-only --release --no-codesign

echo "Entering iOS directory..."
cd "$REPO_PATH/ios"

echo "CocoaPods version:"
pod --version

echo "Cleaning generated pod links..."
rm -rf Pods
rm -rf .symlinks

echo "Installing CocoaPods dependencies..."
pod install --repo-update

echo "Checking geocoding installation..."
grep -i "geocoding" Podfile.lock || true

echo "===== Zidash Xcode Cloud setup completed ====="
