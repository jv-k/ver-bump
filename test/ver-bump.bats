#!/usr/bin/env bats

# UNIT TESTS for VER-BUMP

# Testing everything that could possibly break 🤡

# Note: The RUN helper executes its argument(s) in a subshell,
# so if writing tests against environmental side-effects like a
# variable’s value being changed, these changes will not persist
# after run completes.

setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  repo_dir=$PWD
  profile_script="$repo_dir/ver-bump.sh"

  F_TEMPS=()
  TEST_F_VER=
  TEST_F_INPUT=
  CLEANUP_CMDS=()
}

teardown() {
  run_cleanup_cmds

  unset F_TEMPS
  unset TEST_F_VER
  unset TEST_V_PREV
  unset TEST_F_INPUT
  unset VER_FILE
  unset CLEANUP_CMDS
}

run_cleanup_cmds() {
  for F in "${F_TEMPS[@]}"; do
    [ -f $F ] && rm -f $F && git reset -- $F >&2
  done

  for (( i = 0; i < ${#CLEANUP_CMDS[@]} ; i++ )); do
    # Run each command in array
    eval "${CLEANUP_CMDS[$i]}"
  done
}

get_help_msg() {
  ${profile_script} -h | grep "This script automates"
}

create_ver_file() {
  F_TEMPS+=($(mktemp ${repo_dir}/XXXXXXXXXXXXXXXXXXXX)) # push
  F_TMP=${F_TEMPS[${#F_TEMPS[@]}-1]} # last pushed
  printf "{ \n\"version\": \"${V_TEST}\"\n }" > $F_TMP
  VER_FILE=$F_TMP # set value used in test target
}

jsonfile_get_ver() {
  sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $1
}

# Make a throwaway git repo under /tmp and echo its path. Adds cleanup.
# Initial state: one empty commit on the default branch. No tags.
scratch_repo() {
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  (
    cd "$dir" || exit 1
    git init -q -b main 2>/dev/null || git init -q
    git config user.email "test@example.com"
    git config user.name  "Test User"
    git commit --allow-empty -qm "initial"
  )
  echo "$dir"
}

# Tests #####################################################################

@test "can run script" {
  source ${profile_script}
}

@test "process-arguments: -h: display help message" {
  run get_help_msg
  assert_success
  assert_output --partial "This script automates bumping the git software project's version automatically."
}

@test "process-arguments: -v: fail when not supplying version" {
  source ${profile_script}
  run process-arguments -v
  assert_failure 1 --partial "Option -v requires an argument."
}

@test "process-arguments: -v x.x.x: succeed when supplying version" {
  local TEST_VER="9.8.7"
  source ${profile_script}
  process-arguments -v "${TEST_VER}"
  # assert_success
  assert_equal "${V_USR_SUPPLIED}" "${TEST_VER}"
}

@test "process-arguments: -v: rejects non-SemVer version" {
  source ${profile_script}
  run process-arguments -v "banana"
  assert_failure
  assert_output --partial "'banana' is not a valid SemVer 2.0 version"
}

@test "process-arguments: -v: accepts SemVer prerelease and build metadata" {
  source ${profile_script}
  process-arguments -v "1.2.3-rc.1+build.42"
  assert_equal "${V_USR_SUPPLIED}" "1.2.3-rc.1+build.42"
}

@test "process-arguments: -d: sets dry-run flag" {
  source ${profile_script}
  process-arguments -d
  assert_equal "${FLAG_DRYRUN}" "true"
}

@test "process-arguments: -t <prefix>: overrides tag prefix" {
  source ${profile_script}
  process-arguments -t "release/"
  assert_equal "${TAG_PREFIX}" "release/"
}

@test "process-arguments: -B <prefix>: overrides branch prefix" {
  source ${profile_script}
  process-arguments -B "hotfix-"
  assert_equal "${REL_PREFIX}" "hotfix-"
}

@test "long options: --version, --message, --file accept space-separated value" {
  source ${profile_script}
  process-arguments --version 1.2.3 --message "hello world" --file a.json --file b.json
  assert_equal "${V_USR_SUPPLIED}" "1.2.3"
  assert_equal "${REL_NOTE}" "hello world"
  assert_equal "${JSON_FILES[0]}" "a.json"
  assert_equal "${JSON_FILES[1]}" "b.json"
}

@test "long options: --name=value form" {
  source ${profile_script}
  process-arguments --version=9.8.7 --tag-prefix=release/ --branch-prefix=hotfix-
  assert_equal "${V_USR_SUPPLIED}" "9.8.7"
  assert_equal "${TAG_PREFIX}" "release/"
  assert_equal "${REL_PREFIX}" "hotfix-"
}

@test "long options: boolean flags set corresponding globals" {
  source ${profile_script}
  process-arguments --dry-run --no-commit --no-branch --no-changelog --pause-changelog
  assert_equal "${FLAG_DRYRUN}" "true"
  assert_equal "${FLAG_NOCOMMIT}" "true"
  assert_equal "${FLAG_NOBRANCH}" "true"
  assert_equal "${FLAG_NOCHANGELOG}" "true"
  assert_equal "${FLAG_CHANGELOG_PAUSE}" "true"
}

@test "long options: --push <remote> sets push flag + dest" {
  source ${profile_script}
  process-arguments --push upstream
  assert_equal "${FLAG_PUSH}" "true"
  assert_equal "${PUSH_DEST}" "upstream"
}

@test "long options: rejects unknown long option" {
  source ${profile_script}
  run process-arguments --bogus
  assert_failure
  assert_output --partial "Invalid option: --bogus"
}

@test "long options: rejects missing value for long option" {
  source ${profile_script}
  run process-arguments --version
  assert_failure
  assert_output --partial "Option --version requires an argument"
}

@test "long options: rejects value given to boolean long option" {
  source ${profile_script}
  run process-arguments --dry-run=yes
  assert_failure
  assert_output --partial "Option --dry-run doesn't take a value"
}

@test "long options: short and long forms can be mixed" {
  source ${profile_script}
  process-arguments -v 1.2.3 --dry-run -f a.json --file=b.json
  assert_equal "${V_USR_SUPPLIED}" "1.2.3"
  assert_equal "${FLAG_DRYRUN}" "true"
  assert_equal "${JSON_FILES[0]}" "a.json"
  assert_equal "${JSON_FILES[1]}" "b.json"
}

@test "completions: --completions bash emits a parseable script" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial "complete -F _ver_bump ver-bump"
  # Script must be syntactically valid bash
  tmp=$(mktemp)
  echo "$output" > "$tmp"
  bash -n "$tmp"
  rm -f "$tmp"
}

@test "completions: --completions zsh emits a #compdef script" {
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial "#compdef ver-bump"
  assert_output --partial "_arguments"
}

@test "completions: --completions fish emits complete commands" {
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial "complete -c"
  assert_output --partial "-l tag-prefix"
}

@test "completions: --completions=<shell> form works" {
  run ${profile_script} --completions=zsh
  assert_success
  assert_output --partial "#compdef ver-bump"
}

@test "completions: unknown shell exits non-zero" {
  run ${profile_script} --completions powershell
  assert_failure
  assert_output --partial "Unknown shell: powershell"
}

@test "completions: no shell argument prints usage hint" {
  run ${profile_script} --completions
  assert_success
  assert_output --partial "Usage: ver-bump --completions"
}

@test "is_semver: accepts and rejects per spec" {
  source ${profile_script}
  is_semver "1.2.3"            || return 1
  is_semver "0.0.0"            || return 1
  is_semver "1.2.3-alpha"      || return 1
  is_semver "1.2.3-alpha.1"    || return 1
  is_semver "1.2.3+build"      || return 1
  is_semver "1.2.3-rc.1+sha.2" || return 1

  ! is_semver ""        || return 1
  ! is_semver "1.2"     || return 1
  ! is_semver "1.2.3.4" || return 1
  ! is_semver "v1.2.3"  || return 1
  ! is_semver "1.2.a"   || return 1
  ! is_semver "01.2.3"  || return 1
}

@test "process-arguments: -m: fail when not supplying release note" {
  source ${profile_script}
  run process-arguments -m
  assert_failure 1 --partial "Option -m requires an argument."
}

@test "process-arguments: -m <note>: succeed when supplying release note" {
  local TEST_MSG="This is a custom release note"
  source ${profile_script}
  process-arguments -m "${TEST_MSG}"
  assert_equal "${REL_NOTE}" "${TEST_MSG}"
}

@test "process-arguments: -f: fail when not supplying filenames" {
  source ${profile_script}
  run process-arguments -f
  assert_failure 1 --partial "Option -f requires an argument."
}

@test "process-arguments: -f <filename.json>: succeed with multiple filenames" {
  local TEST_FILENAMES=("test1.json" "test2.json" "test3.json")
  source ${profile_script}
  process-arguments -f "${TEST_FILENAMES[0]}" -f "${TEST_FILENAMES[1]}" -f "${TEST_FILENAMES[2]}"
  assert_equal "${JSON_FILES[0]}" "${TEST_FILENAMES[0]}"
  assert_equal "${JSON_FILES[1]}" "${TEST_FILENAMES[1]}"
  assert_equal "${JSON_FILES[2]}" "${TEST_FILENAMES[2]}"

  # Test info messages
  JSON_FILES=()
  run process-arguments -f "${TEST_FILENAMES[0]}" -f "${TEST_FILENAMES[1]}" -f "${TEST_FILENAMES[2]}"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[0]}>"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[1]}>"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[2]}>"
}

@test "process-arguments: -p: fail when not supplying push destination" {
  source ${profile_script}
  run process-arguments -p
  assert_failure 1 --partial "Option -p requires an argument."
}

@test "process-arguments: -p <repo destination>: succeed when supplying a destination" {
  local TEST_DEST="other-origin"
  source ${profile_script}
  process-arguments -p "${TEST_DEST}"
  assert_equal "${PUSH_DEST}" "${TEST_DEST}"
  assert_equal "${FLAG_PUSH}" "true"

  run process-arguments -p "${TEST_DEST}"
  assert_output --partial "Option set: Pushing to <${PUSH_DEST}>, as the last action in this script."
}

@test "process-arguments: -n: set flag to prevent committing at the end" {
  source ${profile_script}
  process-arguments -n
  assert_equal "${FLAG_NOCOMMIT}" "true"

  run process-arguments -n
  assert_output --partial "Disable commit (and tag + push) after bumping files."
}

@test "process-arguments: -b: set flag to disable creating a release branch" {
  source ${profile_script}
  process-arguments -b
  assert_equal "${FLAG_NOBRANCH}" "true"

  run process-arguments -b
  assert_output --partial "Disable creating a new release-x.x.x branch."
}

@test "process-arguments: -c: set flag to disable creating/updating CHANGELOG.md" {
  source ${profile_script}
  process-arguments -c
  assert_equal "${FLAG_NOCHANGELOG}" "true"

  run process-arguments -c
  assert_output --partial "Option set: Disable updating CHANGELOG.md"
}

@test "process-arguments: -l: set flag to enable pausing after CHANGELOG.md is created" {
  source ${profile_script}
  process-arguments -l
  assert_equal "${FLAG_CHANGELOG_PAUSE}" "true"

  run process-arguments -l
  assert_output --partial "Option set: Pause enabled for amending CHANGELOG.md"
}

@test "process-arguments: fail on not-existing argument" {
  local TEST_OPT="-X"
  source ${profile_script}
  run process-arguments "${TEST_OPT}"
  assert_failure 1 --partial "Invalid option: -${TEST_OPT}"
}

@test "set-v-suggest: increments version" {
  source ${profile_script}

  set-v-suggest "35.12.5" || return 1
  assert_equal "${V_SUGGEST}" "35.12.6"
}

@test "bump-prerelease: bumps trailing numeric counter" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '4.0.0-dev.6')" "4.0.0-dev.7"
  assert_equal "$(bump-prerelease '4.0.0-rc.9')" "4.0.0-rc.10"
  assert_equal "$(bump-prerelease '1.2.3-beta.0')" "1.2.3-beta.1"
}

@test "bump-prerelease: appends .1 when no numeric counter" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '1.0.0-alpha')" "1.0.0-alpha.1"
  assert_equal "$(bump-prerelease '1.0.0-dev')"   "1.0.0-dev.1"
}

