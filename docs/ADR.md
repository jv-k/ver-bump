# Architecture Decision Records

Backfilled 2026-07-13 from git history, the 2.0 PRD, and code as it ships
on `develop`. One section per decision; newest last. Statuses: **Accepted**
(in force), **Proposed** (not yet merged), **Deferred**.

---

## ADR-01 — Pure-bash runtime; no `npm`/`node` at runtime

**Status:** Accepted (2.0) · PRD G1, R-DEP

**Context:** The 1.1.x README claimed "pure bash" while the code shelled out
to `npm version`, which also fired npm lifecycle scripts as a hidden side
effect. The tool's defensible niche is "plain bash, no Node ecosystem
lock-in — `git` + `jq` only".

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
allowlist; unknown keys draw a **non-fatal** warning (exit stays `0`) — a lint
heuristic over top-level `KEY=` assignment lines that catches typos, not
computed assignments, and is explicitly *not* a security control.

**Update (grill 2026-07-16):** the warning was specced in the release plan but
never built — `.ver-bumprc` keys were being silently sourced, so a typo'd key
was accepted in silence (contra G2). This ADR is the authority for
implementing it as the heuristic above; the code + `config.bats` case are on
the 2.0 enactment queue.

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
`npx jv-k/releasetool`; the default was later changed to `gh --generate-notes`
in ADR-18). `gh`/`node` are preflighted only when `--release`
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

---

## ADR-15 — Default-path dependency freeze; features are opt-in and dependency-isolated

**Status:** Accepted (2.0) · grill 2026-07-16 · PRD G1/G3, builds on ADR-01, ADR-11

**Context:** The pitch (PRD §2/§4) is "one file, plain bash, no Node
lock-in." Goal G3 ("workflow parity with modern release tools") pulls toward
*more* features; the pitch pulls toward *fewer*. With no written arbiter,
every new request — config file (a former non-goal), `--undo`, `--release`,
the multi-format bump engine (`tomlq`/`yq`), hooks, grouped changelog —
re-litigated the tool's identity from scratch, and "more" kept winning. The
shipped flag surface has outgrown even the PRD §14 inventory
(`--source`, `--bump`, `--preid`, `--quiet`, `--sign` are absent from it), and `tomlq`/`yq` are conditional deps absent from the §9
table.

**Decision:** A feature ships **on the default path** only if (a) it needs
nothing beyond `bash`, `git`, `jq` and (b) it automates a *mechanical* step
of cutting a release. Anything that **generates content**, **integrates an
external service**, or **adds a dependency** must be opt-in behind an explicit
flag/config key **and** dependency-isolated: preflight the dependency only
when the feature is invoked (`check-release-deps`, `check-bump-deps`,
`check-pr-deps` are the reference pattern). No new **default-path** dependency
is ever added. This ADR is the arbiter cited to accept or reject future
feature requests, in place of re-arguing identity.

**Consequences:** The default path stays `bash`/`git`/`jq`-only by
construction, not vigilance (R-DEP holds structurally). New optional deps are
legitimate only behind a flag + preflight. The PRD §9 dependency table and
§14 flag inventory become the authoritative surface and must be kept current
(both are presently stale — a reconciliation chore, not a scope change).
A "no" to a feature now cites ADR-15 rather than relitigating the pitch.

---

## ADR-16 — `stable` branch retired; tags are the release channel

**Status:** Accepted (2.0) · grill 2026-07-16 · resolves the open clause in ADR-09

**Context:** ADR-09 left `stable` as "the legacy release channel pending a
repoint-or-retire decision **at 2.0**." At 2.0, `origin/stable` (`b31745d`) and
`origin/main` (`bc57325`) are both frozen at the Aug-2023 `1.1.8` merge —
`stable` is just `main` plus one merge commit. A repo-wide search found **no
consumer**: `install.sh` installs from GitHub **release tags**, the
`latest`/`next` dist-tags are npm (CI-driven), and no doc instructs
`clone -b stable`.

**Decision:** Retire `stable` — delete `origin/stable`. The release channel is
git **tags**; `main` is the release-merge target; `develop` integrates. No
branch-shaped "latest stable" pointer is maintained, because nothing resolves
one.

**Consequences:** One fewer frozen ref and the end of the "why are `main` and
`stable` both at 1.1.8?" confusion for anyone browsing the repo.
Near-reversible (recreate from a tag if ever needed). Deletion is a manual
`git push origin --delete stable`, run by the maintainer outside this session.

---

## ADR-17 — `develop` force-push window closes at `v2.0.0` GA

**Status:** Accepted (2.0) · grill 2026-07-16 · amends ADR-09

**Context:** ADR-09 permits force-pushing the canonical local `develop`
"during the 2.0 stabilisation window" but never defines the window's end.
That is safe while the project is solo, but conflicts with the contributor
workflow now in place (issue tracker, triage labels, PR conventions): once an
external contributor branches from `origin/develop` or CI caches it, a
force-push rewrites shared history under them.

**Decision:** The force-push window closes at the `v2.0.0` final tag (GA).

- **Stabilisation (now → 2.0.0 GA):** `develop` may be force-pushed; local is
  canonical.
- **At GA:** `develop` is **append-only** — no force-push; history is shared;
  changes land via PR + merge (or rebase-then-merge). Enable GitHub branch
  protection on `develop` and `main` (block force-push, require PR).

