#!/bin/sh

set -e
set -x

echo "Starting Zidash Xcode Cloud setup"

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter if it is not already available.
if ! command -v flutter >/dev/null 2>&1; then
  git clone \
    --depth 1 \
    --branch stable \
    https://github.com/flutter/flutter.git \
    "$HOME/flutter"

  export PATH="$HOME/flutter/bin:$PATH"
fi

echo "Flutter version:"
flutter --version

# Generate Flutter plugin metadata and iOS artifacts.
flutter config --no-analytics
flutter precache --ios
flutter pub get

# Ensure generated iOS configuration exists.
flutter build ios --config-only --release --no-codesign

cd ios

# Remove stale pod integration from the repository clone.
rm -rf Pods
rm -rf .symlinks

# Install CocoaPods if unavailable.
if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

pod repo update
pod install

echo "Installed geocoding pods:"
grep -i "geocoding" Podfile.lock || true

echo "Zidash Xcode Cloud setup complete"