@test "bump-prerelease: preserves build metadata" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '2.1.0-beta.3+build.sha')" "2.1.0-beta.4+build.sha"
  assert_equal "$(bump-prerelease '1.0.0-rc.1+exp.sha.5114f85')" "1.0.0-rc.2+exp.sha.5114f85"
}

@test "set-v-suggest: bumps prerelease counter instead of patch" {
  source ${profile_script}
  set-v-suggest "4.0.0-dev.6"
  assert_equal "${V_SUGGEST}" "4.0.0-dev.7"

  set-v-suggest "1.0.0-alpha"
  assert_equal "${V_SUGGEST}" "1.0.0-alpha.1"
}

@test "set-v-suggest: fails to increments non SemVer version" {
  source ${profile_script}

  TEST_V_GOOD="35.12.5"
  TEST_V_GOOD_INC="35.12.6"
  TEST_V_BAD="35.12.thiswontincrement"

  set-v-suggest "${TEST_V_GOOD}" || return 1
  assert_equal "${V_SUGGEST}" "${TEST_V_GOOD_INC}"

  set-v-suggest "${TEST_V_BAD}" || return 1
  assert_equal "${V_SUGGEST}" "${TEST_V_BAD}"

  run set-v-suggest "${TEST_V_BAD}" || return 1
  assert_output --partial "Warning: ${TEST_V_BAD} doesn't look like a SemVer compatible version"
}

