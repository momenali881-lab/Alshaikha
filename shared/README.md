# Shared on-device database

The administration APK hosts a SQLite-backed Android ContentProvider. The client APK accesses the same provider through ContentResolver and a signature-level Android permission. Both APKs must be signed with the same certificate. The GitHub Actions test build generates one temporary signing key and uses it for both APKs on the same runner; production distribution must use a protected, persistent upload key stored as GitHub Actions secrets.

The shared Flutter API is in shared/lib/shared_store.dart. Android integration sources are copied into generated Flutter Android projects by scripts/prepare_android.py.

This is device-local synchronization only: it works when both apps are installed on the same Android device. It does not synchronize to another phone.
