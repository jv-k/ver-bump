#!/usr/bin/env bats

# --preid <id>: start or advance a prerelease line (R-PRE bucket, issue #64).
# Composes with the existing --major/--minor/--patch bump-level switches:
#   - level + --preid       -> bump the level, then enter <id>.1   (R-PRE-1)
#   - --preid alone, already prerelease -> same id increments the counter,
#     a different id swaps it and resets to .1                    (R-PRE-2)
#   - --preid alone, stable -> ambiguous, exit 2                   (R-PRE-3)
#   - --preid vs -v         -> mutually exclusive, exit 2          (R-PRE-4)
#   - <id> grammar          -> validated before any mutation       (R-PRE-5)
#   - level w/o --preid on a prerelease -> bumps the stable core   (R-PRE-6)
#
# Flag-parsing coverage (space/= forms, missing/empty value, the -v
# conflict, the PRE_ID env-reset) lives in args.bats per CODE_STYLE; this
# file covers the composition semantics, unit-level and end-to-end.

load 'test_helper'

# Scratch repo with package.json pinned to $1 (default 1.2.3), committed —
# process-version's forced/preid paths never consult conventional commits,
# so no tag or extra history is needed for the e2e cases below.
preid_repo() {
  local ver="${1:-1.2.3}"
  local repo
  repo="$(scratch_repo)"
  cd "$repo" || exit 1
  printf '{ "version": "%s" }\n' "$ver" > package.json
  git add package.json && git commit -qm "chore: bumped to ${ver}"
}

# ── is_prerelease_id — grammar validation (R-PRE-5) ─────────────────────────

@test "is_prerelease_id: accepts and rejects per the SemVer prerelease grammar" {
  source ${profile_script}
  is_prerelease_id "rc"      || return 1
  is_prerelease_id "beta.1"  || return 1
  is_prerelease_id "dev-2"   || return 1
  is_prerelease_id "0"       || return 1
  is_prerelease_id "alpha.0" || return 1

  ! is_prerelease_id ""        || return 1
  ! is_prerelease_id "bad..id" || return 1
  ! is_prerelease_id "01"      || return 1
  ! is_prerelease_id "rc."     || return 1
  ! is_prerelease_id ".rc"     || return 1
}

# ── bump-preid — counter increment vs id swap (R-PRE-2) ─────────────────────

@test "bump-preid: same id increments the trailing counter" {
  source ${profile_script}
  assert_equal "$(bump-preid '4.0.0-dev.6' dev)" "4.0.0-dev.7"
  assert_equal "$(bump-preid '2.0.0-alpha.3' alpha)" "2.0.0-alpha.4"
  assert_equal "$(bump-preid '1.0.0-alpha' alpha)" "1.0.0-alpha.1"
}

@test "bump-preid: different id swaps and resets the counter to .1" {
  source ${profile_script}
  assert_equal "$(bump-preid '2.0.0-alpha.3' rc)" "2.0.0-rc.1"
  assert_equal "$(bump-preid '1.0.0-alpha' beta)" "1.0.0-beta.1"
}

@test "bump-preid: preserves build metadata in both branches" {
  source ${profile_script}
  assert_equal "$(bump-preid '2.1.0-beta.3+build.sha' beta)" "2.1.0-beta.4+build.sha"
  assert_equal "$(bump-preid '2.1.0-beta.3+build.sha' rc)"   "2.1.0-rc.1+build.sha"
}

@test "bump-preid: compares the whole dotted id, not just the first segment" {
  source ${profile_script}
  # Same dotted id -> increment the trailing counter.
  assert_equal "$(bump-preid '1.2.3-foo.bar.6' foo.bar)" "1.2.3-foo.bar.7"
  # A prefix of the current id is DIFFERENT -> swap + reset to .1.
  assert_equal "$(bump-preid '1.2.3-foo.bar.6' foo)" "1.2.3-foo.1"
  # And the reverse: the current id is a prefix of the wanted id.
  assert_equal "$(bump-preid '1.2.3-foo.6' foo.bar)" "1.2.3-foo.bar.1"
  # Dotted id with no trailing numeric counter -> R-BUMP-1 append ".1".
  assert_equal "$(bump-preid '1.2.3-foo.bar' foo.bar)" "1.2.3-foo.bar.1"
}

# ── process-version composition (R-PRE-1) ───────────────────────────────────

@test "process-version: --major --preid rc on a stable version enters a prerelease (R-PRE-1)" {
  source ${profile_script}
  V_TEST="1.2.3"
  create_ver_file
  BUMP_LEVEL="major"
  PRE_ID="rc"
  process-version
  assert_equal "${V_NEW}" "2.0.0-rc.1"
}

