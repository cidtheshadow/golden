# Database Schema

Golden Care uses **Cloud Firestore** (NoSQL) as its primary database and **Firebase Storage** for file uploads.

## Firestore Collections

### `users`

Stores registered user accounts. Document ID = Firebase Auth UID.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Full name |
| `email` | string | Yes | Email address |
| `phone` | string | Yes | Phone number |
| `address` | string | Yes | Full address string |
| `street` | string | No | Street address |
| `city` | string | No | City |
| `state` | string | No | State/province |
| `pincode` | string | No | Postal/ZIP code |
| `country` | string | No | Country (default: "India") |
| `latitude` | number | No | Location latitude |
| `longitude` | number | No | Location longitude |
| `profileImage` | string | No | URL to profile photo in Firebase Storage |
| `dob` | timestamp | No | Date of birth |
| `role` | string | Yes | `"family"`, `"caregiver"`, or `"admin"` |
| `emergencyContacts` | array | Yes | List of `{name, phone, relation}` maps |
| `fcmToken` | string | No | Firebase Cloud Messaging token |
| `fcmTokenUpdatedAt` | timestamp | No | When FCM token was last updated |

**Sub-collection: `users/{userId}/notifications`**

| Field | Type | Description |
|---|---|---|
| `id` | string | Notification ID |
| `userId` | string | Target user ID |
| `title` | string | Notification title |
| `body` | string | Notification body text |
| `timestamp` | timestamp | When the notification was created |
| `isRead` | boolean | Read/unread status |
| `type` | string | `"booking"`, `"system"`, or `"promotion"` |
| `targetId` | string | Related entity ID (e.g., booking ID) |

---

### `bookings`

Stores all service bookings. Document ID = auto-generated.

| Field | Type | Required | Description |
|---|---|---|---|
| `userId` | string | Yes | Family user's UID |
| `userName` | string | No | Family user's display name |
| `serviceId` | string | Yes | Reference to service document |
| `serviceName` | string | Yes | Service title (denormalized) |
| `date` | timestamp | Yes | Booking date |
| `time` | string | No | Time slot (e.g., "10:00 AM") |
| `duration` | string | No | Service duration (e.g., "2 hours") |
| `status` | string | Yes | `"upcoming"`, `"completed"`, `"cancelled"`, `"completion_requested"` |
| `price` | number | Yes | Amount paid |
| `servicePersonnelId` | string | No | Assigned caregiver UID |
| `servicePersonnelName` | string | No | Assigned caregiver name |
| `startTime` | timestamp | No | Computed booking start time |
| `endTime` | timestamp | No | Computed booking end time |
| `completionOtp` | string | No | 6-digit OTP for verified completion |
| `otpGeneratedAt` | timestamp | No | When OTP was generated |
| `isVerifiedComplete` | boolean | No | Whether completion was OTP-verified |
| `latitude` | number | No | Service location latitude |
| `longitude` | number | No | Service location longitude |
| `userLocationAddress` | string | No | Formatted service address |
| `createdAt` | timestamp | Yes | Booking creation timestamp (server) |

---

### `services`

Stores available services. Document ID = auto-generated.

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string | Yes | Service name |
| `description` | string | Yes | Service description |
| `category` | string | Yes | Service category |
| `imageUrl` | string | Yes | URL to service image |
| `includedItems` | array | Yes | List of included items/features (strings) |
| `isPopular` | boolean | Yes | Whether to feature in popular carousel |
| `options` | array | Yes | List of `{duration, price}` pricing tiers |

**`options` sub-structure:**

| Field | Type | Description |
|---|---|---|
| `duration` | string | Duration label (e.g., "2 hours", "Full Day") |
| `price` | number | Price in INR |

---

### `servicePersonnel`

Stores caregiver/partner profiles. Document ID = Firebase Auth UID.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Full name |
| `age` | number | No | Age |
| `gender` | string | No | Gender |
| `rating` | number | No | Average rating |
| `specialties` | array | No | List of specialty strings |
| `imageUrl` | string | No | Profile photo URL |
| `isAvailable` | boolean | No | Currently available for assignments |
| `isOnline` | boolean | No | Currently online |
| `visitsCompleted` | number | No | Total completed bookings |
| `idVerified` | boolean | No | Identity verification status |
| `languages` | array | No | Spoken languages |
| `keySkills` | array | No | Key skills list |
| `reviews` | array | No | List of review objects |
| `experience` | string | No | Experience description |
| `bio` | string | No | Short biography |
| `email` | string | No | Email address |
| `phone` | string | No | Phone number |
| `street` | string | No | Street address |
| `city` | string | No | City |
| `state` | string | No | State |
| `pincode` | string | No | Postal code |
| `country` | string | No | Country |

**Sub-collection: `servicePersonnel/{personnelId}/notifications`**

Same structure as `users/{userId}/notifications`.

---

### `whitelisted_partners`

Pre-approved caregiver emails. Document ID = email address.

| Field | Type | Description |
|---|---|---|
| `isEnabled` | boolean | Whether this email is allowed to register as caregiver |

---

### `config`

System configuration. Managed by admins.

**Document: `system`**

| Field | Type | Description |
|---|---|---|
| `bookingStartHour` | number | Earliest booking hour (24h format) |
| `bookingEndHour` | number | Latest booking hour (24h format) |
| `profilePhotoRequired` | boolean | Whether profile photo is mandatory |

---

## Firebase Storage Structure

```
profile_images/
└── {filename}          # User profile photos (5MB max, image/* MIME types)
```

### Storage Rules
- **Read**: Public (any authenticated user)
- **Write**: Authenticated users only, file < 5MB, must be image MIME type
- **All other paths**: Denied by default

---

## Firestore Security Rules Summary

| Collection | Read | Create | Update/Delete |
|---|---|---|---|
| `users` | Owner or Admin | Authenticated | Owner or Admin (verified) |
| `bookings` | Any verified user | Any verified user | Owner, assigned personnel, or Admin |
| `servicePersonnel` | Any verified user or owner | Authenticated | Owner or Admin |
| `services` | Public (no auth) | Admin only | Admin only |
| `config` | Authenticated | Admin only | Admin only |
| `whitelisted_partners` | Public (no auth) | Admin only | Admin only |
| `*/notifications` | Owner or Admin | Authenticated | Authenticated |
| Everything else | Denied | Denied | Denied |
