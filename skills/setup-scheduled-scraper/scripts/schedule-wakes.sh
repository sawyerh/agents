#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 HH:MM HH:MM" >&2
  exit 1
fi

TIME_A="$1"
TIME_B="$2"
OWNER="PROJECT_SLUG"
WAKE_OFFSET_MIN=5

validate_time() {
  local value="$1"
  if [[ ! "$value" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Invalid time '$value'. Use 24-hour HH:MM (e.g. 19:00)." >&2
    exit 1
  fi
}

to_minutes() {
  local value="$1"
  local hour="${value%%:*}"
  local minute="${value##*:}"
  echo $((10#$hour * 60 + 10#$minute))
}

from_minutes() {
  local total=$1
  local hour=$((total / 60))
  local minute=$((total % 60))
  printf "%02d:%02d" "$hour" "$minute"
}

next_occurrence() {
  local time="$1"
  local now_epoch
  local today
  local candidate_epoch

  now_epoch="$(/bin/date +%s)"
  today="$(/bin/date +%Y-%m-%d)"
  candidate_epoch="$(/bin/date -j -f "%Y-%m-%d %H:%M" "$today $time" +%s)"

  if (( candidate_epoch <= now_epoch )); then
    candidate_epoch="$(/bin/date -j -v+1d -f "%Y-%m-%d %H:%M" "$today $time" +%s)"
  fi

  /bin/date -j -f "%s" "$candidate_epoch" +"%m/%d/%y %H:%M:%S"
}

validate_time "$TIME_A"
validate_time "$TIME_B"

wake_time_for() {
  local run_time="$1"
  local total
  local wake_total
  total="$(to_minutes "$run_time")"
  wake_total=$(((total - WAKE_OFFSET_MIN + 1440) % 1440))
  from_minutes "$wake_total"
}

WAKE_TIME_A="$(wake_time_for "$TIME_A")"
WAKE_TIME_B="$(wake_time_for "$TIME_B")"

while read -r line; do
  [[ -z "$line" ]] && continue
  type="$(echo "$line" | /usr/bin/awk '{print $2}')"
  date_part="$(echo "$line" | /usr/bin/awk '{print $4}')"
  time_part="$(echo "$line" | /usr/bin/awk '{print $5}')"
  if [[ -n "$type" && -n "$date_part" && -n "$time_part" ]]; then
    /usr/bin/pmset schedule cancel "$type" "$date_part $time_part" "$OWNER" >/dev/null 2>&1 || true
  fi
done < <(/usr/bin/pmset -g sched | /usr/bin/grep "by '$OWNER'" || true)

WAKE_DATE_A="$(next_occurrence "$WAKE_TIME_A")"
WAKE_DATE_B="$(next_occurrence "$WAKE_TIME_B")"

/usr/bin/pmset schedule wakeorpoweron "$WAKE_DATE_A" "$OWNER"
if [[ "$WAKE_DATE_B" != "$WAKE_DATE_A" ]]; then
  /usr/bin/pmset schedule wakeorpoweron "$WAKE_DATE_B" "$OWNER"
fi

echo "Scheduled wake events:"
echo "  - $WAKE_DATE_A (for $TIME_A)"
if [[ "$WAKE_DATE_B" != "$WAKE_DATE_A" ]]; then
  echo "  - $WAKE_DATE_B (for $TIME_B)"
fi
