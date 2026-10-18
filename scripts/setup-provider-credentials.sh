#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WIZARD="$SCRIPT_DIR/setup-provider-credentials.wizard.sh"

if [[ ! -f "$WIZARD" ]]; then
  printf 'Missing generated wizard: %s\n' "$WIZARD" >&2
  exit 1
fi

# Keep the curated wizard helper byte-for-byte unchanged, but harden tput at
# the process boundary. Optional styling capabilities may legitimately be
# absent even when the terminal advertises colors; clear may also fail for
# incomplete terminfo entries. Exported Bash functions survive into the child
# Bash that executes the curated wizard.
tput() {
  local capability="${1:-}"
  case "$capability" in
    colors)
      command tput "$@" 2>/dev/null || printf '0'
      ;;
    bold|dim|sgr0|setaf)
      command tput "$@" 2>/dev/null || return 0
      ;;
    clear)
      command tput "$@" 2>/dev/null || printf '\033[2J\033[3J\033[H'
      ;;
    *)
      command tput "$@"
      ;;
  esac
}
export -f tput

exec bash "$WIZARD"
