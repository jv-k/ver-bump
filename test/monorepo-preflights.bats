#!/usr/bin/env bats

# Safety preflights under a package scope (#96, spec #128, R-MONO-5/9/10).
# The dirty-tree check splits by index vs worktree: dirt inside the scope
# fails as today; STAGED changes anywhere fail (a bare `git commit` sweeps
# the whole index into the bump commit); unstaged edits outside the scope no
# longer block. Release notes anchor to the package's tag series, and the
# scoped default is the package's own changelog entry.

load 'test_helper'

# ── dirty-tree split (R-MONO-5) ─────────────────────────────────────────────

@test "dirty: unstaged changes outside the scope don't block (R-MONO-5)" {
  monorepo_fixture
  echo "wip" >> packages/pkg-b/widget.txt
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin
  assert_success
}

@test "dirty: unstaged changes inside the scope still fail with exit 3 (R-MONO-5)" {
  monorepo_fixture
  echo "wip" >> packages/pkg-a/rounding.txt
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin
  assert_failure 3
  strip_ansi_output
  assert_output --partial "uncommitted changes"
}

@test "dirty: staged changes outside the scope fail — a bare commit would sweep them (R-MONO-5)" {
  monorepo_fixture
  echo "wip" >> packages/pkg-b/widget.txt
  git add packages/pkg-b/widget.txt
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin
  assert_failure 3
  strip_ansi_output
  assert_output --partial "sweep them into the bump commit"
  assert_output --partial "pkg-b/widget.txt"
}

@test "dirty: ALLOW_DIRTY still skips the whole check under scope (R-MONO-5)" {
  monorepo_fixture
  echo "wip" >> packages/pkg-a/rounding.txt
  cd packages/pkg-a

  ALLOW_DIRTY=true run ${profile_script} -d -y -p origin
  assert_success
}

@test "dirty: whole-repo scope keeps today's repo-wide behaviour (R-MONO-1/5)" {
  releasable_repo
  echo "tracked" > afile
  git add afile
  git commit -qm "chore: add afile"
  echo "change" >> afile

  run ${profile_script} -d -y -p origin
  assert_failure 3
  strip_ansi_output
  assert_output --partial "uncommitted changes"
}

# ── branch-collision hint (R-MONO-10) ───────────────────────────────────────

@test "branch collision: hint mentions per-package REL_PREFIX under scope (R-MONO-10)" {
  monorepo_fixture
  git branch release-1.2.4
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin --branch -v 1.2.4
  assert_failure 3
  strip_ansi_output
  assert_output --partial "REL_PREFIX"
}

# ── release notes (R-MONO-9) ────────────────────────────────────────────────

@test "release notes: --notes-start-tag anchors generated notes to the series (R-MONO-9)" {
  source ${profile_script}
  releasable_repo

  TAG_PREFIX=v V_PREV=1.2.3 V_NEW=1.3.0 DO_RELEASE=true FLAG_DRYRUN=true \
    run do-github-release
  assert_success
  strip_ansi_output
  assert_output --partial "notes-start-tag v1.2.3"
}

@test "release notes: scoped default notes are the package changelog entry (R-MONO-9)" {
  source ${profile_script}
  monorepo_fixture
  git remote set-url origin https://github.com/acme/mono.git
  cd packages/pkg-a
  # Simulate a completed release: bump commit + tag exist, as they do when
  # do-github-release runs on the live path.
  printf '{ "version": "1.2.4" }\n' > package.json
  git add package.json
  git commit -qm "chore: updated package.json, bumped 1.2.3 -> 1.2.4"
  git tag -a pkg-a-v1.2.4 -m "pkg-a-v1.2.4"

  load-config
  apply-config-defaults
  resolve-commit-scope

  V_PREV=1.2.3 V_NEW=1.2.4 CHANGELOG_STYLE=grouped DO_RELEASE=true FLAG_DRYRUN=true \
    run do-github-release
  assert_success
  strip_ansi_output
  assert_output --partial "compare/pkg-a-v1.2.3...pkg-a-v1.2.4"
  assert_output --partial "correct rounding"
  refute_output --partial "add widget"
}

@test "release notes: VERBUMP_RELEASE_NOTES_CMD still overrides scoped notes (R-MONO-9)" {
  source ${profile_script}
  monorepo_fixture
  cd packages/pkg-a
  git tag -a pkg-a-v1.2.4 -m "pkg-a-v1.2.4"

  load-config
  apply-config-defaults
  resolve-commit-scope

  V_PREV=1.2.3 V_NEW=1.2.4 DO_RELEASE=true FLAG_DRYRUN=true \
    VERBUMP_RELEASE_NOTES_CMD='echo CUSTOM-NOTES' \
    run do-github-release
  assert_success
  strip_ansi_output
  assert_output --partial "CUSTOM-NOTES"
  refute_output --partial "correct rounding"
}
