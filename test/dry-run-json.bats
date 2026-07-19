#!/usr/bin/env bats

# --dry-run --json (R-OUT-5, issue #107): structured release preview.
# One JSON object on stdout (the R-OUT-1 clean channel), decoration on
# stderr. effects[] is ordered as main() would execute it, and contains
# only the operations that would actually run — each site's FLAG/DO_
# guard decides membership, so there is no "skipped" noise. Preview-only:
# --json without --dry-run exits 2 at parse time.

load 'test_helper'

# releasable_repo / released_repo fixtures come from test_helper.bash.

# ── happy path: one valid JSON object on stdout ─────────────────────────────

@test "json: stdout is exactly one valid JSON object, decoration on stderr" {
  releasable_repo

  run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  # The whole of stdout parses as a single JSON value...
  run jq -e 'has("schema")' "$BATS_TEST_TMPDIR/out"
  assert_success
  assert_output "true"
  # ...and the human story still lands on stderr, [dry-run] markers included.
  # (-F: the literal marker — the schema id "verbump.dry-run/v1" legitimately
  # puts the substring "dry-run" on stdout.)
  run grep -cF "[dry-run]" "$BATS_TEST_TMPDIR/err"
  refute_output "0"
  run grep -cF "[dry-run]" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
}

@test "json: schema, version delta, source, and tag are all present (R-OUT-5)" {
  releasable_repo

  run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[.schema, .dryRun, .version.from, .version.to, .version.level, .source, .tag] | join("|")' \
    "$BATS_TEST_TMPDIR/out"
  assert_output "verbump.dry-run/v1|true|1.2.3|1.3.0|minor|package.json|v1.3.0"
}

@test "json: effects[] is ordered as main() would execute it" {
  releasable_repo
  printf '{ "version": "1.2.3" }\n' > composer.json
  echo "1.2.3" > VERSION
  git add composer.json VERSION && git commit -qm "chore: add extra bump files"

  run bash -c '"$1" --minor --yes -p origin --branch -f composer.json --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[.effects[].action] | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "bump-json,bump-json,write,changelog,branch,commit,tag,push"
  # Roles distinguish the source file from -f extras.
  run jq -r '[.effects[] | select(.action == "bump-json") | .role] | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "source,extra"
}

@test "json: package-lock effect records the lock's own (drifted) version" {
  releasable_repo
  # Lock file deliberately behind package.json (1.2.2 vs 1.2.3): the plan
  # must report what the lock actually contains, not the source version.
  printf '{ "name": "x", "version": "1.2.2", "packages": { "": { "version": "1.2.2" } } }\n' > package-lock.json
  git add package-lock.json && git commit -qm "chore: add drifted lockfile"

  run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '.effects[] | select(.role == "lock") | .from + ">" + .to' "$BATS_TEST_TMPDIR/out"
  assert_output "1.2.2>1.3.0"
}

@test "json: guarded-off steps leave no trace in effects[]" {
  releasable_repo

  # -c (no changelog), no --branch, no -p (push is prompted, not planned —
  # but --json needs a prompt-free run, so -n skips commit/tag/push wholesale).
  run bash -c '"$1" --minor --yes -c -n --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[.effects[].action] | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "bump-json"
}

@test "json: hooks are recorded with their commands when set" {
  releasable_repo

  PRE_BUMP_CMD='echo pre' POST_TAG_CMD='echo post' \
    run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[.effects[] | select(.action == "run-hook") | "\(.hook):\(.command)"] | join(",")' \
    "$BATS_TEST_TMPDIR/out"
  assert_output "pre-bump:echo pre,post-tag:echo post"
  # pre-bump is the plan's first step; post-tag sits between tag and push.
  run jq -r '.effects[0].action' "$BATS_TEST_TMPDIR/out"
  assert_output "run-hook"
}

@test "json: full plan with --pr --release (stub gh) ends open-pr, github-release" {
  releasable_repo
  local shim="$BATS_TEST_TMPDIR/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\nexit 0\n' > "$shim/gh"
  chmod +x "$shim/gh"

  PATH="$shim:$PATH" run bash -c '"$1" --minor --yes --pr --release --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[.effects[].action] | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "bump-json,changelog,branch,commit,tag,push,open-pr,github-release"
  run jq -r '.effects[] | select(.action == "open-pr") | .head' "$BATS_TEST_TMPDIR/out"
  assert_output "release-1.3.0"
}

# ── typed fields: booleans and counts are real JSON types ───────────────────

