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

# Sets the top-level "version" member of a JSON file, preserving the file's
# original formatting. Args: <file> <new-version>
#
# jq_inplace re-serialises the whole document in jq's house style, so any
# hand-formatted / 4-space / tab-indented file gets whole-file diff churn in
# exactly the commit that should be minimal (issue #70). Instead, when the
# member sits alone on its own line with the current top-level value, only
# that line is rewritten — indentation (spaces or tabs), key spacing, the
# trailing comma, CRLF endings and a missing final newline all survive
# byte-for-byte (R-FMT-1).
#
# Anchoring the match on the *current* value keeps nested "version" members
# with other values (lockfile entries, config blobs) from counting as
# candidates; a nested member holding the same value makes the match
# ambiguous and is handled below.
#
# Postconditions before the atomic mv (R-FMT-2): the candidate output must
# parse AND report .version == <new-version>. On any postcondition failure
# the tmp file is discarded and nothing is replaced.
#
# Fallback (R-FMT-3): if there is not exactly one unambiguous candidate line
# (minified file, duplicate keys, member sharing a line, no member yet) or a
# postcondition fails, fall back to the full jq rewrite — correct but
# format-normalising — and log the fallback, never silently.
json_set_version() {
  local file="$1" new="$2"
  local old line="" out="" tmp matches=0 eof=false
  # A line holding ONLY the version member: indent, "version", ':', a string
  # value, then at most a comma and trailing whitespace (covers CR of CRLF).
  local re='^([[:space:]]*"version"[[:space:]]*:[[:space:]]*")([^"]*)("[[:space:]]*,?[[:space:]]*)$'

  # Current top-level value anchors the surgical match. Unparseable files or
  # a missing/non-string .version yield "" and take the fallback below.
  old=$(jq -r '.version // empty' "$file" 2>/dev/null)

  if [ -n "$old" ]; then
    while [ "$eof" = false ]; do
      IFS= read -r line || eof=true
      # Clean EOF right after a newline: nothing left to emit.
      [ "$eof" = true ] && [ -z "$line" ] && break
      if [[ $line =~ $re ]] && [ "${BASH_REMATCH[2]}" = "$old" ]; then
        matches=$((matches + 1))
        line=${BASH_REMATCH[1]}${new}${BASH_REMATCH[3]}
      fi
      if [ "$eof" = true ]; then
        out+=$line # final line had no trailing newline — keep it that way
      else
        out+=$line$'\n'
      fi
    done < "$file"

    if [ "$matches" -eq 1 ]; then
      tmp=$(mktemp "${file}.XXXXXX") || return 1
      if printf '%s' "$out" > "$tmp"; then
        # Both postconditions in one probe: jq -e exits >1 if $tmp does not
        # parse and 1 if the comparison is false; 0 only when the rewritten
        # file parses AND carries the new version (R-FMT-2).
        # shellcheck disable=SC2016 # $V is a jq variable, not a bash expansion
        if jq -e --arg V "$new" '.version == $V' "$tmp" >/dev/null 2>&1; then
          mv -f "$tmp" "$file"
          return 0
        fi
      fi
      rm -f "$tmp"
    fi
  fi

  # R-FMT-3: the fallback is never silent. Postconditions hold by
  # construction here: jq exit 0 + non-empty output ⇒ parseable JSON, and
  # the expression itself sets .version to $V.
  log_warn "<${S_VAL-}${file}${RESET-}>: no single \"version\" line found — falling back to a full jq rewrite (formatting normalised)."
  # shellcheck disable=SC2016 # $V is a jq variable, not a bash expansion
  jq_inplace "$file" '.version = $V' --arg V "$new"
}
