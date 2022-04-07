#!/usr/bin/env ./test/bats/bin/bats

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
  echo "\"version\": \"${V_TEST}\"," > $F_TMP
  VER_FILE=$F_TMP # set value used in test target
}

jsonfile_get_ver() {
  echo $( sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $1 )
}

# Tests #####################################################################

@test "can run script" {
  # skip
  source ${profile_script}
}

@test "process-arguments: -h: display help message" {
  # skip
  run get_help_msg
  assert_success
  assert_output --partial "This script automates bumping the git software project's version automatically."
}

@test "process-arguments: -v: fail when not supplying version" {
  # skip
  source ${profile_script}
  run process-arguments -v
  assert_failure 1 --partial "Option -v requires an argument."
}

@test "process-arguments: -v x.x.x: succeed when supplying version" {
  # skip
  local TEST_VER="9.8.7"
  source ${profile_script}
  process-arguments -v "${TEST_VER}"
  # assert_success
  assert_equal "${V_USR_SUPPLIED}" "${TEST_VER}"
}

@test "process-arguments: -m: fail when not supplying release note" {
  # skip
  source ${profile_script}
  run process-arguments -m
  assert_failure 1 --partial "Option -m requires an argument."
}

@test "process-arguments: -m <note>: succeed when supplying release note" {
  # skip
  local TEST_MSG="This is a custom release note"
  source ${profile_script}
  process-arguments -m "${TEST_MSG}"
  assert_equal "${REL_NOTE}" "${TEST_MSG}"
}

@test "process-arguments: -f: fail when not supplying filenames" {
  # skip
  source ${profile_script}
  run process-arguments -f
  assert_failure 1 --partial "Option -f requires an argument."
}

@test "process-arguments: -f <filename.json>: succeed with multiple filenames" {
  # skip
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
  # skip
  source ${profile_script}
  run process-arguments -p
  assert_failure 1 --partial "Option -p requires an argument."
}

@test "process-arguments: -p <repo destination>: succeed when supplying a destination" {
  # skip
  local TEST_DEST="other-origin"
  source ${profile_script}
  process-arguments -p "${TEST_DEST}"
  assert_equal "${PUSH_DEST}" "${TEST_DEST}"
  assert_equal "${FLAG_PUSH}" "true"

  run process-arguments -p "${TEST_DEST}"
  assert_output --partial "Option set: Pushing to <${PUSH_DEST}>, as the last action in this script."
}

@test "process-arguments: -n: set flag to prevent committing at the end" {
  # skip
  source ${profile_script}
  process-arguments -n
  assert_equal "${FLAG_NOCOMMIT}" "true"

  run process-arguments -n
  assert_output --partial "Option set: Disable commit after tagging."
}

@test "process-arguments: -b: set flag to disable creating a release branch" {
  # skip
  source ${profile_script}
  process-arguments -b
  assert_equal "${FLAG_NOBRANCH}" "true"

  run process-arguments -b
  assert_output --partial "Option set: Disable committing to new branch."

}

@test "process-arguments: -c: set flag to disable creating/updating CHANGELOG.md" {
  # skip
  source ${profile_script}
  process-arguments -c
  assert_equal "${FLAG_NOCHANGELOG}" "true"

  run process-arguments -c
  assert_output --partial "Option set: Disable updating CHANGELOG.md file."
}

@test "process-arguments: fail on not-existing argument" {
  # skip
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

@test "set-v-suggest: fails to increments non SemVerversion" {
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
  # skip
  source ${profile_script}
  
  V_TEST="99.88.77"
  V_TEST_INPUT="12.wrong.1"
  create_ver_file

  # forcing return value because otherwise is_number fires a 'return'
  process-version <<< $V_TEST_INPUT || return 1
  assert_equal "${V_PREV}" "${V_TEST}"
  assert_equal "${V_USR_INPUT}" "${V_TEST_INPUT}"
}

@test "process-version: patch of the version from json file should be bumped +1" {
  # skip
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
  assert_output --partial "from ${V_TEST} -> ${V_NEW}"

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

@test "do-tag: create a tag" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  run do-tag
  assert_success --partial "Added GIT tag"
}

@test "check-tag-exists: can create a tag + check it exists" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  git tag -a v${V_NEW} -m "Test tag"

  run check-tag-exists
  assert_success --partial "Error: A release with that tag"
}

@test "do-changelog: can create a CHANGELOG.md" {
  source ${profile_script}
  
  V_PREV="1.2.3"
  V_NEW="1.2.4"
  local F_CL="CHANGELOG.md"

  # backup present 
  [ -f "$F_CL" ] && mv "$F_CL" "${F_CL}.backup" && touch "$F_CL"
  CLEANUP_CMDS+=("rm ${F_CL} && mv ${F_CL}.backup ${F_CL}")

  run do-changelog <<< ""
  assert_success
  assert_output -p "Updated [CHANGELOG.md] file"

  grep -F "Updated ${F_CL}, Bumped ${V_PREV} –> ${V_NEW}" $F_CL
  assert_success
}

