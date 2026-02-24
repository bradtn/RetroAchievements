#!/bin/sh

echo "STEP 1: Script started"

echo "STEP 2: Installing Flutter"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"

echo "STEP 3: Setting PATH"
export PATH="$PATH:$HOME/flutter/bin"

echo "STEP 4: Flutter doctor"
flutter doctor -v

echo "STEP 5: Pub get"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "STEP 6: Building iOS"
flutter build ios --release --no-codesign

echo "STEP 7: Done"
