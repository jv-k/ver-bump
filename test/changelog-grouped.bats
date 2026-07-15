#!/usr/bin/env bats

# CHANGELOG_STYLE=grouped — Conventional-Commit-aware changelog sections
# with commit/PR/compare links (R-CHLOG-1..5, issue #61). Shared setup
# lives in test/test_helper.bash.
#
# All tests run inside a fresh scratch_repo. Snapshot tests interpolate
# each fixture commit's real short SHA so the comparison is byte-exact
# without fragile normalisation.

load 'test_helper'

# Fixture: one commit of every class since v1.0.0. Callers must have
# sourced ${profile_script} first. Sets sha_* globals and the do-changelog
# inputs (V_PREV/V_NEW, grouped style, deterministic prefix).
_grouped_fixture() {
  cd "$(scratch_repo)"
  git tag v1.0.0

  git commit --allow-empty -qm "feat(api): add endpoint (#12)"
  sha_feat=$(git rev-parse --short HEAD)
  git commit --allow-empty -qm "fix(net): retry on 503"
  sha_fix=$(git rev-parse --short HEAD)
  git commit --allow-empty -qm "feat!: drop node 14"
  sha_breaking=$(git rev-parse --short HEAD)
  git commit --allow-empty -qm "chore(deps): bump lodash"
  sha_chore=$(git rev-parse --short HEAD)
  git commit --allow-empty -qm "plain non-conventional message"
  sha_plain=$(git rev-parse --short HEAD)

  V_PREV="1.0.0"
  V_NEW="1.1.0"
  GIT_MSG=""
  COMMIT_MSG_PREFIX="chore: "
  CHANGELOG_STYLE="grouped"
}

# R-CHLOG-2: full snapshot ####################################################

@test "grouped: snapshot — section order, bold scopes, nothing dropped, plain text without a remote" {
  source ${profile_script}
  _grouped_fixture

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output -p "Created [CHANGELOG.md]"

  # Byte-exact expectation: Breaking > Features > Fixes > Other; scopes
  # bolded; the plain commit lands in Other verbatim; no links (no remote);
  # the tool's own bump entry has no SHA (its commit doesn't exist yet).
  printf '%s\n' \
    "## 1.1.0 ($NOW)" \
    "" \
    "### Breaking Changes" \
    "" \
    "- drop node 14 (${sha_breaking})" \
    "" \
    "### Features" \
    "" \
    "- **api:** add endpoint (#12) (${sha_feat})" \
    "" \
    "### Fixes" \
    "" \
    "- **net:** retry on 503 (${sha_fix})" \
    "" \
    "### Other" \
    "" \
    "- created CHANGELOG.md, bumped 1.0.0 -> 1.1.0" \
    "- plain non-conventional message (${sha_plain})" \
    "- **deps:** bump lodash (${sha_chore})" \
    "" > expected.md

  run diff expected.md CHANGELOG.md
  assert_success
}

@test "grouped: BREAKING CHANGE footer routes a commit to Breaking Changes" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag v1.0.0
  git commit --allow-empty -qm "refactor: rework config loader" -m "BREAKING CHANGE: rc keys renamed"

  V_PREV="1.0.0"; V_NEW="2.0.0"; CHANGELOG_STYLE="grouped"

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "### Breaking Changes"
  assert_output --partial "- rework config loader ("
  refute_output --partial "### Features"
  refute_output --partial "### Fixes"
}

@test "grouped: empty sections are omitted" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag v1.0.0
  git commit --allow-empty -qm "fix: solve crash"

  V_PREV="1.0.0"; V_NEW="1.0.1"; COMMIT_MSG_PREFIX="chore: "; CHANGELOG_STYLE="grouped"

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "### Fixes"
  assert_output --partial "### Other" # the tool's own bump entry
  refute_output --partial "### Features"
  refute_output --partial "### Breaking Changes"
}

# R-CHLOG-3/4: links per remote form ##########################################

