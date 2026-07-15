# Architecture Decision Records

Backfilled 2026-07-13 from git history, the 2.0 PRD, and code as it ships
on `develop`. One section per decision; newest last. Statuses: **Accepted**
(in force), **Proposed** (not yet merged), **Deferred**.

---

## ADR-01 — Pure-bash runtime; no `npm`/`node` at runtime

**Status:** Accepted (2.0) · PRD G1, R-DEP

**Context:** The 1.1.x README claimed "pure bash" while the code shelled out
to `npm version`, which also fired npm lifecycle scripts as a hidden side
effect. The tool's defensible niche is "one file, plain bash, no Node
ecosystem lock-in".

**Decision:** Runtime dependencies are exactly `bash`, `git`, `jq`.
`package.json` is bumped with `jq` (atomic write-then-rename via
`jq_inplace`). npm remains an *install* path only. Conditional extras
(`gh`, the `--release` notes command) are preflighted only when their flag
is used.

**Consequences:** npm lifecycle scripts no longer fire (breaking change
B-3); `jq` becomes a hard dependency; the tool works in any SemVer repo.

---

## ADR-02 — Fixed exit-code contract (0–5, 4 reserved)

**Status:** Accepted (2.0) · PRD §5.6, R-EXIT

**Context:** 1.1.x exited `1` for everything; CI wrappers couldn't
distinguish usage errors from preconditions from user aborts.

**Decision:** `0` success, `1` generic, `2` usage/parse, `3` precondition,
`4` reserved for a future hook system, `5` user abort. All exits go through
`fail <code> <message> [hint]` (`lib/errors.sh`). The contract is versioned
with the major release.

**Consequences:** Scriptable failure classes; every new error path needs an
`errors.bats` case. Reserving `4` pre-commits a slot so the future hook
system isn't a breaking change.

---

## ADR-03 — Bash 3.2 compatibility floor

**Status:** Accepted

**Context:** macOS ships Bash 3.2 (GPLv2); requiring Bash 4+ would break
the largest target audience of a no-install shell tool.

**Decision:** Target Bash 3.2+. No associative arrays — parallel indexed
arrays instead (`_CONFIG_KEYS` in `lib/config.sh` is the reference
pattern). No `getopt(1)` reliance for long flags (see ADR-04).

**Consequences:** Some verbosity (parallel arrays, manual long-opt
handling) traded for zero-friction macOS support.

---

## ADR-04 — Long options via argv normalization in front of `getopts`

**Status:** Accepted (2.0) · PRD R-OPT

**Context:** `getopts` (POSIX, available in Bash 3.2) can't parse GNU long
options, and GNU `getopt(1)` isn't portable to macOS.

**Decision:** `normalize-long-opts` translates `--name value` /
`--name=value` into short-form argv (`NORMALIZED_ARGV`), then the existing
`getopts` loop parses uniformly. Modes that must run without a repo
(`--about`, `--completions`, `--install-completions`, `--undo`) and
long-only booleans (`--release`, `--major/--minor/--patch`) are pre-scanned
and dispatched in the same pass; they pre-scan the rest of argv for the
flags they honour (`-d`, `-y`, `-t`, `-B`) so flag order never matters.

**Consequences:** One parsing pipeline, Bash-3.2-safe; the pre-scan block
is the one place with bespoke per-mode logic and needs care when adding
modes.

---

## ADR-05 — `.ver-bumprc` is shell-sourced, permission-guarded, lowest-precedence

**Status:** Accepted (2.0) · PRD §5.10, R-CFG

**Context:** Users wanted per-repo defaults; a config file was originally a
PRD non-goal, then pulled into 2.0. Sourcing shell is simple and dependency
free but executes attacker-controlled code if the file can be tampered
with; discovery walks *up* from `$PWD`, so ownership matters.

