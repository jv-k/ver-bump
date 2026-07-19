#!/usr/bin/env bats

# check-release-branch (R-SAFE-10..13, issue #59): opt-in RELEASE_BRANCHES
# config/env key — a space-separated glob allowlist of branches a release may
# be cut from. Unset (the default) keeps 2.0 behaviour: release from anywhere.
# The guard is not a prompt, so --yes never bypasses it; the one-shot bypass
# is an empty env override (env beats rc per R-CFG-3).

load 'test_helper'

# Seed a scratch repo with a committed package.json and cd into it.
guard_repo() {
  local repo
  repo="$(scratch_repo)"
  cd "$repo" || exit 1
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json && git commit -qm "chore: seed package.json"
}

@test "branch-guard: unset RELEASE_BRANCHES releases from any branch (regression pin)" {
  guard_repo
  git checkout -qb feature-anything

  unset RELEASE_BRANCHES
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "branch-guard: exact match proceeds" {
  guard_repo
  # Pin to the repo's actual default branch name (git init -b main has a
  # fallback path in scratch_repo for older gits).
  local cur
  cur=$(git symbolic-ref --short HEAD)

  RELEASE_BRANCHES="${cur} develop" run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "branch-guard: glob match (release/*) proceeds" {
  guard_repo
  git checkout -qb release/2026-Q3

  RELEASE_BRANCHES="main release/*" run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "branch-guard: non-matching branch -> 3, names branch + allowed list" {
  guard_repo
  git checkout -qb feature-x

  RELEASE_BRANCHES="main develop" run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "Branch 'feature-x' is not a release branch"
  assert_output --partial "main develop"
  assert_output --partial " HINT "
}

@test "branch-guard: detached HEAD with guard active -> 3 (R-SAFE-12)" {
  guard_repo
  git checkout -q --detach

  RELEASE_BRANCHES="main" run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "HEAD is detached"
}

@test "branch-guard: --yes does not bypass the guard (R-SAFE-11)" {
  guard_repo
  git checkout -qb feature-x

  RELEASE_BRANCHES="main" run ${profile_script} -d -b -c -p origin -v 1.0.1 --yes
  assert_failure 3
  strip_ansi_output
  assert_output --partial "is not a release branch"
}

@test "branch-guard: RELEASE_BRANCHES from .verbumprc guards the run" {
  guard_repo
  git checkout -qb feature-x
  printf 'RELEASE_BRANCHES="main develop"\n' > .verbumprc

  unset RELEASE_BRANCHES
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "is not a release branch"
}

@test "branch-guard: empty env override beats the rc value (one-shot bypass)" {
  guard_repo
  git checkout -qb feature-x
  printf 'RELEASE_BRANCHES="main develop"\n' > .verbumprc

  RELEASE_BRANCHES="" run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "branch-guard: --undo is unaffected by the guard (R-SAFE-13)" {
  guard_repo
  # Fabricate the artefacts of a prior run: release branch + bump commit + tag.
  git checkout -qb feat/x
  git checkout -qb release-1.2.0
  printf '{ "version": "1.2.0" }\n' > package.json
  git commit -qam "chore: bumped 1.0.0 -> 1.2.0"
  git tag -a v1.2.0 -m "v1.2.0"

  # Current branch release-1.2.0 does NOT match the allowlist — undo must
  # still run (the guard applies to the release flow only).
  RELEASE_BRANCHES="main" run ${profile_script} --undo 1.2.0 --dry-run
  assert_success
  assert_output --partial "git tag -d v1.2.0"
}

@test "branch-guard: --about and --help are unaffected by the guard (R-SAFE-13)" {
  guard_repo
  git checkout -qb feature-x

  RELEASE_BRANCHES="main" run ${profile_script} --about
  assert_success
  RELEASE_BRANCHES="main" run ${profile_script} --help
  assert_success
}

@test "branch-guard: unit — guard runs before the version prompt (no mutation)" {
  guard_repo
  git checkout -qb feature-x

  # Live run (no -d): must fail before prompting for a version or touching
  # any file — stdin is closed, so reaching the prompt would hang/EOF-differ.
  RELEASE_BRANCHES="main" run ${profile_script} -c -v 1.0.1
  assert_failure 3
  run jq -r '.version' package.json
  assert_output "1.0.0"
  run git tag -l
  assert_output ""
}
