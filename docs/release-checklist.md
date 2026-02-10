# Release Checklist

## Pre-Release

### App Configuration
- [ ] Update version in `pubspec.yaml` (version: X.Y.Z+buildNumber)
- [ ] Verify app name in AndroidManifest.xml ("RetroTrack")
- [ ] Verify package name (com.retrotracker.retrotracker)

### Assets Required
- [x] App icon (512x512) - `RetroTrackIcon.png`
- [x] Horizontal logo - `assets/RetroTrack.png`
- [ ] Feature graphic (1024x500) for Play Store
- [ ] Screenshots (phone) - at least 2, recommended 8
- [ ] Screenshots (tablet) - optional but recommended

### Store Listing
- [x] Short description (80 chars) - see `play-store-listing.md`
- [x] Full description - see `play-store-listing.md`
- [ ] Privacy policy URL (required for apps with account login)

### Signing
- [ ] Create upload keystore (if not exists)
- [ ] Configure `android/key.properties`
- [ ] Configure `android/app/build.gradle` for release signing

### AdMob
- [ ] Account verification complete
- [ ] Ad units approved and serving

---

## Build Commands

```bash
# Build release APK
flutter build apk --release --no-tree-shake-icons

# Build release App Bundle (for Play Store)
flutter build appbundle --release --no-tree-shake-icons
```

---

## Play Console Steps

1. Create app in Google Play Console
2. Complete app content questionnaire
3. Fill out content rating questionnaire
4. Set up pricing (Free)
5. Select countries for distribution
6. Upload App Bundle (.aab)
7. Add store listing assets
8. Submit for review

---

## Post-Release

- [ ] Monitor crash reports in Play Console
- [ ] Respond to user reviews
- [ ] Track AdMob revenue
- [ ] Plan next update features
