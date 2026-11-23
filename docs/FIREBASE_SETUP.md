# Firebase authentication and data setup

The Android apps use the existing Firebase project `alshaikha`.

## Customer accounts
- The customer enters a username and password only.
- The app maps the username internally to `<username>@alshaikha.app` for Firebase Email/Password Authentication. The customer is never asked for an email address or phone number.
- On registration, the app creates `profiles/{uid}` with `role: customer`.

Usernames currently accept 3–24 lowercase English letters, digits, dots, and underscores. Passwords must contain at least 6 characters.

## Administration account
Admin accounts are not self-registering from the app. Create the admin login in Firebase Authentication using the internal email form `adminusername@alshaikha.app`, then create a Firestore document at `profiles/{AUTH_UID}` with:
```json
{
  "uid": "AUTH_UID",
  "username": "adminusername",
  "displayName": "Administration",
  "role": "admin"
}
```
Only a profile whose role is `admin` can enter the administration app.

## Security rules
The repository contains `firestore.rules` and `storage.rules`. Review and deploy them to the existing Firebase project before using real customer data. From a trusted machine with Firebase CLI configured for project `alshaikha`, run:
```sh
firebase use alshaikha
firebase deploy --only firestore:rules,storage
```
Do not place service-account credentials or admin SDK secrets in either Android app.

## Cloud data
The shared data repository reads and writes Firestore collections while retaining the Android local store as a cache where the admin provider is installed. The customer app can also run on a phone without the admin app installed; in that case Firestore is its data source.
