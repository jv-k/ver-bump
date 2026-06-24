#!/usr/bin/env bats

# do-versionfile: the legacy plain-text VERSION file is written-through (with a
# deprecation warning) when present, and is a silent no-op when absent. This
# path previously had zero coverage.

load 'test_helper'

@test "versionfile: overwrites an existing VERSION with the new version" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'old\n' > VERSION

  source ${profile_script}
  V_NEW=1.2.3
  FLAG_DRYRUN=false
  run do-versionfile
  assert_success
  assert_equal "$(cat VERSION)" "1.2.3"
}

@test "versionfile: stages the updated VERSION for commit" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'old\n' > VERSION
  git add VERSION && git commit -qm "seed VERSION"

  source ${profile_script}
  V_NEW=2.0.0
  FLAG_DRYRUN=false
  do-versionfile
  run git diff --cached --name-only
  assert_output --partial "VERSION"
}

@test "versionfile: warns that the VERSION file is deprecated" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'old\n' > VERSION

  source ${profile_script}
  V_NEW=1.0.1
  FLAG_DRYRUN=false
  run do-versionfile
  strip_ansi_output
  assert_output --partial "deprecated"
}

@test "versionfile: dry-run previews but does not modify VERSION" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'old\n' > VERSION

  source ${profile_script}
  V_NEW=9.9.9
  FLAG_DRYRUN=true
  run do-versionfile
  assert_success
  assert_equal "$(cat VERSION)" "old"
}

@test "versionfile: absent VERSION file is a silent no-op" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"

  source ${profile_script}
  V_NEW=1.0.1
  FLAG_DRYRUN=false
  run do-versionfile
  assert_success
  [ ! -f VERSION ]
}
