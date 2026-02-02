#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 HH:MM HH:MM" >&2
  exit 1
fi

TIME_A="$1"
TIME_B="$2"

validate_time() {
  local value="$1"
  if [[ ! "$value" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Invalid time '$value'. Use 24-hour HH:MM (e.g. 15:30)." >&2
    exit 1
  fi
}

validate_time "$TIME_A"
validate_time "$TIME_B"

HOUR_A=$((10#${TIME_A%%:*}))
MIN_A=$((10#${TIME_A##*:}))
HOUR_B=$((10#${TIME_B%%:*}))
MIN_B=$((10#${TIME_B##*:}))

TOTAL_A=$((HOUR_A * 60 + MIN_A))
TOTAL_B=$((HOUR_B * 60 + MIN_B))
if (( TOTAL_A <= TOTAL_B )); then
  EARLY_TOTAL=$TOTAL_A
else
  EARLY_TOTAL=$TOTAL_B
fi
WAKE_SCHED_TOTAL=$(((EARLY_TOTAL + 5) % 1440))
WAKE_SCHED_HOUR=$((WAKE_SCHED_TOTAL / 60))
WAKE_SCHED_MIN=$((WAKE_SCHED_TOTAL % 60))

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PLIST_PATH="$ROOT_DIR/src/launchd/com.sawyer.PROJECT_SLUG.plist"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.sawyer.PROJECT_SLUG.plist"
WAKE_PLIST_PATH="$ROOT_DIR/src/launchd/com.sawyer.PROJECT_SLUG-wake.plist"
WAKE_DAEMON="/Library/LaunchDaemons/com.sawyer.PROJECT_SLUG-wake.plist"

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "LaunchAgent plist not found at $PLIST_PATH" >&2
  exit 1
fi
if [[ ! -f "$WAKE_PLIST_PATH" ]]; then
  echo "Wake LaunchDaemon plist not found at $WAKE_PLIST_PATH" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
ln -sf "$PLIST_PATH" "$LAUNCH_AGENT"

if [[ -L "$WAKE_DAEMON" ]]; then
  sudo rm "$WAKE_DAEMON"
fi
sudo cp "$WAKE_PLIST_PATH" "$WAKE_DAEMON"
sudo chown root:wheel "$WAKE_DAEMON"
sudo chmod 644 "$WAKE_DAEMON"

plist_set() {
  local plist="$1"
  local cmd="$2"
  shift 2
  if [[ "$plist" == "$WAKE_DAEMON" ]]; then
    sudo /usr/libexec/PlistBuddy -c "$cmd" "$plist" "$@"
  else
    /usr/libexec/PlistBuddy -c "$cmd" "$plist" "$@"
  fi
}

/usr/libexec/PlistBuddy -c "Delete :StartCalendarInterval" "$PLIST_PATH" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval array" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:0 dict" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:0:Hour integer $HOUR_A" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:0:Minute integer $MIN_A" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:1 dict" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:1:Hour integer $HOUR_B" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:1:Minute integer $MIN_B" "$PLIST_PATH"

update_wake_plist() {
  local plist="$1"
  [[ -f "$plist" ]] || return 0
  plist_set "$plist" "Delete :StartCalendarInterval" >/dev/null 2>&1 || true
  plist_set "$plist" "Add :StartCalendarInterval dict"
  plist_set "$plist" "Add :StartCalendarInterval:Hour integer $WAKE_SCHED_HOUR"
  plist_set "$plist" "Add :StartCalendarInterval:Minute integer $WAKE_SCHED_MIN"
  plist_set "$plist" "Delete :ProgramArguments" >/dev/null 2>&1 || true
  plist_set "$plist" "Add :ProgramArguments array"
  plist_set "$plist" "Add :ProgramArguments:0 string /bin/bash"
  plist_set "$plist" "Add :ProgramArguments:1 string $ROOT_DIR/scripts/schedule-wakes.sh"
  plist_set "$plist" "Add :ProgramArguments:2 string $TIME_A"
  plist_set "$plist" "Add :ProgramArguments:3 string $TIME_B"
}

update_wake_plist "$WAKE_PLIST_PATH"
update_wake_plist "$WAKE_DAEMON"

sudo "$ROOT_DIR/scripts/schedule-wakes.sh" "$TIME_A" "$TIME_B"

if [[ -f "$LAUNCH_AGENT" ]]; then
  launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
  launchctl load "$LAUNCH_AGENT"
  echo "Updated schedule to $TIME_A and $TIME_B and reloaded LaunchAgent."
else
  echo "Updated schedule to $TIME_A and $TIME_B in $PLIST_PATH."
  echo "LaunchAgent not found at $LAUNCH_AGENT; reload it manually if needed."
fi

if [[ -f "$WAKE_DAEMON" ]]; then
  sudo launchctl bootout system "$WAKE_DAEMON" 2>/dev/null || true
  sudo launchctl bootstrap system "$WAKE_DAEMON"
  echo "Reloaded wake scheduler LaunchDaemon."
fi

echo ""
echo "Verification:"
pmset -g sched || true
launchctl list | rg com.sawyer.PROJECT_SLUG || true
