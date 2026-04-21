#!/usr/bin/env bats

# Config file loader (.ver-bumprc) — Task 1.1 of the v2.0 Foundation.
# Covers walk-up discovery, safety (world-writable refusal), and the
# precedence chain CLI > env > file > default. Shared setup lives in
# test/test_helper.bash.

load 'test_helper'

# Helpers ######################################################################

# Clear every CLI-settable config key from the env inside the bats harness
# itself, so our tests can assert "default" paths deterministically. Does NOT
# unset the generic shell-inherited ones (those never are).
_clear_config_env() {
  unset TAG_PREFIX REL_PREFIX PUSH_DEST COMMIT_MSG_PREFIX \
        FLAG_NOBRANCH FLAG_NOCHANGELOG FLAG_CHANGELOG_PAUSE
}

# Absent file ##################################################################

@test "load-config: absent .ver-bumprc is a silent no-op" {
  source ${profile_script}
  cd "$(scratch_repo)"
  _clear_config_env

  run load-config
  assert_success
  refute_output
}

# Discovery ####################################################################

@test "load-config: finds .ver-bumprc at repo root" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  printf 'TAG_PREFIX=x\n' > "$repo/.ver-bumprc"

  load-config
  assert_equal "$TAG_PREFIX" "x"
}

@test "load-config: walks up to find .ver-bumprc in an ancestor directory" {
  source ${profile_script}
  local repo sub
  repo="$(scratch_repo)"
  printf 'TAG_PREFIX=ancestor-v\nREL_PREFIX=ancestor-rel-\n' > "$repo/.ver-bumprc"

  sub="$repo/nested/deeper"
  mkdir -p "$sub"
  cd "$sub"
  _clear_config_env

  load-config
  assert_equal "$TAG_PREFIX" "ancestor-v"
  assert_equal "$REL_PREFIX" "ancestor-rel-"
}

# Precedence ###################################################################

@test "load-config: env wins over file" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"

  _clear_config_env
  printf 'TAG_PREFIX=file-value\n' > "$repo/.ver-bumprc"
  export TAG_PREFIX="env-wins"
  CLEANUP_CMDS+=("unset TAG_PREFIX")

  load-config
  assert_equal "$TAG_PREFIX" "env-wins"
}

@test "apply-config-defaults: file value beats default when neither env nor CLI set it" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  printf 'TAG_PREFIX=T-from-file\n' > "$repo/.ver-bumprc"

  load-config
  apply-config-defaults
  assert_equal "$TAG_PREFIX" "T-from-file"
}

@test "apply-config-defaults: supplies the builtin defaults when nothing sets the keys" {
  source ${profile_script}
  cd "$(scratch_repo)"
  _clear_config_env

  load-config
  apply-config-defaults
  assert_equal "$TAG_PREFIX" "v"
  assert_equal "$REL_PREFIX" "release-"
  assert_equal "$PUSH_DEST" "origin"
  assert_equal "$COMMIT_MSG_PREFIX" "chore: "
}

@test "ver-bump.sh: CLI -t beats .ver-bumprc TAG_PREFIX (end-to-end dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf 'TAG_PREFIX=from-file\n' > "$repo/.ver-bumprc"
  # Need a package.json with a version so process-version is happy
  printf '{ "version": "1.0.0" }\n' > "$repo/package.json"

  # Non-interactive end-to-end dry run: -v avoids the interactive prompt,
  # -d dry-run means nothing is actually written/committed/pushed, -b -c
  # skip branch + changelog so we get past check-branch-notexist. -p origin
  # makes do-push non-interactive. The "git tag -a" dry-run line is what
  # carries TAG_PREFIX and is what we assert against.
  run ${profile_script} -d -b -c -p origin -t y -v 1.0.1
  strip_ansi_output
  assert_success
  # With TAG_PREFIX=y the dry-run tag line should show "y1.0.1", not "from-file1.0.1"
  assert_output --partial "git tag -a y1.0.1"
  refute_output --partial "from-file1.0.1"
}

