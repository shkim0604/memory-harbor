# Call Debug Matrix (16 cases)

이 문서는 플랫폼 조합 4개 x 종료 시나리오 4개를 동일한 절차로 재현/판정하기 위한 체크리스트입니다.

## 1) 로그 수집

각 케이스를 실행하기 전에 발신자/수신자 로그를 각각 파일로 저장합니다.

```bash
# Android
adb logcat | rg "\[CSV\]|\[CIV\]|\[CNS\]|\[LIFE\]|Agora:" > caller.log
adb logcat | rg "\[CSV\]|\[CIV\]|\[CNS\]|\[LIFE\]|Agora:" > receiver.log
```

iOS는 Xcode 콘솔을 텍스트로 저장해 동일하게 `caller.log`, `receiver.log`로 둡니다.

## 2) 시나리오 코드

- `caller_cancel_ringing`: 발신 도중 발신자 종료
- `receiver_decline_ringing`: 발신 도중 수신자 거부
- `caller_end_connected`: 연결된 뒤 발신자 종료
- `receiver_end_connected`: 연결된 뒤 수신자 종료

## 3) 자동 판정 실행

```bash
scripts/call_log_check.sh \
  --scenario caller_cancel_ringing \
  --call-id <CALL_ID> \
  --caller-log caller.log \
  --receiver-log receiver.log
```

`<CALL_ID>`는 로그의 `[CIV] inviteCall success: callId=...` 값 사용.

## 4) 16개 케이스 매트릭스

| 발신 -> 수신 | caller_cancel_ringing | receiver_decline_ringing | caller_end_connected | receiver_end_connected |
|---|---|---|---|---|
| Android -> iOS | [ ] | [ ] | [ ] | [ ] |
| Android -> Android | [ ] | [ ] | [ ] | [ ] |
| iOS -> Android | [ ] | [ ] | [ ] | [ ] |
| iOS -> iOS | [ ] | [ ] | [ ] | [ ] |

각 셀에 대해 자동 판정 결과를 기록:

- PASS: 스크립트가 `[RESULT] PASS`
- FAIL: 스크립트가 `[RESULT] FAIL`

## 5) FAIL 발생 시 우선 확인 포인트

- 발신 측에 `[CSV] endCall notify:` 또는 `[CIV] postOk path=` 로그가 있는지
- 수신 측 `watcher: callId=..., status=` 가 기대 상태(`declined`, `cancelled`)로 들어오는지
- 연결 후 종료 케이스에서 `Agora: User ... offline` 또는 `[CSV] endCall done:`이 반대편에 보이는지

## 6) 16개 일괄 판정 (옵션)

로그를 아래 구조로 모으면 한 번에 결과표를 생성할 수 있습니다.

```text
logs/
  a2i/
    caller_cancel_ringing_caller.log
    caller_cancel_ringing_receiver.log
    caller_cancel_ringing.callid
    ... (나머지 3개 시나리오 동일)
  a2a/
  i2a/
  i2i/
```

실행:

```bash
scripts/call_matrix_check.sh logs
cat logs/matrix-result.md
```
