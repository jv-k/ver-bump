#!/usr/bin/env bats

# --source <file.json> + git-tag version fallback (R-SRC-1..5, issue #63).
#
# The version source is package.json only by default: --source (or the
# SOURCE_FILE config/env key) points both the version read and the primary
# bump write at any JSON file, and when the source file is absent V_PREV is
# derived from the latest matching release tag — so non-Node repos get the
# full suggestion machinery, and a tag-only release (nothing staged → no
# commit, tag on HEAD) is a valid outcome.

load 'test_helper'

# Scratch repo with NO version file, a v1.4.0 release tag, and a bare
# "remote" wired up as origin so full (non-dry) runs can push with -p origin
# instead of hitting the interactive push prompt.
tagged_repo_no_source() {
  local repo remote
  repo="$(scratch_repo)"
  remote=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${remote}")
  git init -q --bare "$remote"
  cd "$repo" || exit 1
  git remote add origin "$remote"
  git tag -a v1.4.0 -m "v1.4.0"
}

# ── R-SRC-2: tag-derived fallback feeds the suggestion machinery ──────────

@test "tag fallback: no package.json, tag v1.4.0 + feat commit -> suggests 1.5.0, full release (R-SRC-2)" {
  tagged_repo_no_source
  git commit -q --allow-empty -m "feat: add shiny"

  # Bare <enter> accepts the suggested version; -p origin skips the push prompt.
  run bash -c 'printf "\n" | "$1" -p origin' _ "${profile_script}"
  assert_success
  strip_ansi_output
  assert_output --partial "derived from git tag <v1.4.0>: 1.4.0"
  assert_output --partial "suggesting minor bump"

  # CHANGELOG was written and committed; the tag landed on the bump commit.
  run git tag -l "v1.5.0"
  assert_output "v1.5.0"
  [ -f CHANGELOG.md ]
  run grep -c "## 1.5.0" CHANGELOG.md
  assert_output "1"
  # initial + feat + changelog bump commit = 3; no package.json materialised.
  assert_equal "$(git rev-list --count HEAD)" "3"
  [ ! -f package.json ]
}

@test "tag fallback: derivation runs with -v too and feeds the changelog range" {
  tagged_repo_no_source
  git commit -q --allow-empty -m "feat: add shiny"

  run ${profile_script} -p origin -v 2.0.0
  assert_success
  strip_ansi_output
  assert_output --partial "derived from git tag <v1.4.0>: 1.4.0"
  # No suggestion machinery with -v (R-FORCE-3).
  refute_output --partial "suggesting"
  # Changelog range anchored at the derived previous tag: the pre-tag
  # "initial" commit must not leak into the new section.
  run head -5 CHANGELOG.md
  assert_output --partial "## 2.0.0"
  assert_output --partial "feat: add shiny"
  refute_output --partial "initial"
}

# ── R-SRC-3: tag-only release when nothing is staged ──────────────────────

@test "tag-only: no source, -c, nothing staged -> skips commit, annotated tag on HEAD (R-SRC-3)" {
  tagged_repo_no_source
  git commit -q --allow-empty -m "feat: new thing"
  local head_before
  head_before=$(git rev-parse HEAD)

  run ${profile_script} -c -p origin -v 1.5.0
  assert_success
  strip_ansi_output
  assert_output --partial "Nothing staged to commit"

  # No new commit; the tag is annotated and points at the pre-run HEAD.
  assert_equal "$(git rev-parse HEAD)" "$head_before"
  run git cat-file -t "refs/tags/v1.5.0"
  assert_output "tag"
  assert_equal "$(git rev-list -n1 v1.5.0)" "$head_before"
}

@test "tag-only: dry-run previews the same skip without mutating (R-SRC-3 + dry-run parity)" {
  tagged_repo_no_source
  git commit -q --allow-empty -m "feat: shiny"

  run ${profile_script} -d -c -p origin -v 1.5.0
  assert_success
  strip_ansi_output
  assert_output --partial "derived from git tag"
  assert_output --partial "Nothing staged to commit"
  assert_output --partial "would run: git tag -a v1.5.0"
  run git tag -l "v1.5.0"
  assert_output ""
  [ ! -f package.json ]
  [ ! -f CHANGELOG.md ]
}

