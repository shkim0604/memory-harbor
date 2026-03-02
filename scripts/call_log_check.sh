#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/call_log_check.sh --scenario <name> --call-id <id> --caller-log <path> --receiver-log <path>

Scenarios:
  caller_cancel_ringing
  receiver_decline_ringing
  caller_end_connected
  receiver_end_connected
USAGE
}

scenario=""
call_id=""
caller_log=""
receiver_log=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) scenario="$2"; shift 2 ;;
    --call-id) call_id="$2"; shift 2 ;;
    --caller-log) caller_log="$2"; shift 2 ;;
    --receiver-log) receiver_log="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "$scenario" || -z "$call_id" || -z "$caller_log" || -z "$receiver_log" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$caller_log" ]]; then
  echo "[ERROR] caller log not found: $caller_log"
  exit 2
fi
if [[ ! -f "$receiver_log" ]]; then
  echo "[ERROR] receiver log not found: $receiver_log"
  exit 2
fi

contains() {
  local file="$1"
  local regex="$2"
  rg -n --pcre2 "$regex" "$file" >/dev/null 2>&1
}

check() {
  local label="$1"
  local file="$2"
  local regex="$3"
  if contains "$file" "$regex"; then
    echo "[PASS] $label"
    return 0
  fi
  echo "[FAIL] $label"
  return 1
}

# Common sanity: both sides should mention the same call id at least once.
fail=0
check "caller has callId" "$caller_log" "callId=${call_id}|call_id=${call_id}|\bid=${call_id}\b" || fail=1
check "receiver has callId" "$receiver_log" "callId=${call_id}|call_id=${call_id}|\bid=${call_id}\b" || fail=1

case "$scenario" in
  caller_cancel_ringing)
    check "caller sent cancel" "$caller_log" "\\[CSV\\] endCall notify: cancel callId=${call_id}|\\[CIV\\] postOk path=/api/call/cancel ok=true.*call_id.:.?${call_id}" || fail=1
    check "receiver observed cancelled" "$receiver_log" "watcher: callId=${call_id}, status=cancelled|\\[CSV\\] watchCallStatus: callId=${call_id} status=cancelled" || fail=1
    check "receiver dismissed incoming UI" "$receiver_log" "CallKit dismissed for callId=${call_id}|endCall done: callId=${call_id}" || fail=1
    ;;
  receiver_decline_ringing)
    check "receiver sent decline" "$receiver_log" "\\[CIV\\] postOk path=/api/call/answer ok=true.*action.:.?decline.*call_id.:.?${call_id}|\\[CSV\\] declineIncoming: callId=${call_id}" || fail=1
    check "caller observed declined" "$caller_log" "\\[CSV\\] watchCallStatus: callId=${call_id} status=declined|watcher: callId=${call_id}, status=declined" || fail=1
    check "caller ended local session" "$caller_log" "\\[CSV\\] endCall done: callId=${call_id}" || fail=1
    ;;
  caller_end_connected)
    check "caller reached on-call" "$caller_log" "status=CallSessionState\.onCall|통화 중" || fail=1
    check "caller sent end" "$caller_log" "\\[CSV\\] endCall notify: end callId=${call_id}|\\[CIV\\] postOk path=/api/call/end ok=true.*call_id.:.?${call_id}" || fail=1
    check "receiver ended by remote" "$receiver_log" "\\[CSV\\] endCall done: callId=${call_id}|Agora: User .* offline" || fail=1
    ;;
  receiver_end_connected)
    check "receiver reached on-call" "$receiver_log" "status=CallSessionState\.onCall|통화 중" || fail=1
    check "receiver sent end" "$receiver_log" "\\[CSV\\] endCall notify: end callId=${call_id}|\\[CIV\\] postOk path=/api/call/end ok=true.*call_id.:.?${call_id}" || fail=1
    check "caller ended by remote" "$caller_log" "\\[CSV\\] endCall done: callId=${call_id}|Agora: User .* offline" || fail=1
    ;;
  *)
    echo "[ERROR] unknown scenario: $scenario"
    usage
    exit 2
    ;;
esac

if [[ "$fail" -eq 0 ]]; then
  echo "[RESULT] PASS"
  exit 0
fi

echo "[RESULT] FAIL"
exit 1