**Decision:** `.ver-bumprc` is discovered walking up to `/`, shell-sourced
(not parsed), refused (exit `3`) when group/world-writable or not owned by
the invoking user. Precedence is invariant: CLI > env > file > default,
enforced by call order (`load-config` → `apply-config-defaults` →
`process-arguments`). CLI-only switches (`DO_RELEASE`, `BUMP_LEVEL`) are
reset after sourcing so no rc/env can force a release or bump level.

**Consequences:** No parser to maintain; the permission gate is the
security boundary and must not be weakened. Allowed keys are an explicit
allowlist (unknown keys warn).

---

## ADR-06 — Modular `lib/` split; entrypoint orchestrates only

**Status:** Accepted (2.0) · issue #44, commit `5fa7939`

**Context:** `lib/helpers.sh` had grown to hold all behaviour — every
change touched one grab-bag file, and review diffs were unreadable.

**Decision:** Split into focused modules with one reason to change each:
`args`, `version`, `validate`, `changelog`, `git-checks`, `git-actions`,
`config`, `json`, `errors`, `completions`, `usage`, `ui`, `styles`,
`icons`. `ver-bump.sh` keeps globals + `main()` orchestration and
implements nothing.

**Consequences:** Globals are the integration surface between modules
(documented at the top of `ver-bump.sh`); shellcheck lints files in
isolation, so cross-module flag reads carry a file-scope `SC2034` waiver.

---

## ADR-07 — Semantic UI tokens (`S_*`), not raw colours

**Status:** Accepted (2.0) · commits `110734d`…`051b46d`

**Context:** Ad-hoc emoji + raw colour codes made output inconsistent and
untestable, and colour leaked into pipes.

**Decision:** All colour flows through semantic tokens defined in
`lib/styles.sh` (`S_VAL`, `S_WARN`, `S_LIGHT`, …) applied by `log_*` /
`section` helpers with a fixed symbol vocabulary (`lib/icons.sh`). A single
`USE_COLOR` gate honours `NO_COLOR`, `CLICOLOR_FORCE`/`FORCE_COLOR`, and
TTY detection. Narrative text carries no colour; colour marks values,
prompts, warnings, errors.

**Consequences:** Output is regression-testable (`ui.bats`, `color.bats`)
and greppable when piped; library code must use `${TOK-}` default-safe
expansions so sourcing without styles never explodes.

---

## ADR-08 — bats-core suite: one file per feature, scratch-repo isolation

**Status:** Accepted (2.0) · commit `81167d8`

**Context:** A single `ver-bump.bats` monolith (54 tests) was slow to
navigate and git-state leaks between tests corrupted the host repo.

**Decision:** One `.bats` file per feature (20 files, 206 tests at
reconciliation time); anything touching git runs inside a `mktemp`-backed
`scratch_repo`; shared setup lives in `test_helper.bash`; assertions use
bats-assert with explicit exit codes.

**Consequences:** AC-1 (every requirement has a test) is auditable per
feature; the suite never mutates the host checkout.

---

## ADR-09 — `develop` is the integration branch; local `develop` is canonical

**Status:** Accepted · PR #48, commit `592f754`

**Context:** 2.0 work accumulated on a long-lived `feat/v2.0` branch;
release automation needed a stable integration target, and
`feat/v2.0` was cut to `develop` for the 2.0.0-alpha.

**Decision:** All work integrates to `develop`; `main` receives release
merges only; `stable` is the legacy release channel pending a
repoint-or-retire decision at 2.0. The local `develop` is canonical and may
be force-pushed to origin during the 2.0 stabilisation window.

**Consequences:** PRs target `develop`; the rc branch is cut from
`develop`'s tip (an rc cut early goes stale — re-cut rather than patch).

---

## ADR-10 — Supply-chain hardening: SHA-pinned actions, OIDC trusted publishing, tarball allowlist

**Status:** Accepted · commits `de54824`, `0ca798f`, `a2fab9e`, `66ea30e`

**Context:** The npm tarball weighed 17.5 MB (dev assets included), CI used
floating action tags, and publishing used a long-lived npm token.

