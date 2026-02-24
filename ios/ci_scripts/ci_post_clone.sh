#!/bin/sh

# Fail on error
set -e

echo "📦 Installing Flutter..."

# Clone Flutter SDK
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

echo "🔍 Flutter version:"
flutter --version

echo "📥 Getting dependencies..."
cd $CI_PRIMARY_REPOSITORY_PATH
flutter pub get

echo "🍎 Generating iOS build files..."
flutter build ios --release --no-codesign

echo "✅ Flutter setup complete!"
