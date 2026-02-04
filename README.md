# memory_harbor

Flutter client for the MemHarbor app (memory + caregiving).

Last updated (ET): 2026-02-04

## Project Structure

```
lib/
  config/
    agora_config.dart      # Agora appId + API base URL
  utils/
    time_utils.dart        # Timezone helpers (America/New_York)
  data/
    mock_data.dart         # Local seed data for UI development
  firebase/
    firebase_config.dart        # Env + emulator routing for Firebase
    firebase_options_dev.dart   # Dev Firebase options (generated)
    firebase_options_prod.dart  # Prod Firebase options (generated)
    seed.py                     # Emulator seed script
  firebase_options.dart         # Default FlutterFire output (unused)
  services/
    auth_service.dart       # Google/Apple auth wrappers
    user_service.dart       # Firestore user CRUD
    call_service.dart       # Call session CRUD
    care_receiver_service.dart  # Care receiver CRUD
    group_service.dart      # Group CRUD
    permission_service.dart # Runtime permission requests
    seed_service.dart       # Emulator seed helper
    storage_service.dart    # Storage upload/download
    agora_service.dart      # Agora RTC + server recording bridge
    call_notification_service.dart # FCM + CallKit incoming call handling
  viewmodels/
    auth_viewmodel.dart         # Auth state + actions
    call_detail_viewmodel.dart  # Call detail screen state
    call_session_viewmodel.dart # Live call session state
    call_viewmodel.dart         # Call list/state
    history_detail_viewmodel.dart # History detail screen state
    history_viewmodel.dart      # History list/state
    home_viewmodel.dart         # Home dashboard state
    onboarding_viewmodel.dart   # Onboarding flow state
    reviews_viewmodel.dart      # Reviews state
    settings_viewmodel.dart     # Settings state
    app_role_viewmodel.dart     # Caregiver/Receiver role routing
    receiver_home_viewmodel.dart # Receiver home state
  models/
    call.dart              # Call domain model
    care_receiver.dart     # CareReceiver domain model
    group.dart             # Group + GroupStats
    model_helpers.dart     # CallStatus + date parsing helpers
    residence.dart         # Residence + ResidenceStats
    review.dart            # Review model
    user.dart              # AppUser model
    models.dart            # Barrel exports
  screens/
    auth/                  # Auth-related screens
    call/                  # Call UX (call screen, call detail)
    history/               # Memory timeline / history screens
    home/                  # Home dashboard
    reviews/               # Reviews screen
    settings/              # Settings screen
    receiver/              # Receiver UI (home + navigation + history)
    main_navigation.dart   # Bottom tab shell
  theme/                   # App theme & colors
  widgets/                 # Reusable UI widgets
```

## Architecture (MVVM)

This project follows a lightweight MVVM structure:

- `screens/` (View): UI only, renders state and forwards user actions.
- `viewmodels/` (ViewModel): owns UI state, async flows, and pagination logic.
- `services/` (Model layer access): Firestore/Auth/Storage/3rd-party integration.
- `models/` (Domain models): plain Dart models + serialization.

**Guidelines**
1. UI should not directly access Firestore/Auth. Use a ViewModel.
2. ViewModels expose plain fields + methods and notify the view via `setState`.
3. Services are stateless singletons; keep network/storage details there.

## Call + Recording

This client uses Agora RTC for voice and delegates recording to the server.

Flow
```
CallSessionViewModel.startCall()
  -> AgoraService.initialize()
  -> fetchToken() (if needed)
  -> joinChannel()
  -> onJoinChannelSuccess
  -> onUserJoined (remote)
  -> /api/recording/start
```

Recording rules
- Recording starts only after both users are in the channel.
- If a user explicitly ends the call, recording stops immediately.
- If a user drops due to network/timeout, we wait 1 minute for rejoin before stopping.

Server endpoints
- `POST /api/recording/start` with `channel`, `uid`, `token`, `group_id`, `caller_id`, `receiver_id`
- `POST /api/recording/stop` with `channel`, `uid`
- `POST /api/call/answer` with `call_id`, `action=accept|decline`
- `POST /api/call/cancel` with `call_id`
- `POST /api/call/missed` with `call_id`
- `POST /api/call/end` with `call_id`

## Roles (Caregiver vs Receiver)

Role routing happens in `MainNavigation` via `AppRoleViewModel`:
- If the current user UID matches `groups.receiverId`, the app boots into **Receiver UI**.
- Otherwise, the app uses the **Caregiver UI**.

Receiver UI includes:
- Home (community stats + recent call list)
- History
- Settings

## Timezone

All time display and generated timestamps are normalized to **America/New_York (ET, DST-aware)** via `TimeUtils`.
If you change this policy, update `lib/utils/time_utils.dart` and the call sites.

## Firebase Setup (Dev + Emulator)

This app uses environment flags to choose Firebase options and emulator routing.

### Env Flags

- `ENV=dev|emul|prod` (default: `dev`)
- `USE_EMULATOR=true|false` (default: `false`)

### Initialize (already wired)

`lib/main.dart` calls `FirebaseConfig.initialize()` which:
1) selects the correct Firebase options file
2) routes to local emulators when `ENV=emul`

### Generate Firebase options

This project expects **separate option files**:
- `lib/firebase_options_prod.dart`
- `lib/firebase_options_dev.dart`

Generate them with FlutterFire CLI (paths match `lib/firebase/`):

```
flutterfire configure --project=<prod-project-id> --out=lib/firebase/firebase_options_prod.dart --platforms=ios,android
flutterfire configure --project=<dev-project-id> --out=lib/firebase/firebase_options_dev.dart --platforms=ios,android
```

Note: `lib/firebase_options.dart` is the default FlutterFire output and is
**not used** by this project (we route through `lib/firebase/firebase_config.dart`).
You can remove it or keep it, but it should not be referenced by app code.

### Current Routing Rules

- `ENV=dev` uses **real Firebase** with `firebase_options_prod.dart`
- `ENV=emul` uses **emulator** with `firebase_options_dev.dart`
- `ENV=prod` is reserved for a future dedicated prod project

### Run

Dev (real Firebase):
```
flutter run --dart-define=ENV=dev
```

Emulator (iOS Simulator / desktop / web):
```
flutter run --dart-define=ENV=emul
```

Emulator (Android Emulator):
```
flutter run --dart-define=ENV=emul
```
Notes:
- Android emulator routes to your Mac's `localhost` via `10.0.2.2` automatically.

Emulator (physical device: iPhone / real Android):
```
flutter run --dart-define=ENV=emul --dart-define=EMULATOR_HOST=<your-mac-ip>
```
Notes:
- Replace `<your-mac-ip>` with your Mac LAN IP, e.g. `ipconfig getifaddr en0`.
- Ensure the phone and Mac are on the same network (Wi‑Fi), and VPN is off.
- iOS will prompt for Local Network permission on first run (required for emulator access).

### Seed Firestore Emulator (Python)

You can seed the Firestore emulator without running the app:

```
cd lib/firebase
python seed.py
```

Notes:
- Firestore emulator must be running on `localhost:8081`.
- This script uses anonymous credentials for the emulator only.

## Android Notes

This project requires **JDK 17** for Android builds. Ensure Gradle uses JDK 17:
- `android/gradle.properties` includes `org.gradle.java.home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`

## Notes

- `lib/data/mock_data.dart` is used for UI scaffolding and demo data.
- The domain models in `lib/models/` are plain Dart models, designed to be
  firestore-friendly (json serialization + snapshots).
