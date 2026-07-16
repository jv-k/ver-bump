# ver-bump

An opinionated release tool for Git projects with a `package.json` (Node / JS / TS, or any repo that follows SemVer — point `--source <file>.json` at another manifest, or use no version file at all and let the latest release tag supply the current version). Automates SemVer bumps, CHANGELOG updates, tagging, and pushing — driven by Conventional Commits. Tags in place by default, or cut a release branch (`--branch`) and open a pull request (`--pr`). The core flow — bump, changelog, tag, push — works on any Git remote and needs only `git` + `jq`; `--pr` and `--release` are GitHub-specific and require the optional [`gh`](https://cli.github.com) CLI. Plain bash at runtime — `git` + `jq` only.

<p>
  <img src="https://raw.githubusercontent.com/jv-k/ver-bump/main/img/screenshot.png?raw=true" alt="ver-bump --help — the header logo and full flag reference: version input, bump levels, prerelease, changelog, tag, push, and GitHub release options.">
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
  - [Flags](#flags)
  - [Config file (`.ver-bumprc`)](#config-file-ver-bumprc)
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

## Release Steps 👣

The command `ver-bump` will execute the following steps:

### Verify + Prepare Release

- Verify some commits exist
- Selects a semantic version number for the tag (and release branch, when `--branch` / `--pr` is used)
- Suggests the next version based on Conventional Commits since the previous tag (`feat!:` → major, `feat:` → minor, otherwise patch), or bumps the trailing counter on a prerelease version (`4.0.0-dev.6` → `4.0.0-dev.7`)
  - Checks to see a tagged release with the chosen version already exists

### Create Release

- Bump version number in `package.json`
- Write `CHANGELOG.md`
- Commit the changes made by this script to the current branch
- Create a Git tag
- Optionally push the commit + tag to the remote
- *With `--branch` / `--pr`:* cut a `release-<version>` branch first and commit/tag there instead (the pre-2.0 default)

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
      <td>If the version source (e.g. <code>&lt;package.json&gt;</code>) doesn't exist, derive the current version from the latest matching git tag (<code>vX.Y.Z</code>); exit only if no such tag exists either. <br><br>If <code>-v</code> option is
        specified, set version from that.<br><br> Or, grab the version from the source file.<br><br>Suggest
        incremented version number in the form of <code>MAJOR.MINOR.PATCH</code> (incrementing <code>PATCH</code>), as
        per Semver 2.0.0.<br><br>Give the user the option to modify/confirm suggested version bump.</td>
    </tr>
    <tr>
      <td>Check branch exist <em>(only with <code>--branch</code> / <code>--pr</code>)</em></td>
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
      <td>Create release branch <em>(only with <code>--branch</code> / <code>--pr</code>)</em></td>
      <td>By default ver-bump tags in place on the current branch and skips this step. With <code>--branch</code> / <code>--pr</code> it creates a branch named <code>release-MAJOR.MINOR.PATCH</code> and switches to it (following the <a
          href="https://nvie.com/posts/a-successful-git-branching-model/" rel="nofollow">Git branch-based
          workflow</a>).</td>
    </tr>
    <tr>
      <td>Commit changed files</td>
      <td>Commits changes to <code>package.json</code> and <code>CHANGELOG.md</code> (staged in the previous steps) to the current
        branch (or the release branch when <code>--branch</code> / <code>--pr</code> is used).</td>
    </tr>
    <tr>
      <td>Create Git tag</td>
      <td>Create a Git tag referencing the new release version.</td>
    </tr>
    <tr>
      <td>Push</td>
      <td>Optionally, push the commit + tag to origin (plus the release branch when <code>--branch</code> / <code>--pr</code> is used).</td>
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

- A version source: a `package.json` with a `"version": "x.x.x"` field, another
  JSON file via `--source <file.json>` (e.g. `composer.json`), or — with no
  version file at all — at least one release tag (`v1.2.3`) for ver-bump to
  derive the current version from
- You have done some work and have some existing commits
- You have the ability to push to your Git remote via the Git CLI

**Non-Node repos** — Rust / Python / Go / anything SemVer works out of the
box: if there is no version file, ver-bump reads the current version from
your latest matching git tag, runs the same Conventional-Commit suggestion
machinery, and cuts a CHANGELOG + tag release (skipping the commit when
there is nothing to commit). Keep a JSON manifest like `composer.json`?
Point `--source` at it (or set `SOURCE_FILE` in `.ver-bumprc`) and it
becomes both the version source and the file that gets bumped.

**Bumping stack-specific files** — keep the version in a `pyproject.toml`, a
Go const, a Helm `Chart.yaml`, or any text file in lock-step with the tag
via `--bump` (repeatable), or declare the targets once in `.ver-bumprc` as
`BUMP_FILES`:

```sh
# Text pattern — no extra tool; rewrites only the matching line.
# Works for a Go const, a Python __version__, a Makefile, a Dockerfile, …
ver-bump --bump 'main.go:Version = "{{version}}"'
ver-bump --bump 'src/mypkg/__init__.py:__version__ = "{{version}}"'

# Structured dotted path — JSON via jq (built in), TOML/YAML via the
# jq-based yq suite (tomlq / yq) when installed.
ver-bump --bump pyproject.toml:@project.version --bump Chart.yaml:@version

# Or declare them once (newline-separated) — every run keeps them in sync:
# .ver-bumprc
BUMP_FILES="main.go:Version = \"{{version}}\"
src/mypkg/__init__.py:__version__ = \"{{version}}\"
pyproject.toml:@project.version
Chart.yaml:@version"
```

Match your file's exact quoting and spacing — the pattern is a literal
search. `__version__='1.2.3'` (single quotes, no spaces) needs
`--bump "…/__init__.py:__version__='{{version}}'"`.

A bare `--bump <file>` bumps the file's top-level `.version` (JSON/TOML/YAML);
`@<path>` targets any dotted key — including a nested one that the JSON
`.version` default can't reach; and a `{{version}}` text pattern covers
everything else with no dependency. Same-version and missing files are
skipped with a notice; every change is staged and listed in the bump commit.

### CLI

```sh
$ ver-bump [-v <version>] [options]
```

<p>
  <img src="https://raw.githubusercontent.com/jv-k/ver-bump/main/img/demo.gif?raw=true" alt="Animated demo: ver-bump reads commits, sets the version, updates package.json + CHANGELOG, commits, tags in place, prompts before pushing, then pushes the tag to origin.">
</p>

## Options

Every option has a short form and a GNU-style long form. Long forms accept
`--name value` or `--name=value`. Grouped below the way `ver-bump --help`
lists them.

### Flags

#### Choose the new version

| Flag | Description |
| --- | --- |
| `-v`, `--version [<version>]` | Without a value, print the tool version and exit. With a value, set an explicit SemVer. |
| `--major` | Force a major bump from the current version. |
| `--minor` | Force a minor bump from the current version. |
| `--patch` | Force a patch bump from the current version. Without `--preid`, any of the three drops an existing prerelease/build and bumps the stable core (`1.2.3-dev.5 --patch → 1.2.4`). |
| `--preid <id>` | Start or advance a prerelease line; conflicts with `-v`. With a level: bump it, then enter `<id>.1` (`1.2.3 --major --preid rc → 2.0.0-rc.1`). Alone on a prerelease: same id increments the counter, a different id resets to `.1`. |

#### Files to bump

| Flag | Description |
| --- | --- |
| `--source <file.json>` | Version source + primary bump target (default: `package.json`). If the file is missing, the current version derives from the latest matching git tag. |
| `--bump <spec>` | Also bump a JSON / TOML / YAML / text file. Repeatable. `<file>` (top-level `.version` by file type), `<file>:@<path>` (explicit dotted path, e.g. `pyproject.toml:@tool.poetry.version`), or `'<file>:<pattern>'` (text search/replace; the pattern must contain `{{version}}`). |
| `-f`, `--file <file.json>` | Also bump `"version"` in this JSON file. Repeatable. Superseded by `--bump`. |

#### Commit, tag & changelog

| Flag | Description |
| --- | --- |
| `-m`, `--message <message>` | Custom annotated-tag release message. |
| `-t`, `--tag-prefix <prefix>` | Override the tag prefix (default: `v`). |
| `--sign` | Create a signed tag (`git tag -s`; uses your git signing config). |
| `-c`, `--no-changelog` | Disable updating `CHANGELOG.md`. |
| `-l`, `--pause-changelog` | Pause before commit so `CHANGELOG.md` can be edited. |
| `-n`, `--no-commit` | Disable commit (and tag + push) after bumping files. |

#### Push, branch & publish

| Flag | Description |
| --- | --- |
| `-p`, `--push <remote>` | Push the release branch + tag to `<remote>` at the end of the run. |
| `--pr` | Branch + push + open a release PR via `gh` (GitHub-only; implies push to origin). |
| `--base <branch>` | Base branch for `--pr` (GitHub-only; default: the branch you ran ver-bump from). |
| `--release` | Publish a GitHub release for the new tag (GitHub-only; requires `-p`, uses `gh`). |
| `--branch` | Cut a `release-x.x.x` branch; otherwise tag in place (the default). |
| `-B`, `--branch-prefix <prefix>` | Override the branch prefix (default: `release-`). |
| `-b`, `--no-branch` | Deprecated no-op — tag-in-place is the default now. |

#### Skip preflight checks

| Flag | Description |
| --- | --- |
| `--allow-dirty` | Skip the clean-working-tree check (untracked files never trigger it). |
| `--allow-empty` | Release even with no new commits since the previous tag. |
| `--no-fetch` | Skip the remote-sync preflight (no fetch / behind-upstream check). |
| `--no-hooks` | Skip the `PRE_BUMP_CMD` / `POST_TAG_CMD` release hooks for this run. |

#### Undo a release

| Flag | Description |
| --- | --- |
| `--undo [<version>]` | Locally delete `release-X.Y.Z` + tag `vX.Y.Z` (refuses if pushed or dirty). |

#### Run mode & output

| Flag | Description |
| --- | --- |
| `-d`, `--dry-run` | Print every side-effect without executing. |
| `-y`, `--yes` | Skip interactive confirmation prompts. |
| `-q`, `--quiet` | Suppress decoration; print only the new version on stdout (needs `-y`, `-v`, a bump level, or `--preid`). |

#### Help & completions

| Flag | Description |
| --- | --- |
| `-h`, `--help` | Show the help message (paged through `less`/`more` when the terminal is short). |
| `--completions <shell>` | Emit a completion script for bash, zsh, or fish. |
| `--install-completions[=<shell>]` | Install the completion script (auto-detects the shell). |

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
| `PRE_BUMP_CMD` | *(no flag — see [Release hooks](#release-hooks))* | *unset* (no hook) |
| `POST_TAG_CMD` | *(no flag — see [Release hooks](#release-hooks))* | *unset* (no hook) |

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

#### Commit message template (`COMMIT_MSG_TEMPLATE`)

By default the bump commit's message is `COMMIT_MSG_PREFIX` plus a
generated list of what changed:

```text
chore: updated package.json, updated CHANGELOG.md, bumped 1.1.7 -> 1.1.8
```

Set `COMMIT_MSG_TEMPLATE` — in `.ver-bumprc` or as an environment
variable; there is no CLI flag — to replace the **whole** message with
your own template. When it is set, `COMMIT_MSG_PREFIX` is **ignored**:
the template owns the entire message, prefix included.

```sh
# .ver-bumprc — single quotes are required so your shell / the rc loader
# doesn't expand the placeholders before ver-bump sees them
COMMIT_MSG_TEMPLATE='chore(release): v${version}'
```

Available placeholders:

| Placeholder | Replaced with | Example |
| --- | --- | --- |
| `${version}` | the new version | `1.1.8` |
| `${prev_version}` | the previous version | `1.1.7` |
| `${tag}` | the new tag (`TAG_PREFIX` + version) | `v1.1.8` |
| `${files}` | the generated changed-file list | `updated package.json, updated CHANGELOG.md` |

Substitution is a literal string replacement — the template is **never**
evaluated as shell, so `$(...)`, backticks, and unknown `${...}`
placeholders pass through as literal text. The CHANGELOG's entry for the
bump commit uses the same rendered message (first line, in both `flat`
and `grouped` styles), so the two never drift apart. The template applies
to the bump commit only; the annotated tag's message keeps its own knob,
`-m` / `--message`.

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

To **enter** or **advance** a prerelease line, add `--preid <id>`:

| Command | Current | Result |
| --- | --- | --- |
| `--major --preid rc` | `1.2.3` | `2.0.0-rc.1` |
| `--patch --preid beta` | `1.2.3` | `1.2.4-beta.1` |
| `--preid dev` (alone) | `4.0.0-dev.6` | `4.0.0-dev.7` (same id → counter++) |
| `--preid rc` (alone) | `2.0.0-alpha.3` | `2.0.0-rc.1` (different id → reset) |
| `--preid rc` (alone) | `1.2.3` (stable) | exit `2` — ambiguous, combine with `--major`/`--minor`/`--patch` |

`--preid` is mutually exclusive with `-v`, and `<id>` is validated against
the SemVer prerelease grammar before anything is mutated. To graduate a
prerelease back to a stable release, `--major`/`--minor`/`--patch` without
`--preid` bumps from the stable core as usual, or pass an explicit
`-v <version>` / accept the interactive prompt.

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
[dry-run] would run: git commit -m 'chore: updated package.json, ...'
[dry-run] would run: git tag -a v1.0.1 -m 'Tag version 1.0.1.'
```

Combine with `--no-commit` / `--no-changelog` to narrow the preview down to
just the steps you want to see.

### Release hooks

Two hook points cover the common "run my tests before tagging" and "build an
artifact after tagging" cases. Each is a single command string, run via
`bash -c`, set as an environment variable or a `.ver-bumprc` key (same
[precedence](#config-file-ver-bumprc) as every other key — there is
deliberately no CLI flag to set them):

| Key | Runs | On non-zero exit |
| --- | --- | --- |
| `PRE_BUMP_CMD` | after **all** Verify preflights pass, before any file is touched | exit `4`, nothing mutated |
| `POST_TAG_CMD` | after the tag is created, before push / `--pr` / `--release` | exit `4`; the commit + tag are kept — recover with `--undo` |

```sh
# .ver-bumprc
PRE_BUMP_CMD="npm test"
POST_TAG_CMD="npm run build:artifacts"
```

Hook stdout/stderr stream straight through to your terminal, and the resolved
command is logged before it runs. Each hook sees the release context in its
environment:

| Variable | Value |
| --- | --- |
| `VER_BUMP_VERSION` | the new version (e.g. `1.3.0`) |
| `VER_BUMP_PREV_VERSION` | the previous version (e.g. `1.2.3`) |
| `VER_BUMP_TAG` | the full tag name (e.g. `v1.3.0`) |

**Quoting:** `.ver-bumprc` is shell-sourced, so **single-quote** hook strings
that reference these variables — a double-quoted `"echo $VER_BUMP_TAG"`
expands at config-load time (while the variables are still empty), whereas
`'echo $VER_BUMP_TAG'` defers expansion until the hook runs:

```sh
POST_TAG_CMD='echo "released $VER_BUMP_TAG" >> releases.log'
```

Under `--dry-run` the hook command is printed with the `[dry-run]` prefix and
not executed. Pass `--no-hooks` to skip both hooks for a single run (git's
`--no-verify` convention); to disable just one hook for a run, empty the key
instead — env beats the file: `PRE_BUMP_CMD= ver-bump …`

> **Migrating from 1.x:** ver-bump 2.0 no longer shells out to `npm version`,
> so npm's `preversion` / `version` / `postversion` lifecycle scripts stopped
> firing as a side-effect. If you relied on `preversion` to run your tests,
> one `.ver-bumprc` line restores it: `PRE_BUMP_CMD="npm test"`.

### Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | Success. |
| `1` | Generic runtime error (failed commit, jq write error, etc.). |
| `2` | Usage / argument-parse error (unknown flag, missing value). |
| `3` | Precondition failure (missing `package.json`, missing `git`/`jq`, SemVer validation, insecure `.ver-bumprc`, branch/tag already exists). |
| `4` | Hook failure — `PRE_BUMP_CMD` or `POST_TAG_CMD` exited non-zero (see [Release hooks](#release-hooks)). |
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

1. By default `ver-bump` **tags in place** — it commits the bump and tags your current branch, with no release branch. This bumps `package.json` to `1.0.1` and creates the tag `v1.0.1`:

    ```sh
    $ ver-bump
    ```

    Output:

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

    ? Push branch + tags to <origin>? [N/y] y

    Pushing branch + tag to <origin>...
    ✔ To github.com:acme/widget.git
       9abef73..ace8b1e  main -> main
     * [new tag]         v1.0.1 -> v1.0.1

     DONE 
    ✔ Bumped 1.0.0 -> 1.0.1
    ```

    The commit and tag land on your current branch. If you declined the push prompt, push later on a re-run with `-p origin`, or manually with `git push --follow-tags`.

2. **Prefer a release branch + PR instead?** Run `ver-bump --pr` (or `--branch`) to cut a `release-1.0.1` branch, push it, and open a pull request for review rather than tagging in place — the pre-2.0 workflow. With `--pr`, `gh` opens the PR against your base branch (`--base`, else the branch you ran from). See [Workflows](#workflows).

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