# Safety #######################################################################

@test "load-config: refuses world-writable .ver-bumprc (exit code 3)" {
  source ${profile_script}
  local repo rc
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  rc="$repo/.ver-bumprc"
  printf 'TAG_PREFIX=unsafe\n' > "$rc"
  # Force-set o+w; use 666 to bypass any umask stripping on macOS.
  chmod 666 "$rc"
  # Sanity-check the permission actually took (guards against weird FS).
  [ "$(stat -f '%Lp' "$rc" 2>/dev/null || stat -c '%a' "$rc" 2>/dev/null)" = "666" ]

  CLEANUP_CMDS+=("chmod 644 '$rc' 2>/dev/null || true")

  run load-config
  assert_failure 3
  assert_output --partial "world-writable"
  assert_output --partial "Hint:"
}

@test "load-config: refuses group-writable .ver-bumprc (exit code 3)" {
  source ${profile_script}
  local repo rc
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  rc="$repo/.ver-bumprc"
  printf 'TAG_PREFIX=unsafe\n' > "$rc"
  chmod 664 "$rc"
  [ "$(stat -f '%Lp' "$rc" 2>/dev/null || stat -c '%a' "$rc" 2>/dev/null)" = "664" ]

  CLEANUP_CMDS+=("chmod 644 '$rc' 2>/dev/null || true")

  run load-config
  assert_failure 3
  assert_output --partial "group-writable"
  assert_output --partial "Hint:"
}

@test "load-config: refuses .ver-bumprc not owned by current user (exit code 3)" {
  # Needs root to chown to another user; skip unless available.
  if [ "$(id -u)" != "0" ] && ! command -v sudo >/dev/null 2>&1; then
    skip "needs root or sudo to chown to a different user"
  fi
  # Pick a uid that isn't ours. 'nobody' is uid 65534 on most *nixes,
  # but on macOS it's -2 (4294967294). Resolve via id if present.
  local other_uid
  other_uid=$(id -u nobody 2>/dev/null || echo 65534)
  [ "$other_uid" != "$(id -u)" ] || skip "cannot find a non-self uid"

  source ${profile_script}
  local repo rc
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  rc="$repo/.ver-bumprc"
  printf 'TAG_PREFIX=unsafe\n' > "$rc"
  # shellcheck disable=SC2015
  if [ "$(id -u)" = "0" ]; then
    chown "$other_uid" "$rc" || skip "chown failed"
  else
    sudo -n chown "$other_uid" "$rc" 2>/dev/null || skip "passwordless sudo not available"
  fi
  CLEANUP_CMDS+=("sudo -n chown $(id -u) '$rc' 2>/dev/null || chown $(id -u) '$rc' 2>/dev/null || true")

  run load-config
  assert_failure 3
  assert_output --partial "not owned by the current user"
  assert_output --partial "Hint:"
}

# Round-trip all keys ##########################################################

@test "load-config: round-trips every supported key from the file" {
  source ${profile_script}
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  _clear_config_env

  cat > "$repo/.ver-bumprc" <<'EOF'
TAG_PREFIX=rel/
REL_PREFIX=hotfix-
PUSH_DEST=upstream
COMMIT_MSG_PREFIX="release: "
FLAG_NOBRANCH=true
FLAG_NOCHANGELOG=true
FLAG_CHANGELOG_PAUSE=true
EOF

  load-config
  assert_equal "$TAG_PREFIX" "rel/"
  assert_equal "$REL_PREFIX" "hotfix-"
  assert_equal "$PUSH_DEST" "upstream"
  assert_equal "$COMMIT_MSG_PREFIX" "release: "
  assert_equal "$FLAG_NOBRANCH" "true"
  assert_equal "$FLAG_NOCHANGELOG" "true"
  assert_equal "$FLAG_CHANGELOG_PAUSE" "true"
}
