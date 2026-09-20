#!/usr/bin/env bash
# scripts/lib/boards.sh
# Enumerate supported boards from boards/*.conf.sh. Each file declares:
#   # DESCRIPTION: <human readable name>
#   BOARD_ARMBIAN="..."; KERNEL_BRANCH="..."; ASSET_NAME="..."  # ASSET_NAME optional
# Provides: boards_list, boards_list_inline, boards_describe_table,
#           boards_validate, boards_armbian, boards_kernel_branch, boards_asset_name

# Repo root: self-locate two levels up from this file (scripts/lib/boards.sh -> repo root).
_BOARDS_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

# Path to a board's config file (internal). Returns non-zero if absent.
_boards_file() {
  local f="$_BOARDS_ROOT/boards/$1.conf.sh"
  [ -n "$1" ] && [ -e "$f" ] && printf '%s' "$f"
}

# One board id per line; non-zero if none found.
boards_list() {
  local f found=1
  for f in "$_BOARDS_ROOT"/boards/*.conf.sh; do
    [ -e "$f" ] || continue
    f=$(basename "$f"); printf '%s\n' "${f%.conf.sh}"; found=0
  done
  return $found
}

# Inline space-separated list.
boards_list_inline() { boards_list 2>/dev/null | paste -sd' ' -; }

# Validate that a board exists (returns 0 if valid).
boards_validate() { _boards_file "$1" >/dev/null 2>&1; }

# Read one var from a board's config by sourcing it in a subshell.
_boards_var() {
  local f; f=$(_boards_file "$1") || return 1
  # shellcheck disable=SC1090
  ( source "$f"; printf '%s' "${!2-}" )
}

# Armbian internal board name (e.g. rpi -> rpi4b).
boards_armbian()       { _boards_var "$1" BOARD_ARMBIAN; }
# Kernel branch for the board (e.g. current, vendor).
boards_kernel_branch() { _boards_var "$1" KERNEL_BRANCH; }

# Release asset basename; falls back to BOARD_ARMBIAN if ASSET_NAME is unset.
boards_asset_name() {
  local f; f=$(_boards_file "$1") || return 1
  # shellcheck disable=SC1090
  ( source "$f"; printf '%s' "${ASSET_NAME:-$BOARD_ARMBIAN}" )
}

# DESCRIPTION comment, or humanized board id as fallback.
boards_description() {
  local f desc; f=$(_boards_file "$1") || { echo ""; return 1; }
  desc=$(sed -nE 's/^[[:space:]]*#.*(DESCRIPTION|DESC)[[:space:]]*:[[:space:]]*//Ip' "$f" | head -n1)
  [ -n "$desc" ] && { echo "$desc"; return 0; }
  echo "$1" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# Print an aligned "  - <board>  <description>" listing (for usage/help text).
boards_describe_table() {
  local b
  boards_list | while read -r b; do
    printf '  - %-14s %s\n' "$b" "$(boards_description "$b")"
  done
}