**Decision:** `package.json` gets a `files` allowlist (script + `lib/` +
docs only); releases publish with provenance via npmjs **OIDC Trusted
Publishing** (tokenless); GitHub Actions are SHA-pinned with
least-privilege permissions; prereleases publish to the `next` dist-tag,
never `latest`; GitHub Packages publishing is gated separately.

**Consequences:** No npm token to rotate or leak; consumers can verify
provenance; bumping an action version means updating a SHA deliberately.

---

## ADR-11 — GitHub release publishing is opt-in and dependency-isolated

**Status:** Accepted (2.0) · issues #25/#43, PRD §5.8

**Context:** Users asked for release automation, but ADR-01 forbids new
default-path dependencies, and `gh` + a notes generator are heavyweight.

**Decision:** `--release` (long-only, CLI-only — not settable via env or
rc) publishes via `gh release create` after the push; requires `-p`;
release notes come from `VER_BUMP_RELEASE_NOTES_CMD` (default
`npx jv-k/releasetool`). `gh`/`node` are preflighted only when `--release`
is used; prereleases publish as GitHub prereleases.

**Consequences:** The default path stays bash/git/jq-only (R-DEP holds);
notes generation is user-swappable; a failed notes command aborts before
`gh` but does not roll back the pushed tag.

---

## ADR-12 — Tag-in-place default + `--branch` / `--pr` selectable workflows

**Status:** Accepted — PR #49, merged 2026-07-13

**Context:** The release-branch flow predates PR-centric hosting; for most
repos the forced `release-<version>` branch added ceremony without review
value, while PR-centric teams wanted the opposite: a branch *plus* an
opened pull request (release-please/changesets ergonomics).

**Decision:** The gitflow release branch is demoted from forced default to
one of three selectable workflows: **tag-in-place** (default — commit +
tag the current branch), **release branch** (`--branch`, the pre-2.0
default), and **release PR** (`--pr` — implies `--branch` and a push to
`origin`, then opens a PR via `gh`, mirroring the `--release` pattern:
`check-pr-deps` preflight, conditional dependency). `FLAG_NOBRANCH` is
inverted to positive `FLAG_BRANCH`; `-b`/`--no-branch` stays as a
deprecated no-op for script back-compat. The `--pr` base resolves
`--base` › `PR_BASE` (env/`.ver-bumprc`) › invocation branch › remote
HEAD. `--undo` learns tag-in-place releases (deletes the tag, keeps the
bump commit).

**Consequences:** **Breaking** — bare `ver-bump` no longer cuts a branch
(PRD B-5); teams keep the old default via `--branch` or `FLAG_BRANCH=true`
in `.ver-bumprc`. `.ver-bumprc` gains `FLAG_BRANCH` + `PR_BASE`;
`FLAG_NOBRANCH` remains recognised for compatibility.

---

## ADR-13 — Homebrew distribution deferred to post-2.0

**Status:** Deferred · issue #24

**Context:** The release plan (M6) targeted a `jv-k/homebrew-ver-bump` tap
for 2.0; shipping 2.0 was prioritised over standing up a second repo and
formula audit.

**Decision:** Defer the tap to post-2.0; README says "planned for a future
release". `basher` (#39) and GitHub Packages docs (#40) sit in the same
post-2.0 distribution bucket.

**Consequences:** npm / curl-clone remain the install paths at 2.0.0.

---

## ADR-14 — pnpm for dev tooling

**Status:** Accepted · `CLAUDE.md`, `pnpm-lock.yaml`

**Context:** Dev tooling (bats install, scripts) needs a package manager;
the repo carried a stale 3.7k-line `package-lock.json`.

**Decision:** pnpm is the package manager for dev workflows
(`pnpm tests:run`, `pnpm dev`); `pnpm-lock.yaml` is canonical;
`package-lock.json` is treated as stale if it reappears. Runtime is
unaffected (ADR-01).

**Consequences:** Contributors need pnpm for the dev loop; CI uses pnpm.