@test "grouped: GitHub HTTPS remote — SHA links, compare heading, (#N) kept verbatim" {
  source ${profile_script}
  _grouped_fixture
  git remote add origin https://github.com/acme/widget.git

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "## [1.1.0](https://github.com/acme/widget/compare/v1.0.0...v1.1.0) ($NOW)"
  assert_output --partial "- **api:** add endpoint (#12) ([${sha_feat}](https://github.com/acme/widget/commit/${sha_feat}))"
  assert_output --partial "- drop node 14 ([${sha_breaking}](https://github.com/acme/widget/commit/${sha_breaking}))"
}

@test "grouped: GitHub SSH remote resolves to the same https links" {
  source ${profile_script}
  _grouped_fixture
  git remote add origin git@github.com:acme/widget.git

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "## [1.1.0](https://github.com/acme/widget/compare/v1.0.0...v1.1.0) ($NOW)"
  assert_output --partial "- **net:** retry on 503 ([${sha_fix}](https://github.com/acme/widget/commit/${sha_fix}))"
}

@test "grouped: non-GitHub remote falls back to plain text entries without failing" {
  source ${profile_script}
  _grouped_fixture
  git remote add origin git@gitlab.com:acme/widget.git

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "## 1.1.0 ($NOW)"
  assert_output --partial "- **api:** add endpoint (#12) (${sha_feat})"
  refute_output --partial "]("
}

@test "grouped: no previous tag — no compare link, full history listed" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git remote add origin https://github.com/acme/widget.git
  git commit --allow-empty -qm "feat: first feature"

  V_PREV="0.1.0" # intentionally NO v0.1.0 tag in this repo
  V_NEW="1.0.0"
  CHANGELOG_STYLE="grouped"

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "## 1.0.0 ($NOW)"
  refute_output --partial "compare/"
  # Commit links still render, and the scratch repo's root commit is
  # included — grouped keeps flat's full-history fallback.
  assert_output --partial "- first feature (["
  assert_output --partial "- initial (["
}

@test "grouped: slashed TAG_PREFIX is URL-encoded in the compare link, plain heading untouched" {
  source ${profile_script}
  cd "$(scratch_repo)"
  git tag rel/1.0.0
  git commit --allow-empty -qm "feat: shiny"
  git remote add origin https://github.com/acme/widget.git

  TAG_PREFIX="rel/"
  V_PREV="1.0.0"; V_NEW="1.1.0"; CHANGELOG_STYLE="grouped"

  run do-changelog <<< ""
  assert_success

  run cat CHANGELOG.md
  assert_output --partial "## [1.1.0](https://github.com/acme/widget/compare/rel%2F1.0.0...rel%2F1.1.0) ($NOW)"

  # No remote → plain heading with no refs at all, so nothing gets encoded.
  git remote remove origin
  rm CHANGELOG.md
  run do-changelog <<< ""
  assert_success
  run cat CHANGELOG.md
  assert_output --partial "## 1.1.0 ($NOW)"
  refute_output --partial "%2F"
}

# _forge-base-url unit table ##################################################

@test "_forge-base-url: GitHub URL forms parse; non-GitHub and no-remote return 1 silently" {
  source ${profile_script}
  cd "$(scratch_repo)"

  git remote add origin git@github.com:owner/repo.git
  assert_equal "$(_forge-base-url)" "https://github.com/owner/repo"

  git remote set-url origin ssh://git@github.com/owner/repo.git
  assert_equal "$(_forge-base-url)" "https://github.com/owner/repo"

  git remote set-url origin https://github.com/owner/repo.git
  assert_equal "$(_forge-base-url)" "https://github.com/owner/repo"

  git remote set-url origin https://github.com/owner/repo
  assert_equal "$(_forge-base-url)" "https://github.com/owner/repo"

  git remote set-url origin git@gitlab.com:owner/repo.git
  run _forge-base-url
  assert_failure
  refute_output

  git remote remove origin
  run _forge-base-url
  assert_failure
  refute_output
}

# R-CHLOG-5: prepend, -c/-l semantics, dry-run parity #########################

