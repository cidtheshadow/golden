# Build & Deployment Guide

## Build Targets

Golden Care supports three platforms: **Android**, **iOS**, and **Web**.

---

## Android

### Debug Build

```bash
flutter run -d <device-id>
```

### Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Release App Bundle (for Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Signing Configuration

Release builds require a signing keystore. Create `android/key.properties`:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to>/upload-keystore.jks
```

The `android/app/build.gradle.kts` is configured to read this file for release signing.

### Target Architectures

Release builds target: `arm64-v8a`, `armeabi-v7a`, `x86_64`

---

## iOS

### Debug Build

```bash
flutter run -d <ios-device-or-simulator>
```

### Release Build

```bash
flutter build ios --release
```

### Dependency Management

iOS uses CocoaPods for native dependencies:

```bash
cd ios && pod install --repo-update && cd ..
```

### Requirements

- Xcode 15+
- Valid Apple Developer account
- Provisioning profiles configured in Xcode

---

## Web

### Debug Build

```bash
flutter run -d chrome
```

### Release Build

```bash
flutter build web --release
```

Output: `build/web/`

### Firebase Hosting Deployment

```bash
# Build and deploy
flutter build web --release
firebase deploy --only hosting
```

### Hosting Configuration

Defined in `firebase.json`:

- **SPA Routing**: All paths rewrite to `/index.html`
- **Static Asset Caching**: JS, CSS, fonts, images cached for 1 year (`max-age=31536000, immutable`)
- **Index Caching**: No cache (`no-cache, no-store, must-revalidate`)
- **Security Headers**:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: SAMEORIGIN`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`

---

## Firebase Services Deployment

### Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

Rules file: `firestore.rules`

### Storage Security Rules

```bash
firebase deploy --only storage
```

Rules file: `storage.rules`

### Remote Config

```bash
firebase deploy --only remoteconfig
```

Template file: `rc_template.json`

### Deploy All Firebase Services

```bash
firebase deploy
```

---

## App Variants

The project supports two entry points:

| Entry Point | Command | Purpose |
|---|---|---|
| `lib/main.dart` | `flutter run` | Full app (all roles) |
| `lib/main_partner.dart` | `flutter run -t lib/main_partner.dart` | Partner-only variant |

---

## Launcher Icons

App icons are configured via `flutter_launcher_icons` in `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
```

- Source image: `assets/images/logo.png`
- Generated for: Android, iOS, Web
- Theme color: `#6D51DE`
- Background color: `#FFFFFF`

---

## Environment Configuration

### Firebase Project

- **Project ID**: `golden-care-d4863`
- **Android App ID**: `1:143097198020:android:d87719bd3960d5275b2091`
- **iOS App ID**: `1:143097198020:ios:0647a7e9b756f2fa5b2091`
- **Web App ID**: `1:143097198020:web:1bfefba8807c95495b2091`

### Required Remote Config Values

These must be set in the Firebase console before the app functions fully:

| Key | Description |
|---|---|
| `razorpay_key_id` | Razorpay payment gateway API key |
| `maps_api_key` | Google Maps API key (web geocoding) |
| `vapid_key` | FCM VAPID key for web push notifications |

### Required Google Cloud APIs

Enable these in the Google Cloud Console for your project:

- Maps JavaScript API (web)
- Geocoding API (web)
- Identity Toolkit API (authentication)
