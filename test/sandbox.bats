#!/usr/bin/env bats

# dev/sandbox.sh — the contributor sandbox (R-DEV-1..3).
#
# R-DEV-1  creates an isolated throwaway git repo, runs ver-bump inside it,
#          and cleans it up on exit — including on signals.
# R-DEV-2  cleanup must never fire against the host repo.
# R-DEV-3  SANDBOX_VERSION / SANDBOX_COMMITS customise the start state;
#          --keep / -k preserves the temp dir.
#
# ver-bump itself is driven non-interactively: either --dry-run with -p (so
# do-push auto-confirms and short-circuits), or a live run whose declined
# push exits 5 by design (same recipe as e2e-live.bats).

load 'test_helper'

# Path to the script under test (repo_dir is set by the shared setup()).
sandbox_script() {
  echo "${repo_dir}/dev/sandbox.sh"
}

# Extract the sandbox temp dir from a captured run's $output. The script
# announces it as the first "sandbox: /path" status line on stderr.
sandbox_dir_from_output() {
  printf '%s\n' "$output" | sed -n 's/^sandbox: \(\/.*\)$/\1/p' | head -n 1
}

# ── R-DEV-1: isolation, ver-bump execution, cleanup on exit ─────────────────

@test "sandbox: runs ver-bump in a throwaway repo and wipes it on exit" {
  cd "$(scratch_repo)"

  run "$(sandbox_script)" -v 0.2.0 --dry-run -p origin
  strip_ansi_output
  assert_success

  # ver-bump really ran, against the sandbox's seeded 0.1.0 package.json
  assert_output --partial "Bumped 0.1.0 -> 0.2.0"

  # sandbox announced its temp dir ...
  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]

  # ... which lives outside the host checkout ...
  case "$dir" in
    "${repo_dir}"*) bats_fail "sandbox dir ${dir} is inside the host repo" ;;
  esac

  # ... and was wiped by the EXIT trap
  [ ! -d "$dir" ]
}

@test "sandbox: cleanup still fires when ver-bump fails (exit code propagates)" {
  cd "$(scratch_repo)"

  # Invalid SemVer makes ver-bump fail 2; set -e aborts the sandbox and the
  # trap must still remove the temp dir while preserving the exit code.
  run "$(sandbox_script)" -v not-semver
  assert_failure 2

  strip_ansi_output
  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]
  [ ! -d "$dir" ]
}

@test "sandbox: SIGTERM mid-run (Ctrl-C analogue) removes the temp dir" {
  local work fifo out pid child dir i
  work="$(mktemp -d)"
  CLEANUP_CMDS+=("rm -rf '${work}'")
  fifo="${work}/stdin.fifo"
  out="${work}/out.log"
  mkfifo "$fifo"

  # No -v: ver-bump blocks on its version prompt, reading the held-open
  # fifo — a stable "mid-run" state to signal.
  "$(sandbox_script)" < "$fifo" > "$out" 2>&1 &
  pid=$!
  exec 9>"$fifo" # hold the writer open so ver-bump's read blocks

  # Wait until the sandbox has handed off to ver-bump ("---" marker).
  for ((i = 0; i < 100; i++)); do
    grep -q -- '---' "$out" 2>/dev/null && break
    sleep 0.1
  done
  grep -q -- '---' "$out" || { exec 9>&-; bats_fail "sandbox never reached ver-bump (out: $(cat "$out"))"; }

  dir="$(sed -n 's/^sandbox: \(\/.*\)$/\1/p' "$out" | head -n 1)"
  [ -n "$dir" ]
  [ -d "$dir" ]
  CLEANUP_CMDS+=("rm -rf '${dir}'")

  # Ctrl-C sends the signal to the whole foreground process group; from a
  # test we reproduce that by signalling the sandbox AND its ver-bump child
  # (bash defers traps until the foreground child exits).
  child="$(pgrep -P "$pid" | head -n 1)"
  kill -TERM "$pid" 2>/dev/null
  [ -n "$child" ] && kill -TERM "$child" 2>/dev/null

  local rc=0
  wait "$pid" || rc=$?
  exec 9>&-
  assert_equal "$rc" 143 # 128 + SIGTERM

  # The INT/TERM trap must have removed the sandbox dir.
  for ((i = 0; i < 50; i++)); do
    [ ! -d "$dir" ] && break
    sleep 0.1
  done
  [ ! -d "$dir" ]
}

# ── R-DEV-2: the host repo is never touched ─────────────────────────────────

