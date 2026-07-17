#!/usr/bin/env bats

# FLAG_DRYRUN=true behaviour across do-packagefile-bump, do-commit, do-tag,
# do-changelog. Migrated verbatim from the monolithic VerBump.bats;
# shared setup lives in test/test_helper.bash.

load 'test_helper'

@test "dry-run: do-packagefile-bump does not modify package.json" {
  source ${profile_script}
  cd "$(scratch_repo)"
  echo '{"version":"1.0.0"}' > package.json
  git add package.json && git commit -qm "add pkg"

  FLAG_DRYRUN=true
  V_PREV="1.0.0"
  V_NEW="2.0.0"

  run do-packagefile-bump
  assert_success
  assert_output --partial "[dry-run]"

  # File content must still be the original 1.0.0
  run jq -r '.version' package.json
  assert_output "1.0.0"
}

@test "dry-run: do-commit does not create a commit" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_PREV="1.0.0"
  V_NEW="1.0.1"
  GIT_MSG="test, "

  local commits_before
  commits_before=$(git rev-list --count HEAD)

  run do-commit
  assert_success
  assert_output --partial "[dry-run]"

  assert_equal "$(git rev-list --count HEAD)" "$commits_before"
}

@test "dry-run: do-tag does not create a tag" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_NEW="1.0.0"
  REL_NOTE=

  run do-tag
  assert_success
  assert_output --partial "[dry-run]"

  # No tags should exist
  run git tag -l
  assert_output ""
}

@test "dry-run: do-changelog does not write CHANGELOG.md" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_PREV="0.0.0"
  V_NEW="1.0.0"

  [ ! -f CHANGELOG.md ] || return 1
  run do-changelog
  assert_success
  assert_output --partial "[dry-run]"
  [ ! -f CHANGELOG.md ]
}
