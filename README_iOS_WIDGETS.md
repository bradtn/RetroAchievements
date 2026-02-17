# iOS Widget Implementation Guide

## What's Included

This package contains all the files needed to add iOS WidgetKit widgets to your RetroTrack app, matching the 5 Android home screen widgets.

### Files Overview

```
ios/
├── RetroTrackWidgets/           # NEW - Widget Extension
│   ├── RetroTrackWidgets.swift  # Widget bundle entry point
│   ├── SharedDataManager.swift    # App Group UserDefaults reader
│   ├── ImageLoader.swift          # Image caching utility
│   ├── WidgetModels.swift         # Data models
│   ├── StreakWidget.swift         # Small widget - streak display
│   ├── GameTrackerWidget.swift    # Medium widget - game progress
│   ├── AotwWidget.swift           # Medium widget - Achievement of Week
│   ├── RecentAchievementsWidget.swift  # Medium widget - cycling achievements
│   ├── FriendActivityWidget.swift # Medium widget - cycling friend activity
│   ├── Info.plist
│   ├── RetroTrackWidgets.entitlements
│   └── Assets.xcassets/
├── Runner/
│   ├── Runner.entitlements        # NEW - App Groups entitlement
│   └── AppDelegate.swift          # MODIFIED - MethodChannel for widgets
└── Runner.xcodeproj/
    └── project.pbxproj            # MODIFIED - Widget extension target added

lib/services/
├── widget_service.dart            # MODIFIED - iOS App Group methods
└── background_sync_service.dart   # MODIFIED - Dual-write for iOS

pubspec.yaml                       # MODIFIED - iOS icons enabled
```

---

## Step 1: Transfer and Extract

Copy `ios_widget_update.tar.gz` to your Mac, then:

```bash
# Navigate to your Flutter project root
cd /path/to/your/RetroAchievements

# Backup your current iOS folder (recommended)
cp -r ios ios_backup

# Extract the tar file
tar -xzvf /path/to/ios_widget_update.tar.gz
```

---

## Step 2: Configure App Groups in Apple Developer Portal

1. Go to https://developer.apple.com/account
2. Navigate to **Certificates, Identifiers & Profiles** → **Identifiers**

### Configure Main App ID:
3. Find your main app identifier: `com.spectersystems.retrotrack`
4. Click **Edit** and enable **App Groups**
5. Click **+** to add a new App Group: `group.com.spectersystems.retrotrack`
6. Save changes

### Create Widget Extension App ID:
7. Click **+** to register a new identifier
8. Select **App IDs** → Continue
9. Select **App** → Continue
10. Enter:
    - Description: `RetroTrack Widgets`
    - Bundle ID: `com.spectersystems.retrotrack.widgets`
11. Enable **App Groups** capability
12. Select `group.com.spectersystems.retrotrack`
13. Continue and Register

---

## Step 3: Update Provisioning Profiles

1. Go to **Profiles** in Developer Portal
2. Create or regenerate profiles for:
   - Main app: `com.spectersystems.retrotrack` (Development & Distribution)
   - Widget: `com.spectersystems.retrotrack.widgets` (Development & Distribution)
3. Download the profiles (Xcode can also do this automatically)

---

## Step 4: Fix AdMob App ID