@test "process-version: fail on entering non-SemVer input" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_TEST_INPUT="12.wrong.1"
  create_ver_file

  run process-version <<< "$V_TEST_INPUT"
  assert_failure
  assert_output --partial "'${V_TEST_INPUT}' is not a valid SemVer 2.0 version"
}

@test "process-version: patch of the version from json file should be bumped +1" {
  source ${profile_script}

  V_TEST="35.12.5"
  create_ver_file

  process-version <<< "" || return 1
  assert_equal "${V_PREV}" "${V_TEST}"
  assert_equal "${V_NEW}" "35.12.6"
}

@test "do-packagefile-bump: can bump version in package.json + lock file" {
  source ${profile_script}

  local pkg="${repo_dir}/package.json"
  local pkg_lock="${repo_dir}/package-lock.json"

  # backup actual files, as this test will change them
  yes | cp $pkg "${pkg}.backup"
  yes | cp $pkg_lock "${pkg_lock}.backup"
  # add restore file cmds for post-test cleanup
  CLEANUP_CMDS+=("rm ${pkg} ${pkg_lock}")
  CLEANUP_CMDS+=("mv -f ${pkg}.backup ${pkg}")
  CLEANUP_CMDS+=("mv -f ${pkg_lock}.backup ${pkg_lock}")
  CLEANUP_CMDS+=("git reset -- ${pkg}")
  CLEANUP_CMDS+=("git reset -- ${pkg_lock}")

  V_NEW="35.12.23"
  run do-packagefile-bump
  assert_output -p "Bumped version in <package.json> and <package-lock.json>"

  run jsonfile_get_ver $pkg
  assert_output "${V_NEW}"
}