@test "json: tag.annotated/signed and github-release.prerelease are booleans, changelog.entries a number" {
  releasable_repo
  local shim="$BATS_TEST_TMPDIR/shim"
  mkdir -p "$shim"
  printf '#!/bin/sh\nexit 0\n' > "$shim/gh"
  chmod +x "$shim/gh"

  PATH="$shim:$PATH" run bash -c '"$1" --minor --yes -p origin --release --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run jq -r '[
      (.effects[] | select(.action == "tag") | (.annotated | type), (.signed | type)),
      (.effects[] | select(.action == "github-release") | (.prerelease | type)),
      (.effects[] | select(.action == "changelog") | (.entries | type))
    ] | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "boolean,boolean,boolean,number"
}

# ── escaping: adversarial values round-trip through jq ──────────────────────

@test "json: a tag message with quotes and a newline round-trips exactly" {
  releasable_repo

  run bash -c '"$1" --minor --yes -p origin -m "$3" --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR" $'He said "ship it"\nline2 \\ backslash'
  assert_success

  run jq -r '.effects[] | select(.action == "tag") | .message' "$BATS_TEST_TMPDIR/out"
  assert_output $'He said "ship it"\nline2 \\ backslash'
}

# ── version object shape ────────────────────────────────────────────────────

@test "json: explicit -v drops version.level; --preid adds version.preid" {
  releasable_repo

  run bash -c '"$1" -v 3.0.0 --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run jq -r '.version | has("level"), has("preid")' "$BATS_TEST_TMPDIR/out"
  assert_output $'false\nfalse'

  # --preid on a stable version needs a level (R-PRE) — --minor --preid rc.
  run bash -c '"$1" --minor --preid rc --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run jq -r '.version.preid' "$BATS_TEST_TMPDIR/out"
  assert_output "rc"
}

# ── stream discipline with --quiet ──────────────────────────────────────────

@test "json: --quiet --json emits only the JSON object — no bare-version line" {
  releasable_repo

  run bash -c '"$1" --minor --yes --quiet -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  run grep -cx "1.3.0" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
  run jq -r '.version.to' "$BATS_TEST_TMPDIR/out"
  assert_output "1.3.0"
}

# ── parse-time rejections (exit 2, with hints) ──────────────────────────────

@test "json: --json without --dry-run -> exit 2 naming the fix" {
  releasable_repo

  run ${profile_script} --json --yes --minor
  assert_failure 2
  strip_ansi_output
  assert_output --partial "requires --dry-run"
  assert_output --partial "--json"
}

@test "json: --json without --yes/-v/level -> exit 2 (prompt guard, mirrors R-OUT-2)" {
  releasable_repo

  run ${profile_script} --dry-run --json
  assert_failure 2
  strip_ansi_output
  assert_output --partial "non-interactive version choice"
  assert_output --partial "--yes"
}

@test "json: --json=value is rejected as a boolean flag (R-OPT-2)" {
  releasable_repo

  run ${profile_script} --json=true --dry-run --yes
  assert_failure 2
  strip_ansi_output
  assert_output --partial "doesn't take a value"
}

# ── CLI-only: rc/env cannot switch JSON mode on ─────────────────────────────

@test "json: FLAG_JSON is CLI-only — a .verbumprc key cannot force JSON output" {
  releasable_repo
  printf 'FLAG_JSON=true\n' > .verbumprc
  chmod 644 .verbumprc

  run bash -c '"$1" --minor --yes -c -n --dry-run >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  # Normal dry-run output — nothing JSON-shaped anywhere.
  run grep -c "verbump.dry-run/v1" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
  run grep -c "verbump.dry-run/v1" "$BATS_TEST_TMPDIR/err"
  assert_output "0"
}

@test "json: env FLAG_JSON cannot force JSON output either (CLI-only reset)" {
  releasable_repo

  FLAG_JSON=true run bash -c '"$1" --minor --yes -c -n --dry-run >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run grep -c "verbump.dry-run/v1" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
}

# ── no-op and non-json runs ─────────────────────────────────────────────────

@test "json: no-op run (nothing to release) -> exit 0, stdout completely empty" {
  released_repo

  run bash -c '"$1" --yes -v 1.2.4 --dry-run --json >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  # Like --quiet's R-OUT-4: empty stdout is the "no release would happen" test.
  [ ! -s "$BATS_TEST_TMPDIR/out" ]
  run grep -c "^no-release" "$BATS_TEST_TMPDIR/err"
  assert_output "1"
}

@test "json: without --json a dry-run emits no JSON (zero-cost accumulator)" {
  releasable_repo

  run bash -c '"$1" --minor --yes -c -n --dry-run >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run grep -c "verbump.dry-run/v1" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
}

# ── surface parity ──────────────────────────────────────────────────────────

@test "json: --help lists --json" {
  run bash -c 'get_help_msg() { "$1" -h 2>&1; }; get_help_msg "$1"' _ "${profile_script}"
  assert_success
  strip_ansi_output
  assert_output --partial "--json"
}

@test "json: completions list --json in bash/zsh/fish" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial -- "--json"
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial -- "--json"
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial -- "-l json"
}
