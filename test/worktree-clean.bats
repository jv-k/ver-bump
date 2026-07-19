#!/usr/bin/env bats

# check-worktree-clean (R-SAFE-1..4, issue #57): refuse to release with
# modified tracked files or a non-empty index — a bare `git commit` in
# do-commit would silently sweep them into the release commit. Untracked
# files are ignored; --allow-dirty / ALLOW_DIRTY bypass; -n/--no-commit
# skips the guard; --dry-run still enforces it.

load 'test_helper'

# Seed a scratch repo with a committed package.json and cd into it.
clean_repo() {
  local repo
  repo="$(scratch_repo)"
  cd "$repo" || exit 1
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json && git commit -qm "chore: seed package.json"
}

@test "worktree-clean: modified tracked file -> 3, names the file, tree untouched" {
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  run ${profile_script} -c -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "uncommitted changes to tracked files"
  assert_output --partial "package.json"
  assert_output --partial " HINT "

  # No mutation happened: content untouched, no tag, no extra commit.
  run jq -r '.version' package.json
  assert_output "1.0.0"
  run git tag -l
  assert_output ""
  assert_equal "$(git rev-list --count HEAD)" "2"
}

@test "worktree-clean: pre-staged unrelated file -> 3" {
  clean_repo
  echo "unrelated" > extra.txt
  git add extra.txt

  run ${profile_script} -c -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "extra.txt"
}

@test "worktree-clean: untracked files alone do not trigger the guard" {
  clean_repo
  echo "stray" > stray.txt

  run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "worktree-clean: --allow-dirty bypasses the guard" {
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  run ${profile_script} -d -b -c -p origin -v 1.0.1 --allow-dirty
  assert_success
}

@test "worktree-clean: ALLOW_DIRTY=true in .verbumprc bypasses the guard" {
  clean_repo
  printf 'ALLOW_DIRTY=true\n' > .verbumprc
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_success
}

@test "worktree-clean: env ALLOW_DIRTY=false beats an rc true (R-CFG-3)" {
  clean_repo
  printf 'ALLOW_DIRTY=true\n' > .verbumprc
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  ALLOW_DIRTY=false run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "uncommitted changes to tracked files"
}

@test "worktree-clean: CLI --allow-dirty beats env ALLOW_DIRTY=false (R-CFG-3)" {
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  ALLOW_DIRTY=false run ${profile_script} -d -b -c -p origin -v 1.0.1 --allow-dirty
  assert_success
}

@test "worktree-clean: -n / --no-commit skips the guard (R-SAFE-4)" {
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  run ${profile_script} -n -c -v 1.0.1
  assert_success
  # The bump itself still ran — only the commit (and the guard) were skipped.
  run jq -r '.version' package.json
  assert_output "1.0.1"
}

@test "worktree-clean: --dry-run still enforces the guard (R-SAFE-3)" {
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  run ${profile_script} -d -b -c -p origin -v 1.0.1
  assert_failure 3
  strip_ansi_output
  assert_output --partial "uncommitted changes to tracked files"
  # The failure fires before any previewed side-effect.
  refute_output --partial "[dry-run] would"
  refute_output --partial "[dry-run] git add"
}

@test "worktree-clean: unit — FLAG_NOCOMMIT=true returns success on a dirty tree" {
  source ${profile_script}
  clean_repo
  printf '{ "version": "1.0.0", "name": "wip" }\n' > package.json

  FLAG_NOCOMMIT=true run check-worktree-clean
  assert_success
}

@test "worktree-clean: unit — reports the offending-path count" {
  source ${profile_script}
  clean_repo
  printf 'a\n' > a.txt; printf 'b\n' > b.txt
  git add a.txt b.txt && git commit -qm "chore: seed a b"
  printf 'a2\n' > a.txt; printf 'b2\n' > b.txt

  run check-worktree-clean
  assert_failure 3
  strip_ansi_output
  assert_output --partial "(2)"
  assert_output --partial "a.txt"
  assert_output --partial "b.txt"
}

@test "worktree-clean: completions list --allow-dirty in bash/zsh/fish" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial -- "--allow-dirty"
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial -- "--allow-dirty"
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial -- "-l allow-dirty"
}
