#!/usr/bin/env bats

# --undo: locally delete release branch + tag for a given version. Refuses
# on dirty tree, when artefacts were pushed, or when the release branch was
# already merged into another branch.

load 'test_helper'

setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  repo_dir=$PWD
  profile_script="$repo_dir/ver-bump.sh"

  TMP=$(mktemp -d)
  cd "$TMP" || return 1
  git init -q -b main
  git config user.email t@t
  git config user.name  t
  echo '{"version":"1.0.0"}' > package.json
  git add . && git commit -q -m "init"
  git checkout -q -b feat/x
  # Set up the artefacts a ver-bump run would produce — release branch with
  # a bump commit, tag pointing at it. Bypasses the real bump pipeline so
  # the test doesn't have to feed the interactive push prompt.
  git checkout -q -b release-1.2.0
  echo '{"version":"1.2.0"}' > package.json
  git commit -q -am "chore: bumped 1.0.0 -> 1.2.0"
  git tag -a v1.2.0 -m "v1.2.0"
}

teardown() {
  cd /
  rm -rf "$TMP"
}

@test "undo: --dry-run prints plan, makes no changes" {
  run ${profile_script} --undo --dry-run
  assert_success
  assert_output --partial "git checkout feat/x"
  assert_output --partial "git branch -D release-1.2.0"
  assert_output --partial "git tag -d v1.2.0"
  # Artefacts still present
  run git tag -l v1.2.0
  assert_output "v1.2.0"
  run git rev-parse --verify --quiet refs/heads/release-1.2.0
  assert_success
}

@test "undo: --yes deletes branch + tag and switches to parent" {
  run ${profile_script} --undo --yes
  assert_success
  assert_output --partial "Undid release"
  run git tag -l v1.2.0
  assert_output ""
  run git rev-parse --verify --quiet refs/heads/release-1.2.0
  assert_failure
  run git symbolic-ref --short HEAD
  assert_output "feat/x"
}

@test "undo: derives version from current release branch" {
  # Already on release-1.2.0 from setup
  run ${profile_script} --undo --yes
  assert_success
  assert_output --partial "1.2.0"
}

@test "undo: refuses with dirty tree" {
  echo dirt > extra.txt && git add extra.txt
  run ${profile_script} --undo --yes
  assert_failure 3
  assert_output --partial "uncommitted changes"
}

@test "undo: refuses if branch already merged" {
  git checkout -q feat/x
  git merge -q --no-ff release-1.2.0 -m "merge"
  run ${profile_script} --undo 1.2.0 --yes
  assert_failure 3
  assert_output --partial "already merged into"
}

@test "undo: refuses if pushed to remote" {
  remote=$(mktemp -d)
  ( cd "$remote" && git init -q --bare )
  git remote add origin "$remote"
  git push -q origin release-1.2.0 v1.2.0
  run ${profile_script} --undo --yes
  assert_failure 3
  assert_output --partial "present on remote"
  assert_output --partial "git push origin :refs/tags/v1.2.0"
  rm -rf "$remote"
}

@test "undo: rejects non-SemVer version" {
  run ${profile_script} --undo notaver
  assert_failure 2
  assert_output --partial "not a valid SemVer"
}

@test "undo: rejects unknown version" {
  run ${profile_script} --undo 9.9.9
  assert_failure 3
  assert_output --partial "does not exist locally"
}

@test "undo: no arg + not on release branch fails with hint" {
  git checkout -q feat/x
  run ${profile_script} --undo
  assert_failure 2
  assert_output --partial "isn't a 'release-"
}

@test "undo: declined confirmation aborts" {
  run bash -c "echo n | ${profile_script} --undo"
  assert_failure 5
  assert_output --partial "undo declined"
  # Artefacts still present
  run git tag -l v1.2.0
  assert_output "v1.2.0"
}
