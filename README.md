# DailyHub — All-in-One Daily Life Manager

A cross-platform Flutter app (Android + iOS + web) that shares the **same
Firebase backend as your existing web app** (`khurram-world`). Trips and to-dos
created on the web show up here and vice-versa, plus a stack of new features for
everyday life.

> Your deployed HTML web app is **untouched**. This is a separate Flutter app
> that talks to the same Realtime Database.

---

## What's inside (features)

1. Email/password + Google login (same accounts as web)
2. Home dashboard — today's tasks, upcoming reminders, quick stats
3. To-Dos — priority, date/time, deadline notifications *(interoperates with web)*
4. Trips — flight/train/bus/car with mode-specific fields *(interoperates with web)*
5. Quick Notes — pin, colors, tags, search
6. **Quick Capture** — the ⚡ button on every screen to jot an idea instantly
7. Reminders — one-time & repeating, fire **even when the app is closed**
8. Habit tracker — daily check-ins + streaks 🔥
9. Expense tracker — categories, monthly total, pie chart (₹)
10. Goals — progress tracking
11. Journal — daily entries with mood
12. Bookmarks — save & open links
13. Calendar — month view aggregating tasks, trips & reminders
14. Global search — across notes, tasks & trips
15. **Dark mode** (persisted)
16. **Hindi / English** in-app toggle
17. **Offline mode** — works with no connection, syncs when back online
18. Data export — download all your data as JSON
19. Local push notifications (Android 13+ permission handled)
20. Shared account/data model with your web workspace-sharing feature

---

## Setup (one-time)

### 0. Prerequisites
- Flutter SDK 3.3+  (`flutter --version`)
- Android Studio or VS Code with the Flutter/Dart extensions
- A device or emulator (you mentioned USB/wireless debugging — perfect)

### 1. Generate the native project scaffolding
This folder contains the Dart code (`lib/`), `pubspec.yaml`, Android override
files, and this README — but **not** the `android/`, `ios/`, `web/` native
folders (those are machine-generated). Generate them in-place:

```bash
cd dailyhub
flutter create . --org com.khurram --project-name dailyhub --platforms android,ios,web
```

This will NOT overwrite the `lib/` files that are already here.

### 2. Install packages
```bash
flutter pub get
```

### 3. Connect Firebase (Android) — the one part only you can do
You need a `google-services.json`. Two options:

**Option A (recommended — automatic):**
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=khurram-world
```
Select Android (and iOS if you want). This writes `google-services.json`,
`GoogleService-Info.plist`, and updates `lib/firebase_options.dart` with the
correct native app IDs.

**Option B (manual):**
1. Go to Firebase Console → project **khurram-world** → Add app → Android.
2. Package name: `com.khurram.dailyhub`
3. Download `google-services.json` → place in `android/app/`.

### 4. Apply the Android tweaks for notifications
- Merge `android_setup/AndroidManifest.xml` into
  `android/app/src/main/AndroidManifest.xml` (permissions + receivers).
- Follow `android_setup/GRADLE_NOTES.md` (desugaring + Google Services plugin + minSdk 23).

### 5. Enable Google Sign-In (if using it)
Firebase Console → Authentication → Sign-in method → enable **Google**.
For Android you must add your app's **SHA-1** fingerprint:
```bash
cd android && ./gradlew signingReport
```
Copy the SHA-1 into Firebase Console → Project settings → your Android app →
Add fingerprint, then re-download `google-services.json`.

### 6. Run it
```bash
flutter run
```

---

## Build for Play Store

```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

Before your first upload:
- **Confirm the package name** `com.khurram.dailyhub` (permanent once published —
  change it now if you want something else, in `android/app/build.gradle` and
  `flutter create --org`).
- Create an upload keystore and configure signing
  (https://docs.flutter.dev/deployment/android#signing-the-app).
- App name shown on the store = the `android:label` ("DailyHub").

---

## Notes / honest status
- This code was written carefully but **could not be compiled in the environment
  it was generated in**, so treat this as a v1 you run first. Expect to run
  `flutter pub get` and possibly bump a package version if pub resolves a newer
  one. Report any analyzer errors and they're quick to fix.
- Reminders currently schedule the **first** occurrence for repeating items; a
  small background re-scheduler for daily/weekly/monthly repeats is the natural
  next add.
- Data model mirrors your web app exactly (`users/{uid}/trips`, `.../todos`,
  `emailToUid/...`) so nothing about the web app changes.

---

## Project structure
```
lib/
  main.dart                 # init Firebase, offline persistence, notifications
  app.dart                  # MaterialApp, theme/locale, auth gate
  firebase_options.dart     # web config real; android via google-services.json
  core/                     # theme, dark-mode provider, localization (EN/HI)
  services/                 # auth, database (generic CRUD), notifications
  screens/                  # one file per feature
  widgets/                  # shared widgets + quick capture
android_setup/              # manifest + gradle snippets to merge after `flutter create`
```