**Consequences:** Full rewrite freedom through the rc/stabilisation phase;
contributor-safe from the moment contributors can appear. Post-GA history
surgery on `develop` needs a deliberate, announced exception. Branch
protection is a one-time repo-settings change performed *at* GA (a GA step,
not a now step).

---

## ADR-18 — `--release` notes default to `gh --generate-notes`; custom command is opt-in

**Status:** Accepted (2.0) · grill 2026-07-16 · refines ADR-11, PRD §5.8 (R-REL-2/4/5)

**Context:** `--release` already requires `gh`. But
`VER_BUMP_RELEASE_NOTES_CMD` defaulted to `npx jv-k/releasetool`, so the
out-of-the-box `--release` path pulled in node + network + trust in a
maintainer-personal package — the one place the no-Node-lock-in tool reached
for Node **by default**. `gh release create --generate-notes` produces notes
from commits/PRs since the last tag with no dependency beyond the
already-required `gh`. 2.0 has not GA'd (no `v2.0.0` tag), so changing the
default costs no migration.

**Decision:** When `VER_BUMP_RELEASE_NOTES_CMD` is unset/empty (the new
default), `do-github-release` runs `gh release create <tag> --generate-notes`
— `gh`-only, no node. When it is set, the existing capture-stdout path (run
the command, pass its stdout via `--notes`, abort before `gh` on a non-zero
exit per R-REL-6) is used unchanged. Dry-run prints the resolved invocation
for whichever path applies; on the default path no notes command runs.

**Consequences:** The default `--release` path is `gh`-only; node/npx drops to
a conditional dependency *only when the notes command is overridden* (PRD §9
and R-REL-4 updated to say so). R-REL-2's default changes from
`npx jv-k/releasetool` to gh's built-in generator; `release.bats` and
`docs/features/github-release` grow coverage for both the default and
overridden paths. Author-coupling is removed from the default path.

---

## ADR-19 — `develop` lands on `main` by reset at GA; prereleases stay tag-only

**Status:** Accepted (2.0) · grill 2026-07-16 · builds on ADR-09, ADR-16, ADR-17

**Context:** `origin/main` (`bc57325`, frozen Aug 2023) is **not** an ancestor
of `origin/develop`; they diverged at `873b13e` (2021-09-15). `main` carries
170 commits holding the entire `v1.0.0`–`v1.1.8` release history; `develop`
carries 340 commits of 2.x work and never contained the 1.x line. Every 1.x
release is **tag-anchored**, so that history survives independent of `main`'s
branch pointer (ADR-16 — tags are the archive). A fast-forward is impossible.

**Decision:**

- **Prereleases are tag-only on `develop`:** tag `v2.0.0-rc.N` on `develop`'s
  tip, publish a GitHub prerelease + npm `next` dist-tag (ADR-10); `main` stays
  frozen (ADR-09 — `main` receives GA merges only).
- **At GA, `develop` lands on `main` by reset, not merge:** `git branch -f main
  develop` + one force-push. The 170 old commits leave `main`'s branch but stay
  reachable via their `v1.x` tags. A merge commit (rejected) would bake a
  permanent 2021 fork into `main`'s first-parent line to preserve a lineage
  tags already preserve; a squash (rejected) would destroy `develop`'s history.
- **The GA sequence is ordered:** reset `main` → tag `v2.0.0` → enable branch
  protection (ADR-17). Protection is enabled **last** because it would block
  the reset.

**Consequences:** Post-GA `main` is linear and reads as the actual project
(`git log main` is honest). The reset is a one-time destructive act on the
default branch, safe only because `main` is frozen, `stable` is retired
(ADR-16), and nothing builds on `main`; it must be announced and done once. At
most a couple of untagged 2023 merge commits at `main`'s tip drop off the
branch (recoverable via reflog/`ORIG_HEAD`). Effectively irreversible once
contributors pull the rewritten `main`.

---

## ADR-20 — GA exit criteria (rc → `v2.0.0` gate)

**Status:** Accepted (2.0) · grill 2026-07-16 · gates ADR-19

**Context:** "Cut rc.1, harden, then GA" had no written exit criteria, making
"are we done?" a judgment call. The GA reset (ADR-19) is irreversible in
practice, so the gate protecting it must be explicit and checkable.

**Decision:** Promote `rc.N` → `v2.0.0` only when all hold:

1. **Queue drained** — the grill's doc reconciliations plus both code changes
   (ADR-18 notes default, ADR-05 config warn) are landed *with tests*.
2. **CI green on the contract** — `pnpm tests:run` 0 failures on **Ubuntu +
   macOS** (AC-3); `shellcheck -x` zero warnings (AC-2); AC-4/AC-5/AC-6 pass.
3. **No open blockers** — the 2.0 milestone has no open P0/P1; **#51** (undo
   `fail`-shadowing) is closed.
4. **Real dogfood** — `rc` cut *with `ver-bump` itself* (PRD §11.3), installed
   on a clean `bash`/`git`/`jq`-only machine via the rc tarball, with a live
   bump run in the sandbox.
5. **Behavioural changes verified end-to-end** — `--release` default produces a
   release via `gh --generate-notes`; a typo'd `.ver-bumprc` key warns.

A short **soak** (rc sits a few days / ≥ 1 external install before GA) is
encouraged but not a hard gate — maintainer discretion.

**Consequences:** "Done" is a checklist, not a feeling; the gate is the last
guard before the ADR-19 reset. Behavioural changes introduced during hardening
extend criterion 5.
