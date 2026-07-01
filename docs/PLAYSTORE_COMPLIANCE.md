# Google Play Compliance Checklist (Golden Care)

## 1. Core App Summary
Golden Care is a service-booking platform connecting families with caregivers.

- Family users create accounts, complete profiles, book services, pay online, and track bookings.
- Caregivers create profiles, receive assignments, and complete service workflows.
- The app uses Firebase (Auth, Firestore, Storage, Cloud Functions, FCM), Google Maps/location features, and Razorpay for payments.

## 2. Policy Requirements Mapped
This checklist is aligned with Google Play requirements for:

- User Data policy and Privacy Policy requirements
- Data Safety form completeness and accuracy
- Sensitive permission and location usage disclosure
- Account deletion requirements (in-app + outside-app path)

## 3. In-App Legal Routes (Public)
Ensure these routes remain publicly reachable:

- `/legal/privacy`
- `/legal/terms`
- `/legal/refunds`
- `/legal/data-collection`
- `/legal/account-deletion`

## 4. Mandatory Play Console Actions
Before submission, confirm all items below:

1. Add a public privacy policy URL in Play Console.
2. Add account deletion web URL in Play Console Data deletion section.
3. Complete Data Safety form for all collected/shared data types.
4. Keep Data Safety answers consistent with in-app legal text.
5. Provide app access/test credentials if review access is restricted.
6. Ensure target audience, ads declaration, and content rating are current.

## 5. Data Safety Declaration Guidance (App-Specific)
Use this as a starting point and verify final behavior before submission.

- Personal info: name, email, phone, address fields
- Financial info: payment metadata (transaction/order references)
- Location: user-selected address/location for booking operations
- Photos/media: profile image uploads (user initiated)
- App info/performance: diagnostics/security logs (if collected)
- Device or other IDs: FCM token for notifications
- Health-related user input: optional care notes/medical conditions if used in booking details

For each selected data type in Play Console:

1. Declare whether data is collected and/or shared.
2. Declare purpose(s): app functionality, account management, analytics (only if actually used), fraud prevention/security, etc.
3. Declare encryption in transit accurately.
4. Declare deletion request mechanism accurately.

## 6. Permissions and Location
Current manifest-level sensitive permissions include:

- Location (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`)
- Camera (`CAMERA`)
- Notifications (`POST_NOTIFICATIONS`)

Compliance notes:

- Request permissions contextually, only when feature is used.
- Avoid requesting unnecessary scope.
- Do not use location solely for ads/analytics.
- If background location is ever introduced, submit the additional declaration and required video/disclosure artifacts.

## 7. Account Deletion Requirement
Golden Care now includes an in-app path (`Profile -> Delete Account`) and a public account deletion policy route.

Operational rule currently enforced in backend:

- Active bookings block immediate deletion until resolved.

## 8. Final Pre-Release Verification
Run this pre-submit sequence each release:

1. Verify all legal routes open on production web/app builds.
2. Verify profile delete-account flow works in a test account.
3. Verify privacy policy URL and account deletion URL are accessible without login.
4. Verify policy text matches current real app behavior.
5. Re-check Data Safety answers after adding SDKs or new data fields.

## 9. Legal Note
This checklist improves policy alignment and review readiness but is not legal advice. Have final legal text reviewed by your legal counsel for jurisdiction-specific obligations.
