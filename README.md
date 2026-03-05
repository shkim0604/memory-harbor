# memory_harbor

Flutter client for the MemHarbor app (memory + caregiving).

Last updated (ET): 2026-03-02

## Project Structure

```
lib/
  config/
    agora_config.dart      # Agora appId + API base URL
  utils/
    time_utils.dart        # Timezone helpers (America/New_York)
    call_format_utils.dart # Call date/duration UI formatting helpers
  firebase/
    firebase_config.dart        # Env-based Firebase options routing
    firebase_options_dev.dart   # Dev Firebase options (generated)
    firebase_options_prod.dart  # Prod Firebase options (generated)
  firebase_options.dart         # Default FlutterFire output (unused)
  services/
    auth_service.dart       # Google/Apple auth wrappers
    user_service.dart       # Firestore user CRUD
    call_service.dart       # Call session CRUD
    care_receiver_service.dart  # Care receiver CRUD
    group_service.dart      # Group CRUD
    permission_service.dart # Runtime permission requests
    storage_service.dart    # Storage upload/download
    agora_service.dart      # Agora RTC + server recording bridge
    call_notification_service.dart # FCM + CallKit incoming call handling
    review_service.dart    # Reviews API client
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

## Refactoring Notes (2026-03-02)

- 콜 세션 로직(`CallSessionViewModel`, `AgoraService`, `CallInviteService`)은 **동작 변경 없이** 가독성 중심으로만 정리했습니다.
- 화면 계층에서 반복되던 통화 시간/날짜 포맷 로직을 `CallFormatUtils`로 추출해 중복을 줄였습니다.
- 리시버/홈 화면의 텍스트 포맷 및 일부 린트 이슈를 정리해 유지보수성을 개선했습니다.
- 앱 루트(`main.dart`)에서 최소 텍스트 스케일(1.08)을 보장해 중장년층 대상 가독성을 높였습니다.

## Firestore Direct Access vs Server API (검토안)

현재 클라이언트 일부 ViewModel은 Firestore를 직접 조회합니다. 빠른 개발에는 유리하지만, 아래 상황에서는 서버 API로 옮기는 편이 좋습니다.

- 권한 정책/감사 로그/비즈니스 룰을 서버에서 강제해야 할 때
- 복잡한 조인/집계/정렬이 늘어나 쿼리 유지비가 커질 때
- 앱 업데이트 없이 응답 스키마를 점진적으로 바꾸고 싶을 때

권장 단계:
1. 조회량이 큰 화면(리뷰/히스토리)부터 읽기 API를 서버로 이관
2. 앱은 Service 레이어를 통해 API/Firestore를 교체 가능하게 유지
3. 안정화 후 Firestore rules를 최소 권한 기준으로 재정비

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

## Firebase Setup (Dev + Prod)

This app uses environment flags to choose Firebase options.

### Env Flags

- `ENV=dev|prod` (default: `dev`)

### Initialize (already wired)

`lib/main.dart` calls `FirebaseConfig.initialize()` which:
1) selects the correct Firebase options file

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
- `ENV=prod` is reserved for a future dedicated prod project

### Run

Dev (real Firebase):
```
flutter run --dart-define=ENV=dev
```

Prod:
```
flutter run --dart-define=ENV=prod
```

## Android Notes

This project requires **JDK 17** for Android builds. Ensure Gradle uses JDK 17:
- `android/gradle.properties` includes `org.gradle.java.home=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`

## Notes

- The domain models in `lib/models/` are plain Dart models, designed to be
  firestore-friendly (json serialization + snapshots).

## Operational Docs

- `docs/device-accessibility-qa-checklist.md`
- `docs/firestore-to-server-migration-plan.md`
- `docs/playstore-release-checklist.md`
