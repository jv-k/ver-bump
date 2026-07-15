#!/usr/bin/env bats

# Multi-format bump targets (R-TGT) — lib/textbump.sh. Text-pattern and
# structured-@path locators via --bump / BUMP_FILES. Shared setup lives in
# test/test_helper.bash. Every test runs inside a fresh scratch_repo.

load 'test_helper'

# --- Text pattern locator (R-TGT-2) -----------------------------------------

@test "bump-target-files: text pattern rewrites only the matching line" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf 'package main\n\nconst Version = "1.2.3"\nvar other = "version 9.9.9"\n' > main.go

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'main.go:Version = "{{version}}"' )

  run bump-target-files
  strip_ansi_output
  assert_success
  assert_output --partial "Updated <main.go>: 1.2.3 → 1.2.4 (1×)."

  run cat main.go
  assert_line 'const Version = "1.2.4"'
  # The unrelated line that also contains the word "version" is untouched.
  assert_line 'var other = "version 9.9.9"'
}

@test "bump-target-files: text pattern preserves CRLF + missing final newline byte-for-byte" {
  source ${profile_script}
  cd "$(scratch_repo)"

  # No trailing newline on the last line; CRLF endings throughout.
  printf 'a\r\nVERSION = "1.2.3"\r\nb' > ver.cfg
  printf 'a\r\nVERSION = "1.2.4"\r\nb' > expected.cfg

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'ver.cfg:VERSION = "{{version}}"' )

  run bump-target-files
  assert_success

  run diff ver.cfg expected.cfg
  assert_success
}

@test "bump-target-files: zero-match text pattern logs an error naming the search" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf 'const Version = "9.9.9"\n' > main.go   # current version is not V_PREV

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'main.go:Version = "{{version}}"' )

  run bump-target-files
  strip_ansi_output
  assert_output --partial 'no line matching'
  assert_output --partial 'Version = "1.2.3"'
  # File left untouched.
  run cat main.go
  assert_output 'const Version = "9.9.9"'
}

@test "bump-target-files: text target already at new version warns and skips" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf 'const Version = "1.2.4"\n' > main.go   # already at V_NEW

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'main.go:Version = "{{version}}"' )

  run bump-target-files
  strip_ansi_output
  assert_output --partial "already contains version 1.2.4"
}

# --- Structured @path locator (R-TGT-3) -------------------------------------

@test "bump-target-files: JSON @path bumps a nested version (improved jq bump)" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "name": "x",\n  "tool": { "version": "1.2.3" }\n}\n' > nested.json

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'nested.json:@tool.version' )

  run bump-target-files
  strip_ansi_output
  assert_success
  assert_output --partial "Updated <nested.json>"
  assert_output --partial "at @tool.version"

  run jq -r '.tool.version' nested.json
  assert_output "1.2.4"
}

@test "bump-target-files: bare JSON file uses surgical top-level .version rewrite" {
  source ${profile_script}
  cd "$(scratch_repo)"

  # 4-space indent + tab elsewhere: json_set_version must preserve it.
  printf '{\n    "version": "1.2.3",\n    "keep": "me"\n}\n' > app.json

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'app.json' )

  run bump-target-files
  assert_success

  run cat app.json
  assert_line '    "version": "1.2.4",'   # 4-space indent preserved
  assert_line '    "keep": "me"'
}

@test "bump-target-files: structured target already at new version warns and skips" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{ "tool": { "version": "1.2.4" } }\n' > nested.json

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'nested.json:@tool.version' )

  run bump-target-files
  strip_ansi_output
  assert_output --partial "already contains version 1.2.4"
}

# --- Dry-run (R-TGT-7) ------------------------------------------------------

@test "bump-target-files: dry-run previews to stderr and touches nothing" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf 'const Version = "1.2.3"\n' > main.go
  cp main.go before.snapshot

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=true; GIT_MSG=""
  BUMP_TARGETS=( 'main.go:Version = "{{version}}"' )

  run bump-target-files
  strip_ansi_output
  assert_success
  assert_output --partial "[dry-run] would replace"
  assert_output --partial "Version = \"1.2.3\""
  assert_output --partial "Version = \"1.2.4\""

  run diff main.go before.snapshot
  assert_success
}

# --- Missing / unreadable file (R-TGT-8) ------------------------------------

@test "bump-target-files: missing file warns and skips" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_TARGETS=( 'nope.go:Version = "{{version}}"' )

  run bump-target-files
  strip_ansi_output
  assert_success
  assert_output --partial "<nope.go> not found"
}

# --- Grammar validation (R-TGT-1/2) -----------------------------------------

@test "_bt-parse-spec: text pattern without {{version}} is a usage error (exit 2)" {
  source ${profile_script}

  run _bt-parse-spec 'main.go:Version = "x"'
  assert_failure 2
  strip_ansi_output
  assert_output --partial "does not contain the {{version}} placeholder"
}

@test "_bt-parse-spec: bare non-structured file is a usage error (exit 2)" {
  source ${profile_script}

  run _bt-parse-spec 'Dockerfile'
  assert_failure 2
  strip_ansi_output
  assert_output --partial "can't infer where the version lives"
}

@test "_bt-parse-spec: @path on a text file is a usage error (exit 2)" {
  source ${profile_script}

  run _bt-parse-spec 'main.go:@version'
  assert_failure 2
  strip_ansi_output
  assert_output --partial "structured @path needs a JSON, TOML, or YAML file"
}

# --- Conditional dependency (R-TGT-4) ---------------------------------------

@test "check-bump-deps: TOML @path without tomlq exits 3 with a dual hint" {
  command -v tomlq >/dev/null 2>&1 && skip "tomlq is installed — the missing-helper path can't be exercised"
  source ${profile_script}

  BUMP_FILES=""
  BUMP_TARGETS=( 'pyproject.toml:@project.version' )

  run check-bump-deps
  assert_failure 3
  strip_ansi_output
  assert_output --partial "needs 'tomlq'"
  assert_output --partial "text pattern instead"
}

# --- Accumulation: BUMP_FILES (config) + --bump (CLI) (R-TGT-1) --------------

@test "bump-target-files: BUMP_FILES config and --bump CLI both apply" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf 'const Version = "1.2.3"\n' > main.go
  printf 'version: 1.2.3\n' > Chart.yaml

  V_PREV="1.2.3"; V_NEW="1.2.4"; FLAG_DRYRUN=false; GIT_MSG=""
  BUMP_FILES=$'main.go:Version = "{{version}}"'
  BUMP_TARGETS=( 'Chart.yaml:version: {{version}}' )

  run bump-target-files
  strip_ansi_output
  assert_success
  assert_output --partial "Updated <main.go>"
  assert_output --partial "Updated <Chart.yaml>"

  run grep -c '1.2.4' main.go
  assert_output "1"
  run cat Chart.yaml
  assert_output "version: 1.2.4"
}

# --- End-to-end via the script (R-TGT-9 staging + commit message) -----------

@test "--bump end-to-end (dry-run) reports the target in the plan" {
  local repo; repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "0.9.0" }\n' > package.json
  printf 'const Version = "0.9.0"\n' > main.go
  git add -A; git commit -qm "feat: seed"; git tag v0.9.0
  printf 'x\n' > f.txt; git add f.txt; git commit -qm "fix: change"

  run ${profile_script} -d -c -y -p origin -v 1.0.1 --bump 'main.go:Version = "{{version}}"'
  strip_ansi_output
  assert_success
  assert_output --partial 'would replace'
  assert_output --partial 'Version = "0.9.0"'
  assert_output --partial 'Version = "1.0.1"'
}