@test "bump-json-files: can bump version in a json file" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.78"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output -p "from ${V_TEST} -> ${V_NEW}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_NEW}"
}

@test "bump-json-files: can fail bumping a json file when a version already exists in file" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output --partial "already contains version ${V_TEST}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_TEST}"
}

@test "bump-json-files: can fail bumping a json file when no version found inside it" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  > $VER_FILE <<< "" # clear file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output --partial "a version name/value pair was not found to replace!"
}

@test "check-branch-notexist: can detect branch DOES exist" {
  source ${profile_script}

  local V_NEW="123.456.7"
  # create test branch
  git branch "${REL_PREFIX}${V_NEW}"
  CLEANUP_CMDS+=("git branch -D ${REL_PREFIX}${V_NEW} --force")

  run check-branch-notexist
  assert_failure
}

@test "check-branch-notexist: can confirm branch DOES'NT exist" {
  source ${profile_script}

  local V_NEW="123.456.78338834"

  run check-branch-notexist
  assert_success
}

@test "do-branch: can create a release branch" {
  source ${profile_script}

  local V_NEW="123.456.7"
  local CURR_BRANCH=$( git rev-parse --abbrev-ref HEAD )
  CLEANUP_CMDS+=("git checkout ${CURR_BRANCH} && git branch -D ${REL_PREFIX}${V_NEW} --force")

  run do-branch
  assert_success
}

@test "do-tag: create a tag" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  run do-tag
  assert_success --partial "Added GIT tag"
}

