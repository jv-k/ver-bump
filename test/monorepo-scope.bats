#!/usr/bin/env bats

# Package-scoped commit analysis (#96, spec #128, R-MONO): with a per-package
# .verbumprc, COMMIT_PATHS (default "." resolved against the rc's directory)
# restricts the bump suggestion, changelog, no-release gate, and release
# preview to commits touching the package. The blessed flow is
# "cd packages/<pkg> && verbump". A root rc / no rc resolves to the repo
# root and must behave exactly as before.

load 'test_helper'

# monorepo_fixture (pkg-a 1.2.3 / pkg-b 0.4.0, per-package rc + tags, one
# feat(pkg-b) + one fix(pkg-a) commit) comes from test_helper.bash.
#
# Every full run here MUST pin stdin (`</dev/null`, or a piped answer). None
# of these pass -v / --major|--minor|--patch, so they reach the interactive
# version prompt, whose first read is `read -rsn1` — with ambient stdin it
# consumes whatever the terminal supplies, and a stray ESC aborts the run
# with exit 5. `-y` does NOT cover this prompt. EOF falls through to the
# suggested version, which is what these tests assert.

# ── bump suggestion (R-MONO-2) ──────────────────────────────────────────────

@test "scope: pkg-a suggestion ignores pkg-b's feat -> patch, not minor (R-MONO-2)" {
  monorepo_fixture
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  refute_output --partial "suggesting minor bump"
  assert_output --partial "1.2.4"
}

@test "scope: pkg-b suggestion sees its own feat -> minor (R-MONO-2)" {
  monorepo_fixture
  cd packages/pkg-b

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "suggesting minor bump"
  assert_output --partial "0.5.0"
}

# ── changelog scoping + package-local CHANGELOG.md (R-MONO-3) ───────────────

@test "scope: changelog preview lists only pkg-a commits (R-MONO-3)" {
  monorepo_fixture
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "correct rounding"
  refute_output --partial "add widget"
}

@test "scope: full run writes a package-local CHANGELOG and prefixed tag (R-MONO-3/8)" {
  monorepo_fixture
  cd packages/pkg-a

  run bash -c 'printf "\n" | "$1" -p origin' _ "${profile_script}"
  assert_success
  [ -f CHANGELOG.md ]
  [ ! -f ../../CHANGELOG.md ]
  run grep -c "correct rounding" CHANGELOG.md
  assert_output "1"
  run grep -c "add widget" CHANGELOG.md
  assert_output "0"
  run git tag -l "pkg-a-v1.2.4"
  assert_output "pkg-a-v1.2.4"
  run jq -r '.version' package.json
  assert_output "1.2.4"
  # pkg-b is untouched.
  run jq -r '.version' ../pkg-b/package.json
  assert_output "0.4.0"
}

# ── observability (R-MONO-6) ────────────────────────────────────────────────

@test "scope: resolved scope is printed when narrower than the repo (R-MONO-6)" {
  monorepo_fixture
  cd packages/pkg-a

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "packages/pkg-a"
}

# ── no-release gate (R-MONO-4) ──────────────────────────────────────────────

@test "scope: no phantom release — foreign commits don't satisfy the gate (R-MONO-4)" {
  monorepo_fixture
  cd packages/pkg-a
  # Fully release pkg-a (bump commit + tag at its last change) …
  printf '{ "version": "1.2.4" }\n' > package.json
  git add package.json
  git commit -qm "chore: updated package.json, bumped 1.2.3 -> 1.2.4"
  git tag -a pkg-a-v1.2.4 -m "pkg-a-v1.2.4"
  # … then only pkg-b moves.
  echo "more" >> ../pkg-b/widget.txt
  git add ../pkg-b/widget.txt
  git commit -qm "feat(pkg-b): more widgets"

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "Nothing to release"
  run bash -c '"$1" -d -y -p origin </dev/null | grep -c "^no-release"' _ "${profile_script}"
  assert_output "1"
}

# ── COMMIT_PATHS config surface (R-MONO-1) ──────────────────────────────────

@test "config: COMMIT_PATHS is a supported rc key — no unknown-key warning (R-MONO-1)" {
  monorepo_fixture
  cd packages/pkg-a
  # The fixture's rc is tracked — commit the edit so the tree stays clean.
  printf 'TAG_PREFIX=pkg-a-v\nCOMMIT_PATHS=.\n' > .verbumprc
  chmod 644 .verbumprc
  git add .verbumprc
  git commit -qm "chore(pkg-a): set COMMIT_PATHS"

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  refute_output --partial "Unknown .verbumprc key"
}

