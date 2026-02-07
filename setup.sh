#!/bin/bash

echo "=== RetroTracker Setup Script ==="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing..."

    # Download Flutter
    cd ~
    git clone https://github.com/flutter/flutter.git -b stable --depth 1

    # Add to PATH
    export PATH="$PATH:$HOME/flutter/bin"
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc

    echo "Flutter installed. Please restart your terminal or run:"
    echo "  source ~/.bashrc"
fi

# Navigate to project
cd /opt/RetroAchievements

# Check Flutter setup
echo "Checking Flutter setup..."
flutter doctor

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Generate code
echo "Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To run the app:"
echo "  flutter run              # Run on connected device"
echo "  flutter run -d chrome    # Run in Chrome (web)"
echo "  flutter run -d linux     # Run as Linux desktop app"
echo ""
echo "To build:"
echo "  flutter build apk        # Build Android APK"
echo "  flutter build ios        # Build iOS (requires Mac)"
