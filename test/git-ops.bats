#!/usr/bin/env bats

# Git-side operations: do-branch, do-tag, and their preflight checks
# (check-branch-notexist, check-tag-exists). Shared setup lives in
# test/test_helper.bash.
#
# All tests run inside a fresh scratch_repo — mutating the real project
# checkout (creating phantom release branches, orphan tags) would otherwise
# leave the developer in a broken state if a test crashed mid-run.

load 'test_helper'

@test "check-branch-notexist: can detect branch DOES exist" {
  source ${profile_script}
  cd "$(scratch_repo)"

  local V_NEW="123.456.7"
  git branch "${REL_PREFIX}${V_NEW}"

  run check-branch-notexist
  assert_failure
}

@test "check-branch-notexist: can confirm branch DOES'NT exist" {
  source ${profile_script}
  cd "$(scratch_repo)"

  local V_NEW="123.456.78338834"

  run check-branch-notexist
  assert_success
}

@test "do-branch: can create a release branch" {
  source ${profile_script}
  cd "$(scratch_repo)"

  local V_NEW="123.456.7"

  run do-branch
  assert_success
}

@test "do-tag: create a tag" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_NEW="35.12.5"
  REL_NOTE=

  run do-tag
  assert_success --partial "Added GIT tag"
}

@test "check-tag-exists: check doesn't exist" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_NEW="35.12.5"
  REL_NOTE=

  run check-tag-exists
  assert_success
}

@test "check-tag-exists: check it exists" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_NEW="35.12.5"
  REL_NOTE=

  git tag -a v${V_NEW} -m "Test tag"

  run check-tag-exists
  assert_output --partial "Error: A release with that tag"
}