@test "config: env COMMIT_PATHS overrides the rc default (R-MONO-1, R-CFG-3)" {
  monorepo_fixture
  cd packages/pkg-a

  # Env beats the rc-derived default "." — pkg-b's feat now counts.
  COMMIT_PATHS=". ../pkg-b" run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "suggesting minor bump"
}

@test "config: explicit COMMIT_PATHS widens the scope to extra paths (R-MONO-1)" {
  monorepo_fixture
  cd packages/pkg-a
  # The fixture's rc is tracked — commit the edit so the tree stays clean.
  # Multi-value keys need quoting — the rc is shell-sourced (same as
  # RELEASE_BRANCHES).
  printf 'TAG_PREFIX=pkg-a-v\nCOMMIT_PATHS=". ../pkg-b"\n' > .verbumprc
  chmod 644 .verbumprc
  git add .verbumprc
  git commit -qm "chore(pkg-a): widen COMMIT_PATHS"

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  # pkg-b's feat commit now counts toward pkg-a's suggestion.
  assert_output --partial "suggesting minor bump"
}

# ── release preview (R-MONO-7) ──────────────────────────────────────────────

@test "json: scoped preview carries scope.paths repo-root-relative (R-MONO-7)" {
  monorepo_fixture
  cd packages/pkg-a

  run bash -c '"$1" --dry-run --json -y -p origin >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run jq -r '.scope.paths | join(",")' "$BATS_TEST_TMPDIR/out"
  assert_output "packages/pkg-a"
  run jq -r '.tag' "$BATS_TEST_TMPDIR/out"
  assert_output "pkg-a-v1.2.4"
}

@test "json: whole-repo preview has no scope member — payload unchanged (R-MONO-1/7)" {
  releasable_repo

  run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run jq -r 'has("scope")' "$BATS_TEST_TMPDIR/out"
  assert_output "false"
}

# ── tag-series isolation lock-in (R-MONO-8) ─────────────────────────────────

@test "tag series: derivation stays prefix-anchored with foreign tags present (R-MONO-8)" {
  monorepo_fixture
  git tag -a v9.0.0 -m "v9.0.0"
  git rm -q packages/pkg-b/package.json
  git commit -qm "chore: drop pkg-b manifest"
  cd packages/pkg-b

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "derived from git tag <pkg-b-v0.4.0>: 0.4.0"
}

@test "compare-url: prefixed tags render a valid compare link in grouped changelog (R-MONO-8)" {
  monorepo_fixture
  git remote set-url origin https://github.com/acme/mono.git
  cd packages/pkg-a

  CHANGELOG_STYLE=grouped run ${profile_script} -d -y -p origin --no-fetch </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "compare/pkg-a-v1.2.3...pkg-a-v1.2.4"
}

@test "compare-url: a slash-containing TAG_PREFIX is %2F-encoded in the compare link (R-MONO-8)" {
  released_repo
  git remote add origin https://github.com/acme/widget.git
  git tag -a "rel/1.2.3" -m "rel/1.2.3"
  git commit -q --allow-empty -m "fix: something new"

  TAG_PREFIX="rel/" CHANGELOG_STYLE=grouped \
    run ${profile_script} -d -y -p origin --no-fetch </dev/null
  assert_success
  strip_ansi_output
  assert_output --partial "compare/rel%2F1.2.3...rel%2F1.2.4"
}

@test "root rc: whole-repo runs have no scope — no print, no JSON member (R-MONO-1/7)" {
  releasable_repo
  printf 'TAG_PREFIX=v\n' > .verbumprc
  chmod 644 .verbumprc

  run ${profile_script} -d -y -p origin </dev/null
  assert_success
  strip_ansi_output
  refute_output --partial "Package scope"

  run bash -c '"$1" --minor --yes -p origin --dry-run --json >"$2/out" 2>/dev/null </dev/null' _ \
    "${profile_script}" "$BATS_TEST_TMPDIR"
  assert_success
  run jq -r 'has("scope")' "$BATS_TEST_TMPDIR/out"
  assert_output "false"
}
