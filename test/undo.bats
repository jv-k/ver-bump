#!/usr/bin/env bats

# --undo: locally delete release branch + tag for a given version. Refuses
# on dirty tree, when artefacts were pushed, or when the release branch was
# already merged into another branch.

load 'test_helper'

setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  repo_dir=$PWD
  profile_script="$repo_dir/VerBump.sh"

  TMP=$(mktemp -d)
  cd "$TMP" || return 1
  git init -q -b main
  git config user.email t@t
  git config user.name  t
  echo '{"version":"1.0.0"}' > package.json
  git add . && git commit -q -m "init"
  git checkout -q -b feat/x
  # Set up the artefacts a VerBump run would produce — release branch with
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

@test "undo: --dry-run preview prints to stderr, not stdout (R-DRY-2)" {
  # Redirections live inside bash -c so `run` still captures the real exit
  # status while stdout/stderr land in separate files for the assertions.
  run bash -c '"$1" --undo --dry-run >"$2/out" 2>"$2/err"' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success

  # The [dry-run] preview line goes to stderr…
  run cat "$BATS_TEST_TMPDIR/err"
  strip_ansi_output
  assert_output --partial "[dry-run]"

  # …and stdout stays clean of it (safe for piping).
  run cat "$BATS_TEST_TMPDIR/out"
  strip_ansi_output
  refute_output --partial "[dry-run]"
}

# Recreate a tag-in-place release (the 2.0 default): the bump commit + tag live
# on the current branch, with NO release-<v> branch. Folds the setup's release
# branch into feat/x, then drops it.
_make_tag_in_place() {
  git checkout -q feat/x
  git reset -q --hard v1.2.0
  git branch -D release-1.2.0
}

@test "undo: tag-in-place (no release branch) deletes the tag, keeps the commit" {
  _make_tag_in_place

  run ${profile_script} --undo 1.2.0 --yes
  assert_success
  strip_ansi_output
  assert_output --partial "deleted tag v1.2.0"

  # Tag gone…
  run git tag -l v1.2.0
  assert_output ""
  # …but the bump commit stays on the current branch, and we didn't switch away.
  run git log -1 --pretty=%s
  assert_output --partial "bumped 1.0.0 -> 1.2.0"
  run git symbolic-ref --short HEAD
  assert_output "feat/x"
}

@test "undo: tag-in-place --dry-run shows a tag-only plan and changes nothing" {
  _make_tag_in_place

  run ${profile_script} --undo 1.2.0 --dry-run
  assert_success
  strip_ansi_output
  assert_output --partial "git tag -d v1.2.0"
  refute_output --partial "git branch -D"
  assert_output --partial "version-bump commit stays"
  # Tag untouched.
  run git tag -l v1.2.0
  assert_output "v1.2.0"
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
  # Exits via `fail 3` (contract precondition), not a raw exit after log_warn.
  assert_output --partial "Error:"
  assert_output --partial "Refusing to undo"
  assert_output --partial "present on remote"
  assert_output --partial "git push origin :refs/tags/v1.2.0"
  assert_output --partial "Hint:"
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

# ── Pass-2 review regression tests ──────────────────────────────────────

@test "undo: honours -t / -B prefix overrides from the CLI" {
  # Replace the default-prefix artefacts from setup with custom-prefix ones.
  git checkout -q feat/x
  git branch -D release-1.2.0
  git tag -d v1.2.0
  git checkout -q -b rel/1.2.0
  git commit -q --allow-empty -m "chore: bumped 1.0.0 -> 1.2.0"
  git tag -a ver-1.2.0 -m "ver-1.2.0"
  git checkout -q feat/x

  run ${profile_script} --undo 1.2.0 -t ver- -B rel/ --yes --dry-run
  assert_success
  assert_output --partial "git branch -D rel/1.2.0"
  assert_output --partial "git tag -d ver-1.2.0"
}

@test "undo: not fooled by a release branch live in another worktree" {
  git checkout -q feat/x
  # release-1.2.0 checked out in a linked worktree makes 'git branch' emit
  # '+ release-1.2.0'; without the '+ ' strip this trips a false "already
  # merged" refusal. Nest under $TMP so the file teardown cleans it up.
  git worktree add -q "$TMP/wt" release-1.2.0

  run ${profile_script} --undo 1.2.0 --yes --dry-run
  assert_success
  refute_output --partial "already merged"
  assert_output --partial "git branch -D release-1.2.0"
  assert_output --partial "git tag -d v1.2.0"
}
