#!/usr/bin/env bats

# Integration tests for the env > file > default precedence chain, exercised
# by actually exec-ing ver-bump.sh as a subprocess (not sourcing into the
# bats harness). Catches the class of bug where top-level assignments in
# ver-bump.sh clobber inherited env vars before load-config can snapshot
# them — which sourcing-based tests can't detect.

load 'test_helper'

@test "env TAG_PREFIX wins over .ver-bumprc (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'TAG_PREFIX=from-file\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  TAG_PREFIX=from-env run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -a from-env1.0.1"
  refute_output --partial "from-file1.0.1"
}

@test "CLI -t wins over env TAG_PREFIX (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  TAG_PREFIX=from-env run ${profile_script} -d -b -c -p origin -t from-cli -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -a from-cli1.0.1"
  refute_output --partial "from-env1.0.1"
}

@test ".ver-bumprc wins over the builtin default when env is unset (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'TAG_PREFIX=from-file\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  # Scrub TAG_PREFIX so only the file can supply it. `run` is a bats
  # function, so we unset in-shell rather than with env(1).
  unset TAG_PREFIX
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -a from-file1.0.1"
}

@test "builtin default is used when neither env nor .ver-bumprc set a value (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  unset TAG_PREFIX
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -a v1.0.1"
}
