#!/usr/bin/env bats

# -q/--quiet (R-OUT-1..4, issue #65): machine-readable stdout for CI.
# On success stdout carries exactly one line — the new version, bare —
# and everything decorative is rerouted to stderr, so
# NEW_VERSION=$(VerBump --yes --quiet …) captures cleanly. Quiet and
# interactive prompts are incompatible by construction (a hidden prompt
# is a hung pipeline): missing --yes/-v/level, or -l/--pause-changelog,
# exits 2 at parse time. A quiet no-op (R-SAFE-14) prints nothing on
# stdout and exits 0, so [ -z "$out" ] is the "no release happened" test.

load 'test_helper'

# releasable_repo / released_repo fixtures come from test_helper.bash.

# ── R-OUT-1: success prints exactly the bare version on stdout ─────────────

@test "quiet: --quiet --yes success -> stdout is byte-exactly 'X.Y.Z\\n' (R-OUT-1)" {
  releasable_repo

  # -n -c keeps the run prompt-free after the version step (no push, no
  # changelog); the suggestion path itself is what --yes vouches for.
  run bash -c '"$1" --quiet --yes -n -c >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  printf '1.3.0\n' > "$BATS_TEST_TMPDIR/want"
  run cmp "$BATS_TEST_TMPDIR/out" "$BATS_TEST_TMPDIR/want"
  assert_success

  # Decoration is rerouted to stderr, not dropped — the run still tells
  # its story where a human (or a CI log) can see it.
  run grep -c "Bumped version" "$BATS_TEST_TMPDIR/err"
  assert_output "1"
}

@test "quiet: -q clusters with other short flags (-yqnc)" {
  releasable_repo

  run bash -c '"$1" -yqnc >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "1.3.0"
}

@test "quiet: no colour codes on stdout even when colour is forced (R-OUT-1)" {
  releasable_repo

  CLICOLOR_FORCE=1 run bash -c '"$1" --quiet --yes -n -c >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  printf '1.3.0\n' > "$BATS_TEST_TMPDIR/want"
  run cmp "$BATS_TEST_TMPDIR/out" "$BATS_TEST_TMPDIR/want"
  assert_success
}

@test "quiet: --quiet --major prints the forced-bump version (R-OUT-1)" {
  releasable_repo

  run bash -c '"$1" --quiet --major -d -c -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "2.0.0"
}

# ── R-OUT-2: quiet + prompts exit 2 at parse time ───────────────────────────

@test "quiet: --quiet without --yes/-v/level -> exit 2 naming the fix (R-OUT-2)" {
  releasable_repo

  run ${profile_script} --quiet
  assert_failure 2
  strip_ansi_output
  assert_output --partial "hidden prompt is a hung pipeline"
  assert_output --partial "--yes"
  assert_output --partial "--major/--minor/--patch"
}

@test "quiet: --quiet -l -> exit 2 even with --yes (R-OUT-2)" {
  releasable_repo

  run ${profile_script} --quiet --yes -l
  assert_failure 2
  strip_ansi_output
  assert_output --partial "pause-changelog"
}

@test "quiet: rc-set FLAG_CHANGELOG_PAUSE is caught too (R-OUT-2)" {
  releasable_repo
  printf 'FLAG_CHANGELOG_PAUSE=true\n' > .verbumprc
  chmod 644 .verbumprc

  run ${profile_script} --quiet --yes
  assert_failure 2
  strip_ansi_output
  assert_output --partial "pause-changelog"
}

@test "quiet: --quiet --undo without --yes -> exit 2 (R-OUT-2)" {
  released_repo

  run ${profile_script} --quiet --undo 1.2.3
  assert_failure 2
  strip_ansi_output
  assert_output --partial "requires --yes"
}

@test "quiet: --quiet=value is rejected as a boolean flag (R-OPT-2)" {
  releasable_repo

  run ${profile_script} --quiet=true --yes
  assert_failure 2
  strip_ansi_output
  assert_output --partial "doesn't take a value"
}

# ── quiet + --undo: stdout stays completely empty ───────────────────────────

@test "quiet: --quiet --undo --yes undoes silently, stdout empty" {
  released_repo

  run bash -c '"$1" --quiet --undo 1.2.3 --yes >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  # No version to report for an undo — stdout is byte-empty.
  [ ! -s "$BATS_TEST_TMPDIR/out" ]
  # The tag really was deleted.
  run git tag -l
  assert_output ""
}

