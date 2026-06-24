#!/usr/bin/env bats

# Live (non-dry-run) end-to-end test of the core bump pipeline: every other
# full-pipeline test is dry-run, and the --undo tests fabricate their branch +
# tag by hand. This runs a REAL bump in a scratch repo and asserts the branch,
# commit, tag, and bumped files it actually produced — so an orchestration or
# call-ordering regression in main() is caught even when every unit stays green.

load 'test_helper'

@test "e2e: live bump creates release branch + commit + tag + bumped files" {
  local repo remote
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.2.0" }\n' > package.json
  git add package.json && git commit -qm "feat: seed a feature"

  # Push to a throwaway bare remote so the push step runs without prompting
  # (FLAG_PUSH=true) and the pipeline completes end-to-end.
  remote=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${remote}")
  git init -q --bare "${remote}"

  run ${profile_script} -v 1.3.0 -p "${remote}" -y
  assert_success

  # 1. release branch created AND checked out
  assert_equal "$(git symbolic-ref --short HEAD)" "release-1.3.0"

  # 2. annotated tag created
  run git tag -l v1.3.0
  assert_output "v1.3.0"

  # 3. tag points at the new HEAD commit (the bump commit)
  assert_equal "$(git rev-parse 'v1.3.0^{commit}')" "$(git rev-parse HEAD)"

  # 4. package.json bumped to the new version
  assert_equal "$(jq -r '.version' package.json)" "1.3.0"

  # 5. CHANGELOG written with the new version heading
  run cat CHANGELOG.md
  assert_output --partial "1.3.0"

  # 6. everything was committed — no leftover staged/unstaged changes
  run git status --porcelain
  assert_output ""

  # 7. branch + tag actually reached the remote. Address the bare repo via an
  # explicit --git-dir so this passes regardless of the operator's global
  # safe.bareRepository setting.
  run git --git-dir="${remote}" tag -l v1.3.0
  assert_output "v1.3.0"
}

@test "e2e: live bump without -p stays local (declined push aborts with code 5)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.2.0" }\n' > package.json
  git add package.json && git commit -qm "fix: seed"

  # No -p and answer 'n' to the push prompt -> documented user-abort (exit 5),
  # but the local branch + tag are still created first.
  run bash -c "printf 'n\n' | ${profile_script} -v 1.2.1"
  assert_failure 5
  run git -C "$repo" tag -l v1.2.1
  assert_output "v1.2.1"
}
