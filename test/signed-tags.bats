#!/usr/bin/env bats

# Signed release tags (R-SIGN-1..4, #68): --sign / TAG_SIGN switch do-tag
# from `git tag -a` to `git tag -s`. Git argv is captured with a PATH-stubbed
# `git` so no signing key is needed; the CLI > env > rc > default precedence
# chain is exercised end-to-end via the dry-run preview line (same recipe as
# config-env.bats). One real SSH-key signing round-trip runs where the
# environment can sign, and skips where it can't.

load 'test_helper'

# Drop a fake `git` at the front of PATH that appends its argv to
# <stubdir>/git-args.log and succeeds. Echoes the stub dir; callers prefix
# PATH for the calls under test. scratch_repo setup must run BEFORE the stub
# is on PATH (it needs real git).
make_git_stub() {
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  cat > "${dir}/git" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "${dir}/git-args.log"
exit 0
EOF
  chmod +x "${dir}/git"
  echo "$dir"
}

# Fake `git` whose `tag` subcommand fails like a broken signing setup.
make_failing_git_stub() {
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  cat > "${dir}/git" <<EOF
#!/bin/bash
if [ "\$1" = tag ]; then
  echo "error: gpg failed to sign the data" >&2
  exit 128
fi
exit 0
EOF
  chmod +x "${dir}/git"
  echo "$dir"
}

# ── R-SIGN-1: -s vs -a selection ─────────────────────────────────────────

@test "do-tag: TAG_SIGN=true uses git tag -s, not -a (R-SIGN-1)" {
  source ${profile_script}
  cd "$(scratch_repo)"
  local stub
  stub=$(make_git_stub)

  V_NEW="1.2.3"
  REL_NOTE=
  TAG_SIGN=true

  PATH="${stub}:$PATH" run do-tag
  assert_success

  run cat "${stub}/git-args.log"
  assert_output --partial "tag -s v1.2.3"
  refute_output --partial "tag -a"
}

@test "do-tag: default stays git tag -a (unsigned, R-SIGN-1)" {
  source ${profile_script}
  cd "$(scratch_repo)"
  local stub
  stub=$(make_git_stub)

  V_NEW="1.2.3"
  REL_NOTE=
  unset TAG_SIGN

  PATH="${stub}:$PATH" run do-tag
  assert_success

  run cat "${stub}/git-args.log"
  assert_output --partial "tag -a v1.2.3"
  refute_output --partial "tag -s"
}

# ── R-SIGN-4: composes with -m/--message ─────────────────────────────────

@test "do-tag: --sign composes with a custom -m message (R-SIGN-4)" {
  source ${profile_script}
  cd "$(scratch_repo)"
  local stub
  stub=$(make_git_stub)

  V_NEW="1.2.3"
  REL_NOTE="my custom release note"
  TAG_SIGN=true

  PATH="${stub}:$PATH" run do-tag
  assert_success

  run cat "${stub}/git-args.log"
  assert_output --partial "tag -s v1.2.3 -m my custom release note"
}

# ── R-SIGN-2: signing failure follows the existing tag-failure path ──────

@test "do-tag: signing failure aborts with git's output surfaced (R-SIGN-2)" {
  source ${profile_script}
  cd "$(scratch_repo)"
  local stub
  stub=$(make_failing_git_stub)

  V_NEW="1.2.3"
  REL_NOTE=
  TAG_SIGN=true

  PATH="${stub}:$PATH" run do-tag
  assert_failure 1
  strip_ansi_output
  assert_output --partial "gpg failed to sign the data"
  assert_output --partial "Failed to create git tag v1.2.3"
}

# ── R-SIGN-3: dry-run preview ────────────────────────────────────────────

@test "dry-run: --sign preview prints git tag -s and creates nothing (R-SIGN-3)" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_NEW="1.0.0"
  REL_NOTE=
  TAG_SIGN=true

  run do-tag
  strip_ansi_output
  assert_success
  assert_output --partial "[dry-run]"
  assert_output --partial "git tag -s v1.0.0"

  run git tag -l
  assert_output ""
}

@test "dry-run: preview prints a backslash-containing -m message verbatim" {
  source ${profile_script}
  cd "$(scratch_repo)"

  FLAG_DRYRUN=true
  V_NEW="1.0.0"
  REL_NOTE='note with \n backslash'
  TAG_SIGN=true

  run do-tag
  strip_ansi_output
  assert_success
  # echo -e would have turned \n into a real newline; printf %s must not.
  assert_output --partial "git tag -s v1.0.0 -m 'note with \\n backslash'"
}

# ── R-SIGN-1 precedence (R-CFG-3), end-to-end via the dry-run preview ────

@test "TAG_SIGN=true in .ver-bumprc → signed tag (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'TAG_SIGN=true\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  unset TAG_SIGN
  run ${profile_script} -d -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -s v1.0.1"
}

@test "env TAG_SIGN=false beats .ver-bumprc TAG_SIGN=true (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'TAG_SIGN=true\n' > "$repo/.ver-bumprc"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  TAG_SIGN=false run ${profile_script} -d -c -p origin -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -a v1.0.1"
  refute_output --partial "git tag -s"
}

@test "CLI --sign beats env TAG_SIGN=false (end-to-end)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  TAG_SIGN=false run ${profile_script} -d -c -p origin --sign -v 1.0.1
  strip_ansi_output
  assert_success
  assert_output --partial "git tag -s v1.0.1"
  refute_output --partial "git tag -a"
}

# ── Real signing round-trip (no stub): throwaway SSH key ─────────────────

@test "do-tag: real git tag -s with a throwaway ssh key produces a signed tag" {
  command -v ssh-keygen >/dev/null 2>&1 || skip "ssh-keygen not available"

  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"

  ssh-keygen -t ed25519 -N '' -q -f "$repo/signkey"
  git config gpg.format ssh
  git config user.signingkey "$repo/signkey"

  # Probe: skip (environment, not code) when this git/ssh-keygen pair can't
  # do SSH signing at all (git < 2.34 or OpenSSH without `-Y sign`).
  if ! git tag -s probe -m probe >/dev/null 2>&1; then
    skip "git/ssh-keygen cannot SSH-sign in this environment"
  fi
  git tag -d probe >/dev/null 2>&1

  V_NEW="1.2.3"
  REL_NOTE=
  TAG_SIGN=true

  run do-tag
  assert_success

  run git cat-file tag v1.2.3
  assert_output --partial "BEGIN SSH SIGNATURE"
}
