#!/usr/bin/env ./test/libs/bats/bin/bats

# UNIT TESTS for VER-BUMP 

# Testing everything that could possibly break 🤡

# Note: The RUN helper executes its argument(s) in a subshell, 
# so if writing tests against environmental side-effects like a 
# variable’s value being changed, these changes will not persist 
# after run completes.

profile_script="./ver-bump.sh"

setup() {
  load 'libs/bats-support/load'
  load 'libs/bats-assert/load'
  F_TEMPS=()
  TEST_F_VER=
  TEST_F_INPUT=
  GIT_CLNUP_CMDS=()
}

teardown() {
  for F in "${F_TEMPS[@]}"; do
    [ -f $F ] && rm -f $F
  done
  unset F_TEMPS
  unset TEST_F_VER
  unset TEST_V_PREV
  unset TEST_F_INPUT
  unset VER_FILE
  run_cleanup_cmds
}
        run_cleanup_cmds() {
          for (( i = 0; i < ${#GIT_CLNUP_CMDS[@]} ; i++ )); do
            # Run each command in array 
            eval "${GIT_CLNUP_CMDS[$i]}"
          done  
        }

        get_help_msg() {
          # skip
          ${profile_script} -h | grep "This script automates"
        }

@test "can run script" {
  # skip
  source ${profile_script}
  assert_success
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
  assert_success
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
  assert_success
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
  assert_success
  assert_equal "${JSON_FILES[0]}" "${TEST_FILENAMES[0]}"
  assert_equal "${JSON_FILES[1]}" "${TEST_FILENAMES[1]}"
  assert_equal "${JSON_FILES[2]}" "${TEST_FILENAMES[2]}"
  
  # Test info messages
  JSON_FILES=()
  run process-arguments -f "${TEST_FILENAMES[0]}" -f "${TEST_FILENAMES[1]}" -f "${TEST_FILENAMES[2]}"
  assert_success
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
  assert_success
  assert_equal "${PUSH_DEST}" "${TEST_DEST}"
  assert_equal "${FLAG_PUSH}" "true"

  run process-arguments -p "${TEST_DEST}"
  assert_success
  assert_output --partial "Option set: Pushing to <${PUSH_DEST}>, as the last action in this script."
}

@test "process-arguments: -n: set flag to prevent committing at the end" {
  # skip
  source ${profile_script}
  process-arguments -n
  assert_success
  assert_equal "${FLAG_NOCOMMIT}" "true"

  run process-arguments -n
  assert_success
  assert_output --partial "Option set: Disable commit after tagging."
}

@test "process-arguments: -b: set flag to disable creating a release branch" {
  # skip
  source ${profile_script}
  process-arguments -b
  assert_success
  assert_equal "${FLAG_NOBRANCH}" "true"

  run process-arguments -b
  assert_success
  assert_output --partial "Option set: Disable committing to new branch."

}

@test "process-arguments: -c: set flag to disable creating/updating CHANGELOG.md" {
  # skip
  source ${profile_script}
  process-arguments -c
  assert_success
  assert_equal "${FLAG_NOCHANGELOG}" "true"

  run process-arguments -c
  assert_success
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

      create_ver_file() {
        F_TEMPS+=($(mktemp ./XXXXXXXXXXXXXXXXXXXX)) # push
        F_TMP=${F_TEMPS[${#F_TEMPS[@]}-1]} # last pushed
        echo "\"version\": \"${TEST_V_PREV}\"," > $F_TMP
        VER_FILE=$F_TMP # set value used in test target
      }

@test "process-version: fail on entering non-SemVer input" {
  # skip
  source ${profile_script}
  
  TEST_V_PREV="99.88.77"
  TEST_F_INPUT="12.wrong.1"
  create_ver_file

  # forcing return value because otherwise is_number fires a 'return'
  process-version <<< $TEST_F_INPUT || return 1
  assert_equal "${V_PREV}" "${TEST_V_PREV}"
  assert_equal "${V_USR_INPUT}" "${TEST_F_INPUT}"
}

@test "process-version: patch of the version from json file should be bumped +1" {
  # skip
  source ${profile_script}
  
  TEST_V_PREV="35.12.5"
  create_ver_file
  
  process-version <<< "" || return 1 
  assert_equal "${V_PREV}" "${TEST_V_PREV}" 
  assert_equal "${V_NEW}" "35.12.6" 
}

# @test "check-version: 