# ── R-OUT-3: composes with --dry-run ────────────────────────────────────────

@test "quiet: --quiet --dry-run -v 1.2.4 -> stdout '1.2.4', dry-run lines on stderr only (R-OUT-3)" {
  releasable_repo

  run bash -c '"$1" --quiet --dry-run -v 1.2.4 -c -p origin >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  printf '1.2.4\n' > "$BATS_TEST_TMPDIR/want"
  run cmp "$BATS_TEST_TMPDIR/out" "$BATS_TEST_TMPDIR/want"
  assert_success

  run grep -c "dry-run" "$BATS_TEST_TMPDIR/err"
  refute_output "0"
  run grep -c "dry-run" "$BATS_TEST_TMPDIR/out"
  assert_output "0"

  # Dry-run really was dry: no tag, no file change.
  run git tag -l
  assert_output "v1.2.3"
  run jq -r '.version' package.json
  assert_output "1.2.3"
}

# ── failure path: empty stdout, error on stderr, contract exit code ────────

@test "quiet: dirty-tree preflight -> exit 3, empty stdout, error on stderr" {
  releasable_repo
  echo "dirty" >> package.json

  run bash -c '"$1" --quiet --yes -v 1.2.4 >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_failure 3
  [ ! -s "$BATS_TEST_TMPDIR/out" ]
  run grep -c "uncommitted changes" "$BATS_TEST_TMPDIR/err"
  assert_output "1"
}

# ── R-OUT-4: quiet no-op prints nothing on stdout, exits 0 ─────────────────

@test "quiet: no-op run -> exit 0, stdout completely empty (R-OUT-4)" {
  released_repo

  run bash -c '"$1" --quiet --yes -v 1.2.4 >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  # [ -z "$out" ] is the documented CI branch test — the no-release token
  # is rerouted with the rest of the decoration (R-SAFE-15 keeps it on
  # stdout only for non-quiet runs).
  [ ! -s "$BATS_TEST_TMPDIR/out" ]
  run grep -c "^no-release" "$BATS_TEST_TMPDIR/err"
  assert_output "1"
}

# ── regression pins: non-quiet output is unchanged ──────────────────────────

@test "quiet: without --quiet, decoration and the no-release token stay on stdout" {
  released_repo

  # Success-path decoration on stdout (dry-run side-effects on stderr).
  git commit -q --allow-empty -m "feat: something new"
  run bash -c '"$1" -d -c -p origin -v 1.2.4 >"$2/out" 2>"$2/err" </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run grep -c "Option set" "$BATS_TEST_TMPDIR/out"
  assert_output "3"
  # And no stray bare-version machine line was added to non-quiet runs:
  # stdout has no line that is exactly the version.
  run grep -cx "1.2.4" "$BATS_TEST_TMPDIR/out"
  assert_output "0"
}

@test "quiet: FLAG_QUIET is CLI-only — a .verbumprc key cannot hide output" {
  releasable_repo
  printf 'FLAG_QUIET=true\n' > .verbumprc
  chmod 644 .verbumprc

  run bash -c '"$1" -d -c -p origin -v 1.2.4 >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  # Decoration still on stdout: the rc key was reset in process-arguments.
  run grep -c "Option set" "$BATS_TEST_TMPDIR/out"
  assert_output "3"
}

@test "quiet: env FLAG_QUIET cannot hide output either (CLI-only reset)" {
  releasable_repo

  FLAG_QUIET=true run bash -c '"$1" -d -c -p origin -v 1.2.4 >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run grep -c "Option set" "$BATS_TEST_TMPDIR/out"
  assert_output "3"
}

# ── surface parity ───────────────────────────────────────────────────────────

@test "quiet: --help lists -q/--quiet" {
  run bash -c 'get_help_msg() { "$1" -h 2>&1; }; get_help_msg "$1"' _ "${profile_script}"
  assert_success
  strip_ansi_output
  assert_output --partial "--quiet"
}

@test "quiet: completions list --quiet in bash/zsh/fish" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial -- "--quiet"
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial -- "--quiet"
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial -- "-l quiet"
}
