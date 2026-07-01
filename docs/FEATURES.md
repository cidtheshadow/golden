# Features Documentation

## Authentication

### Sign Up / Sign In
- **Email & Password** - Standard registration with email verification
- **Google OAuth** - One-tap sign-in (popup on web, native SDK on mobile)
- **Phone Number** - Optional SMS OTP verification, can be linked to existing account

### Email Verification
- Required before accessing any gated features
- Automatic redirect to verification screen post-registration
- Re-send verification email functionality

### Role Selection
- Users choose a role during registration: **Family** (care seeker) or **Caregiver** (service provider)
- Role determines routing, available features, and dashboard type
- Caregivers require email whitelisting (pre-registered in `whitelisted_partners` Firestore collection)

### Profile Setup (Family Users)
- Mandatory fields: name, phone number, address, date of birth
- Optional: profile photo upload, emergency contacts
- Profile completeness enforced by the router before dashboard access

---

## Booking System

### Booking Flow (Multi-Step)
The booking process is a guided 6-step stepper:

1. **Service Selection** - Browse available services, choose a pricing option (duration + price)
2. **Date & Time** - Pick a date from calendar, select an available time slot
3. **Details** - Confirm name, phone, address; add optional notes; pick location on map
4. **Terms** - Review and accept terms of service
5. **Payment** - Process payment via Razorpay
6. **Confirmation** - Booking confirmed with assigned caregiver

### Time Slot Calculation
- Available slots are calculated dynamically based on:
  - Configurable booking hours (from Firebase Remote Config)
  - Existing bookings for the selected date
  - 30-minute cooldown buffer between bookings for the same caregiver
- Slot granularity: hourly intervals within operating hours

### Booking Statuses
| Status | Description |
|---|---|
| `upcoming` | Booking confirmed, awaiting service date |
| `completion_requested` | Caregiver requested completion (OTP generated) |
| `completed` | Family user verified OTP, booking closed |
| `cancelled` | Booking cancelled by user |

### OTP-Based Completion
- When a caregiver marks a booking as done, a 6-digit OTP is generated
- The family user receives the OTP and must verify it to confirm completion
- Prevents false completion claims

### Booking History
- Family users see all their bookings sorted by date
- Caregivers see assignments filtered by status
- Status-based filtering (upcoming, completed, cancelled)

---

## Caregiver Partner Portal

### Registration
- Multi-field form: name, age, gender, phone, address, specialties, languages, key skills, experience, bio
- Phone verification required during registration
- Profile photo upload
- Profile completion tracking with `isProfileComplete` flag

### Partner Dashboard
- **Stats Cards** - Rating, total visits completed
- **Upcoming Tasks** - Next assigned bookings
- **Quick Actions** - Navigate to bookings, profile

### Booking Management (Caregiver Side)
- View all assigned bookings
- Filter by status
- View booking details (service, family info, location, date/time)
- Request booking completion (triggers OTP flow)

---

## Service Browsing

### Service Catalog
- Browse all services from Firestore
- Filter by category
- View service details: title, description, image, included items
- Multiple pricing tiers per service (different durations at different prices)

### Popular Services
- Services flagged as `isPopular` appear in a highlighted carousel on the home screen

---

## Location Services

### Location Picker
- Interactive Google Maps widget for selecting service address
- Reverse geocoding: tap on map → get formatted address
- Current location detection via GPS (Geolocator)
- Cross-platform geocoding:
  - **Mobile**: Native `geocoding` package
  - **Web**: Google Maps Geocoding API via HTTP

### Saved Addresses
- User's address stored in profile
- Latitude/longitude stored with bookings for caregiver navigation

---

## Notifications

### Push Notifications (FCM)
- Firebase Cloud Messaging integration
- FCM token stored per user/personnel in Firestore
- Token refresh handling

### In-App Notifications
- Stored as sub-collections under `users/{id}/notifications` and `servicePersonnel/{id}/notifications`
- Types: `booking`, `system`, `promotion`
- Read/unread tracking
- Used to notify caregivers of new booking assignments

---

## Payment Integration

### Razorpay
- **Mobile** (Android/iOS): Native Razorpay SDK via `razorpay_flutter`
- **Web**: Razorpay hosted checkout page via URL launcher
- Payment parameters: amount (in paise), user email, phone, description
- Razorpay API key fetched from Firebase Remote Config
- Platform-specific conditional imports with stub for unsupported platforms

---

## User Profile Management

### Profile Screen
- View/edit personal information (name, phone, address, DOB)
- Profile photo upload/change (Firebase Storage, 5MB limit, image MIME types only)
- Emergency contacts management
- Location update with map picker
- Sign out functionality

---

## Legal & Information Pages

All legal pages render Markdown content stored in `PolicyData`:

- **Privacy Policy** (`/legal/privacy`)
- **Terms of Service** (`/legal/terms`)
- **Cancellation & Refunds Policy** (`/legal/refunds`)
- **Data Collection and Usage Policy** (`/legal/data-collection`)
- **Account Deletion Policy** (`/legal/account-deletion`)
- **Shipping & Delivery Policy** (`/legal/shipping`)
- **About Us** (`/about`)
- **Contact Us** (`/contact`) - Displays email, phone, address

---

## Admin Features

Currently minimal:
- Admin dashboard route (`/dashboard/admin`) exists but reuses the family `HomeScreen`
- Booking statistics providers available (`allBookingsCountProvider`, `pendingBookingsCountProvider`)
- Admin role-based write access in Firestore security rules
- Admin can manage services, config, and whitelisted partners via Firestore rules

---

## App Variants

The project supports two entry points:
- **`main.dart`** - Full app (family users + caregivers)
- **`main_partner.dart`** - Partner-only app variant for caregivers
