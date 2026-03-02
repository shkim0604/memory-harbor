#!/usr/bin/env bash
set -euo pipefail

# Expected file naming:
# logs/<combo>/<scenario>_caller.log
# logs/<combo>/<scenario>_receiver.log
# logs/<combo>/<scenario>.callid
# combo: a2i, a2a, i2a, i2i
# scenario: caller_cancel_ringing, receiver_decline_ringing, caller_end_connected, receiver_end_connected

ROOT_DIR="${1:-logs}"

SCENARIOS=(
  caller_cancel_ringing
  receiver_decline_ringing
  caller_end_connected
  receiver_end_connected
)
COMBOS=(a2i a2a i2a i2i)

label_combo() {
  case "$1" in
    a2i) echo "Android -> iOS" ;;
    a2a) echo "Android -> Android" ;;
    i2a) echo "iOS -> Android" ;;
    i2i) echo "iOS -> iOS" ;;
    *) echo "$1" ;;
  esac
}

result_file="${ROOT_DIR}/matrix-result.md"
mkdir -p "$ROOT_DIR"

{
  echo "# Call Matrix Result"
  echo
  echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "| 발신 -> 수신 | caller_cancel_ringing | receiver_decline_ringing | caller_end_connected | receiver_end_connected |"
  echo "|---|---|---|---|---|"

  for combo in "${COMBOS[@]}"; do
    row="| $(label_combo "$combo")"
    for scenario in "${SCENARIOS[@]}"; do
      caller_log="$ROOT_DIR/$combo/${scenario}_caller.log"
      receiver_log="$ROOT_DIR/$combo/${scenario}_receiver.log"
      callid_file="$ROOT_DIR/$combo/${scenario}.callid"

      if [[ ! -f "$caller_log" || ! -f "$receiver_log" || ! -f "$callid_file" ]]; then
        row+=" | N/A"
        continue
      fi

      call_id="$(tr -d '[:space:]' < "$callid_file")"
      if [[ -z "$call_id" ]]; then
        row+=" | FAIL"
        continue
      fi

      if scripts/call_log_check.sh \
        --scenario "$scenario" \
        --call-id "$call_id" \
        --caller-log "$caller_log" \
        --receiver-log "$receiver_log" >/tmp/call_matrix_check.$$ 2>&1; then
        row+=" | PASS"
      else
        row+=" | FAIL"
      fi
    done
    row+=" |"
    echo "$row"
  done
} > "$result_file"

echo "Wrote: $result_file"
