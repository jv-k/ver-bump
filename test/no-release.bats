#!/usr/bin/env bats

# check-releasable-commits (R-SAFE-14..18, issue #60): when the previous
# version's tag exists and HEAD has no commits since it, VerBump prints a
# notice with a stable `no-release` stdout token and exits 0 without mutating
# anything — the semantic-release-style idempotent no-op that makes a release
# step safe to run unconditionally in CI. --allow-empty forces the old
# behaviour for deliberate empty releases / re-tags.

load 'test_helper'

# released_repo (tagged 1.2.3, zero commits since) comes from test_helper.bash.

@test "no-release: zero commits since tag -> exit 0, token, no mutation (R-SAFE-14/15)" {
  released_repo

  run ${profile_script} -v 1.2.4 -y
  assert_success
  strip_ansi_output
  assert_output --partial "Nothing to release"
  # Stable greppable token: a line beginning `no-release`.
  run bash -c '"$1" -v 1.2.4 -y | grep -c "^no-release"' _ "${profile_script}"
  assert_output "1"

  # Nothing was created or modified.
  run git tag -l
  assert_output "v1.2.3"
  run jq -r '.version' package.json
  assert_output "1.2.3"
  assert_equal "$(git rev-list --count HEAD)" "2"
}

@test "no-release: token goes to stdout so CI can branch on it (R-SAFE-15)" {
  released_repo

  run bash -c '"$1" -v 1.2.4 -y >"$2/out" 2>"$2/err"' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run grep '^no-release' "$BATS_TEST_TMPDIR/out"
  assert_success
  assert_output --partial "v1.2.3"
}

@test "no-release: one commit since the tag -> proceeds" {
  released_repo
  git commit -q --allow-empty -m "fix: something new"

  run ${profile_script} -d -b -c -p origin -v 1.2.4
  assert_success
  strip_ansi_output
  refute_output --partial "no-release"
  assert_output --partial "[dry-run]"
}

@test "no-release: no previous tag at all -> proceeds (first release, R-SAFE-18)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.2.3" }\n' > package.json
  git add package.json && git commit -qm "chore: seed package.json"

  run ${profile_script} -d -b -c -p origin -v 1.2.4
  assert_success
  strip_ansi_output
  refute_output --partial "no-release"
}

@test "no-release: --allow-empty forces the empty release (R-SAFE-16)" {
  released_repo

  run ${profile_script} -c -v 1.2.4 --allow-empty -n
  assert_success
  strip_ansi_output
  refute_output --partial "no-release"
  # The bump really happened (files written; -n skips commit/tag/push).
  run jq -r '.version' package.json
  assert_output "1.2.4"
}

@test "no-release: applies to --patch as well as -v (R-SAFE-17)" {
  released_repo

  run ${profile_script} --patch -y
  assert_success
  strip_ansi_output
  assert_output --partial "Nothing to release"
  run git tag -l
  assert_output "v1.2.3"
}

@test "no-release: applies to the interactive suggestion path too" {
  released_repo

  # Accept the suggested version with a bare <enter>; the no-op check fires
  # right after process-version resolves it.
  run bash -c 'printf "\n" | "$1"' _ "${profile_script}"
  assert_success
  strip_ansi_output
  assert_output --partial "no-release"
  run git tag -l
  assert_output "v1.2.3"
}

@test "no-release: custom tag prefix is honoured when finding the previous tag" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.2.3" }\n' > package.json
  git add package.json && git commit -qm "chore: bumped to 1.2.3"
  git tag -a rel/1.2.3 -m "rel/1.2.3"

  run ${profile_script} -t rel/ -v 1.2.4 -y
  assert_success
  strip_ansi_output
  assert_output --partial "no-release"
  assert_output --partial "rel/1.2.3"
}

@test "no-release: env ALLOW_EMPTY cannot force an empty release (CLI-only reset)" {
  released_repo

  ALLOW_EMPTY=true run ${profile_script} -v 1.2.4 -y
  assert_success
  strip_ansi_output
  # The env var is reset in process-arguments — the run is still a no-op.
  assert_output --partial "no-release"
  run git tag -l
  assert_output "v1.2.3"
}

@test "no-release: completions list --allow-empty in bash/zsh/fish" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial -- "--allow-empty"
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial -- "--allow-empty"
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial -- "-l allow-empty"
}
