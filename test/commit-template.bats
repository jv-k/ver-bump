#!/usr/bin/env bats

# COMMIT_MSG_TEMPLATE — whole-message template for the bump commit with
# literal ${version}/${prev_version}/${tag}/${files} placeholders
# (R-TPL-1..4, issue #69). Shared setup lives in test/test_helper.bash.
#
# render-commit-msg is the ONE renderer shared by do-commit and
# do-changelog's manual bump entry; the live tests below pin that the
# actual commit message and the CHANGELOG entry stay identical in both
# changelog styles, with and without a template.

load 'test_helper'

# Unit fixture: deterministic renderer inputs. Callers must have sourced
# ${profile_script} first.
_render_fixture() {
  V_PREV="1.0.0"
  V_NEW="1.1.0"
  TAG_PREFIX="v"
  COMMIT_MSG_PREFIX="chore: "
  unset COMMIT_MSG_TEMPLATE
}

# Live fixture: scratch repo with package.json@1.0.0 and a throwaway bare
# remote so `-p <remote> -y` completes end-to-end without prompting
# (mirrors e2e-live.bats). Sets LIVE_REMOTE.
_live_repo() {
  local remote
  cd "$(scratch_repo)"
  printf '{ "version": "1.0.0" }\n' > package.json
  git add package.json && git commit -qm "feat: seed a feature"
  remote=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${remote}")
  git init -q --bare "${remote}"
  LIVE_REMOTE="${remote}"
}

# R-TPL-1: legacy default (unset template) #####################################

@test "render-commit-msg: unset template renders the legacy prefix + list + bump summary byte-identically" {
  source ${profile_script}
  _render_fixture

  assert_equal \
    "$(render-commit-msg 'updated package.json, updated CHANGELOG.md, ')" \
    "chore: updated package.json, updated CHANGELOG.md, bumped 1.0.0 -> 1.1.0"

  # Same-version path keeps the legacy "bumped to" wording too.
  V_PREV="1.1.0"
  assert_equal \
    "$(render-commit-msg 'updated package.json, ')" \
    "chore: updated package.json, bumped to 1.1.0"
}

@test "live: unset template — commit message and flat CHANGELOG entry are the legacy strings, byte-identical (regression pin)" {
  _live_repo
  unset COMMIT_MSG_TEMPLATE

  run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" \
    "chore: updated package.json, created CHANGELOG.md, bumped 1.0.0 -> 1.1.0"
  # The changelog's manual bump entry is the same rendered message.
  assert_equal "$(sed -n 2p CHANGELOG.md)" \
    "- chore: updated package.json, created CHANGELOG.md, bumped 1.0.0 -> 1.1.0"
}

# R-TPL-1: placeholders ########################################################

@test "render-commit-msg: every placeholder renders; \${files} is the generated list without the trailing comma" {
  source ${profile_script}
  _render_fixture
  COMMIT_MSG_TEMPLATE='v=${version} p=${prev_version} t=${tag} f=[${files}] again=${version}'

  assert_equal \
    "$(render-commit-msg 'updated package.json, updated CHANGELOG.md, ')" \
    "v=1.1.0 p=1.0.0 t=v1.1.0 f=[updated package.json, updated CHANGELOG.md] again=1.1.0"
}

@test "render-commit-msg: unknown placeholders pass through literally" {
  source ${profile_script}
  _render_fixture
  COMMIT_MSG_TEMPLATE='keep ${unknown} and ${VERSION} but not ${version}'

  assert_equal \
    "$(render-commit-msg '')" \
    'keep ${unknown} and ${VERSION} but not 1.1.0'
}

@test "live: template — commit subject is exactly the rendered template; tag message is untouched (R-TPL-2/4)" {
  _live_repo

  COMMIT_MSG_TEMPLATE='chore(release): v${version}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  # The template owns the WHOLE message — no prefix, no generated list.
  assert_equal "$(git log -1 --pretty=%B)" "chore(release): v1.1.0"
  # The annotated tag keeps its own message (-m/--message knob), R-TPL-4.
  assert_equal "$(git tag -l --format='%(contents:subject)' v1.1.0)" \
    "Tag version 1.1.0."
}

@test "live: template \${files} matches today's generated changed-file list" {
  _live_repo

  COMMIT_MSG_TEMPLATE='files: ${files}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" \
    "files: updated package.json, created CHANGELOG.md"
}

# R-TPL-2: COMMIT_MSG_PREFIX is ignored when the template is set ###############

@test "render-commit-msg: template set — COMMIT_MSG_PREFIX is ignored" {
  source ${profile_script}
  _render_fixture
  COMMIT_MSG_PREFIX="zzz: "
  COMMIT_MSG_TEMPLATE='chore(release): v${version}'

  assert_equal "$(render-commit-msg 'updated package.json, ')" \
    "chore(release): v1.1.0"
}

# R-TPL-3: literal substitution, never eval ####################################

@test "render-commit-msg: \$(...) and backticks in the template stay literal — nothing executes" {
  source ${profile_script}
  cd "$(scratch_repo)"
  _render_fixture
  COMMIT_MSG_TEMPLATE='pwn $(touch ./pwned-a) `touch ./pwned-b` ${version}'

  assert_equal "$(render-commit-msg '')" \
    'pwn $(touch ./pwned-a) `touch ./pwned-b` 1.1.0'
  [ ! -f pwned-a ]
  [ ! -f pwned-b ]
}

