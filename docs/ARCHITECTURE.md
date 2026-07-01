# Architecture Overview

Golden Care follows a **feature-first** architecture with clear separation between data, business logic, and presentation layers. It is built with Flutter and uses Firebase as the backend-as-a-service.

## High-Level Architecture

```
┌──────────────────────────────────────────────────┐
│                   Flutter App                     │
│  ┌─────────────┐  ┌────────────┐  ┌────────────┐ │
│  │  Features    │  │ Components │  │   Core     │ │
│  │  (Screens &  │  │ (Reusable  │  │ (Theme,    │ │
│  │  Controllers)│  │  Widgets)  │  │  Router,   │ │
│  │             │  │            │  │  Constants) │ │
│  └──────┬──────┘  └────────────┘  └────────────┘ │
│         │                                         │
│  ┌──────▼──────┐                                  │
│  │ Repositories│  (Data abstraction layer)        │
│  └──────┬──────┘                                  │
│         │                                         │
│  ┌──────▼──────┐                                  │
│  │  Firebase    │  (Auth, Firestore, Storage,     │
│  │  Services    │   Messaging, Remote Config)     │
│  └──────┬──────┘                                  │
└─────────┼────────────────────────────────────────┘
          │
┌─────────▼────────────────────────────────────────┐
│              Firebase Cloud Services              │
│  ┌──────────┐ ┌───────────┐ ┌──────────────────┐ │
│  │ Firestore│ │  Storage  │ │  Authentication  │ │
│  └──────────┘ └───────────┘ └──────────────────┘ │
│  ┌──────────┐ ┌───────────┐ ┌──────────────────┐ │
│  │   FCM    │ │Remote Cfg │ │    App Check     │ │
│  └──────────┘ └───────────┘ └──────────────────┘ │
└──────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                    # Primary app entry point
├── main_partner.dart            # Partner app variant entry point
├── firebase_options.dart        # Firebase platform config (auto-generated)
│
├── models/                      # Data models (Firestore ↔ Dart)
│   ├── user_model.dart
│   ├── booking_model.dart
│   ├── service_model.dart
│   ├── service_personnel_model.dart
│   └── notification_model.dart
│
├── repositories/                # Data access layer
│   ├── user_repository.dart
│   ├── booking_repository.dart
│   ├── service_repository.dart
│   └── service_personnel_repository.dart
│
├── firebase/                    # Firebase service wrappers
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   ├── notification_service.dart
│   └── config_service.dart
│
├── core/                        # App-wide configuration
│   ├── router.dart              # GoRouter navigation configuration
│   ├── theme.dart               # Material 3 theme definition
│   ├── colors.dart              # Design color tokens
│   ├── typography.dart          # Text styles (Playfair Display + Inter)
│   ├── spacing.dart             # Layout spacing constants
│   └── constants.dart           # App-wide constants
│
├── components/                  # Reusable UI widgets (prefixed with "gc_")
│   ├── gc_button.dart
│   ├── gc_text_field.dart
│   ├── gc_card.dart
│   ├── gc_avatar.dart
│   └── gc_nav_bar.dart
│
├── features/                    # Feature modules (screen + logic)
│   ├── splash/                  # Splash screen
│   ├── landing/                 # Marketing/landing page
│   ├── auth/                    # Authentication flows
│   ├── home/                    # Family user dashboard
│   ├── bookings/                # Booking creation & management
│   ├── caregivers/              # Browse caregivers
│   ├── partner/                 # Caregiver portal (dashboard, registration)
│   ├── profile/                 # User profile management
│   ├── payment/                 # Razorpay payment integration
│   ├── legal/                   # Legal pages (privacy, T&C, etc.)
│   └── join/                    # "Join as caregiver" info page
│
└── utils/                       # Utility functions
    ├── error_handler.dart       # Centralized error handling
    └── geocoding_helper.dart    # Cross-platform geocoding
```

## State Management

The app uses **Flutter Riverpod** for state management with the following provider patterns:

| Provider Type | Usage | Example |
|---|---|---|
| `StreamProvider` | Real-time Firestore data | `authStateProvider`, `userModelProvider`, `userBookingsProvider` |
| `FutureProvider` | One-time data fetches | `servicesProvider`, `allBookingsCountProvider` |
| `StateNotifierProvider` | Complex state + actions | `authControllerProvider` |
| `Provider` | Singleton services & config | `routerProvider`, `authServiceProvider`, repository providers |
| `FutureProvider.family` | Parameterized queries | `personnelBookingsByStatusProvider` |

### Key Providers

- **`authStateProvider`** - Firebase Auth state stream (logged in/out)
- **`userModelProvider`** - Current user's Firestore document (real-time)
- **`currentPersonnelProvider`** - Caregiver's ServicePersonnel record
- **`userBookingsProvider`** - Family user's bookings (real-time)
- **`caregiverAssignmentsProvider`** - Bookings assigned to a caregiver
- **`routerProvider`** - GoRouter with role-based redirect logic

## Navigation & Routing

Navigation uses **GoRouter** with declarative route definitions and a centralized redirect function that enforces:

1. **Authentication gating** - Unauthenticated users redirected to `/auth/login`
2. **Email verification** - Unverified users redirected to `/auth/verify-email`
3. **Profile completion** - Family users without complete profiles → `/auth/setup-profile`
4. **Role-based routing** - Caregivers → `/partner/*` routes, Family → `/dashboard/family`
5. **Caregiver registration** - Incomplete personnel profiles → `/partner/register`

### Shell Routes

Two shell routes provide persistent bottom navigation bars:
- **`MainLayout`** - Family user layout (Home, Profile tabs)
- **`PartnerMainLayout`** - Caregiver layout (Dashboard, Bookings, Profile tabs)

## Data Layer

### Models

All models implement `fromFirestore()` and `toMap()` for Firestore serialization:

- **`UserModel`** - User account (name, email, address, role, emergency contacts)
- **`BookingModel`** - Service booking (service, date/time, status, OTP verification)
- **`ServiceModel`** - Available service (title, category, pricing options)
- **`ServicePersonnelModel`** - Caregiver profile (specialties, languages, rating)
- **`NotificationModel`** - In-app notification (title, body, type, read status)

### Repositories

Repositories abstract Firestore operations and expose typed methods:

- **`UserRepository`** - CRUD for user documents
- **`BookingRepository`** - Booking creation, status updates, queries
- **`ServiceRepository`** - Service listing and filtering
- **`ServicePersonnelRepository`** - Caregiver profiles, availability

## Design System

The app uses **Material 3** with a custom design system:

- **Theme** - `GCTheme` with light mode Material 3 color scheme
- **Colors** - `GCColors` design tokens (primary: `#6D51DE`, surface, text, status colors)
- **Typography** - `GCTypography` using Playfair Display (headings) and Inter (body)
- **Spacing** - `GCSpacing` standardized spacing values (4, 8, 12, 16, 20, 24, 32, 40, 48)
- **Components** - Prefixed with `GC` (GCButton, GCTextField, GCCard, GCAvatar, GCNavBar)

## Platform Support

| Platform | Status | Notes |
|---|---|---|
| Android | Supported | Native Razorpay SDK, Google Maps SDK |
| iOS | Supported | Native Razorpay SDK, CocoaPods dependencies |
| Web | Supported | Hosted Razorpay checkout, JS-based maps geocoding |

Cross-platform handling uses **conditional imports** for platform-specific code (e.g., payment processing, geocoding).
