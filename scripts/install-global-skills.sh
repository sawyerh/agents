#!/usr/bin/env bash
set -euo pipefail

# Add new mappings as "relative/source:destination-name" entries.
MAPPINGS=(
  "skills/setup-scheduled-scraper:setup-scheduled-scraper"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
# Add new destination roots as needed.
DEST_ROOTS=(
  "${CODEX_HOME}/skills"
  "${CLAUDE_HOME}/skills"
)

confirm_overwrite() {
  local dest="$1"

  if [[ ! -t 0 ]]; then
    echo "Warning: non-interactive shell, skipping existing destination: $dest" >&2
    return 1
  fi

  local response
  read -r -p "Destination exists: $dest. Overwrite? [y/N] " response
  case "$response" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

copy_dir() {
  local src="$1"
  local dest="$2"
  local overwrite="${3:-false}"

  if [[ ! -d "$src" ]]; then
    echo "Missing source directory: $src" >&2
    exit 1
  fi

  if command -v rsync >/dev/null 2>&1; then
    if [[ "$overwrite" == "true" ]]; then
      rsync -a --delete "$src/" "$dest/"
    else
      rsync -a "$src/" "$dest/"
    fi
  else
    if [[ "$overwrite" == "true" ]]; then
      rm -rf "$dest"
    fi
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
  fi
}

for mapping in "${MAPPINGS[@]}"; do
  IFS=":" read -r src_rel dest_name <<<"$mapping"
  src_path="$REPO_ROOT/$src_rel"
  for dest_root in "${DEST_ROOTS[@]}"; do
    if [[ ! -d "$dest_root" ]]; then
      echo "Warning: destination root missing, skipping: $dest_root" >&2
      continue
    fi
    dest_path="$dest_root/$dest_name"
    if [[ -e "$dest_path" ]]; then
      if ! confirm_overwrite "$dest_path"; then
        echo "Skipped $src_rel -> $dest_path"
        continue
      fi
      copy_dir "$src_path" "$dest_path" "true"
    else
      copy_dir "$src_path" "$dest_path"
    fi
    echo "Installed $src_rel -> $dest_path"
  done
done