@test "render-commit-msg: & and backslash in the template text stay literal" {
  source ${profile_script}
  _render_fixture
  COMMIT_MSG_TEMPLATE='R&D \release\ v${version} & co'

  assert_equal "$(render-commit-msg '')" 'R&D \release\ v1.1.0 & co'
}

@test "render-commit-msg: & and backslash in substituted values stay literal (bash 5.2 patsub_replacement)" {
  source ${profile_script}
  _render_fixture
  # On bash 5.2+ an unescaped & in the replacement would splice the matched
  # placeholder back in ("updated R${files}D.json ..."); bash 3.2 was always
  # literal. The assertion is on the final message only, so it must pass
  # identically on both generations.
  COMMIT_MSG_TEMPLATE='files: ${files} (${version})'

  assert_equal "$(render-commit-msg 'updated R&D.json, updated a\b.json, ')" \
    'files: updated R&D.json, updated a\b.json (1.1.0)'
}

@test "live: injection-shaped template lands literally in the real commit, and nothing executes" {
  _live_repo

  COMMIT_MSG_TEMPLATE='release ${version} $(touch ./pwned)' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  [ ! -f ./pwned ]
  assert_equal "$(git log -1 --pretty=%B)" 'release 1.1.0 $(touch ./pwned)'
}

@test "live: bumped file named with & lands literally in the templated message" {
  _live_repo
  printf '{ "version": "1.0.0" }\n' > "R&D.json"
  git add "R&D.json" && git commit -qm "chore: add R&D.json"

  COMMIT_MSG_TEMPLATE='files: ${files}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y -f "R&D.json"
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" \
    "files: updated package.json, updated R&D.json, created CHANGELOG.md"
}

# CHANGELOG parity: the manual bump entry uses the same renderer ###############

@test "live flat: CHANGELOG bump entry equals the templated commit subject" {
  _live_repo

  COMMIT_MSG_TEMPLATE='chore(release): v${version}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(sed -n 2p CHANGELOG.md)" "- $(git log -1 --pretty=%s)"
  assert_equal "$(sed -n 2p CHANGELOG.md)" "- chore(release): v1.1.0"
}

@test "live grouped: non-conventional template — CHANGELOG bump entry equals the commit subject verbatim" {
  _live_repo

  CHANGELOG_STYLE=grouped COMMIT_MSG_TEMPLATE='release ${prev_version} -> ${version}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" "release 1.0.0 -> 1.1.0"
  # Non-conventional subjects render verbatim under Other (nothing dropped).
  run cat CHANGELOG.md
  assert_output --partial "### Other"
  assert_output --partial "- release 1.0.0 -> 1.1.0"
}

@test "live grouped: conventional template is classified and scope-bolded like any other commit" {
  _live_repo

  CHANGELOG_STYLE=grouped COMMIT_MSG_TEMPLATE='chore(release): v${version}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" "chore(release): v1.1.0"
  # Same grouped rendering rules as every other entry: chore → Other,
  # scope becomes a bold prefix — derived from the SAME rendered message.
  run cat CHANGELOG.md
  assert_output --partial "### Other"
  assert_output --partial "- **release:** v1.1.0"
}

@test "live: multi-line template — commit keeps the full body, CHANGELOG logs the subject line only" {
  _live_repo

  COMMIT_MSG_TEMPLATE=$'chore(release): v${version}\n\nbumped from ${prev_version}' \
    run ${profile_script} -v 1.1.0 -p "${LIVE_REMOTE}" -y
  assert_success

  assert_equal "$(git log -1 --pretty=%B)" \
    $'chore(release): v1.1.0\n\nbumped from 1.0.0'
  assert_equal "$(sed -n 2p CHANGELOG.md)" "- chore(release): v1.1.0"
}

# R-CFG-3 precedence: env > .verbumprc > default ##############################

@test "precedence: env COMMIT_MSG_TEMPLATE beats .verbumprc (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  # Single quotes in the rc are load-bearing: it is shell-sourced, so a
  # double-quoted ${version} would expand (to empty) at source time.
  printf "COMMIT_MSG_TEMPLATE='from-file \${version}'\n" > "$repo/.verbumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  COMMIT_MSG_TEMPLATE='from-env ${version}' \
    run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  # The preview %q-quotes the message (spaces become backslash-escaped).
  assert_output --partial 'git commit -m from-env\ 1.0.1'
  refute_output --partial "from-file"
}

@test "precedence: .verbumprc COMMIT_MSG_TEMPLATE beats the legacy default (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf "COMMIT_MSG_TEMPLATE='from-file \${version}'\n" > "$repo/.verbumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  unset COMMIT_MSG_TEMPLATE
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial 'git commit -m from-file\ 1.0.1'
  refute_output --partial "chore:"
}

@test "precedence: nothing set — dry-run previews the legacy message (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  unset COMMIT_MSG_TEMPLATE
  run ${profile_script} -d -b -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial 'git commit -m chore:\ updated\ package.json\,\ bumped\ 1.0.0\ -\>\ 1.0.1'
}
