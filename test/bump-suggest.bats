#!/usr/bin/env bats

# suggest-bump-level: conventional-commits bump-level inference.
# Migrated verbatim from the monolithic ver-bump.bats; shared setup lives
# in test/test_helper.bash.

load 'test_helper'

@test "suggest-bump-level: falls back to patch when no previous tag" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git commit --allow-empty -qm "feat: whatever"
  # No tag for "0.1.0" exists, so must fall back to patch
  assert_equal "$(suggest-bump-level 0.1.0)" "patch"
}

@test "suggest-bump-level: patch when only fix/chore commits" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "fix: small fix"
  git commit --allow-empty -qm "chore: tidy"
  assert_equal "$(suggest-bump-level 0.1.0)" "patch"
}

@test "suggest-bump-level: minor when any feat: commit present" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "fix: small fix"
  git commit --allow-empty -qm "feat: new thing"
  git commit --allow-empty -qm "chore: tidy"
  assert_equal "$(suggest-bump-level 0.1.0)" "minor"
}

@test "suggest-bump-level: minor respects feat(scope): form" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "feat(api): new endpoint"
  assert_equal "$(suggest-bump-level 0.1.0)" "minor"
}

@test "suggest-bump-level: major on <type>! in subject" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "feat: safe addition"
  git commit --allow-empty -qm "fix!: removes deprecated API"
  assert_equal "$(suggest-bump-level 0.1.0)" "major"
}

@test "suggest-bump-level: major on feat(scope)! subject" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "feat(core)!: incompatible rewrite"
  assert_equal "$(suggest-bump-level 0.1.0)" "major"
}

@test "suggest-bump-level: major on BREAKING CHANGE footer" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag -a v0.1.0 -m "tag"
  git commit --allow-empty -qm "refactor: move things

Body explaining.

BREAKING CHANGE: old consumers must migrate."
  assert_equal "$(suggest-bump-level 0.1.0)" "major"
}

@test "suggest-bump-level: uses TAG_PREFIX override to locate previous tag" {
  source ${profile_script}
  cd "$(scratch_repo)"
  TAG_PREFIX="r-"
  git tag -a r-0.1.0 -m "tag"
  git commit --allow-empty -qm "feat: thing"
  assert_equal "$(suggest-bump-level 0.1.0)" "minor"
}
