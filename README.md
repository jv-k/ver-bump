# VerBump

**A pure-bash release tool for any Git repo.**

- **Suggests the right bump** — reads your [Conventional Commits](https://www.conventionalcommits.org/) to propose the next [SemVer](https://semver.org/), prereleases included
- **Writes the changelog** — flat or grouped by commit type, with commit / PR / compare links
- **Bumps any file** — `package.json`, `pyproject.toml`, `Chart.yaml`, a Go const, any `{{version}}` text pattern
- **Three workflows** — tag in place, cut a release branch, or open a GitHub PR
- **Safe by default** — preflight checks, `--dry-run` previews every side-effect, `--undo` rolls back
- **Nothing to install but bash** — `git` and `jq` are the only runtime dependencies

<div align="center">

[![bash 3.2+](https://img.shields.io/badge/bash-3.2%2B-1f425f?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/) [![CI](https://img.shields.io/github/actions/workflow/status/jv-k/VerBump/ci.yml?branch=main&label=CI&logo=githubactions&logoColor=white)](https://github.com/jv-k/VerBump/actions/workflows/ci.yml?query=branch%3Amain) [![CodeFactor](https://www.codefactor.io/repository/github/jv-k/VerBump/badge)](https://www.codefactor.io/repository/github/jv-k/VerBump) [![npm version](https://img.shields.io/npm/v/ver-bump?logo=npm&color=cb3837)](https://www.npmjs.com/package/ver-bump) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img src="https://raw.githubusercontent.com/jv-k/VerBump/main/img/screenshot.png" alt="VerBump --help output: the header logo and the full flag reference, covering version input, bump levels, prerelease, changelog, tag, push, and GitHub release options.">

</div>

## Quickstart

### Install with curl (no Node required):

```sh
curl -fsSL https://raw.githubusercontent.com/jv-k/VerBump/main/install.sh | bash
```

### Install from a registry (npm / pnpm):

```sh
pnpm add -g verbump
```

or

```sh
npm install -g verbump
```

### Manual install (clone and symlink):

```sh
git clone https://github.com/jv-k/VerBump.git ~/.local/share/verbump
ln -s ~/.local/share/verbump/VerBump.sh ~/.local/bin/VerBump   # ensure ~/.local/bin is on $PATH
```

See [Installation](#installation) for checksum verification, version pinning, prefix options, and the Homebrew path.

### Use it in your repo folder:

```sh
cd your-repo
VerBump --dry-run   # preview a release end-to-end, changes nothing
VerBump             # cut it: reads commits, suggests a bump, prompts before pushing
```

## Demo

<div align="center">
  <img src="https://raw.githubusercontent.com/jv-k/VerBump/main/img/demo.gif" alt="Animated demo: VerBump reads commits, sets the version, updates package.json and CHANGELOG, commits, tags in place, prompts before pushing, then pushes the tag to origin.">
</div>

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
<details>
<summary>Details</summary>

- [Why `VerBump`?](#why-verbump)
- [How it works](#how-it-works)
- [Features](#features)
  - [Misc Features](#misc-features)
- [Requirements](#requirements)
  - [Platform support](#platform-support)
- [Installation](#installation)
  - [Install script](#install-script)
  - [npm / pnpm](#npm--pnpm)
  - [Manual install](#manual-install)
  - [Homebrew](#homebrew)
  - [Basher](#basher)
- [Workflows](#workflows)
- [Migrating from 1.x](#migrating-from-1x)
- [Migrating from ver-bump](#migrating-from-ver-bump)
- [Options](#options)
  - [Choosing the new version](#choosing-the-new-version)
  - [Bumping files](#bumping-files)
  - [Commit, tag & changelog](#commit-tag--changelog)
  - [Push, branch & publish](#push-branch--publish)
  - [Skip preflight checks](#skip-preflight-checks)
  - [Undo, run mode & help](#undo-run-mode--help)
- [Configuration](#configuration)
  - [Grouped changelog (`CHANGELOG_STYLE=grouped`)](#grouped-changelog-changelog_stylegrouped)
  - [Commit message template (`COMMIT_MSG_TEMPLATE`)](#commit-message-template-commit_msg_template)
- [Bumping non-Node projects and extra files](#bumping-non-node-projects-and-extra-files)
- [Version suggestion](#version-suggestion)
- [Dry-run](#dry-run)
- [Release hooks](#release-hooks)
- [Exit codes](#exit-codes)
- [Shell completions](#shell-completions)
- [Example](#example)
- [Development](#development)
- [Tests](#tests)
- [Contributing](#contributing)
- [License](#license)

</details>
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Why `VerBump`?

I built VerBump because cutting a release shouldn't require installing a bigger toolchain than the thing being released.

Release tooling has drifted into two camps: fully automated CI machinery like [semantic-release](https://github.com/semantic-release/semantic-release) — powerful, but Node-only, deliberately prompt-free, and a deep dependency tree for what is ultimately a git tag — and single-purpose bumpers like [bump-my-version](https://github.com/callowayproject/bump-my-version) that rewrite a version string and stop. I wanted the middle of that spectrum, for every repo and not just the Node ones: a tool that reads your Conventional Commits and *suggests* the right SemVer bump, then writes the changelog, tags, pushes, and opens the PR or GitHub release — with every side-effect previewable via `--dry-run`, reversible via `--undo`, and nothing to install beyond standard CLI tools: `git` and `jq`.

<!-- If VerBump isn't your jam, the notable neighbours are: [semantic-release](https://github.com/semantic-release/semantic-release) for fully hands-off releases from CI, [release-it](https://github.com/release-it/release-it) as the closest interactive cousin when a Node dependency is fine, [release-please](https://github.com/googleapis/release-please) for Google's release-PR flow on GitHub, [changesets](https://github.com/changesets/changesets) for monorepos, [np](https://github.com/sindresorhus/np) for interactive npm publishing, and [GoReleaser](https://goreleaser.com) for building and shipping artifacts once a tag exists — that last one pairs well with VerBump rather than replacing it. -->

## How it works

A single `VerBump` run walks through five phases:

| Phase | What happens |
| --- | --- |
| 1. **Verify** | Confirms commits exist, the working tree is clean, the remote is in sync, and the current branch is allowed to release. |
| 2. **Choose a version** | Suggests the next SemVer from your Conventional Commits, or takes an explicit `-v <version>`, a forced `--major` / `--minor` / `--patch`, or a prerelease `--preid <id>`. |
| 3. **Bump** | Writes the new version into `package.json` (and any `--bump` targets), then regenerates `CHANGELOG.md`. |
| 4. **Commit & tag** | Commits the changes on the current branch and creates an annotated (or `--sign`ed) tag. |
| 5. **Push & publish** | Optionally pushes the commit and tag. With `--pr` / `--release` it opens a pull request or a GitHub release. |

Every side-effecting step honours `--dry-run`, and preconditions fail with a [documented exit code](#exit-codes) and an actionable hint.

## Features

| # | Feature | Description |
| :--: | --- | --- |
| 1 | ✅ **Zero real dependencies** | Pure bash. Only `git` and `jq` are needed to run it. |
| 2 | ✅ **Multi-format file bumps** | Keeps `package.json`, `pyproject.toml`, a Go const, a Helm chart, or any text file in sync with the tag via `--bump`. |
| 3 | ✅ **Smart bump suggestion** | Reads Conventional Commits since the last tag to propose **major** / **minor** / **patch**, and advances prerelease counters.<br />Example: `4.0.0-dev.6 → 4.0.0-dev.7` |
| 4 | ✅ **Automatic CHANGELOG** | Generates and updates `CHANGELOG.md`: a flat list, or Conventional-Commit-**grouped** sections with commit/PR/compare links |
| 5 | ✅ **Three release workflows** | 1. **Tag-in-place** (default)<br />2. Release **branch** (`--branch`)<br />3. Release **PR** (`--pr`)<br />Pick per-run or set a default. (See [Workflows](#workflows).) |
| 6 | ✅ **Safety preflights** | Refuses to release on a dirty tree, an out-of-sync remote, or a disallowed branch, each individually overridable. |
| 7 | ✅ **Dry-run** | `--dry-run` prints every side-effect (file write, `git add`, commit, tag, push) without executing any of them. |
| 8 | ✅ **Undo** | `--undo` rolls back a local release (tag + release branch) before anything is pushed. |
| 9 | ✅ **GitHub releases & PRs** | `--release` publishes a GitHub release for the new tag. `--pr` opens a pull request. Both use the optional [`gh`](https://cli.github.com) CLI. |

### Misc Features

| # | Feature | Description |
| :--: | --- | --- |
| 10 | ✅ **Release hooks** | `PRE_BUMP_CMD` / `POST_TAG_CMD` run your tests before the bump and build artifacts after the tag. |
| 11 | ✅ **Signed tags** | Annotated tags by default. `--sign` produces [GPG-signed tags](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work) using your git config. |
| 12 | ✅ **Shell completions** | Built-in completion scripts for **bash**, **zsh**, and **fish**. |
| 13 | ✅ **SemVer 2.0 validation** | Every version input is validated against the SemVer 2.0 spec, including `-prerelease` and `+build` metadata. Typos fail fast. |

## Requirements

**Bash 3.2+**, a **Git repository**, and **`git`** + **`jq`** on your `PATH`.

The [`gh`](https://cli.github.com) CLI is an optional dependency, used only by `--pr` and `--release`.

### Platform support

`VerBump` is pure bash, so it runs wherever bash does:

| Platform | Status |
| --- | --- |
| **Linux, macOS** | Tested in CI. The full suite runs on both for every change. |
| **WSL** | Expected to work. It is Linux underneath, with the same `bash`, `git`, and `jq`. |
| **Git Bash / MSYS2** | Best effort, untested. Should work, though CRLF line endings are the usual suspect if it does not. |

## Installation

### Install script

Downloads the latest GitHub release, verifies its published sha256 checksum, and installs to `~/.local` (`share/verbump/` for the files, `bin/VerBump` as the command). Re-running upgrades in place, and a failed install restores the previous one:

```sh
curl -fsSL https://raw.githubusercontent.com/jv-k/VerBump/main/install.sh | bash
```

To pin a version or change the prefix, insert `VERBUMP_INSTALL_VERSION=<x.y.z>` and/or `VERBUMP_PREFIX=<dir>` before the final `bash` — or download the script and run `bash install.sh --version <x.y.z> --prefix <dir>`.

### npm / pnpm

```sh
pnpm add -g verbump
```

```sh
npm install -g verbump
```

> The npm package is **`verbump`** (lowercase — npm forbids uppercase); it installs the **`VerBump`** command. So: `npm i -g verbump`, then run `VerBump`.

### Manual install

Clone and symlink the script:

```sh
git clone https://github.com/jv-k/VerBump.git ~/.local/share/verbump
ln -s ~/.local/share/verbump/VerBump.sh ~/.local/bin/VerBump   # ensure ~/.local/bin is on $PATH
```

### Homebrew

```sh
brew install jv-k/tap/verbump
```

Installs from the [`jv-k/tap` tap](https://github.com/jv-k/homebrew-tap) with the `bash` and `jq` dependencies included. The command it installs is `VerBump`, and the tap's formula tracks the latest stable release automatically.

### Basher

> [Coming soon](https://github.com/jv-k/VerBump/issues/39)

## Workflows

`VerBump` supports three release workflows. Pick one per-run with a flag, or set a default in [`.verbumprc`](#configuration):

| Workflow | Command | What it does |
| --- | --- | --- |
| **Tag-in-place** *(default)* | `VerBump` | Bumps files, writes CHANGELOG, commits, and tags **the current branch**. No branch is created. |
| **Release branch** | `VerBump --branch` | Cuts a `release-<version>` branch (the [Git branch-based workflow](https://nvie.com/posts/a-successful-git-branching-model/)), commits and tags there, and leaves the merge back to you. |
| **Release PR** | `VerBump --pr` | Like `--branch`, then pushes and opens a pull request via the [`gh`](https://cli.github.com) CLI. Implies a push to `origin` (override with `-p <remote>`). |

The `--pr` base branch resolves in this order: `--base <branch>`, then `PR_BASE` from `.verbumprc`, then the branch you ran VerBump from, then the remote's default branch.

## Migrating from 1.x

**The default changed.** VerBump 1.x always cut a `release-<version>` branch. 2.0 **tags the current branch in place** by default. Pass `--branch` to keep the old behaviour. The old `-b` / `--no-branch` flag is now a no-op (kept so existing scripts don't break).

## Migrating from ver-bump

The project was renamed from `ver-bump` to **VerBump** in 4.0. The command, repo, and brand are `VerBump`; the npm package and config file are lowercase `verbump`. What to update:

| Was | Now |
| --- | --- |
| command `ver-bump` | `VerBump` |
| `npm i -g ver-bump` | `npm i -g verbump` *(new package; old one deprecated)* |
| `.ver-bumprc` | `.verbumprc` |
| `VER_BUMP_*` env vars | `VERBUMP_*` |
| `github.com/jv-k/ver-bump` | `github.com/jv-k/VerBump` *(old URLs redirect)* |

`PRE_BUMP_CMD` / `POST_TAG_CMD` and the default tag prefix are unchanged. An existing `ver-bump` install keeps working until you remove it.

## Options

```sh
VerBump [-v <version>] [options]
```

Every option has a short form and a GNU-style long form. Long forms accept `--name value` or `--name=value`. The groups below match `VerBump --help`.

### Choosing the new version

| Flag | Description |
| --- | --- |
| `-v <version>`, `--version <version>` | Set an explicit SemVer as the new version (skips the suggestion and prompt). |
| `-v`, `--version` *(no value)* | Print VerBump's own version and exit. |
| `--major` | Force a major bump from the current version. |
| `--minor` | Force a minor bump from the current version. |
| `--patch` | Force a patch bump from the current version. |
| `--preid <id>` | Start or advance a prerelease line (conflicts with `-v`). With a level: bump it, then enter `<id>.1` (`1.2.3 --major --preid rc → 2.0.0-rc.1`). Alone on a prerelease: same id increments the counter, a different id resets to `.1`. |

The three bump levels are mutually exclusive with each other and with `-v`. Without `--preid` they drop any existing prerelease/build metadata and bump the stable core (`1.2.3-dev.5 --patch → 1.2.4`) — the full rules live in [Version suggestion](#version-suggestion).

### Bumping files

| Flag | Description |
| --- | --- |
| `--source <file.json>` | Version source and primary bump target (default: `package.json`). If the file is missing, the current version derives from the latest matching git tag. |
| `--bump <spec>` | Also bump a JSON / TOML / YAML / text file. Repeatable. `<file>` (top-level `.version` by file type), `<file>:@<path>` (explicit dotted path, e.g. `pyproject.toml:@tool.poetry.version`), or `'<file>:<pattern>'` (text search/replace, where the pattern must contain `{{version}}`). |
| `-f`, `--file <file.json>` | Also bump `"version"` in this JSON file. Repeatable. Superseded by `--bump`. |

### Commit, tag & changelog

| Flag | Description |
| --- | --- |
| `-m`, `--message <message>` | Custom annotated-tag release message. |
| `-t`, `--tag-prefix <prefix>` | Override the tag prefix (default: `v`). |
| `--sign` | Create a signed tag (`git tag -s`, using your git signing config). |
| `-c`, `--no-changelog` | Disable updating `CHANGELOG.md`. |
| `-l`, `--pause-changelog` | Pause before commit so `CHANGELOG.md` can be edited. |
| `-n`, `--no-commit` | Disable commit (and tag and push) after bumping files. |

### Push, branch & publish

| Flag | Description |
| --- | --- |
| `-p`, `--push <remote>` | Push the commit and tag (and release branch, with `--branch` / `--pr`) to `<remote>` at the end of the run. |
| `--pr` | Branch, push, and open a release PR via `gh` (GitHub-only, and implies push to origin). |
| `--base <branch>` | Base branch for `--pr` (GitHub-only, default: the branch you ran VerBump from). |
| `--release` | Publish a GitHub release for the new tag (GitHub-only, requires `-p`, uses `gh`). |
| `--branch` | Cut a `release-<version>` branch instead of tagging the current branch in place. |
| `-B`, `--branch-prefix <prefix>` | Override the branch prefix (default: `release-`). |
| `-b`, `--no-branch` | Deprecated no-op. Tag-in-place is the default now. |

### Skip preflight checks

| Flag | Description |
| --- | --- |
| `--allow-dirty` | Skip the clean-working-tree check (untracked files never trigger it). |
| `--allow-empty` | Release even with no new commits since the previous tag. |
| `--no-fetch` | Skip the remote-sync preflight (no fetch / behind-upstream check). |
| `--no-hooks` | Skip the `PRE_BUMP_CMD` / `POST_TAG_CMD` release hooks for this run. |

### Undo, run mode & help

| Flag | Description |
| --- | --- |
| `--undo [<version>]` | Delete an unpushed release's tag, plus its `release-X.Y.Z` branch when one was cut; with tag-in-place the bump commit stays on your branch. Refuses if pushed or dirty. |
| `-d`, `--dry-run` | Print every side-effect without executing. |
| `-y`, `--yes` | Skip interactive confirmation prompts. |
| `-q`, `--quiet` | Suppress decoration and print only the new version on stdout (needs `-y`, `-v`, a bump level, or `--preid`). |
| `-h`, `--help` | Show the help message (paged through `less`/`more` when the terminal is short). |
| `--completions <shell>` | Emit a completion script for bash, zsh, or fish. |
| `--install-completions[=<shell>]` | Install the completion script (auto-detects the shell). |

**What `--undo` does and doesn't undo.** With tag-in-place (the default), `--undo` deletes the tag but the bump commit stays on your branch — for a full rollback, follow it with `git reset --hard HEAD~1` (run `git log -1` first to confirm HEAD is the bump commit). With `--branch` / `--pr` the undo is complete, because the bump commit lives on the release branch it deletes. Once anything has been pushed — or a release branch has been merged — `--undo` refuses: delete the remote tag/branch and `git revert` the bump commit instead.

## Configuration

`VerBump` reads a `.verbumprc` file, walking up from your current directory toward `/`. The first file found is shell-sourced, so a team can commit its defaults at the repo root. Precedence, highest to lowest: **CLI flag** > **environment variable** > **`.verbumprc`** > **built-in default**.

<details>
<summary><b>All config keys</b>, security, grouped changelog, and commit templates</summary>

Every key maps 1:1 to an existing global:

| Key | Equivalent flag | Default |
| --- | --- | --- |
| `TAG_PREFIX` | `-t` / `--tag-prefix` | `v` |
| `REL_PREFIX` | `-B` / `--branch-prefix` | `release-` |
| `PUSH_DEST` | `-p` / `--push` | `origin` |
| `SOURCE_FILE` | `--source` | `package.json` |
| `BUMP_FILES` | `--bump` | *unset* (no extra targets) |
| `COMMIT_MSG_PREFIX` | *(no flag)* | `"chore: "` |
| `COMMIT_MSG_TEMPLATE` | *(no flag)* | *unset* (prefix + generated file list) |
| `CHANGELOG_STYLE` | *(no flag)* | `flat` |
| `FLAG_BRANCH` | `--branch` | *unset* (tag in place) |
| `PR_BASE` | `--base` | *(auto-detect)* |
| `FLAG_NOCHANGELOG` | `-c` / `--no-changelog` | *unset* |
| `FLAG_CHANGELOG_PAUSE` | `-l` / `--pause-changelog` | *unset* |
| `ALLOW_DIRTY` | `--allow-dirty` | *unset* (dirty tree refuses) |
| `NO_FETCH` | `--no-fetch` | *unset* (fetch + behind-upstream check) |
| `RELEASE_BRANCHES` | *(no flag)* | *unset* (release from any branch) |
| `TAG_SIGN` | `--sign` | `false` (annotated, unsigned tag) |
| `PRE_BUMP_CMD` | *(no flag, see [Release hooks](#release-hooks))* | *unset* (no hook) |
| `POST_TAG_CMD` | *(no flag, see [Release hooks](#release-hooks))* | *unset* (no hook) |

```sh
# .verbumprc — committed at repo root
TAG_PREFIX="release/"
REL_PREFIX="hotfix-"
PUSH_DEST="upstream"
COMMIT_MSG_PREFIX="release: "
FLAG_NOCHANGELOG=true
RELEASE_BRANCHES="main develop release/*"
```

`RELEASE_BRANCHES` is a space-separated list of glob patterns naming the branches a release may be cut from. When set, running VerBump from any other branch (or from a detached HEAD) exits with code 3. It is a guard, not a prompt, so `--yes` does not bypass it. Clear it for a single run with an empty environment override, since env beats the file: `RELEASE_BRANCHES= VerBump …`

**Security.** `VerBump` *sources* this file as shell, so do not commit one you wouldn't execute. As a safeguard, it refuses to load a world-writable rc and exits with code 3. Run `chmod 644 .verbumprc` to fix it.

### Grouped changelog (`CHANGELOG_STYLE=grouped`)

By default the CHANGELOG section is a flat list of commit subjects (unchanged since 1.x). Set `CHANGELOG_STYLE=grouped`, in `.verbumprc` or as an environment variable (there is no CLI flag), to group commits by Conventional Commit type instead, with commit, PR and compare links when the remote is on GitHub:

```markdown
## [1.1.0](https://github.com/acme/widget/compare/v1.0.0...v1.1.0) (2026-07-15)

### Breaking Changes

- drop node 14 ([2296697](https://github.com/acme/widget/commit/2296697))

### Features

- **api:** add endpoint (#12) ([a746a76](https://github.com/acme/widget/commit/a746a76))

### Fixes

- **net:** retry on 503 ([7a1ecc3](https://github.com/acme/widget/commit/7a1ecc3))

### Other

- updated package.json, updated CHANGELOG.md, bumped 1.0.0 -> 1.1.0
- plain non-conventional message ([e0d3107](https://github.com/acme/widget/commit/e0d3107))
```

Sections appear in that order and empty ones are omitted. Breaking changes are detected from a `<type>!:` subject or a `BREAKING CHANGE:` footer. Everything that isn't `feat`/`fix`/breaking (including commits that don't follow Conventional Commits at all) lands under **Other**, so nothing is ever dropped. Scopes render as a bold `**scope:**` prefix. With a non-GitHub remote (or no remote) the same grouping renders as plain text without links. Any other `CHANGELOG_STYLE` value falls back to `flat`.

### Commit message template (`COMMIT_MSG_TEMPLATE`)

By default the bump commit's message is `COMMIT_MSG_PREFIX` plus a generated list of what changed:

```text
chore: updated package.json, updated CHANGELOG.md, bumped 1.1.7 -> 1.1.8
```

Set `COMMIT_MSG_TEMPLATE`, in `.verbumprc` or as an environment variable (there is no CLI flag), to replace the **whole** message with your own template. When it is set, `COMMIT_MSG_PREFIX` is **ignored**: the template owns the entire message, prefix included.

```sh
# .verbumprc — single quotes are required so your shell / the rc loader
# doesn't expand the placeholders before VerBump sees them
COMMIT_MSG_TEMPLATE='chore(release): v${version}'
```

Available placeholders:

| Placeholder | Replaced with | Example |
| --- | --- | --- |
| `${version}` | the new version | `1.1.8` |
| `${prev_version}` | the previous version | `1.1.7` |
| `${tag}` | the new tag (`TAG_PREFIX` + version) | `v1.1.8` |
| `${files}` | the generated changed-file list | `updated package.json, updated CHANGELOG.md` |

Substitution is a literal string replacement. The template is **never** evaluated as shell, so `$(...)`, backticks, and unknown `${...}` placeholders pass through as literal text. The CHANGELOG's entry for the bump commit uses the same rendered message (first line, in both `flat` and `grouped` styles), so the two never drift apart. The template applies to the bump commit only. The annotated tag's message keeps its own knob, `-m` / `--message`.

</details>

## Bumping non-Node projects and extra files

No `package.json`? VerBump reads the current version from your latest matching git tag. Point `--source` at another manifest, or keep any JSON / TOML / YAML / text file in lock-step with the tag via `--bump`.

<details>
<summary><b>Non-Node repos</b>, <code>--bump</code> specs, and <code>BUMP_FILES</code></summary>

**Non-Node repos.** Rust, Python, Go, anything SemVer works out of the box. If there is no version file, VerBump reads the current version from your latest matching git tag, runs the same Conventional-Commit suggestion machinery, and cuts a CHANGELOG and tag release (skipping the commit when there is nothing to commit). Keep a JSON manifest like `composer.json`? Point `--source` at it (or set `SOURCE_FILE` in `.verbumprc`) and it becomes both the version source and the file that gets bumped.

**Bumping stack-specific files.** Keep the version in a `pyproject.toml`, a Go const, a Helm `Chart.yaml`, or any text file in lock-step with the tag via `--bump` (repeatable), or declare the targets once in `.verbumprc` as `BUMP_FILES`:

```sh
# Text pattern — no extra tool; rewrites only the matching line.
# Works for a Go const, a Python __version__, a Makefile, a Dockerfile, …
VerBump --bump 'main.go:Version = "{{version}}"'
VerBump --bump 'src/mypkg/__init__.py:__version__ = "{{version}}"'

# Structured dotted path — JSON via jq (built in), TOML/YAML via the
# jq-based yq suite (tomlq / yq) when installed.
VerBump --bump pyproject.toml:@project.version --bump Chart.yaml:@version

# Or declare them once (newline-separated) — every run keeps them in sync:
# .verbumprc
BUMP_FILES="main.go:Version = \"{{version}}\"
src/mypkg/__init__.py:__version__ = \"{{version}}\"
pyproject.toml:@project.version
Chart.yaml:@version"
```

Match your file's exact quoting and spacing, because the pattern is a literal search. `__version__='1.2.3'` (single quotes, no spaces) needs `--bump "…/__init__.py:__version__='{{version}}'"`.

A bare `--bump <file>` bumps the file's top-level `.version` (JSON/TOML/YAML). `@<path>` targets any dotted key, including a nested one that the JSON `.version` default can't reach. A `{{version}}` text pattern covers everything else with no dependency. Same-version and missing files are skipped with a notice, and every change is staged and listed in the bump commit.

</details>

## Version suggestion

When `-v` / `--version` is omitted, `VerBump` suggests the next version: it advances a prerelease counter, or reads Conventional Commits since the last tag to pick **major** / **minor** / **patch**.

<details>
<summary><b>Suggestion rules</b>, forced bumps, and prerelease lines</summary>

**Prereleases.** If the current version has a `-<id>` segment, the trailing numeric counter is bumped (or `.1` is appended if there isn't one). Build metadata after `+` is preserved:

| Current | Suggested |
| --- | --- |
| `4.0.0-dev.6` | `4.0.0-dev.7` |
| `4.0.0-rc.9` | `4.0.0-rc.10` |
| `1.0.0-alpha` | `1.0.0-alpha.1` |
| `2.1.0-beta.3+sha.abc` | `2.1.0-beta.4+sha.abc` |

**Stable versions.** VerBump inspects Conventional Commits since the previous tag:

- `feat!:` / `<type>!:` / `BREAKING CHANGE:` in body → **major**
- `feat:` → **minor**
- anything else (or no previous tag) → **patch**

You can always override the suggestion at the interactive prompt, or pass `-v <version>` to skip the prompt entirely. Values passed to `-v` are validated against SemVer 2.0, so typos like `VerBump -v banana` fail fast.

For a non-interactive forced bump that doesn't require typing the full version, use `--major` / `--minor` / `--patch`. They bump the current version's matching component, drop any prerelease/build metadata (`1.2.3-dev.5 --patch` → `1.2.4`), and are mutually exclusive with each other and with `-v`. Combining more than one exits with code `2`.

To **enter** or **advance** a prerelease line, add `--preid <id>`:

| Command | Current | Result |
| --- | --- | --- |
| `--major --preid rc` | `1.2.3` | `2.0.0-rc.1` |
| `--patch --preid beta` | `1.2.3` | `1.2.4-beta.1` |
| `--preid dev` (alone) | `4.0.0-dev.6` | `4.0.0-dev.7` (same id → counter++) |
| `--preid rc` (alone) | `2.0.0-alpha.3` | `2.0.0-rc.1` (different id → reset) |
| `--preid rc` (alone) | `1.2.3` (stable) | exit `2`, ambiguous (combine with `--major`/`--minor`/`--patch`) |

`--preid` is mutually exclusive with `-v`, and `<id>` is validated against the SemVer prerelease grammar before anything is mutated. To graduate a prerelease back to a stable release, `--major`/`--minor`/`--patch` without `--preid` bumps from the stable core as usual, or pass an explicit `-v <version>` or accept the interactive prompt.

</details>

## Dry-run

Pass `-d` / `--dry-run` to preview a release end-to-end without touching anything: no files written, no `git add`, no commit, no tag, no push:

```sh
$ VerBump --dry-run
...
[dry-run] would set .version = '1.0.1' in package.json
[dry-run] git add package.json
[dry-run] would replace CHANGELOG.md with: ...
[dry-run] would run: git commit -m 'chore: updated package.json, ...'
[dry-run] would run: git tag -a v1.0.1 -m 'Tag version 1.0.1.'
```

Combine with `--no-commit` / `--no-changelog` to narrow the preview down to just the steps you want to see.

## Release hooks

`PRE_BUMP_CMD` runs after the preflights pass and before any file is touched, and `POST_TAG_CMD` runs after the tag is created. A non-zero hook exit stops the release with code 4. Set either in `.verbumprc` or the environment (there is deliberately no CLI flag).

<details>
<summary><b>Hook timing</b>, environment variables, quoting, and dry-run behaviour</summary>

| Key | Runs | On non-zero exit |
| --- | --- | --- |
| `PRE_BUMP_CMD` | after **all** Verify preflights pass, before any file is touched | exit `4`, nothing mutated |
| `POST_TAG_CMD` | after the tag is created, before push / `--pr` / `--release` | exit `4`. The commit and tag are kept, recover with `--undo`. |

```sh
# .verbumprc
PRE_BUMP_CMD="npm test"
POST_TAG_CMD="npm run build:artifacts"
```

Hook stdout/stderr stream straight through to your terminal, and the resolved command is logged before it runs. Each hook sees the release context in its environment:

| Variable | Value |
| --- | --- |
| `VERBUMP_VERSION` | the new version (e.g. `1.3.0`) |
| `VERBUMP_PREV_VERSION` | the previous version (e.g. `1.2.3`) |
| `VERBUMP_TAG` | the full tag name (e.g. `v1.3.0`) |

**Quoting.** `.verbumprc` is shell-sourced, so **single-quote** hook strings that reference these variables. A double-quoted `"echo $VERBUMP_TAG"` expands at config-load time (while the variables are still empty), whereas `'echo $VERBUMP_TAG'` defers expansion until the hook runs:

```sh
POST_TAG_CMD='echo "released $VERBUMP_TAG" >> releases.log'
```

Under `--dry-run` the hook command is printed with the `[dry-run]` prefix and not executed. Pass `--no-hooks` to skip both hooks for a single run (git's `--no-verify` convention). To disable just one hook for a run, empty the key instead, since env beats the file: `PRE_BUMP_CMD= VerBump …`

> **Migrating from 1.x:** VerBump 2.0 no longer shells out to `npm version`, so npm's `preversion` / `version` / `postversion` lifecycle scripts stopped firing as a side-effect. If you relied on `preversion` to run your tests, one `.verbumprc` line restores it: `PRE_BUMP_CMD="npm test"`.

</details>

## Exit codes

Every run ends with a stable, documented exit code, so scripts and CI can branch on `$?`.

<details>
<summary><b>All codes</b>, 0–5</summary>

| Code | Meaning |
| ---: | --- |
| `0` | Success. |
| `1` | Generic runtime error (failed commit, jq write error, etc.). |
| `2` | Usage / argument-parse error (unknown flag, missing value). |
| `3` | Precondition failure (missing `git`/`jq`, dirty tree, disallowed branch, SemVer validation, insecure `.verbumprc`, branch/tag already exists). |
| `4` | Hook failure: `PRE_BUMP_CMD` or `POST_TAG_CMD` exited non-zero (see [Release hooks](#release-hooks)). |
| `5` | User abort (declined a prompt, e.g. push confirmation). |

</details>

## Shell completions

`VerBump --completions <shell>` emits a bash, zsh, or fish completion script, or `VerBump --install-completions` auto-detects your shell and installs it for you.

<details>
<summary><b>Manual install paths</b> and what you get</summary>

Drop the emitted script wherever your shell looks for completions:

```sh
# bash (with bash-completion installed, e.g. via Homebrew)
VerBump --completions bash > "$(brew --prefix)/etc/bash_completion.d/VerBump"

# zsh — any directory on $fpath works
VerBump --completions zsh  > "${fpath[1]}/_VerBump"

# fish
VerBump --completions fish > ~/.config/fish/completions/VerBump.fish
```

Then restart the shell (or `compinit` / `source` the file). You get:

- Tab-completion for every short and long flag
- `.json` file suggestions after `-f` / `--file`
- `bash | zsh | fish` suggestions after `--completions`
- Suppressed completion after options taking free-form arguments (so the shell doesn't guess wrong values for `-v`, `-m`, `-p`, `-t`, `-B`)

</details>

## Example

This example assumes a `package.json` at `version: "1.0.0"`, on the branch you want to release, with un-released commits already made.

By default `VerBump` **tags in place**: it commits the bump and tags your current branch, with no release branch. This bumps `package.json` to `1.0.1` and creates the tag `v1.0.1`:

```sh
$ VerBump
```

Output:

<!-- deslop-lint-disable -->

```text
VERIFY 
Current version read from <package.json>: 1.0.0

Enter a new version number, <enter> for [1.0.1], or <esc> to quit: ⏎

RELEASE 
✔ Bumped version in <package.json>.

CHANGELOG 
No existing [CHANGELOG.md] found — creating one.
✔ Created [CHANGELOG.md].

Committing...
✔ [main ace8b1e] chore: updated package.json, created CHANGELOG.md, bumped 1.0.0 -> 1.0.1
 2 files changed, 7 insertions(+), 1 deletion(-)
 create mode 100644 CHANGELOG.md
✔ Tagged v1.0.1

INPUT REQUEST
Push branch + tags to <origin>? [N/y] y

Pushing branch + tag to <origin>...
✔ To github.com:acme/widget.git
   9abef73..ace8b1e  main -> main
 * [new tag]         v1.0.1 -> v1.0.1

DONE 
✔ Bumped 1.0.0 -> 1.0.1
```

<!-- deslop-lint-enable -->

The commit and tag land on your current branch. If you declined the push prompt, push later on a re-run with `-p origin`, or manually with `git push --follow-tags`.

Prefer a release branch and PR instead? `VerBump --pr` cuts a `release-1.0.1` branch, pushes it, and opens a pull request via `gh` against your base branch (`--base`, else the branch you ran from) — the pre-2.0 workflow. `VerBump --branch` cuts the branch and stops there, leaving push and merge to you. See [Workflows](#workflows).

## Development

The sandbox harness exercises the script against a throwaway git repo, so your real repo is never touched:

```sh
pnpm dev                              # interactive, suggests bump from seed commits
pnpm dev -- -v 2.0.0                  # non-interactive, explicit version
pnpm dev:dry                          # alias for pnpm dev -- --dry-run
pnpm dev -- --keep                    # leaves the temp dir around for inspection
SANDBOX_VERSION=4.0.0-dev.6 pnpm dev  # exercise the prerelease bumper
SANDBOX_COMMITS='feat!: big change; fix: oops' pnpm dev  # custom seed commits
```

Under the hood, [`dev/sandbox.sh`](dev/sandbox.sh) `mktemp -d`s a fresh dir, writes a minimal `package.json`, seeds a git repo with conventional-commit messages and a starting tag, then invokes `VerBump` inside it. The temp dir is wiped on exit (or `^C`) unless you pass `--keep`. All flags after `--` are forwarded to `VerBump`.

**Environment variables** for the sandbox:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SANDBOX_VERSION` | `0.1.0` | Starting `"version"` in the seed `package.json`. |
| `SANDBOX_COMMITS` | *(three built-in seeds)* | Semicolon-separated commit subjects to seed, e.g. `'feat!: big; fix: small'`. |

You can invoke the script directly if you prefer: `./dev/sandbox.sh -v 2.0.0` needs no `--` separator.

## Tests

Tests are written with [bats](https://github.com/bats-core/bats-core):

```sh
pnpm tests:install   # one-time: vendors bats-core + helpers
pnpm tests:run       # run the full suite
```

> **On Windows?** Run the suite under [WSL](https://learn.microsoft.com/en-us/windows/wsl/), since bats can't run natively on Windows (see [Requirements](#requirements) for the full platform-support picture).

The suite covers short/long option parsing, SemVer validation (including prerelease and build metadata), prerelease counter bumping, conventional-commit version suggestion, JSON file bumping (via `jq`, no `npm`), CHANGELOG generation, branch/tag creation, and the shell-completion emitters.

## Contributing

Contributions are welcome — start with [`CONTRIBUTING.md`](CONTRIBUTING.md), then open [an issue or pull request](https://github.com/jv-k/VerBump/issues/new/choose). Coding standards, commit conventions, and the test/lint workflow live in [`docs/CODE_STYLE.md`](docs/CODE_STYLE.md).

## License

The scripts and documentation in this project are released under the [MIT license](LICENSE).
