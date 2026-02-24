#!/bin/sh

# Print each command before executing (for debugging)
set -x
# Fail on error
set -e

echo "=== CI POST CLONE START ==="
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "HOME: $HOME"
echo "PWD: $(pwd)"

# Install Flutter
echo "=== INSTALLING FLUTTER ==="
FLUTTER_HOME="$HOME/flutter"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
export PATH="$PATH:$FLUTTER_HOME/bin"

echo "=== FLUTTER VERSION ==="
flutter --version

echo "=== FLUTTER PUB GET ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "=== FLUTTER BUILD IOS ==="
flutter build ios --release --no-codesign

echo "=== CI POST CLONE COMPLETE ==="
