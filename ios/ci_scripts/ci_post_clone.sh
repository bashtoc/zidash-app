#!/bin/sh

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios
flutter pub get

cd ios
pod install --repo-update