Edit `ios/Runner/Info.plist` and replace the placeholder AdMob ID:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-2658368978045167~XXXXXXXXXX</string>
```

Replace `XXXXXXXXXX` with your real iOS AdMob App ID, or remove the GADApplicationIdentifier entry entirely if not using ads.

---

## Step 5: Generate iOS App Icons

```bash
cd /path/to/your/RetroAchievements
flutter pub get
flutter pub run flutter_launcher_icons
```

---

## Step 6: Open in Xcode

```bash
open ios/Runner.xcworkspace
```

**IMPORTANT:** Always open `.xcworkspace`, NOT `.xcodeproj`!

---

## Step 7: Configure Signing & Capabilities in Xcode

### For Runner target:
1. Select **Runner** project in the left sidebar
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team**
6. **Add App Groups capability:**
   - Click the **+ Capability** button (top left of capabilities area)
   - Search for **App Groups** and double-click to add it
   - Click **+** under the App Groups section
   - Add: `group.com.spectersystems.retrotrack`

### For RetroTrackWidgets target:
7. Select **RetroTrackWidgets** target
8. Go to **Signing & Capabilities** tab
9. Check **Automatically manage signing**
10. Select the **same Team** as Runner
11. **Add App Groups capability:**
    - Click the **+ Capability** button
    - Search for **App Groups** and double-click to add it
    - Select the same group: `group.com.spectersystems.retrotrack`

**IMPORTANT:** Both targets MUST have the identical App Group ID for widget data sharing to work.

### Capabilities NOT needed:
- Push Notifications (app uses local notifications only)
- Background Modes
- iCloud
- Keychain Sharing

---

## Step 8: Build Flutter

```bash
cd /path/to/your/RetroAchievements
flutter clean
flutter pub get
flutter build ios --no-codesign
```

---

## Step 9: Build and Run in Xcode

1. In Xcode, select your device or simulator (must be iOS 14.0+)
2. Make sure **Runner** scheme is selected (not RetroTrackWidgets)
3. Press **⌘+B** to Build
4. Press **⌘+R** to Run

---

## Step 10: Test the Widgets

### Adding Widgets:
1. Go to the device/simulator Home Screen
2. Long press on empty area
3. Tap **+** button (top left corner)
4. Search for "RetroTrack" or scroll to find it
5. You'll see 5 widget options:

| Widget | Size | Description |
|--------|------|-------------|
| Streak | Small | Shows current and best streak |
| Game Tracker | Medium | Progress on pinned game |
| Achievement of the Week | Medium | Current AOTW |
| Recent Achievements | Medium | Cycles through recent achievements |
| Friend Activity | Medium | Cycles through friend activity |

### Getting Data to Appear:
1. Open the main RetroTrack app
2. Log in with your credentials
3. Navigate around to trigger data sync
4. Check Home tab loads properly
5. Now widgets should show your data

---

## Troubleshooting

### "No such module 'WidgetKit'" error
- Ensure deployment target is iOS 14.0+
- Product → Clean Build Folder (⇧⌘K)
- Restart Xcode

### Widgets show "No Data" or placeholder
- Open main app first and let it fully sync
- Check App Groups configured identically for both targets
- Verify the App Group ID matches exactly: `group.com.spectersystems.retrotrack`

### Signing/Provisioning errors
- Ensure both targets use the same Team
- Try disabling then re-enabling "Automatically manage signing"
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Widget not appearing in widget gallery
- Restart device/simulator
- Delete app completely and reinstall
- Check Console.app for widget extension crash logs

### Build fails with "Multiple commands produce" error
- Product → Clean Build Folder
- Delete Pods folder and Podfile.lock, then `pod install`

---

## Quick Commands Reference

```bash
# Full clean rebuild
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios && pod install && cd ..
flutter build ios

# Open Xcode
open ios/Runner.xcworkspace

# Check for build errors without Xcode
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Debug build
```

---

## Widget Data Flow

```
┌─────────────────────┐
│   Flutter App       │
│  (Main App Opens)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ background_sync_    │
│ service.dart        │
│ - Fetches API data  │
│ - Writes to prefs   │
│ - Writes to App     │
│   Group (iOS)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ AppDelegate.swift   │
│ - MethodChannel     │
│ - Writes to         │
│   UserDefaults      │
│ - Calls WidgetKit   │
│   reloadTimelines   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ iOS WidgetKit       │
│ - Reads from App    │
│   Group UserDefaults│
│ - Renders widgets   │
└─────────────────────┘
```

---

## Support

If you encounter issues:
1. Check Xcode's Issue Navigator for specific errors
2. Look at Console.app for runtime logs
3. Verify all App Group IDs match exactly
4. Ensure iOS deployment target is 14.0+
