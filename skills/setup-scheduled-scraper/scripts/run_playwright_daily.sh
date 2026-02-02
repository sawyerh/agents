#!/usr/bin/env bash
set -Eeuo pipefail

# Scheduled Playwright runner. Intended to be invoked by launchd.

PROJECT_DIR="/Users/sawyer/Dev/Projects/PROJECT_SLUG"
LOG_DIR="$HOME/Library/Logs"
OUT_LOG="$LOG_DIR/PROJECT_SLUG.out.log"
ERR_LOG="$LOG_DIR/PROJECT_SLUG.err.log"
NOTIFY_TITLE="PROJECT_SLUG"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"

# Be explicit about PATH for launchd context
export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$PROJECT_DIR"

json_escape() {
  local value=${1:-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf "%s" "$value"
}

log_json() {
  local level=$1
  local msg=$2
  local time
  time="$(date -Iseconds)"
  printf '{"level":%s,"time":"%s","msg":"%s"}\n' \
    "$level" \
    "$time" \
    "$(json_escape "$msg")"
}

notify() {
  local message=${1:-}
  /usr/bin/osascript -e "display notification \"${message//\"/\\\"}\" with title \"${NOTIFY_TITLE//\"/\\\"}\"" >/dev/null 2>&1 || true
}

notify_failure() {
  local code=${1:-1}
  notify "Scheduled run failed (exit ${code})."
}

notify_success() {
  notify "Scheduled run succeeded (scrape + push)."
}

trap 'notify_failure $?' ERR

{
  log_json 30 "Scheduled scrape start"
  log_json 30 "Running: npm run scrape"
  npm run --silent scrape
  log_json 30 "Scheduled scrape end"
} >>"$OUT_LOG" 2>>"$ERR_LOG"

# Commit the results.json file (and metadata) and push to GitHub
{
  log_json 30 "Committing results to GitHub"
  git add results.json scraper-metadata.json >>/dev/null 2>&1
  git commit -m "Automated scrape results update: $(date -I)" > /dev/null 2>&1 || {
    log_json 40 "No changes to commit"
    exit 0
  }
  git push origin main >>/dev/null 2>&1
  log_json 30 "Results committed and pushed to GitHub"
} >>"$OUT_LOG" 2>>"$ERR_LOG"

notify_success
