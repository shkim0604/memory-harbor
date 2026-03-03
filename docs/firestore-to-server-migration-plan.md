# Firestore -> Server API 이관 계획 (MVVM 기준)

Last updated (ET): 2026-03-02

## 목표
- 클라이언트의 Firestore 직접 접근을 줄여 권한/감사/비즈니스 규칙을 서버에서 통제한다.
- **콜 세션 로직(초대/수락/종료/녹음)은 동작 변경 없이 유지**한다.
- 화면/뷰모델은 Service 인터페이스만 사용하도록 정리한다.

## 현재 직접 접근 지점(우선 확인)
1. `lib/screens/reviews/review_write_screen.dart`
2. `lib/viewmodels/reviews_viewmodel.dart`

위 두 지점은 `screens`/`viewmodels`에서 Firestore 트랜잭션과 다중 조회를 직접 수행하고 있어, MVVM 분리 원칙과 유지보수성 측면에서 이관 우선순위가 가장 높다.

## 이관 우선순위

### P0 (즉시)
1. 리뷰 작성/수정 트랜잭션 서버화
2. 리뷰 피드 조회 서버화
3. 리뷰 작성 컨텍스트(통화 메모, 주제 옵션) 서버화

### P1 (다음)
1. 히스토리/통계성 집계 조회 서버화
2. 권한 정책을 서버 검증 기반으로 강화

### P2 (선택)
1. 서버 응답 캐시/페이지네이션 고도화
2. 관측성(요청 ID, 지연시간, 실패율) 대시보드화

## 권장 엔드포인트 설계

### 1) 리뷰 컨텍스트 조회
- `GET /api/reviews/context?call_id={callId}`
- 용도: 리뷰 화면 초기 진입 데이터 제공
- 응답 예시 필드:
  - `callId`
  - `humanNotes`
  - `receiverId`
  - `selectedTopicType`
  - `selectedTopicId`
  - `topicOptions` (residence/meaning 통합 목록)

### 2) 내 기존 리뷰 조회
- `GET /api/reviews/my?call_id={callId}`
- 용도: 작성/수정 모드 판단, 기존 값 채우기

### 3) 리뷰 업서트(생성/수정)
- `POST /api/reviews/upsert`
- 용도: 기존 Firestore transaction 로직을 서버 단일 트랜잭션으로 이동
- 요청 핵심 필드:
  - `callId`
  - `listeningScore`
  - `selectedTopicType`, `selectedTopicId`
  - `mentionedResidences`
  - `notFullyHeardMoment`, `nextSessionTry`
  - `emotionWord`, `emotionSource`, `smallReset`
  - `requiredQuestionDurationSec`
  - `humanNotes`

### 4) 리뷰 피드 조회
- `GET /api/reviews/feed?group_id={groupId}&limit={limit}&cursor={cursor}`
- 용도: `ReviewsViewModel` 페이징 대체
- 응답:
  - `items[]`
  - `nextCursor`
  - `hasMore`

## 인증/보안 권장안
1. 클라이언트는 Firebase ID Token을 `Authorization: Bearer`로 전달
2. 서버는 토큰 검증 후 `uid`를 신뢰 소스로 사용
3. `writerUserId`는 요청 본문 값 무시하고 서버에서 강제
4. 그룹 소속/콜 참여자 권한을 서버에서 검증

## 클라이언트 변경 전략

### 단계 1: Service 추가(병행 지원)
1. `ReviewService` 신설
2. 기존 Firestore 경로와 API 경로를 feature flag로 분기
3. 스크린/뷰모델은 `ReviewService`만 호출

### 단계 2: 화면/뷰모델 치환
1. `review_write_screen.dart`의 Firestore 코드를 ViewModel/Service 호출로 이동
2. `reviews_viewmodel.dart`의 Firestore 쿼리를 API 페이징으로 교체

### 단계 3: 정리
1. direct Firestore 코드 제거
2. Firestore rules 최소권한 재조정
3. 문서/테스트 업데이트

## 회귀 방지 체크포인트
1. 리뷰 생성/수정 시 `reviewCount` 증감 로직 일치
2. `mentionedResidences` 및 `selectedMeaningId` 반영 일치
3. 필수 응답 시간(`requiredQuestionDurationSec`) 저장 일치
4. 통화 종료 -> 리뷰 화면 진입/저장 플로우 불변
5. 콜 invite/answer/end API 동작 불변

## 롤아웃 계획
1. 내부 계정 2개로 스테이징 A/B 테스트(기존 Firestore vs API)
2. 실패 시 feature flag로 즉시 롤백
3. 안정화 후 기본 경로를 API로 전환
