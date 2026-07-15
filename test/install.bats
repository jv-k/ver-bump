#!/usr/bin/env bats

# install.sh (R-DIST-1..5, issue #66): arg/env parsing, layout paths, asset
# URLs, and checksum verification are driven as pure functions by sourcing
# the installer. End-to-end runs stub http_fetch — the installer's single
# network seam — with local fixture files, so no test touches the network.
# Negative cases assert the R-DIST-5 contract: non-zero exit, nothing
# installed, no partial files left behind.

load 'test_helper'

# Isolate HOME, the install prefix, and TMPDIR per test so failure cases can
# assert "nothing installed" and "no temp leftovers" against empty dirs.
setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  repo_dir=$PWD
  installer="$repo_dir/install.sh"

  FAKE_HOME=$(mktemp -d)
  export HOME="$FAKE_HOME"
  PREFIX="$FAKE_HOME/.local"

  FIXTURE_DIR=$(mktemp -d)
  SCRATCH_TMP=$(mktemp -d)

  F_TEMPS=()
  CLEANUP_CMDS=( "rm -rf ${FAKE_HOME}" "rm -rf ${FIXTURE_DIR}" "rm -rf ${SCRATCH_TMP}" )
}

teardown() {
  run_cleanup_cmds
  unset FAKE_HOME PREFIX FIXTURE_DIR SCRATCH_TMP
  unset VER_BUMP_INSTALL_VERSION VER_BUMP_PREFIX
}

# Build a fake "release" in $FIXTURE_DIR from the real working tree — the
# same file set the publish workflow tars up — so fixtures can't drift from
# what CI ships. Requires install.sh to be sourced (uses sha256_of).
make_release_fixture() {
  (cd "$repo_dir" && tar -czf "$FIXTURE_DIR/ver-bump.tar.gz" ver-bump.sh lib LICENSE package.json)
  printf '%s  ver-bump.tar.gz\n' "$(sha256_of "$FIXTURE_DIR/ver-bump.tar.gz")" \
    > "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
}

# ── executed / piped entrypoint ─────────────────────────────────────────

@test "install: --help prints usage on stdout and exits 0" {
  run bash "$installer" --help
  assert_success
  assert_output --partial "VER_BUMP_INSTALL_VERSION"
  assert_output --partial "--prefix <dir>"
}

@test "install: unknown option exits 2 with usage" {
  run bash "$installer" --bogus
  assert_failure 2
  assert_output --partial "unknown option: --bogus"
}

@test "install: main also runs when piped into bash (curl | bash path)" {
  # An invalid pinned version proves main ran (and bailed in parse-args,
  # before any network or filesystem work).
  run bash -c "VER_BUMP_INSTALL_VERSION=banana bash < '$installer'"
  assert_failure 2
  assert_output --partial "not a valid SemVer version"
}

# ── parse-args: flags, env, precedence ──────────────────────────────────

@test "install: parse-args defaults to latest + \$HOME/.local" {
  source "$installer"
  parse-args
  assert_equal "$INSTALL_VERSION" ""
  assert_equal "$INSTALL_PREFIX" "$HOME/.local"
}

@test "install: parse-args reads VER_BUMP_INSTALL_VERSION and VER_BUMP_PREFIX" {
  source "$installer"
  export VER_BUMP_INSTALL_VERSION="v2.0.0"   # leading v is accepted + stripped
  export VER_BUMP_PREFIX="/opt/ver-bump"
  parse-args
  assert_equal "$INSTALL_VERSION" "2.0.0"
  assert_equal "$INSTALL_PREFIX" "/opt/ver-bump"
}

@test "install: flags win over env (CLI > env precedence)" {
  source "$installer"
  export VER_BUMP_INSTALL_VERSION="1.0.0"
  export VER_BUMP_PREFIX="/from-env"
  parse-args --version 2.0.0 --prefix /from-cli
  assert_equal "$INSTALL_VERSION" "2.0.0"
  assert_equal "$INSTALL_PREFIX" "/from-cli"
}

@test "install: --version=<v> equals form accepts a prerelease" {
  source "$installer"
  parse-args --version=2.0.0-rc.1
  assert_equal "$INSTALL_VERSION" "2.0.0-rc.1"
}

@test "install: --version without a value exits 2" {
  source "$installer"
  run parse-args --version
  assert_failure 2
  assert_output --partial "--version requires a value"
}

@test "install: empty --version= / --prefix= exit 2" {
  source "$installer"
  run parse-args --version=
  assert_failure 2
  assert_output --partial "--version requires a value"
  run parse-args --prefix=
  assert_failure 2
  assert_output --partial "--prefix requires a value"
}

@test "install: non-SemVer version exits 2 with hint" {
  source "$installer"
  run parse-args --version banana
  assert_failure 2
  assert_output --partial "not a valid SemVer version: banana"
  assert_output --partial "VER_BUMP_INSTALL_VERSION"
}

# ── layout + asset URLs ─────────────────────────────────────────────────

@test "install: install-paths derives share dir, bin dir and symlink from prefix" {
  source "$installer"
  INSTALL_PREFIX="/x"
  install-paths
  assert_equal "$SHARE_DIR" "/x/share/ver-bump"
  assert_equal "$BIN_DIR" "/x/bin"
  assert_equal "$BIN_LINK" "/x/bin/ver-bump"
}

