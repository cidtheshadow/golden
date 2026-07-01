# Navigation Routes

Golden Care uses **GoRouter** for declarative routing with role-based access control.

## Route Map

### Public Routes (No Authentication Required)

| Route | Screen | Description |
|---|---|---|
| `/splash` | `SplashScreen` | App launch splash screen (initial route) |
| `/` | `LandingScreen` | Marketing/landing page |
| `/auth/login` | `AuthScreen` | Sign in / Sign up (accepts `?mode=signin&role=family` query params) |
| `/caregivers` | `CaregiversScreen` | Browse all caregivers |
| `/join-as-caregiver` | `JoinCaregiverScreen` | Information page for joining as caregiver |
| `/contact` | `ContactUsScreen` | Contact information |
| `/about` | `AboutUsScreen` | About the company |
| `/legal/privacy` | `LegalPolicyScreen` | Privacy Policy |
| `/legal/terms` | `LegalPolicyScreen` | Terms of Service |
| `/legal/refunds` | `LegalPolicyScreen` | Cancellation & Refunds Policy |
| `/legal/data-collection` | `LegalPolicyScreen` | Data Collection and Usage Policy |
| `/legal/account-deletion` | `LegalPolicyScreen` | Account Deletion Policy |
| `/legal/shipping` | `LegalPolicyScreen` | Shipping & Delivery Policy |

### Auth Flow Routes

| Route | Screen | Description |
|---|---|---|
| `/auth/verify-email` | `EmailVerificationScreen` | Email verification prompt |
| `/auth/setup-profile` | `ProfileSetupScreen` | Mandatory profile completion for family users |

### Authenticated Routes (Family Users)

| Route | Screen | Layout | Description |
|---|---|---|---|
| `/dashboard/family` | `HomeScreen` | `MainLayout` | Family user home dashboard |
| `/profile` | `ProfileScreen` | `MainLayout` | User profile management |
| `/dashboard/admin` | `HomeScreen` | `MainLayout` | Admin dashboard |
| `/book` | `BookingScreen` | None | Booking creation flow (stepper) |
| `/bookings` | `BookingsScreen` | None | Booking history list |
| `/booking-details/:id` | `BookingDetailsScreen` | None | Single booking details |

### Caregiver Partner Routes

| Route | Screen | Layout | Description |
|---|---|---|---|
| `/partner/register` | `PartnerRegistrationScreen` | None | Caregiver profile registration |
| `/partner/dashboard` | `PartnerDashboardScreen` | `PartnerMainLayout` | Caregiver dashboard |
| `/partner/bookings` | `PartnerBookingsScreen` | `PartnerMainLayout` | Caregiver booking list |
| `/partner/profile` | `PartnerProfileScreen` | `PartnerMainLayout` | Caregiver profile view/edit |
| `/partner/booking-details/:id` | `PartnerBookingDetailScreen` | None | Booking details (caregiver view) |

---

## Redirect Logic

The router applies these redirects in priority order:

```
1. Not authenticated + not on public route → /auth/login
2. Authenticated + email not verified     → /auth/verify-email
3. Verified + already on verify screen    → / (landing)
4. Family + profile incomplete            → /auth/setup-profile
5. Caregiver + no personnel record        → /partner/register
6. Caregiver + on non-partner route       → /partner/dashboard
7. Authenticated + on login screen        → role-based dashboard
8. /dashboard accessed directly           → role-specific dashboard
```

### Role-Based Dashboard Routing

| Role | Dashboard Route |
|---|---|
| `family` | `/dashboard/family` |
| `caregiver` | `/partner/dashboard` |
| `admin` | `/dashboard/admin` |

---

## Shell Routes (Persistent Navigation)

### Family/Admin Layout (`MainLayout`)
Provides persistent bottom navigation bar for:
- `/dashboard/family` - Home
- `/profile` - Profile
- `/dashboard/admin` - Admin (same layout)

### Partner Layout (`PartnerMainLayout`)
Provides persistent bottom navigation bar for:
- `/partner/dashboard` - Dashboard
- `/partner/bookings` - Bookings
- `/partner/profile` - Profile

---

## Query Parameters

### `/auth/login`

| Parameter | Values | Description |
|---|---|---|
| `mode` | `signin`, `signup` | Initial tab selection |
| `role` | `family`, `caregiver` | Pre-select registration role |

Example: `/auth/login?mode=signup&role=caregiver`

### Path Parameters

| Route | Parameter | Description |
|---|---|---|
| `/booking-details/:id` | `id` | Booking document ID |
| `/partner/booking-details/:id` | `id` | Booking document ID |
