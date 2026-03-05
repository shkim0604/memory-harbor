# Play Store Release Checklist

Last updated (ET): 2026-03-02

## 1) Upload Key 생성 (최초 1회)

```bash
keytool -genkeypair -v \
  -keystore android/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

## 2) 서명 설정 파일 준비

```bash
cp android/key.properties.example android/key.properties
```

`android/key.properties` 예시:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

대안: CI에서는 아래 환경변수 4개만 설정해도 동작합니다.

- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## 3) 버전 올리기

`pubspec.yaml`의 `version`을 매 릴리즈마다 증가:

- 형식: `x.y.z+buildNumber`
- Play Store는 `+buildNumber(versionCode)`가 이전보다 반드시 커야 함

## 4) AAB 빌드

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=ENV=dev
```

출력물:

- `build/app/outputs/bundle/release/app-release.aab`

## 5) Play Console 업로드 전 확인

- 앱 이름/아이콘/스크린샷/개인정보처리방침 URL 최신화
- Data safety 설문 최신화
- 권한 사용 목적 설명 (`RECORD_AUDIO`, `POST_NOTIFICATIONS`, `CAMERA`)
- 타겟 SDK/정책 위반 경고 없음 확인
- 내부 테스트 트랙 업로드 후 설치/통화/알림 스모크 테스트

## 6) 업로드 후

- Internal testing 배포
- 실제 기기에서 로그인/통화 수신/통화 종료/히스토리 저장 확인
- 문제 없으면 Closed/Open testing 또는 Production으로 승격
