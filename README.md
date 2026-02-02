# memory_harbor

Flutter client for the MemHarbor app (memory + caregiving).

## Project Structure

```
lib/
  data/
    mock_data.dart         # Local seed data for UI development
  firebase/
    firebase_config.dart        # Env + emulator routing for Firebase
    firebase_options_dev.dart   # Dev Firebase options (generated)
    firebase_options_prod.dart  # Prod Firebase options (generated)
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
  theme/                   # App theme & colors
  widgets/                 # Reusable UI widgets
```

## Firebase Setup (Prod/Dev + Emulator)

This app uses environment flags to choose Firebase options and emulator routing.

### Env Flags

- `ENV=prod|dev` (default: `dev`)
- `USE_EMULATOR=true|false` (default: `true`)

### Initialize (already wired)

`lib/main.dart` calls `FirebaseConfig.initialize()` which:
1) selects the correct Firebase options file
2) routes to local emulators when `ENV=dev` and `USE_EMULATOR=true`

### Generate Firebase options

This project expects **separate option files**:
- `lib/firebase_options_prod.dart`
- `lib/firebase_options_dev.dart`

Generate them with FlutterFire CLI (paths match `lib/firebase/`):

```
flutterfire configure --project=<prod-project-id> --out=lib/firebase/firebase_options_prod.dart --platforms=ios,android
flutterfire configure --project=<dev-project-id> --out=lib/firebase/firebase_options_dev.dart --platforms=ios,android
```

### Run

Prod (disable emulator):
```
flutter run --dart-define=ENV=prod --dart-define=USE_EMULATOR=false
```

Dev + emulator:
```
flutter run --dart-define=ENV=dev --dart-define=USE_EMULATOR=true
```

## Notes

- `lib/data/mock_data.dart` is used for UI scaffolding and demo data.
- The domain models in `lib/models/` are plain Dart models, designed to be
  firestore-friendly (json serialization + snapshots).
