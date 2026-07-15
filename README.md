# ver-bump

An opinionated release tool for Git projects with a `package.json` (Node / JS / TS, or any repo that follows SemVer via `-f <file>.json`). Automates SemVer bumps, CHANGELOG updates, tagging, and pushing — driven by Conventional Commits. Tags in place by default, or cut a release branch (`--branch`) and open a pull request (`--pr`). The core flow — bump, changelog, tag, push — works on any Git remote and needs only `git` + `jq`; `--pr` and `--release` are GitHub-specific and require the optional [`gh`](https://cli.github.com) CLI. Single-file bash at runtime.

<p>
  <img src="https://raw.githubusercontent.com/jv-k/ver-bump/main/img/demo.gif?raw=true" alt="Animated demo: ver-bump reads commits, suggests a SemVer bump, updates package.json + CHANGELOG, creates a release branch, tags, and pushes.">
</p>

[![!#/bin/bash](https://img.shields.io/badge/-%23!%2Fbin%2Fbash-1f425f.svg?logo=image%2Fpng%3Bbase64%2CiVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyZpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw%2FeHBhY2tldCBiZWdpbj0i77u%2FIiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8%2BIDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuNi1jMTExIDc5LjE1ODMyNSwgMjAxNS8wOS8xMC0wMToxMDoyMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENDIDIwMTUgKFdpbmRvd3MpIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkE3MDg2QTAyQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkE3MDg2QTAzQUZCMzExRTVBMkQxRDMzMkJDMUQ4RDk3Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6QTcwODZBMDBBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6QTcwODZBMDFBRkIzMTFFNUEyRDFEMzMyQkMxRDhEOTciLz4gPC9yZGY6RGVzY3JpcHRpb24%2BIDwvcmRmOlJERj4gPC94OnhtcG1ldGE%2BIDw%2FeHBhY2tldCBlbmQ9InIiPz6lm45hAAADkklEQVR42qyVa0yTVxzGn7d9Wy03MS2ii8s%2BeokYNQSVhCzOjXZOFNF4jx%2BMRmPUMEUEqVG36jo2thizLSQSMd4N8ZoQ8RKjJtooaCpK6ZoCtRXKpRempbTv5ey83bhkAUphz8fznvP8znn%2B%2F3NeEEJgNBoRRSmz0ub%2FfuxEacBg%2FDmYtiCjgo5NG2mBXq%2BH5I1ogMRk9Zbd%2BQU2e1ML6VPLOyf5tvBQ8yT1lG10imxsABm7SLs898GTpyYynEzP60hO3trHDKvMigUwdeaceacqzp7nOI4n0SSIIjl36ao4Z356OV07fSQAk6xJ3XGg%2BLCr1d1OYlVHp4eUHPnerU79ZA%2F1kuv1JQMAg%2BE4O2P23EumF3VkvHprsZKMzKwbRUXFEyTvSIEmTVbrysp%2BWr8wfQHGK6WChVa3bKUmdWou%2BjpArdGkzZ41c1zG%2Fu5uGH4swzd561F%2BuhIT4%2BLnSuPsv9%2BJKIpjNr9dXYOyk7%2FBZrcjIT4eCnoKgedJP4BEqhG77E3NKP31FO7cfQA5K0dSYuLgz2TwCWJSOBzG6crzKK%2BohNfni%2Bx6OMUMMNe%2Fgf7ocbw0v0acKg6J8Ql0q%2BT%2FAXR5PNi5dz9c71upuQqCKFAD%2BYhrZLEAmpodaHO3Qy6TI3NhBpbrshGtOWKOSMYwYGQM8nJzoFJNxP2HjyIQho4PewK6hBktoDcUwtIln4PjOWzflQ%2Be5yl0yCCYgYikTclGlxadio%2BBQCSiW1UXoVGrKYwH4RgMrjU1HAB4vR6LzWYfFUCKxfS8Ftk5qxHoCUQAUkRJaSEokkV6Y%2F%2BJUOC4hn6A39NVXVBYeNP8piH6HeA4fPbpdBQV5KOx0QaL1YppX3Jgk0TwH2Vg6S3u%2BdB91%2B%2FpuNYPYFl5uP5V7ZqvsrX7jxqMXR6ff3gCQSTzFI0a1TX3wIs8ul%2Bq4HuWAAiM39vhOuR1O1fQ2gT%2F26Z8Z5vrl2OHi9OXZn995nLV9aFfS6UC9JeJPfuK0NBohWpCHMSAAsFe74WWP%2BvT25wtP9Bpob6uGqqyDnOtaeumjRu%2ByFu36VntK%2FPA5umTJeUtPWZSU9BCgud661odVp3DZtkc7AnYR33RRC708PrVi1larW7XwZIjLnd7R6SgSqWSNjU1B3F72pz5TZbXmX5vV81Yb7Lg7XT%2FUXriu8XLVqw6c6XqWnBKiiYU%2BMt3wWF7u7i91XlSEITwSAZ%2FCzAAHsJVbwXYFFEAAAAASUVORK5CYII%3D)](https://www.gnu.org/software/bash/)  [![CI](https://github.com/jv-k/ver-bump/actions/workflows/ci.yml/badge.svg)](https://github.com/jv-k/ver-bump/actions/workflows/ci.yml)  [![CodeFactor](https://www.codefactor.io/repository/github/jv-k/ver-bump/badge)](https://www.codefactor.io/repository/github/jv-k/ver-bump)  [![npm version](https://badge.fury.io/js/ver-bump.svg)](https://badge.fury.io/js/ver-bump)  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Highlights 📦🚀

It does several things that are typically required for releasing a Git repository:

- Three release [workflows](#workflows): **tag-in-place** (default — commit + [tag](https://git-scm.com/book/en/v2/Git-Basics-Tagging) the current branch), **release branch** (`--branch`, following the [Git branch-based workflow](https://nvie.com/posts/a-successful-git-branching-model/)), or **release PR** (`--pr` — branch, push, and open a pull request via `gh`)
- Enforces [Semantic Versioning](https://semver.org/) specification — inputs are validated against SemVer 2.0 (including `-prerelease` and `+build` metadata)
- Smart bump suggestion: reads [Conventional Commits](https://www.conventionalcommits.org/) between the previous tag and `HEAD` to propose **major**/**minor**/**patch**; bumps the trailing counter on prereleases like `4.0.0-dev.6 → 4.0.0-dev.7`
- Avoid potential mistakes associated with manual releases, such as forgetting a step
- Create and update a changelog file automatically
- Pushes release to a remote
- Opens a release pull request for you with `--pr` (or leaves the merge to you in plain `--branch` mode)
- **Dry-run mode** (`-d` / `--dry-run`) prints every side-effect — file write, git add, commit, tag, push — without executing any of them, so you can preview a release end-to-end
- Shell completion scripts for **bash**, **zsh**, and **fish** built in (`ver-bump --completions <shell>`)
- Pure-bash runtime with only `git` + `jq` as dependencies — no Node/npm required at run time

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
<details>
<summary>Details</summary>

- [Release Steps 👣](#release-steps-)
  - [Verify + Prepare Release](#verify--prepare-release)
  - [Create Release](#create-release)
- [Release Steps: In detail 🔎](#release-steps-in-detail-)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [Workflows](#workflows)
- [Usage](#usage)
  - [Pre-requisites](#pre-requisites)
  - [CLI](#cli)
- [Options](#options)
  - [Config file (`.ver-bumprc`)](#config-file-ver-bumprc)
  - [Version suggestion](#version-suggestion)
  - [Dry-run](#dry-run)
  - [Exit codes](#exit-codes)
- [Shell completions](#shell-completions)
- [Example](#example)
- [Development](#development)
- [Tests](#tests)
- [Contributing](#contributing)
- [License](#license)

</details>
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Release Steps 👣

The command `ver-bump` will execute the following steps:

### Verify + Prepare Release

- Verify some commits exist
- Selects a semantic version number for the release branch & tag
- Suggests the next version based on Conventional Commits since the previous tag (`feat!:` → major, `feat:` → minor, otherwise patch), or bumps the trailing counter on a prerelease version (`4.0.0-dev.6` → `4.0.0-dev.7`)
  - Checks to see a tagged release with the chosen version already exists

### Create Release

- Bump version number in `package.json`
- Write `CHANGELOG.md`
- Create release branch
- Commit changes to files made by this script
- Create a Git tag
- Push release branch + tag to remote

## Release Steps: In detail 🔎

<table>
  <thead>
    <tr>
      <th></th>
      <th>Step</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5">Verify + Prepare Release</td>
      <td>Process user arguments</td>
      <td>Check and store CLI arguments supplied by user for later processing.</td>
    </tr>
    <tr>
      <td>Check commits</td>
      <td>Verify some commits exist for release.</td>
    </tr>
    <tr>
      <td>Determine Release Version</td>
      <td>If <code>&lt;package.json&gt;</code> doesn't exist, warn + exit. <br><br>If <code>-v</code> option is
        specified, set version from that.<br><br> Or, grab from version from <code>package.json</code>.<br><br>Suggest
        incremented version number in the form of <code>MAJOR.MINOR.PATCH</code> (incrementing <code>PATCH</code>), as
        per Semver 2.0.0.<br><br>Give the user the option to modify/confirm suggested version bump.</td>
    </tr>
    <tr>
      <td>Check branch exist</td>
      <td>Ensure a release branch with the chosen version number doesn't already exist, if so exit.</td>
    </tr>
    <tr>
      <td>Check tag exists</td>
      <td>Ensure a tag with the chosen version number doesn't exist, and exit if it does.</td>
    </tr>
    <tr>
      <td rowspan="6">Create Release</td>
      <td>Bump version number</td>
      <td>Update semantic version number in <code>package.json</code> + stages changes.</td>
    </tr>
    <tr>
      <td>Generate changelog</td>
      <td>Commits since the last release are automatically added to <code>CHANGELOG.md</code>, as well as new commit
        messages for files modified by this script itself. Stages changes for commit action later.</td>
    </tr>
    <tr>
      <td>Create release branch</td>
      <td>Create a branch with the name <code>release-MAJOR.MINOR.PATCH</code> and switch to it (following the <a
          href="https://nvie.com/posts/a-successful-git-branching-model/" rel="nofollow">Git branch-based
          workflow</a>).</td>
    </tr>
    <tr>
      <td>Commit changed files</td>
      <td>Commits changes to <code>package.json</code> and CHANGELOG.md` (staged in the previous steps) to the release
        branch.</td>
    </tr>
    <tr>
      <td>Create Git tag</td>
      <td>Create a Git tag referencing the new release version.</td>
    </tr>
    <tr>
      <td>Push</td>
      <td>Optionally, push the release branch to origin.</td>
    </tr>
  </tbody>
</table>

## Requirements

In order to use `ver-bump` you need:

- To host your project code in a Git repository
- Have `git` and `jq` installed in your environment
- `npm` / `node` are *optional* — only required if you want to install `ver-bump` from the npm registry, not at run time

**Platform support** — `ver-bump` is pure bash, so it runs wherever bash does:

- **Tested in CI:** Linux and macOS — the full test suite runs on both for every change.
- **Expected to work:** WSL — it's just Linux underneath, with the same `bash` + `git` + `jq`.
- **Best effort, untested:** Git Bash / MSYS2 — should work, but nothing in CI verifies it; if something breaks, CRLF line endings are the usual suspect.
- **Unsupported:** native `cmd` / PowerShell — there's no bash there to run the script.

## Installation

`ver-bump` is bash with `git` + `jq` as its only runtime dependencies, so
install it whichever way suits you. `node`/`npm`/`pnpm` are only needed to
install *from the registry* — never to run the tool.

**curl (no Node required)** — downloads the latest GitHub release, verifies
its published SHA-256 checksum, and installs to `~/.local`:

```sh
curl -fsSL https://raw.githubusercontent.com/jv-k/ver-bump/main/install.sh | bash
```

Re-running upgrades in place. `VER_BUMP_INSTALL_VERSION=x.y.z` pins a
release; `VER_BUMP_PREFIX=<dir>` changes the prefix (layout:
`<prefix>/share/ver-bump/` + a `<prefix>/bin/ver-bump` symlink — make sure
`<prefix>/bin` is on your `$PATH`).

> **Piping a script into your shell runs code you haven't read.** The
> checksum protects the release *tarball*; it can't vet the installer
> itself. If that trade-off isn't for you, download it first, read it (it's
> short and boring on purpose), then run it:
>
> ```sh
> curl -fsSLO https://raw.githubusercontent.com/jv-k/ver-bump/main/install.sh
> less install.sh
> bash install.sh
> ```

**npm / pnpm** — install from the registry:

```sh
# pnpm (this repo's package manager)
pnpm add -g ver-bump

# npm
npm install -g ver-bump
```

**Manual** — clone and symlink the script; `lib/` travels with it, so module
resolution still works:

```sh
git clone https://github.com/jv-k/ver-bump.git ~/.local/share/ver-bump
ln -s ~/.local/share/ver-bump/ver-bump.sh ~/.local/bin/ver-bump   # ensure ~/.local/bin is on $PATH
```

> **Homebrew** ([#24](https://github.com/jv-k/ver-bump/issues/24)) and
> **basher** ([#39](https://github.com/jv-k/ver-bump/issues/39)) install
> paths are tracked for a future release.

## Quickstart

```sh
cd your-repo
ver-bump --dry-run   # preview a release end-to-end — prints every step, changes nothing
ver-bump             # cut it for real: reads commits, suggests a bump, prompts before pushing
```

## Workflows

ver-bump supports three release workflows. Pick one per-run with a flag, or set
a default in `.ver-bumprc`.

| Workflow | How | What it does |
| --- | --- | --- |
| **Tag-in-place** *(default)* | `ver-bump` | Bumps files, writes CHANGELOG, commits, and tags **the current branch**. No branch is created. |
| **Release branch** | `ver-bump --branch` | Cuts a `release-<version>` branch (the [Git branch-based workflow](https://nvie.com/posts/a-successful-git-branching-model/)), commits + tags there, and leaves the merge back to you. |
| **Release PR** | `ver-bump --pr` | Like `--branch`, then pushes and opens a pull request via the [`gh`](https://cli.github.com) CLI. Implies a push to `origin` (override with `-p <remote>`). |

The `--pr` base branch resolves in this order: `--base <branch>` › `PR_BASE`
from `.ver-bumprc` › the branch you ran ver-bump from › the remote's default
branch.

> **Migrating from 1.x:** the default changed. ver-bump 1.x always cut a
> `release-<version>` branch; 2.0 **tags the current branch in place** by
> default. Pass `--branch` to keep the old behaviour. The old `-b` /
> `--no-branch` flag is now a no-op (kept so existing scripts don't break).

## Usage

### Pre-requisites

- Make sure you have `package.json` file in your project and it contains a `"version": "x.x.x"` parameter
- You have done some work and have some existing commits
- You have the ability to push to your Git remote via the Git CLI

### CLI

```sh
$ ver-bump [-v|--version [<v>]] [-m|--message <msg>] [-f|--file <file.json>]... \
           [-p|--push <remote>] [-t|--tag-prefix <p>] [-B|--branch-prefix <p>] \
           [-d|--dry-run] [-n|--no-commit] [-b|--no-branch] \
           [-c|--no-changelog] [-l|--pause-changelog] [-y|--yes] [-q|--quiet] [-h|--help] \
           [--branch] [--pr] [--base <branch>] \
           [--allow-dirty] [--allow-empty] [--no-fetch] \
           [--undo [<version>]] [--major | --minor | --patch] [--release] \
           [--completions <shell>] [--install-completions[=<shell>]] [--about]
```

<p>
  <img src="https://raw.githubusercontent.com/jv-k/ver-bump/main/img/screenshot.png?raw=true" alt="ver-bump --help">
</p>

## Options

Every option has a short form and a GNU-style long form. Long forms accept
`--name value` or `--name=value`.

### Config file (`.ver-bumprc`)

`ver-bump` looks for a `.ver-bumprc` file by walking up from your current
directory toward `/`. The first file found is shell-sourced so teams can
commit their project-wide defaults alongside the repo.

Supported keys (each maps 1:1 to an existing global):

| Key | Equivalent flag | Default |
| --- | --- | --- |
| `TAG_PREFIX` | `-t` / `--tag-prefix` | `v` |
| `REL_PREFIX` | `-B` / `--branch-prefix` | `release-` |
| `PUSH_DEST` | `-p` / `--push` | `origin` |
| `COMMIT_MSG_PREFIX` | *(no flag)* | `"chore: "` |
| `CHANGELOG_STYLE` | *(no flag)* | `flat` |
| `FLAG_BRANCH` | `--branch` | *unset* (tag in place) |
| `PR_BASE` | `--base` | *(auto-detect)* |
| `FLAG_NOCHANGELOG` | `-c` / `--no-changelog` | *unset* |
| `FLAG_CHANGELOG_PAUSE` | `-l` / `--pause-changelog` | *unset* |
| `ALLOW_DIRTY` | `--allow-dirty` | *unset* (dirty tree refuses) |
| `NO_FETCH` | `--no-fetch` | *unset* (fetch + behind-upstream check) |
| `RELEASE_BRANCHES` | *(no flag)* | *unset* (release from any branch) |

Example:

```sh
# .ver-bumprc — committed at repo root
TAG_PREFIX="release/"
REL_PREFIX="hotfix-"
PUSH_DEST="upstream"
COMMIT_MSG_PREFIX="release: "
FLAG_NOCHANGELOG=true
RELEASE_BRANCHES="main develop release/*"
```

`RELEASE_BRANCHES` is a space-separated list of glob patterns naming the
branches a release may be cut from. When set, running ver-bump from any
other branch (or from a detached HEAD) exits with code 3 — it is a guard,
not a prompt, so `--yes` does not bypass it. Clear it for a single run
with an empty environment override (env beats the file):

```sh
RELEASE_BRANCHES= ver-bump …
```

**Precedence** — highest to lowest: **CLI flag** > **environment variable**
> **`.ver-bumprc`** > **built-in default**. So an exported
`TAG_PREFIX=foo` overrides whatever the file says, and passing `-t bar`
overrides both.

**Security** — `ver-bump` *sources* this file as shell, so do not commit
one you wouldn't execute. As a safeguard, `ver-bump` refuses to load a
world-writable rc and exits with code 3; `chmod 644 .ver-bumprc` fixes it.

#### Grouped changelog (`CHANGELOG_STYLE=grouped`)

By default the CHANGELOG section is a flat list of commit subjects
(unchanged since 1.x). Set `CHANGELOG_STYLE=grouped` — in `.ver-bumprc` or
as an environment variable; there is no CLI flag — to group commits by
Conventional Commit type instead, with commit, PR and compare links when
the remote is on GitHub:

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

Sections appear in that order and empty ones are omitted. Breaking changes
are detected from a `<type>!:` subject or a `BREAKING CHANGE:` footer;
everything that isn't `feat`/`fix`/breaking — including commits that don't
follow Conventional Commits at all — lands under **Other**, so nothing is
ever dropped. Scopes render as a bold `**scope:**` prefix. With a
non-GitHub remote (or no remote) the same grouping renders as plain text
without links. Any other `CHANGELOG_STYLE` value behaves as `flat`, whose
output stays byte-identical to previous releases.

```text
-v, --version [<version>]     Without a value: print tool version and exit.
                              With a value: set manual SemVer (validated against 2.0).
-m, --message <message>       Custom annotated-tag release message.
-f, --file <filename.json>    Also bump "version" in this JSON file. Repeatable:
                                ver-bump -f src/plugin/package.json -f composer.json
-p, --push <remote>           Push branch + tag to <remote> (e.g. origin) as the last step.
-t, --tag-prefix <prefix>     Override tag prefix (default: "v" → v1.2.3).
-B, --branch-prefix <prefix>  Override branch prefix (default: "release-").
-d, --dry-run                 Print every side-effect (file write, git add, commit,
                              tag, push) without executing any of them.
-n, --no-commit               Disable commit (also skips tag + push).
-b, --no-branch               (deprecated) No-op — tag-in-place is the default now.
-c, --no-changelog            Disable updating CHANGELOG.md automatically.
-l, --pause-changelog         Pause before commit so CHANGELOG.md can be hand-edited.
-y, --yes                     Skip interactive confirmation prompts.
-q, --quiet                   Suppress decorative output — on success stdout carries
                              exactly one line: the new version (no tag prefix, no
                              colour); everything else goes to stderr. Errors keep
                              the usual exit codes; a no-op run (nothing to release)
                              prints nothing and exits 0. Requires --yes, -v, or
                              --major/--minor/--patch, and refuses -l/--pause-changelog
                              (a hidden prompt would hang the pipeline). CI capture:
                                NEW_VERSION=$(ver-bump --yes --quiet -p origin)
-h, --help                    Show help message.
    --undo [<version>]        Locally delete the release branch + tag for <version>
                              (refuses if pushed, dirty, or already merged).
    --major                   Force a major bump from the current version.
                              Mutually exclusive with --minor / --patch and -v.
                              From a prerelease (X.Y.Z-dev.N), drops the prerelease
                              before bumping the stable component.
    --minor                   Force a minor bump (see --major for semantics).
    --patch                   Force a patch bump (see --major for semantics).
    --allow-dirty             Skip the clean-working-tree check and release with
                              uncommitted changes to tracked files. Untracked files
                              never trigger the check. Also available as the
                              ALLOW_DIRTY config/env key.
    --allow-empty             Release even when there are no new commits since the
                              previous tag. Without it, such a run prints a notice
                              (a stdout line starting with "no-release") and exits 0
                              without changing anything — safe to run unconditionally
                              in CI.
    --no-fetch                Skip the remote-sync preflight: no 'git fetch <remote>
                              --tags' and no behind-upstream check before releasing.
                              Remote-only tag collisions then surface at push time
                              instead. Also available as the NO_FETCH config/env key.
    --branch                  Cut a release-<version> branch (the pre-2.0 default).
                              Otherwise ver-bump tags the current branch in place.
    --pr                      Create the release branch, push it, then open a pull
                              request (GitHub-only, requires the `gh` CLI). Implies a
                              push to origin (override the remote with -p). Base
                              resolves to --base, else the branch you ran ver-bump from.
    --base <branch>           Base branch for the --pr pull request (GitHub-only;
                              only used with --pr, which requires `gh`).
    --release                 After pushing, publish a GitHub release for the new tag
                              (GitHub-only, requires `gh` and -p / --push <remote>).
                              Notes are read from $VER_BUMP_RELEASE_NOTES_CMD (default
                              `npx jv-k/releasetool`).
    --about                   Print name, version, author, and homepage; then exit.
    --completions <shell>     Emit completion script for bash, zsh, or fish to stdout.
    --install-completions [=<shell>]
                              Install completion script (auto-detects shell if omitted).
```

### Version suggestion

When `-v` / `--version` is omitted, `ver-bump` picks a suggestion for you:

**1. Prereleases** — if the current version has a `-<id>` segment, the
trailing numeric counter is bumped (or `.1` is appended if there isn't one).
Build metadata after `+` is preserved:

| Current                | Suggested              |
| ---------------------- | ---------------------- |
| `4.0.0-dev.6`          | `4.0.0-dev.7`          |
| `4.0.0-rc.9`           | `4.0.0-rc.10`          |
| `1.0.0-alpha`          | `1.0.0-alpha.1`        |
| `2.1.0-beta.3+sha.abc` | `2.1.0-beta.4+sha.abc` |

**2. Stable versions** — inspects Conventional Commits since the previous tag:

- `feat!:` / `<type>!:` / `BREAKING CHANGE:` in body → **major**
- `feat:` → **minor**
- anything else (or no previous tag) → **patch**

You can always override the suggestion at the interactive prompt, or pass
`-v <version>` to skip the prompt entirely. Values passed to `-v` are
validated against SemVer 2.0, so typos like `ver-bump -v banana` fail fast.

For a non-interactive forced bump that doesn't require typing the full
version, use `--major` / `--minor` / `--patch`. They bump the current
version's matching component, drop any prerelease/build metadata
(`1.2.3-dev.5 --patch` → `1.2.4`), and are mutually exclusive with each
other and with `-v`. Combining more than one exits with code `2`.

### Dry-run

Pass `-d` / `--dry-run` to preview a release end-to-end without touching
anything — no files written, no `git add`, no commit, no tag, no push:

```sh
$ ver-bump --dry-run
...
[dry-run] would set .version = '1.0.1' in package.json
[dry-run] would set .version = '1.0.1' in package-lock.json
[dry-run] git add package.json
[dry-run] git add package-lock.json
[dry-run] would replace CHANGELOG.md with: ...
[dry-run] would run: git branch release-1.0.1 && git checkout release-1.0.1
[dry-run] would run: git commit -m 'chore: updated package.json, ...'
[dry-run] would run: git tag -a v1.0.1 -m 'Tag version 1.0.1.'
```

Combine with `--no-branch` / `--no-commit` / `--no-changelog` to narrow the
preview down to just the steps you want to see.

### Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | Success. |
| `1` | Generic runtime error (failed commit, jq write error, etc.). |
| `2` | Usage / argument-parse error (unknown flag, missing value). |
| `3` | Precondition failure (missing `package.json`, missing `git`/`jq`, SemVer validation, insecure `.ver-bumprc`, branch/tag already exists). |
| `4` | Hook failure (reserved for future use). |
| `5` | User abort (declined a prompt, e.g. push confirmation). |

## Shell completions

`ver-bump --completions <shell>` emits a completion script for **bash**,
**zsh**, or **fish** to stdout. Drop it wherever your shell looks for
completions:

```sh
# bash (with bash-completion installed, e.g. via Homebrew)
ver-bump --completions bash > "$(brew --prefix)/etc/bash_completion.d/ver-bump"

# zsh — any directory on $fpath works
ver-bump --completions zsh  > "${fpath[1]}/_ver-bump"

# fish
ver-bump --completions fish > ~/.config/fish/completions/ver-bump.fish
```

Then restart the shell (or `compinit` / `source` the file). You get:

- Tab-completion for every short and long flag
- `.json` file suggestions after `-f` / `--file`
- `bash | zsh | fish` suggestions after `--completions`
- Suppressed completion after options taking free-form arguments (so the
  shell doesn't guess wrong values for `-v`, `-m`, `-p`, `-t`, `-B`)

## Example

> This example assumes that a `package.json` contains `version: "1.0.0"`, and the user is working in the branch to be released with pre-existing un-released commits.

1. This will create a new Git branch called `release-1.0.1` and a Git tag named `v1.0.1`:

    ```sh
    $ ver-bump
    ```

    Output:

    ```text
    Current version read from <package.json> file: 1.0.0

    Enter a new version number or press <enter> to use [1.0.1]: <pressed enter>

    ––––––

    ✅ Updated file <package.json> from 1.0.0 -> 1.0.1

    ✅ Updated [CHANGELOG.md] file

    Make adjustments to [CHANGELOG.md] if required now. Press <enter> to continue.

    Creating new release branch...

    ✅ Switched to branch 'release-1.0.1'
    M CHANGELOG.md
    M package.json

    Committing...

    ✅ [release-1.0.1 ace8b1e] Updated package.json, Updated CHANGELOG.md, Bumped 1.0.0 –> 1.0.1
    2 files changed, 9 insertions(+), 1 deletion(-)

    ✅ Added GIT tag

    Push tags to <origin>? [N/y]: n

    ––––––

    ✅ Bumped 1.0.0 –> 1.0.1

    🏁 Done!
    ```

2. After checking out the changes in the branch and confirming them, test the release, and push the release branch to your remote if you didn't choose to push it automatically. Alternatively, use `$ ver-bump -p origin` to bypass the prompt and push the release branch anyway to the remote automatically.
3. If your code checks out, then open a Pull Request to merge the release branch into your `develop` or main branch.

    You can merge the release branch into your development branch or main branch like this, without fast-forwarding so that the branch topology is preseved as you're merging in a release branch that hasn't diverged (apart from new changes to `CHANGELOG.md` and `package.json`) and you want to ensure it's clearly evident when reading the history that a merge was performed, as opposed to a fast-forward merge, where new commits performed by the merge will become descendents of the last commit before the merge.

    A release branch shouldn't normally diverge from the branch it was created during the time `ver-bump` is operating, so a non-fastforward should be possible instead of a normal merge, which would simply looks like a new commit was made to the main or development branch.

    ```sh
    $ git checkout develop # Switch to development branch from the new release branch

    $ git merge --no-ff release-1.0.1 # Merge the new release branch to your development branch
    ```

## Development

Want to hack on `ver-bump` itself? Use the sandbox harness to exercise the
script against a throwaway git repo, so your real repo is never touched:

```sh
pnpm dev                              # interactive, suggests bump from seed commits
pnpm dev -- -v 2.0.0                  # non-interactive, explicit version
pnpm dev:dry                          # alias for pnpm dev -- --dry-run
pnpm dev -- --keep                    # leaves the temp dir around for inspection
SANDBOX_VERSION=4.0.0-dev.6 pnpm dev  # exercise the prerelease bumper
SANDBOX_COMMITS='feat!: big change; fix: oops' pnpm dev  # custom seed commits
```

Under the hood, [`dev/sandbox.sh`](dev/sandbox.sh) `mktemp -d`s a fresh dir,
writes a minimal `package.json`, seeds a git repo with conventional-commit
messages and a starting tag, then invokes `ver-bump` inside it. The temp
dir is wiped on exit (or `^C`) unless you pass `--keep`. All flags after
`--` are forwarded to `ver-bump`.

**Environment variables** for the sandbox:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SANDBOX_VERSION` | `0.1.0` | Starting `"version"` in the seed `package.json`. |
| `SANDBOX_COMMITS` | *(three built-in seeds)* | Semicolon-separated commit subjects to seed, e.g. `'feat!: big; fix: small'`. |

You can invoke the script directly if you prefer — `./dev/sandbox.sh -v 2.0.0`
needs no `--` separator.

## Tests

This project uses [bats](https://github.com/bats-core/bats-core) to test the functionality of ver-bump.

To run the tests, first install the pre-requisites:

```sh
$ pnpm tests:install
```

And finally, run the test suite:

```sh
$ pnpm tests:run
```

> **On Windows?** Run the suite under [WSL](https://learn.microsoft.com/en-us/windows/wsl/) — bats can't run natively on
> Windows (see [Requirements](#requirements) for the full platform-support picture).

The suite covers short/long option parsing, SemVer validation (including
prerelease and build metadata), prerelease counter bumping, conventional-commit
version suggestion, JSON file bumping (via `jq`, no `npm`), CHANGELOG
generation, branch/tag creation, and the shell-completion emitters.

## Contributing

I'd love you to contribute to `@jv-k/ver-bump`, [pull requests](https://github.com/jv-k/ver-bump/issues/new/choose) are welcome for submitting issues and bugs!

## License

The scripts and documentation in this project are released under the [MIT license](https://github.com/jv-k/ver-bump/blob/master/LICENSE).