@test "sandbox: cleanup never fires against the host repo" {
  # Deliberately run from inside the host checkout — the hazardous cwd.
  cd "$repo_dir"

  local head_before status_before ver_before
  head_before="$(git rev-parse HEAD)"
  status_before="$(git status --porcelain)"
  ver_before="$(jsonfile_get_ver "${repo_dir}/package.json")"

  # One successful run and one aborted run — the trap fires in both.
  run "$(sandbox_script)" -v 0.2.0 --dry-run -p origin
  assert_success
  strip_ansi_output
  local dir
  dir="$(sandbox_dir_from_output)"
  case "$dir" in
    ""|"${repo_dir}"*) bats_fail "sandbox dir '${dir}' is missing or inside the host repo" ;;
  esac

  run "$(sandbox_script)" -v not-semver
  assert_failure 2

  # Host checkout is bit-for-bit undisturbed.
  [ -d "${repo_dir}/.git" ] || [ -f "${repo_dir}/.git" ] # worktrees use a .git file
  assert_equal "$(git rev-parse HEAD)" "$head_before"
  assert_equal "$(git status --porcelain)" "$status_before"
  assert_equal "$(jsonfile_get_ver "${repo_dir}/package.json")" "$ver_before"
}

@test "sandbox: live bump lands in the sandbox repo, not the host" {
  cd "$(scratch_repo)"

  # Live (non-dry-run) bump; the declined push is the documented exit-5
  # user-abort (same recipe as e2e-live.bats), but branch + tag + file bump
  # have already happened — inside the sandbox thanks to --keep.
  # Script path passed as a positional so bash -c never re-parses it.
  run bash -c 'printf "n\n" | "$1" --keep -v 9.9.9' _ "$(sandbox_script)"
  assert_failure 5

  strip_ansi_output
  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]
  CLEANUP_CMDS+=("rm -rf '${dir}'")
  [ -d "$dir" ]

  # The bump happened in the sandbox repo ...
  run git -C "$dir" tag -l v9.9.9
  assert_output "v9.9.9"
  assert_equal "$(jsonfile_get_ver "${dir}/package.json")" "9.9.9"

  # ... and the sandbox repo is its own toplevel (a real isolated repo,
  # not nested inside the host checkout).
  assert_equal "$(git -C "$dir" rev-parse --show-toplevel)" "$(cd "$dir" && pwd -P)"

  # The host repo saw none of it.
  run git -C "$repo_dir" tag -l v9.9.9
  assert_output ""
}

# ── R-DEV-3: SANDBOX_VERSION / SANDBOX_COMMITS / --keep ─────────────────────

@test "sandbox: SANDBOX_VERSION sets the seeded version and tag; --keep preserves the dir" {
  cd "$(scratch_repo)"

  SANDBOX_VERSION=3.2.1 run "$(sandbox_script)" --keep -v 3.3.0 --dry-run -p origin
  strip_ansi_output
  assert_success
  assert_output --partial "Bumped 3.2.1 -> 3.3.0"
  assert_output --partial "(--keep)"

  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]
  CLEANUP_CMDS+=("rm -rf '${dir}'")

  # --keep preserved the sandbox ...
  [ -d "$dir" ]

  # ... seeded at the requested version, tag included (dry-run left it as-is)
  assert_equal "$(jsonfile_get_ver "${dir}/package.json")" "3.2.1"
  run git -C "$dir" tag -l v3.2.1
  assert_output "v3.2.1"
}

@test "sandbox: SANDBOX_COMMITS overrides the default seed commits (-k alias)" {
  cd "$(scratch_repo)"

  SANDBOX_COMMITS='feat: custom alpha; fix: custom beta' \
    run "$(sandbox_script)" -k -v 0.2.0 --dry-run -p origin
  strip_ansi_output
  assert_success

  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]
  CLEANUP_CMDS+=("rm -rf '${dir}'")
  [ -d "$dir" ]

  # Custom seeds present, default seeds absent, count = initial + 2.
  run git -C "$dir" log --format=%s
  assert_output --partial "feat: custom alpha"
  assert_output --partial "fix: custom beta"
  refute_output --partial "add shiny new thing"
  assert_equal "$(git -C "$dir" rev-list --count HEAD)" 3
}

@test "sandbox: without --keep the temp dir is gone after a successful run" {
  cd "$(scratch_repo)"

  run "$(sandbox_script)" -v 0.2.0 --dry-run -p origin
  assert_success
  strip_ansi_output
  refute_output --partial "(--keep)"

  local dir
  dir="$(sandbox_dir_from_output)"
  [ -n "$dir" ]
  [ ! -d "$dir" ]
}