@test "process-version: --patch --preid beta on a stable version enters a prerelease (R-PRE-1)" {
  source ${profile_script}
  V_TEST="1.2.3"
  create_ver_file
  BUMP_LEVEL="patch"
  PRE_ID="beta"
  process-version
  assert_equal "${V_NEW}" "1.2.4-beta.1"
}

@test "process-version: --minor --preid on an existing prerelease drops it first, then re-enters (R-PRE-1 + R-PRE-6)" {
  source ${profile_script}
  V_TEST="4.0.0-rc.1"
  create_ver_file
  BUMP_LEVEL="minor"
  PRE_ID="alpha"
  process-version
  assert_equal "${V_NEW}" "4.1.0-alpha.1"
}

# ── process-version composition: --preid alone (R-PRE-2 / R-PRE-3) ─────────

@test "process-version: --preid alone, same id increments the counter (R-PRE-2)" {
  source ${profile_script}
  V_TEST="4.0.0-dev.6"
  create_ver_file
  PRE_ID="dev"
  process-version
  assert_equal "${V_NEW}" "4.0.0-dev.7"
}

@test "process-version: --preid alone, different id swaps and resets (R-PRE-2)" {
  source ${profile_script}
  V_TEST="2.0.0-alpha.3"
  create_ver_file
  PRE_ID="rc"
  process-version
  assert_equal "${V_NEW}" "2.0.0-rc.1"
}

@test "process-version: --preid alone preserves build metadata (R-PRE-2)" {
  source ${profile_script}
  V_TEST="2.1.0-beta.3+build.sha"
  create_ver_file
  PRE_ID="beta"
  process-version
  assert_equal "${V_NEW}" "2.1.0-beta.4+build.sha"
}

@test "process-version: --preid alone on a stable version exits 2, naming the fix (R-PRE-3)" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  V_TEST="1.2.3"
  create_ver_file
  PRE_ID="rc"

  run process-version
  assert_failure 2
  strip_ansi_output
  assert_output --partial "ambiguous"
  assert_output --partial "--major"
  assert_output --partial "--minor"
  assert_output --partial "--patch"
}

@test "process-version: --preid suppresses the conventional-commit suggestion" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  V_TEST="4.0.0-dev.6"
  create_ver_file
  # A feat: commit after the tag would make set-v-suggest print "suggesting
  # ... bump" — --preid (like --major/--minor/--patch) must skip that.
  git tag -a v4.0.0-dev.6 -m "v4.0.0-dev.6"
  git commit -q --allow-empty -m "feat: something"
  PRE_ID="dev"

  run process-version
  assert_success
  strip_ansi_output
  refute_output --partial "suggesting"
  assert_output --partial "4.0.0-dev.7"
}

# ── End-to-end CLI: quiet-mode bare-version trick (cf. quiet.bats) ─────────

@test "e2e: --quiet --major --preid rc prints the entered prerelease (R-PRE-1)" {
  preid_repo "1.2.3"

  run bash -c '"$1" --quiet --major --preid rc -d -c -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "2.0.0-rc.1"
}

@test "e2e: --quiet --patch --preid beta prints the entered prerelease (R-PRE-1)" {
  preid_repo "1.2.3"

  run bash -c '"$1" --quiet --patch --preid beta -d -c -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "1.2.4-beta.1"
}

@test "e2e: --quiet --preid dev alone advances an existing prerelease (R-PRE-2)" {
  preid_repo "4.0.0-dev.6"

  run bash -c '"$1" --quiet --preid dev -d -c -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "4.0.0-dev.7"
}

@test "e2e: --quiet --preid rc alone swaps a different existing prerelease id (R-PRE-2)" {
  preid_repo "2.0.0-alpha.3"

  run bash -c '"$1" --quiet --preid rc -d -c -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run cat "$BATS_TEST_TMPDIR/out"
  assert_output "2.0.0-rc.1"
}

@test "e2e: --preid alone on a stable version exits 2 (R-PRE-3)" {
  preid_repo "1.2.3"

  run ${profile_script} --preid rc -d -c
  assert_failure 2
  strip_ansi_output
  assert_output --partial "ambiguous"
}

@test "e2e: --preid rc -v 2.0.0 exits 2 without mutating the repo (R-PRE-4)" {
  preid_repo "1.2.3"

  run ${profile_script} --preid rc -v 2.0.0 -d -c
  assert_failure 2

  run git status --porcelain
  assert_output ""
  run jq -r '.version' package.json
  assert_output "1.2.3"
}

@test "e2e: --preid 'bad..id' exits 2 before any mutation (R-PRE-5)" {
  preid_repo "1.2.3"

  run ${profile_script} --preid 'bad..id' -d -c
  assert_failure 2

  run git status --porcelain
  assert_output ""
  run jq -r '.version' package.json
  assert_output "1.2.3"
}
