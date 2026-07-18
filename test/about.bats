#!/usr/bin/env bats

# --about: print the branded name / version / author / homepage block and
# exit 0. Previously had zero coverage.

load 'test_helper'

@test "about: prints name, author and homepage, then exits 0" {
  run ${profile_script} --about
  assert_success
  strip_ansi_output
  assert_output --partial "VerBump"
  assert_output --partial "Author:"
  assert_output --partial "Homepage:"
}

@test "about: reports the package.json version" {
  local ver
  ver=$(jq -r '.version' "$repo_dir/package.json")
  run ${profile_script} --about
  assert_success
  strip_ansi_output
  assert_output --partial "$ver"
}

@test "about: writes nothing to stderr" {
  ${profile_script} --about >/dev/null 2>"$BATS_TEST_TMPDIR/err"
  run cat "$BATS_TEST_TMPDIR/err"
  assert_output ""
}
