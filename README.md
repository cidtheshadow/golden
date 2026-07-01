# Golden Care

A multi-platform Flutter application for connecting families with professional caregivers. Families can browse services, book care sessions, and manage bookings. Caregivers can register, receive assignments, and manage their schedules through a dedicated partner portal.

**Version:** 1.0.0
**Platforms:** Android, iOS, Web
**Backend:** Firebase (Auth, Firestore, Storage, FCM, Remote Config)

---

## Current Project Status

| Area | Status | Notes |
|---|---|---|
| Authentication (Email, Google, Phone) | Done | Email verification, role-based access, caregiver whitelisting |
| Family User Dashboard | Done | Home screen with service browsing, popular services carousel |
| Booking Flow | Done | 6-step guided flow with date/time selection, payment, caregiver assignment |
| Booking Management | Done | History, status tracking, OTP-verified completion |
| Caregiver Partner Portal | Done | Registration, dashboard, booking management, profile |
| Service Catalog | Done | Browse, filter by category, multi-tier pricing |
| Payment Integration (Razorpay) | Done | Mobile (native SDK) and web (hosted checkout) |
| Location Services (Google Maps) | Done | Map picker, geocoding, cross-platform support |
| Push Notifications (FCM) | Done | Token management, in-app notification storage |
| Profile Management | Done | Photo upload, address, emergency contacts |
| Legal Pages | Done | Privacy, T&C, cancellation, shipping, data collection, account deletion policies |
| Firestore Security Rules | Done | Role-based access, ownership checks, default deny |
| Firebase Hosting (Web) | Done | SPA routing, caching, security headers configured |
| Admin Dashboard | Partial | Routes and providers exist; reuses family HomeScreen |
| Reviews & Ratings | Partial | Model fields exist on ServicePersonnel; no submission UI |
| Test Coverage | Minimal | 1 widget test; no unit/integration tests |

**Estimated overall completeness: ~85-90%**

### What Works
- Full end-to-end booking flow from service selection through payment to caregiver assignment
- Complete authentication with email verification and role-based routing
- Caregiver portal with registration, dashboard, and booking management
- OTP-based booking completion verification
- Cross-platform builds (Android, iOS, Web) with platform-specific payment/geocoding handling
- Real-time data sync via Firestore streams and Riverpod providers

### Known Gaps
- **Admin panel** needs a dedicated UI (currently shares the family home screen)
- **Review/rating submission** has no user-facing UI yet
- **Test suite** needs unit tests for services/repositories, widget tests for key screens, and integration tests for booking flow
- **Debug logging** has ~155+ `debugPrint` statements that should be removed or gated for production

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart >= 3.3.0) |
| State Management | Flutter Riverpod 2.5.1 |
| Navigation | GoRouter 14.0.0 |
| Design System | Material 3, Google Fonts (Playfair Display + Inter) |
| Backend | Firebase (Auth, Firestore, Storage, FCM, Remote Config, App Check) |
| Payments | Razorpay Flutter 1.4.1 |
| Maps | Google Maps Flutter 2.14.2, Geolocator 14.0.2, Geocoding 4.0.0 |
| Animations | Flutter Animate 4.5.0 |

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── main_partner.dart         # Partner-only variant
├── firebase_options.dart     # Firebase config
├── models/                   # Data models (5 files)
├── repositories/             # Data access layer (4 files)
├── firebase/                 # Firebase service wrappers (5 files)
├── core/                     # Theme, router, design tokens (6 files)
├── components/               # Reusable UI widgets (5 files)
├── features/                 # Feature modules
│   ├── auth/                 # Sign in/up, verification, profile setup
│   ├── home/                 # Family dashboard
│   ├── bookings/             # Booking flow & history
│   ├── caregivers/           # Browse caregivers
│   ├── partner/              # Caregiver portal
│   ├── profile/              # User profile
│   ├── payment/              # Razorpay integration
│   ├── legal/                # Policy pages
│   └── ...
└── utils/                    # Error handling, geocoding helpers
```

---

## Quick Start

### Prerequisites

- Flutter SDK >= 3.3.0
- Firebase CLI (`npm install -g firebase-tools`)
- A configured Firebase project

### Install & Run

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run web version
flutter run -d chrome

# Run partner variant
flutter run -t lib/main_partner.dart
```

### Build for Production

```bash
# Android APK
flutter build apk --release

# Web (then deploy to Firebase Hosting)
flutter build web --release
firebase deploy --only hosting
```

---

## Documentation

Detailed documentation is available in the [`docs/`](docs/) directory:

| Document | Description |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | System architecture, directory structure, state management, design system |
| [Features](docs/FEATURES.md) | Detailed feature documentation for all modules |
| [Database Schema](docs/DATABASE.md) | Firestore collections, fields, security rules summary |
| [Routes](docs/API_ROUTES.md) | All navigation routes, redirect logic, query parameters |
| [Setup Guide](docs/SETUP.md) | Installation, configuration, Firebase setup, troubleshooting |
| [Deployment](docs/DEPLOYMENT.md) | Build commands, Firebase Hosting, release signing |
| [Play Store Compliance](docs/PLAYSTORE_COMPLIANCE.md) | App-content, Data Safety, privacy, permission, and account deletion checklist |

---

## Key Workflows

### Family User Flow
1. Register with email (select "Family" role) -> Verify email -> Complete profile
2. Browse services on dashboard -> Start booking
3. Select service & pricing tier -> Pick date/time -> Confirm details -> Pay via Razorpay
4. Caregiver assigned automatically -> Track booking status
5. Verify completion via OTP when caregiver finishes

### Caregiver Flow
1. Email must be whitelisted in `whitelisted_partners` collection
2. Register with email (select "Caregiver" role) -> Verify email -> Complete partner registration
3. View assigned bookings on partner dashboard
4. Mark bookings as complete -> Family user verifies via OTP

---

## Firebase Project

- **Project ID:** `golden-care-d4863`
- **Required Remote Config keys:** `razorpay_key_id`, `maps_api_key`, `vapid_key`
- **Security:** Firestore rules with role-based access, Storage rules with size/type limits, App Check with reCAPTCHA