@test "tag fallback: no-op guard still applies — no commits since derived tag -> no-release (R-SAFE-14)" {
  tagged_repo_no_source

  run ${profile_script} -p origin -v 1.5.0
  assert_success
  strip_ansi_output
  assert_output --partial "no-release"
  run git tag -l "v1.5.0"
  assert_output ""
}

# ── R-SRC-1: --source replaces the source AND the primary bump target ─────

@test "--source composer.json: reads + bumps it; package.json and lock file untouched (R-SRC-1)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "2.3.4" }\n' > composer.json
  printf '{ "version": "0.0.1" }\n' > package.json
  printf '{ "version": "0.0.1", "packages": { "": { "version": "0.0.1" } } }\n' > package-lock.json
  git add composer.json package.json package-lock.json
  git commit -qm "chore: seed"

  run ${profile_script} --source composer.json -c -n -v 2.4.0
  assert_success
  strip_ansi_output
  assert_output --partial "Current version read from <composer.json>: 2.3.4"
  assert_output --partial "Bumped version in <composer.json>"
  refute_output --partial "package-lock.json"

  run jq -r '.version' composer.json
  assert_output "2.4.0"
  run jq -r '.version' package.json
  assert_output "0.0.1"
  run jq -r '.version' package-lock.json
  assert_output "0.0.1"
}

@test "--source composer.json: suggestion machinery reads the alternate source" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "2.3.4" }\n' > composer.json
  git add composer.json && git commit -qm "chore: seed"
  git tag -a v2.3.4 -m "v2.3.4"
  git commit -q --allow-empty -m "feat: php thing"

  # Bare <enter> accepts the suggestion (2.4.0 from the feat: commit).
  run bash -c 'printf "\n" | "$1" --source composer.json -c -n' _ "${profile_script}"
  assert_success
  strip_ansi_output
  assert_output --partial "Current version read from <composer.json>: 2.3.4"
  assert_output --partial "suggesting minor bump"
  run jq -r '.version' composer.json
  assert_output "2.4.0"
}

@test "regression: default package.json flow unchanged (bump + lock companion)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > package.json
  printf '{ "version": "1.0.0", "packages": { "": { "version": "1.0.0" } } }\n' > package-lock.json
  git add package.json package-lock.json && git commit -qm "chore: seed"
  git tag -a v1.0.0 -m "v1.0.0"
  git commit -q --allow-empty -m "fix: bug"

  run ${profile_script} -c -n -v 1.0.1
  assert_success
  strip_ansi_output
  assert_output --partial "Bumped version in <package.json> and <package-lock.json>"
  run jq -r '.version' package.json
  assert_output "1.0.1"
  run jq -r '.version' package-lock.json
  assert_output "1.0.1"
  run jq -r '.packages."".version' package-lock.json
  assert_output "1.0.1"
}

# ── R-SRC-2: custom tag prefix respected in the describe match ─────────────

@test "tag fallback: custom --tag-prefix rel/ drives the describe match (R-SRC-2)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  git tag -a rel/1.4.0 -m "rel/1.4.0"
  git tag -a v9.9.9 -m "decoy with the default prefix"
  git commit -q --allow-empty -m "fix: something"

  run ${profile_script} -t rel/ -c -n --patch
  assert_success
  strip_ansi_output
  assert_output --partial "derived from git tag <rel/1.4.0>: 1.4.0"
  assert_output --partial "1.4.1"
  refute_output --partial "9.9.9"
}

# ── R-SRC-4: no tags AND no source file -> exit 3 with the dual hint ──────

@test "no tags + no source file -> exit 3 with dual hint (R-SRC-4)" {
  cd "$(scratch_repo)"

  run ${profile_script}
  assert_failure 3
  strip_ansi_output
  assert_output --partial "was not found"
  assert_output --partial "no 'v*' release tag"
  assert_output --partial "Hint:"
  assert_output --partial "-v <version>"
  assert_output --partial "create package.json"
}