@test "check-tag-exists: check doesn't exist" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=

  run check-tag-exists
  assert_success
}

@test "check-tag-exists: check it exists" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  # run do-tag
  git tag -a v${V_NEW} -m "Test tag"

  run check-tag-exists
  assert_output --partial "Error: A release with that tag"
}

@test "do-changelog: can create a CHANGELOG.md" {
  source ${profile_script}

  V_PREV="0.1.0" # guaranteed: commits available
  V_NEW="1.0.0"
  local F_CL="CHANGELOG.md"

  # backup present
  [ -f "$F_CL" ] && mv "$F_CL" "${F_CL}.backup" && touch "$F_CL"
  CLEANUP_CMDS+=("rm ${F_CL} && mv ${F_CL}.backup ${F_CL}")

  run do-changelog <<< ""
  assert_success
  assert_output -p "Updated [CHANGELOG.md] file"

  # Test CL.md actually contains the line
  grep -F "updated ${F_CL}, bumped ${V_PREV} -> ${V_NEW}" $F_CL
  assert_success
}

# suggest-bump-level ##########################################################

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

# Dry-run behavior ############################################################

@test "dry-run: do-packagefile-bump does not modify package.json" {
  source ${profile_script}
  cd "$(scratch_repo)"
  echo '{"version":"1.0.0"}' > package.json
  git add package.json && git commit -qm "add pkg"

  FLAG_DRYRUN=true
  V_PREV="1.0.0"
  V_NEW="2.0.0"

  run do-packagefile-bump
  assert_success
  assert_output --partial "[dry-run]"

  # File content must still be the original 1.0.0
  run jq -r '.version' package.json
  assert_output "1.0.0"
}

@test "dry-run: do-commit does not create a commit" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_PREV="1.0.0"
  V_NEW="1.0.1"
  GIT_MSG="test, "

  local commits_before
  commits_before=$(git rev-list --count HEAD)

  run do-commit
  assert_success
  assert_output --partial "[dry-run]"

  assert_equal "$(git rev-list --count HEAD)" "$commits_before"
}

@test "dry-run: do-tag does not create a tag" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_NEW="1.0.0"
  REL_NOTE=

  run do-tag
  assert_success
  assert_output --partial "[dry-run]"

  # No tags should exist
  run git tag -l
  assert_output ""
}

@test "dry-run: do-changelog does not write CHANGELOG.md" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_PREV="0.0.0"
  V_NEW="1.0.0"

  [ ! -f CHANGELOG.md ] || return 1
  run do-changelog
  assert_success
  assert_output --partial "[dry-run]"
  [ ! -f CHANGELOG.md ]
}

# Prefix overrides end-to-end #################################################

@test "prefix override: do-tag uses TAG_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  V_NEW="1.2.3"
  REL_NOTE=

  run do-tag
  assert_success

  run git tag -l
  assert_output "rel/1.2.3"
}

@test "prefix override: check-tag-exists uses TAG_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  V_NEW="1.2.3"
  git tag -a "rel/1.2.3" -m "tag"

  run check-tag-exists
  assert_output --partial "A release with that tag"
}

@test "prefix override: do-branch uses REL_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  REL_PREFIX="hotfix-"
  V_NEW="9.9.9"

  run do-branch
  assert_success

  run git rev-parse --abbrev-ref HEAD
  assert_output "hotfix-9.9.9"
}

@test "prefix override: do-changelog uses TAG_PREFIX when finding previous tag" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  git tag -a "rel/0.1.0" -m "tag"
  git commit --allow-empty -qm "feat: after previous tag"

  V_PREV="0.1.0"
  V_NEW="0.2.0"

  run do-changelog <<< ""
  assert_success
  assert_output --partial "Created [CHANGELOG.md] file"
  grep -F "feat: after previous tag" CHANGELOG.md
}

# Global leakage regression ###################################################

@test "bump-json-files: does not stomp global V_PREV (needed by do-changelog)" {
  source ${profile_script}
  V_TEST="99.88.77"
  V_NEW="99.88.78"
  V_PREV="outer-sentinel"  # simulate the global set earlier in main()

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )
  bump-json-files >/dev/null

  assert_equal "${V_PREV}" "outer-sentinel"
}

