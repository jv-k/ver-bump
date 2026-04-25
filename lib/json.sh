#!/bin/bash

# shellcheck disable=SC2288
true

# Writes JSON to a temp file next to the target, then atomically replaces it.
# Args: <file> <jq-expr> [<jq-args>...]
# Keeps stderr separate so jq warnings can't corrupt the JSON output.
# Returns 0 on success, prints jq error to stderr and returns non-zero on failure.
jq_inplace() {
  local file="$1"; shift
  local expr="$1"; shift
  local tmp err rc
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  err=$(mktemp "${file}.err.XXXXXX") || { rm -f "$tmp"; return 1; }
  jq "$@" "$expr" "$file" >"$tmp" 2>"$err"; rc=$?
  if [ "$rc" -eq 0 ] && [ -s "$tmp" ]; then
    # Surface any jq warnings to the caller's stderr but still commit the write.
    [ -s "$err" ] && cat "$err" >&2
    rm -f "$err"
    mv -f "$tmp" "$file"
    return 0
  fi
  cat "$err" >&2
  rm -f "$tmp" "$err"
  return 1
}