@test "no tags + no source file + -v proceeds (first release escape route, R-SRC-4)" {
  cd "$(scratch_repo)"

  run ${profile_script} -d -c -p origin -v 0.1.0
  assert_success
  strip_ansi_output
  refute_output --partial "Hint:"
  assert_output --partial "would run: git tag -a v0.1.0"
}

# ── R-SRC-5: SOURCE_FILE config/env key mirrors the flag ──────────────────

@test "SOURCE_FILE via .ver-bumprc is honoured (R-SRC-5)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'SOURCE_FILE=composer.json\n' > .ver-bumprc
  printf '{ "version": "3.0.0" }\n' > composer.json
  git add composer.json .ver-bumprc && git commit -qm "chore: seed"

  unset SOURCE_FILE
  run ${profile_script} -d -c -p origin -v 3.0.1
  assert_success
  strip_ansi_output
  assert_output --partial "read from <composer.json>: 3.0.0"
  assert_output --partial "would set .version = '3.0.1' in composer.json"
}

@test "env SOURCE_FILE beats .ver-bumprc (R-SRC-5 / R-CFG-3)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'SOURCE_FILE=fromfile.json\n' > .ver-bumprc
  printf '{ "version": "1.0.0" }\n' > fromfile.json
  printf '{ "version": "2.0.0" }\n' > fromenv.json
  git add . && git commit -qm "chore: seed"

  SOURCE_FILE=fromenv.json run ${profile_script} -d -c -p origin -v 9.9.9
  assert_success
  strip_ansi_output
  assert_output --partial "read from <fromenv.json>: 2.0.0"
  refute_output --partial "fromfile.json>: 1.0.0"
}

@test "--source beats env SOURCE_FILE (R-SRC-5 / R-CFG-3)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "2.0.0" }\n' > fromenv.json
  printf '{ "version": "3.0.0" }\n' > fromcli.json
  git add . && git commit -qm "chore: seed"

  SOURCE_FILE=fromenv.json run ${profile_script} --source fromcli.json -d -c -p origin -v 9.9.9
  assert_success
  strip_ansi_output
  assert_output --partial "read from <fromcli.json>: 3.0.0"
  refute_output --partial "fromenv.json>: 2.0.0"
}

# ── Surface parity: help + completions ─────────────────────────────────────

@test "--help documents --source" {
  run get_help_msg
  assert_success
  assert_output --partial -- "--source"
  assert_output --partial "default: package.json"
}

@test "completions list --source in bash/zsh/fish, restricted to *.json (R-COMP-3)" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial -- "-f|--file|--source"
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial -- '--source[version source'
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial -- "-l source"
  assert_output --partial "__fish_complete_suffix .json"
}

# ── Review regressions (PR #83): stdout hygiene + dry-run parity ──────────

@test "--source before --completions keeps stdout clean (Option set goes to stderr)" {
  # --source is parsed in the same normalize loop that emits completions, so
  # its "Option set" notice must not land on stdout and corrupt the script.
  run bash -c '"$1" --source pkg.json --completions bash 2>/dev/null </dev/null' _ "${profile_script}"
  assert_success
  refute_output --partial "Option set"
  echo "$output" | bash -n
}

@test "dry-run previews a commit for pre-staged changes (R-SRC-3 parity, no dry-run-only skip)" {
  tagged_repo_no_source
  git commit -q --allow-empty -m "feat: releasable change"
  # A change staged outside this run (the --allow-dirty scenario). Source is
  # absent and -c skips the changelog, so this run's own ledger is empty — but
  # the index is not, so a live run would commit it. Dry-run must preview that
  # commit, not take a tag-only early return. -p origin + --dry-run intercepts
  # the push with no prompt (R-DRY-4).
  echo "outside change" > extra.txt
  git add extra.txt

  run ${profile_script} --dry-run --allow-dirty -c -v 1.5.0 -p origin </dev/null
  assert_success
  strip_ansi_output
  refute_output --partial "Nothing staged to commit"
  assert_output --partial "would run: git commit"
}
