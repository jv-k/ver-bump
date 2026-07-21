#!/bin/bash

# shellcheck disable=SC2288
true

# ── Effects accumulator (R-OUT-5) ──────────────────────────────────────────
#
# Structured sibling of the human "[dry-run] would ..." lines. Every mutating
# site records ONE fact here; emit-effects-json serialises the lot once, at the
# end of main(), as a single JSON object on FD 3 — the same clean-stdout
# channel --quiet uses for the bare version (R-OUT-1). Human decoration keeps
# going to stderr exactly as today; --json only adds the machine payload.
#
# Why jq and not printf: the payload carries commit messages, changelog text
# and arbitrary file paths — values that contain quotes, newlines and the odd
# control char. Hand-built JSON corrupts on the first `"` in a commit subject.
# jq owns all escaping (same discipline as lib/json.sh). jq is already a hard
# runtime dependency, so this adds none.
#
# Bash 3.2: no associative arrays. The accumulator is a single string holding
# JSON array text (`[]` → grows by one object per record-effect). Indexed
# arrays and here-strings only — both are 3.2-safe.

# JSON array text, grown by record-effect. Reset per run in reset-effects.
VB_EFFECTS='[]'

reset-effects() { VB_EFFECTS='[]'; }

# record-effect <key> <value> [<key> <value> ...]
#
# Appends one object to VB_EFFECTS, built from the key/value pairs via jq's
# `$ARGS.named` — every value arrives through --arg, so jq escapes it. All
# values are strings (the common case: paths, versions, messages, refs). For a
# typed or nested field (a boolean, a list) use record-effect-raw instead.
#
# No-op unless FLAG_JSON is on, so the hot path (normal runs) pays nothing:
# every call site can invoke it unconditionally, the way `dryrun` wraps git.
record-effect() {
  [ "${FLAG_JSON:-false}" = true ] || return 0
  local jqargs=() obj merged
  while [ "$#" -ge 2 ]; do
    jqargs+=(--arg "$1" "$2")
    shift 2
  done
  obj=$(jq -nc "${jqargs[@]}" '$ARGS.named') || return 1
  # Merge into a temp first: a failed jq must not clobber the accumulator
  # (VB_EFFECTS= empty would make emit-effects-json fail on --argjson).
  merged=$(jq -c --argjson e "$obj" '. + [$e]' <<<"$VB_EFFECTS") || return 1
  VB_EFFECTS=$merged
}

# record-effect-raw '<json-object-text>'
#
# Escape hatch for effects that need non-string fields (e.g. {"annotated":true})
# or nesting. Caller is responsible for well-formed JSON; jq validates on merge
# and a bad fragment fails loudly rather than corrupting the array.
record-effect-raw() {
  [ "${FLAG_JSON:-false}" = true ] || return 0
  local merged
  merged=$(jq -c --argjson e "$1" '. + [$e]' <<<"$VB_EFFECTS") || return 1
  VB_EFFECTS=$merged
}

# emit-effects-json
#
# One object on FD 3 (the real stdout saved by process-arguments under the
# --quiet/--json stream discipline). Mirrors R-OUT-1's channel so a caller can
# `verbump --minor --dry-run --json >preview.json` and get nothing but JSON on
# stdout, all decoration on stderr. `level` and `preid` are dropped when empty
# (an explicit -v X.Y.Z run has no bump level) so payloads carry no null noise.
emit-effects-json() {
  [ "${FLAG_JSON:-false}" = true ] || return 0
  # Package scope (R-MONO-7): additive optional member, present only when the
  # scope is narrower than the repo root — whole-repo payloads stay
  # byte-identical, so the schema id is unchanged. Paths are repo-root-
  # relative so an orchestration loop can tell packages' payloads apart.
  local scope_json="null"
  if [ "${VB_SCOPE_ACTIVE:-false}" = true ]; then
    scope_json=$(printf '%s\n' "${VB_SCOPE_REL[@]}" | jq -R . | jq -sc '{paths: .}')
  fi
  jq -n \
    --arg from   "${V_PREV-}" \
    --arg to     "${V_NEW-}" \
    --arg level  "${BUMP_LEVEL-}" \
    --arg preid  "${PRE_ID-}" \
    --arg source "${VER_FILE-}" \
    --arg tag    "${TAG_PREFIX-}${V_NEW-}" \
    --argjson scope "$scope_json" \
    --argjson effects "$VB_EFFECTS" \
    '{
      schema:  "verbump.dry-run/v1",
      dryRun:  true,
      version: ({ from: $from, to: $to }
                 + (if $level == "" then {} else { level: $level } end)
                 + (if $preid == "" then {} else { preid: $preid } end)),
      source:  $source,
      tag:     $tag,
      effects: $effects
    }
    + (if $scope == null then {} else { scope: $scope } end)' >&3
}
