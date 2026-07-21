# Monorepo support (package scope)

Per-package releases from one repository (ADR-23, spec #128, feature #96):
run VerBump from inside a package whose `.verbumprc` sets `TAG_PREFIX`, and
commit analysis scopes to that package via `COMMIT_PATHS`. Orchestration
(which packages, when) stays with the user's scripts. Design locked via
wayfinder map #117 (grills #119–#122, audit #118).

| ID | Requirement | Status |
| --- | --- | --- |
| R-MONO-1 | `COMMIT_PATHS` config key: space-separated git pathspecs resolved against the `.verbumprc`'s directory, default `"."`. A root rc — or no rc — resolves to the repo root, treated as "no scope": whole-repo runs behave byte-identically to before. Precedence follows R-CFG-3 (env override works; no CLI flag). | ✅ shipped — `resolve-commit-scope` |
| R-MONO-2 | The bump suggestion scans only commits touching the scope — a sibling package's `feat:` cannot inflate this package's bump. | ✅ shipped |
| R-MONO-3 | The changelog entry and the `--pr` body list only commits touching the scope; `CHANGELOG.md` stays cwd-relative, i.e. package-local under the blessed package-cwd flow. Root-aggregated changelogs are rejected by design. | ✅ shipped |
| R-MONO-4 | The nothing-to-release gate (R-SAFE-14..18) counts only commits touching the scope — foreign commits cannot manufacture a phantom release. The `no-release` stdout token is unchanged. | ✅ shipped |
| R-MONO-5 | Dirty-tree preflight under scope splits by index vs worktree: any dirt inside the scope fails (exit 3); staged changes anywhere fail (a bare `git commit` sweeps the whole index); unstaged edits outside the scope are allowed. `ALLOW_DIRTY` still skips the whole check. Branch / upstream / tag-collision / commits-exist preflights stay repo-wide. | ✅ shipped |
| R-MONO-6 | The resolved scope is printed in run output whenever it is narrower than the repo root — never silent. | ✅ shipped |
| R-MONO-7 | The release preview (`--dry-run --json`) gains an optional `scope.paths` member (repo-root-relative), present only when scoped; whole-repo payloads are byte-identical and the schema id stays `verbump.dry-run/v1`. | ✅ shipped |
| R-MONO-8 | Tag-series isolation is locked by tests: every tag lookup stays `TAG_PREFIX`-anchored with mixed tag styles present, and prefixed tags render valid compare URLs. (Behaviour predates this feature — audit #118.) | ✅ shipped (tests) |
| R-MONO-9 | Release notes: under scope the default is the package's own changelog entry in the **grouped** style (sections, commit links, compare link) regardless of `CHANGELOG_STYLE`, rendered in-memory (works with `-c`); at whole-repo scope `gh --generate-notes` stays the default (ADR-18) and gains `--notes-start-tag <prev-tag>` when the series' previous tag exists. `VERBUMP_RELEASE_NOTES_CMD` beats both. | ✅ shipped |
| R-MONO-10 | The release-branch collision error's hint mentions per-package `REL_PREFIX` when a scope is active — the colliding branch likely belongs to a sibling package. | ✅ shipped |

Out of scope (ADR-23): dependency-graph bumping, workspace version
rewriting, "release everything that changed" orchestration, a `--package`
flag, root-aggregated changelogs, reimplementing GitHub's notes generator
("New Contributors") for scoped releases.

Migration is docs-only: baseline-tag each package (`git tag pkg-a-v<current>`)
before its first prefixed run, or the first entry spans the package's full
history — documented as expected behaviour, not a bug.

Modules: `lib/config.sh` (`resolve-commit-scope`), `lib/version.sh`,
`lib/changelog.sh` (`render-release-notes`), `lib/git-checks.sh`,
`lib/git-actions.sh`, `lib/effects.sh`. Tests: `test/monorepo-scope.bats`
(15), `test/monorepo-preflights.bats` (9), fixture `monorepo_fixture` in
`test/test_helper.bash`.