@test "grouped: prepends to an existing CHANGELOG.md, old entries intact" {
  source ${profile_script}
  _grouped_fixture
  printf '## 1.0.0 (2020-01-01)\n- old entry\n\n' > CHANGELOG.md

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output -p "Updated [CHANGELOG.md]"

  run cat CHANGELOG.md
  assert_output --partial "### Features"
  assert_output --partial "- old entry"
  # The new section is prepended: line 1 is the new heading.
  assert_equal "$(head -1 CHANGELOG.md)" "## 1.1.0 ($NOW)"
}

@test "grouped: FLAG_NOCHANGELOG (-c) still skips the changelog entirely" {
  source ${profile_script}
  _grouped_fixture
  FLAG_NOCHANGELOG=true

  run do-changelog
  assert_success
  refute_output
  [ ! -f CHANGELOG.md ]
}

@test "grouped: FLAG_CHANGELOG_PAUSE (-l) still pauses for hand edits" {
  source ${profile_script}
  _grouped_fixture
  FLAG_CHANGELOG_PAUSE=true

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output --partial "Make adjustments"
  [ -f CHANGELOG.md ]
}

@test "grouped: dry-run previews the grouped section and writes nothing" {
  source ${profile_script}
  _grouped_fixture
  FLAG_DRYRUN=true

  [ ! -f CHANGELOG.md ]
  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output --partial "[dry-run]"
  assert_output --partial "### Features"
  [ ! -f CHANGELOG.md ]
}

# R-CHLOG-1: opt-in + R-CFG-3 precedence (end-to-end, mirrors config-env.bats)

@test "precedence: env CHANGELOG_STYLE=grouped beats .ver-bumprc flat (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'CHANGELOG_STYLE=flat\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"
  git commit --allow-empty -qm "feat: shiny"

  CHANGELOG_STYLE=grouped run ${profile_script} -d -b -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "### Features"
  refute_output --partial "- feat: shiny"
}

@test "precedence: .ver-bumprc CHANGELOG_STYLE=grouped beats the flat default (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'CHANGELOG_STYLE=grouped\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"
  git commit --allow-empty -qm "feat: shiny"

  unset CHANGELOG_STYLE
  run ${profile_script} -d -b -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "### Features"
}

@test "precedence: default stays flat when nothing sets CHANGELOG_STYLE (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"
  git commit --allow-empty -qm "feat: shiny"

  unset CHANGELOG_STYLE
  run ${profile_script} -d -b -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "- feat: shiny"
  refute_output --partial "### Features"
}

# classify-commit unit table (shared helper backing R-CHLOG-2 and R-BUMP-2)

@test "classify-commit: table of subject/body classifications" {
  source ${profile_script}

  assert_equal "$(classify-commit 'feat: add thing' '')"                    "feat"
  assert_equal "$(classify-commit 'feat(api): add thing' '')"               "feat"
  assert_equal "$(classify-commit 'fix: squash bug' '')"                    "fix"
  assert_equal "$(classify-commit 'fix(net): squash bug' '')"               "fix"
  assert_equal "$(classify-commit 'feat!: breaking thing' '')"              "breaking"
  assert_equal "$(classify-commit 'refactor(core)!: rewrite' '')"           "breaking"
  assert_equal "$(classify-commit 'refactor: rework' 'BREAKING CHANGE: x')" "breaking"
  assert_equal "$(classify-commit 'refactor: rework' 'BREAKING-CHANGE: x')" "breaking"
  assert_equal "$(classify-commit 'chore: tidy' '')"                        "other"
  assert_equal "$(classify-commit 'docs(readme): typo' '')"                 "other"
  assert_equal "$(classify-commit 'plain message, no type' '')"             "other"
  # A body that merely QUOTES a breaking subject must not escalate.
  assert_equal "$(classify-commit 'chore: notes' 'see "feat!: dropped" above')" "other"
  # feature/fixture words that only PREFIX the type must not match.
  assert_equal "$(classify-commit 'feature: not conventional feat' '')"     "other"
  assert_equal "$(classify-commit 'fixture: not a fix' '')"                 "other"
}
