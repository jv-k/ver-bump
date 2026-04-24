# ver-bump — Product Requirements Document

| | |
| --- | --- |
| **Status** | Draft |
| **Target release** | `2.0.0` |
| **Owner** | John Valai ([@jv-k](https://github.com/jv-k)) |
| **Last updated** | 2026-04-22 |
| **Supersedes** | `1.1.8` |

---

## 1. Summary

`ver-bump` is **an opinionated release tool for Git projects with a
`package.json`** — primarily Node / JS / TS, but also usable for any SemVer
repo via `-f <file>.json` for the bump target. It automates the mechanical
parts of cutting a release (SemVer bump, CHANGELOG, release branch, tag,
push), driven by Conventional Commits, and leaves the integration step
(merge back to `develop` / `main`) to the human.

`2.0.0` is a correctness, ergonomics, and trust release: a long-standing
`-p` flag bug is fixed, the tool drops its hidden `npm` runtime dependency,
and it gains first-class support for SemVer validation, prerelease iteration,
conventional-commit bump suggestion, dry-run mode, GNU-style long options,
shell completions (and a one-shot `--install-completions` installer with
shell auto-detection), a branded `--about` block, a structured log
vocabulary + inverse-video section headers, and a stable exit-code contract.
A `dev/` sandbox harness lands alongside so changes can be exercised
end-to-end without polluting a real repo.

The release is intentionally **non-additive in behaviour**: every existing
short flag keeps its semantics; what changed is that the tool now does the
thing the original README *said* it did, rather than whatever the 2021
implementation happened to execute.

---

## 2. Background & motivation

`ver-bump` lives in a crowded niche (`semantic-release`, `release-please`,
`release-it`, `bumpversion`, `changeset`, `goreleaser`). Its defensible pitch
is **one file, plain bash, no Node ecosystem lock-in** for solo devs and
small teams that want a predictable release script.

That pitch was undermined by several issues in `1.1.x`:

| Area | `1.1.x` behaviour | Consequence |
| --- | --- | --- |
| Dependency claim | README said "pure bash"; code required `npm` to bump `package.json` | Credibility gap; dev-env friction |
| `-p` flag | README documented it as a boolean; implementation required an argument; tests expected an argument | Undefined user experience |
| `-v` validation | Accepted any string, happily tagged `vbanana` | Easy to corrupt a repo with a typo |
| Prerelease bump | Fell through to a warning and kept the input unchanged (e.g. `4.0.0-dev.6` → `4.0.0-dev.6`) | Pre-release workflows unusable without `-v` |
| Bump suggestion | Always `+1` on patch, even when commits were `feat!:` | Suggestion always wrong for meaningful releases |
| Safety | No way to preview a release; version bump commits happened unconditionally | Hard to build confidence / trust |
| File writes | `tmpfile` in CWD, `.temp` files left on failure | Dirty tree after aborted runs |
| Error surface | Hard-coded `exit 1` everywhere; no convention for scripted callers | CI wrappers couldn't distinguish bug vs. user error vs. precondition |
| Discoverability | Short flags only; no completions | High friction vs. modern CLI tools |

`2.0.0` closes every row above and adds the things that are table stakes in
comparable tools (long flags, completions, dry-run).

---

## 3. Goals

**G1 — Truthful pitch.** "Pure bash, `git` + `jq` only" must be literally
true at runtime. No `npm`, no `node`.

**G2 — Safe-by-default semantics.** Every mutating step must be previewable
via `--dry-run`. Interactive input that looks wrong must be rejected before
mutations begin, not after.

**G3 — Workflow parity with modern release tools** for the features that
matter to the target user: conventional-commit bump suggestion, prerelease
iteration, long options, shell completions.

**G4 — Stable machine contract.** Exit codes, flag semantics, and public
behaviour are documented and tested so CI wrappers and contributors can
depend on them.

**G5 — Developer ergonomics.** Contributors must be able to exercise the
real script (not just dry-run) without touching their working repo.

### 3.1 Non-goals

- **Not a CHANGELOG rewriter.** The existing `git log` dump is preserved as-is. A grouped, conventional-commit-aware changelog is scope for a later release.
- **Not a monorepo release manager.** One tool, one `package.json`, one bump. `-f` remains a secondary knob.
- **Not integrated with GitHub releases / npm publish.** Users wire those in via their own CI.
- **Not a config-file-driven tool.** All knobs are CLI flags or environment variables. A `.ver-bumprc` is out of scope.
- **No plugin/hook system** in this release (exit code `4` is reserved for it as a forward-compat signal).

---

## 4. Target users

1. **Solo maintainer / small team lead**, Git-native, shell-comfortable, wants a predictable release step in a one-file script they can read.
2. **CI author** embedding `ver-bump` in a GitHub Actions / GitLab CI step, needs stable exit codes and non-interactive flags.
3. **Contributor to `ver-bump` itself**, needs to exercise the tool end-to-end during development.

Out of audience: users who want a GUI, users who want the tool to also publish to a registry, users who want a plugin marketplace.

---

## 5. Requirements

Each requirement has an ID so tests and PRs can reference it.

### 5.1 Dependency surface

| ID | Requirement |
| --- | --- |
| **R-DEP-1** | Runtime dependencies are exactly `bash`, `git`, `jq`. Calling `ver-bump.sh` on a clean machine with only those three installed must succeed. |
| **R-DEP-2** | `npm` / `node` MUST NOT be invoked at runtime. Installing via `npm -g` remains supported but is one of several install paths, not a requirement. |
| **R-DEP-3** | Missing dependencies must exit `3` with a single-line error identifying the missing tool(s) and a hint on how to install them. |

### 5.2 Version input

| ID | Requirement |
| --- | --- |
| **R-VER-1** | `-v <value>` / `--version <value>` rejects any input that is not valid SemVer 2.0 before any mutation. |
| **R-VER-2** | Interactive prompt input is validated identically to `-v`. |
| **R-VER-3** | SemVer validation accepts prerelease (`-alpha.1`) and build metadata (`+sha.abc`). |

### 5.3 Bump suggestion

| ID | Requirement |
| --- | --- |
| **R-BUMP-1** | If the current version has a prerelease identifier, the suggestion is the current version with the trailing numeric counter incremented (or `.1` appended if there is no numeric counter). Build metadata is preserved. |
| **R-BUMP-2** | Otherwise, suggestion is based on Conventional Commits between the previous tag and `HEAD`: `<type>!:` or `BREAKING CHANGE:` → major; `feat:` → minor; else patch. |
| **R-BUMP-3** | If no previous tag exists for the current version, fall back to `patch`. Never produce an invalid SemVer. |
| **R-BUMP-4** | The chosen bump level is printed to the user before the interactive prompt, so the suggestion is never silent. |

### 5.4 Flags & options

| ID | Requirement |
| --- | --- |
| **R-OPT-1** | Every short flag has a matching GNU long form. Both `--name value` and `--name=value` parse. |
| **R-OPT-2** | Boolean long options reject `--name=value` with exit `2`. |
| **R-OPT-3** | Unknown long options exit `2` with a message naming the option. |
| **R-OPT-4** | `--` stops option processing; remaining argv is forwarded verbatim. |
| **R-OPT-5** | `--completions <bash\|zsh\|fish>` emits a shell completion script to stdout and exits `0`. It does not require a `package.json`, a git repo, or any mutation. Unknown shell exits `1`. |
| **R-OPT-6** | `-t <prefix>` / `--tag-prefix` overrides the tag prefix (default `v`). `-B <prefix>` / `--branch-prefix` overrides the branch prefix (default `release-`). The chosen prefix is used consistently by every step that reads or writes tags / branches. |

### 5.5 Dry-run

| ID | Requirement |
| --- | --- |
| **R-DRY-1** | With `-d` / `--dry-run`, no files are written, no `git add`/`commit`/`tag`/`push`/`branch`/`checkout` is executed. |
| **R-DRY-2** | Every side-effect that would have occurred is printed to stderr with a `[dry-run]` prefix, in the order it would have been executed. |
| **R-DRY-3** | Running `--dry-run` against this repo's own checkout must not modify the working tree (regression guard). |

### 5.6 Exit codes

`ver-bump` commits to the following contract:

| Code | Meaning |
| ---- | ------- |
| `0`  | Success |
| `1`  | Generic / unexpected error |
| `2`  | Usage or argument-parse error (bad/unknown flag, bad value) |
| `3`  | Precondition failure (missing `git`/`jq`, no `package.json`, dirty tree, missing tag, SemVer parse failure) |
| `4`  | Hook failure — **reserved** for user-supplied release hooks (future) |
| `5`  | User abort (declined an interactive prompt) |

| ID | Requirement |
| --- | --- |
| **R-EXIT-1** | Every user-visible error path must exit with a code from the table above, not a bare `exit 1`. |
| **R-EXIT-2** | The contract is versioned with the major release. It must not shift between `2.x` patch releases. |

### 5.7 Shell completions

| ID | Requirement |
| --- | --- |
| **R-COMP-1** | Emitted bash script must pass `bash -n`. Zsh script must pass `zsh -n`. Fish script must pass `fish -n` when fish is available. |
| **R-COMP-2** | Completions must offer every short and long flag. |
| **R-COMP-3** | After `-f`/`--file`, completion must restrict to `*.json`. |
| **R-COMP-4** | After `--completions`, completion must offer `bash zsh fish`. |
| **R-COMP-5** | Completions must be registered for both `ver-bump` and `ver-bump.sh` command names. |

### 5.8 GitHub release publishing

| ID | Requirement |
| --- | --- |
| **R-REL-1** | `--release` publishes a GitHub release for the newly-created tag by invoking `gh release create <tag> --notes "<notes>"` after the tag is pushed. |
| **R-REL-2** | Release notes are produced by running the command in `VER_BUMP_RELEASE_NOTES_CMD` and capturing its stdout. Default: `npx jv-k/releasetool`. |
| **R-REL-3** | `--release` requires `-p <remote>` / `--push <remote>`. Invoking `--release` without a push remote exits `2` with a message naming the missing flag. |
| **R-REL-4** | `gh` (and anything the notes command needs) are **conditional** dependencies: required only when `--release` is used. Missing → exit `3`. R-DEP-1/2 still hold for the default path: calls without `--release` must not invoke `gh`, `node`, or `npx`. |
| **R-REL-5** | Under `--dry-run`, no `gh` call is made and no release is published. The resolved `gh release create` invocation is printed to stderr with the `[dry-run]` prefix, including the tag and a clear indication of the notes source. The notes command itself MAY still run (it is expected to be read-only) so the preview reflects real output. |
| **R-REL-6** | If the notes command exits non-zero, `--release` aborts before calling `gh` and exits `1` with the captured stderr surfaced to the user. The tag push is not rolled back. |

### 5.9 Developer harness

| ID | Requirement |
| --- | --- |
| **R-DEV-1** | `pnpm dev` / `./dev/sandbox.sh` creates an isolated throwaway git repo, runs `ver-bump` inside it, and cleans up on exit (including Ctrl-C). |
| **R-DEV-2** | The sandbox's cleanup must never fire against the host repo. |
| **R-DEV-3** | Environment variables `SANDBOX_VERSION` and `SANDBOX_COMMITS` customise the starting version and seed commits respectively. `--keep` / `-k` preserves the temp dir for inspection. |

---

## 6. User stories

1. **US-1** — *As a solo maintainer*, I run `ver-bump`, see a bump suggestion derived from my recent commits, press Enter, and the release happens. Outcome: correct bump without me having to think.
2. **US-2** — *As a maintainer working on a pre-release*, I'm on `4.0.0-dev.6`. I run `ver-bump`, see `4.0.0-dev.7` suggested, press Enter.
3. **US-3** — *As a cautious maintainer*, I run `ver-bump --dry-run` first, read the side-effects, satisfy myself nothing surprising is about to happen, then re-run without `--dry-run`.
4. **US-4** — *As a CI author*, I run `ver-bump -v 1.2.3 -p origin -n` in a GH Actions job and branch on exit code: `0` succeeds, `2` fails the workflow with an "invalid input" message, `3` fails with a "precondition" message.
5. **US-5** — *As a new user*, I pipe `ver-bump --completions zsh` into `_ver-bump` on my `fpath`, restart my shell, and get tab-completion for every flag.
6. **US-6** — *As a contributor*, I clone the repo, run `pnpm dev`, and can exercise the real release flow end-to-end without touching my clone's working tree.
7. **US-7** — *As someone with a typo-prone setup*, I run `ver-bump -v banana` and get exit `2` with a clear message before anything is mutated.
8. **US-8** — *As a user with a custom tagging convention*, I run `ver-bump --tag-prefix=release/` and get `release/1.2.3` tags instead of `v1.2.3`.

---

## 7. Acceptance / success criteria

- **AC-1** All `R-*` requirements above have at least one bats test exercising them.
- **AC-2** Shellcheck (with `-x`) passes on `ver-bump.sh`, `lib/*.sh`, and `dev/sandbox.sh` with zero warnings.
- **AC-3** The test suite (`pnpm tests:run`) reports `0 failures`.
- **AC-4** Running `./ver-bump.sh --dry-run -v 1.1.9` against this repo leaves `git status --porcelain` byte-identical to its pre-run state.
- **AC-5** A fresh container with only `bash`, `git`, `jq` installed can run `./ver-bump.sh --dry-run -v 0.0.1` against a minimal repo without missing-dependency errors.
- **AC-6** `ver-bump --completions bash | bash -n` exits `0`; same for `zsh -n`.
- **AC-7** `README.md` and `./ver-bump.sh --help` enumerate the same set of flags.

---

## 8. Backward compatibility & migration

### 8.1 Breaking changes

- **B-1 — `-v` rejects non-SemVer.** Existing calls like `-v banana` will fail with exit `2`. This was never guaranteed; old behaviour tagged a corrupt version. **Migration**: fix the input.
- **B-2 — Exit codes change.** `1.1.x` used `exit 1` for nearly every error. `2.0.0` uses `2`/`3`/`5` for usage, precondition, and user-abort failures. **Migration**: CI wrappers that branched on exit code `0` vs. non-zero are unaffected; wrappers that branched on specific non-zero codes must update.
- **B-3 — `npm` no longer invoked.** `npm version`'s lifecycle scripts (`preversion`, `version`, `postversion`) will no longer fire as a side-effect of running `ver-bump`. **Migration**: if you relied on them, invoke them explicitly or move the logic into a separate step.

### 8.2 Non-breaking

- Every short flag keeps its argument contract from `1.1.x` (including `-p`, which always required an argument in the implementation — the docs were wrong).
- Tag prefix still defaults to `v`; branch prefix still defaults to `release-`.
- `CHANGELOG.md` format unchanged.

### 8.3 Deprecations carried forward

- The `VERSION` file remains deprecated (already signalled since `0.2.0`). Will be removed in `3.0.0`.

---

## 9. Dependencies

| | |
| --- | --- |
| Required at runtime | `bash ≥ 4.0`, `git`, `jq ≥ 1.5` |
| Required for tests | `bats-core`, `bats-support`, `bats-assert` |
| Required for linting | `shellcheck ≥ 0.8` |
| Conditional at runtime | `gh` and the command resolved by `VER_BUMP_RELEASE_NOTES_CMD` (default `npx jv-k/releasetool` → implies `node`) — only when `--release` is used |
| Optional | `pnpm` or `npm` (install + `dev` scripts); `zsh`, `fish` (to verify their completion scripts locally); `terminalizer` (regenerate demo GIF) |

---

## 10. Testing strategy

- **Unit level** — `test/ver-bump.bats` covers every requirement in §5. Minimum **60 tests** at release; currently at 54 before this PRD is merged.
- **Contract level** — exit-code table is asserted per branch in `fail()` unit tests.
- **Regression** — running the test suite must not mutate the host repo. `git status --porcelain` before and after must match (add a `trap` in the test harness to enforce this).
- **Emitted artefacts** — every completion script is syntax-checked by invoking `bash -n` / `zsh -n` on the emitted output.
- **Sandbox** — `pnpm dev` is the primary tool for exploratory E2E testing.
- **CI matrix** — shellcheck on `ubuntu-latest`, `macos-latest`, `windows-latest` (existing). Add bats on Ubuntu + macOS.

---

## 11. Release plan

1. Land remaining uncommitted work on `develop` as `fix:` / `feat:` commits following Conventional Commits.
2. Draft `CHANGELOG.md` entry for `2.0.0` summarising each `R-*` bucket.
3. Cut a `release-2.0.0` branch via `ver-bump` itself (dog-fooding against the sandbox first).
4. Open PR to `main`.
5. Tag `v2.0.0`, publish GitHub release with the PRD changelog.
6. `npm publish` (optional — install path remains supported).

---

## 12. Open questions

1. **Q-1** Do we want a `--yes` / `-y` flag to auto-accept the bump suggestion and bypass the interactive prompt entirely, for use in CI where `-v` is awkward to compute? *(Proposed: defer to 2.1.)*
2. **Q-2** Should `--dry-run` imply `--no-push` even when `-p <remote>` is passed, to prevent accidental network calls? *(Current behaviour: dry-run intercepts the push call; user is never prompted for it. Acceptable.)*
3. **Q-3** Should `-f <file>` default to also bumping the repo's `package-lock.json` if present, given that `do-packagefile-bump` already does? *(Current behaviour: yes, built-in. `-f` is for additional files.)*

---

## 13. Future work (post-2.0)

- **Grouped CHANGELOG** from Conventional Commits (the other major friction point vs. modern tools).
- **Hook system** (exit code `4` is reserved): `pre-bump`, `post-tag`, `post-push`.
- **`--major` / `--minor` / `--patch`** explicit override switches.
- **Config file** (`.ver-bumprc` or `ver-bump` section in `package.json`) for defaults.
- **Non-npm install paths** (Homebrew formula, `basher`).

---

## 14. Appendix — flag inventory (for review completeness)

Exactly the flags shipping in `2.0.0`:

| Short | Long | Takes arg | Purpose |
| :---: | --- | :---: | --- |
| `-v` | `--version` | ✓ | Manual SemVer (validated) |
| `-m` | `--message` | ✓ | Annotated-tag message |
| `-f` | `--file` | ✓ | Extra JSON file to bump (repeatable) |
| `-p` | `--push` | ✓ | Push remote |
| `-t` | `--tag-prefix` | ✓ | Tag prefix override |
| `-B` | `--branch-prefix` | ✓ | Branch prefix override |
| `-d` | `--dry-run` | | Preview-only mode |
| `-n` | `--no-commit` | | Disable commit (and tag + push) |
| `-b` | `--no-branch` | | Disable release branch creation |
| `-c` | `--no-changelog` | | Disable CHANGELOG.md update |
| `-l` | `--pause-changelog` | | Pause before commit |
| `-h` | `--help` | | Help output |
| — | `--completions` | ✓ | Emit completion script |
| — | `--release` | | Publish GitHub release for the new tag (requires `-p`) |
| — | `--` | | Stop option processing |