@test "install: asset-url uses the latest-release alias when unpinned" {
  source "$installer"
  INSTALL_VERSION=""
  run asset-url "ver-bump.tar.gz"
  assert_success
  assert_output "https://github.com/jv-k/ver-bump/releases/latest/download/ver-bump.tar.gz"
}

@test "install: asset-url uses the v-prefixed tag path when pinned" {
  source "$installer"
  INSTALL_VERSION="1.2.3"
  run asset-url "ver-bump.tar.gz.sha256"
  assert_success
  assert_output "https://github.com/jv-k/ver-bump/releases/download/v1.2.3/ver-bump.tar.gz.sha256"
}

# ── dependency preflight ────────────────────────────────────────────────

@test "install: missing tar is reported with exit 3" {
  source "$installer"
  # Shadow the probe for tar only; everything else resolves normally.
  have_cmd() {
    [ "$1" = tar ] && return 1
    command -v "$1" >/dev/null 2>&1
  }
  run check-install-deps
  assert_failure 3
  assert_output --partial "missing required tools: tar"
}

# ── checksum verification (fixtures, no network) ────────────────────────

@test "install: verify_checksum accepts a matching digest" {
  source "$installer"
  make_release_fixture
  run verify_checksum "$FIXTURE_DIR/ver-bump.tar.gz" "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  assert_success
}

@test "install: verify_checksum rejects a wrong digest" {
  source "$installer"
  make_release_fixture
  printf '%064d  ver-bump.tar.gz\n' 0 > "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  run verify_checksum "$FIXTURE_DIR/ver-bump.tar.gz" "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  assert_failure
  assert_output --partial "checksum mismatch"
}

@test "install: verify_checksum rejects a malformed checksum file" {
  source "$installer"
  make_release_fixture
  printf '<html>404 Not Found</html>\n' > "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  run verify_checksum "$FIXTURE_DIR/ver-bump.tar.gz" "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  assert_failure
  assert_output --partial "malformed"
}

# ── end-to-end with a stubbed http_fetch ────────────────────────────────

@test "install: e2e happy path installs tree + symlink and prints version" {
  source "$installer"
  make_release_fixture
  http_fetch() { cp "$FIXTURE_DIR/${1##*/}" "$2"; }
  export TMPDIR="$SCRATCH_TMP"

  run main --prefix "$PREFIX"
  assert_success

  [ -f "$PREFIX/share/ver-bump/ver-bump.sh" ]
  [ -x "$PREFIX/share/ver-bump/ver-bump.sh" ]
  [ -d "$PREFIX/share/ver-bump/lib" ]
  [ -L "$PREFIX/bin/ver-bump" ]
  assert_equal "$(readlink "$PREFIX/bin/ver-bump")" "$PREFIX/share/ver-bump/ver-bump.sh"

  # R-DIST-3: prints the installed version + the completions suggestion.
  assert_output --partial "Installed ver-bump $(jsonfile_get_ver "$repo_dir/package.json")"
  assert_output --partial "ver-bump --install-completions"

  # No temp leftovers on success either.
  [ -z "$(ls -A "$SCRATCH_TMP")" ]
}

@test "install: e2e re-run upgrades in place (idempotent)" {
  source "$installer"
  make_release_fixture
  http_fetch() { cp "$FIXTURE_DIR/${1##*/}" "$2"; }
  export TMPDIR="$SCRATCH_TMP"

  # Seed a stale install: the swap must replace the whole tree, not merge.
  mkdir -p "$PREFIX/share/ver-bump"
  touch "$PREFIX/share/ver-bump/stale-file-from-old-version"

  run main --prefix "$PREFIX"
  assert_success
  run main --prefix "$PREFIX"
  assert_success

  [ ! -e "$PREFIX/share/ver-bump/stale-file-from-old-version" ]
  [ -L "$PREFIX/bin/ver-bump" ]
  [ -z "$(ls -A "$SCRATCH_TMP")" ]
}

@test "install: e2e corrupted checksum exits 1, installs nothing, cleans up" {
  source "$installer"
  make_release_fixture
  printf '%064d  ver-bump.tar.gz\n' 0 > "$FIXTURE_DIR/ver-bump.tar.gz.sha256"
  http_fetch() { cp "$FIXTURE_DIR/${1##*/}" "$2"; }
  export TMPDIR="$SCRATCH_TMP"

  run main --prefix "$PREFIX"
  assert_failure 1
  assert_output --partial "sha256 verification failed"

  # R-DIST-5: nothing installed, no partial files anywhere.
  [ ! -e "$PREFIX/share/ver-bump" ]
  [ ! -e "$PREFIX/bin/ver-bump" ]
  [ -z "$(ls -A "$SCRATCH_TMP")" ]
}

@test "install: e2e download failure exits 1 with pin hint, installs nothing" {
  source "$installer"
  http_fetch() { return 1; }
  export TMPDIR="$SCRATCH_TMP"

  run main --prefix "$PREFIX"
  assert_failure 1
  assert_output --partial "download failed"
  assert_output --partial "VER_BUMP_INSTALL_VERSION"

  [ ! -e "$PREFIX/share/ver-bump" ]
  [ ! -e "$PREFIX/bin/ver-bump" ]
  [ -z "$(ls -A "$SCRATCH_TMP")" ]
}
