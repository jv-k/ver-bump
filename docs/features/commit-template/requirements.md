# Commit message template (COMMIT_MSG_TEMPLATE)

Whole-message template for the bump commit, so teams can express the
near-standard `chore(release): v2.0.0` convention (or anything else)
instead of the wordy generated default. Config/env only — no CLI flag.
Originated in issue #69 (2026-07-15 feature review, Tier 3 — polish).

| ID | Requirement | Status |
| --- | --- | --- |
| R-TPL-1 | `COMMIT_MSG_TEMPLATE` config/env key (R-CFG-3 precedence: env > `.ver-bumprc` > default). Placeholders: `${version}`, `${prev_version}`, `${tag}`, `${files}` (the generated changed-file list that makes up the legacy message body, without its trailing `", "`). Unset/empty → the exact `COMMIT_MSG_PREFIX` + generated-list behaviour, byte-identical. | ✅ shipped — `render-commit-msg` |
| R-TPL-2 | When set, the template owns the whole message and `COMMIT_MSG_PREFIX` is ignored (interaction documented in the README `.ver-bumprc` section). | ✅ shipped |
| R-TPL-3 | Substitution is literal string replacement (bash `${var//pat/rep}`) — no `eval`, no command substitution of template content; `$(...)`/backticks/unknown placeholders stay literal text. | ✅ shipped |
| R-TPL-4 | Applies to the bump commit only; the annotated tag message keeps its own knob (`-m`/`--message`). | ✅ shipped |

## Design note — one renderer

`render-commit-msg` (`lib/changelog.sh`) is the single renderer. Both
consumers MUST go through it:

- `do-commit` (`lib/git-actions.sh`) — the real `git commit -m`.
- `do-changelog` (`lib/changelog.sh`) — the manual CHANGELOG entry for the
  bump commit, which is written *before* that commit exists.

That sharing is the invariant that keeps the CHANGELOG entry and the
actual commit message identical in both `CHANGELOG_STYLE`s. The changelog
logs the rendered message's first line only (the same subject-only view
`git log %s` gives every other entry); grouped style then applies its
normal subject rendering (type stripped, scope bolded) to that line, as
it does for every commit.

`${files}` is substituted last, so a bumped file whose name contains
placeholder text cannot be substituted a second time. Because
`.ver-bumprc` is shell-sourced, templates in the rc must be single-quoted
(`COMMIT_MSG_TEMPLATE='chore(release): v${version}'`) or the shell
expands the placeholders to empty strings at source time.

On bash 5.2+ (`patsub_replacement`, on by default) `&` and `\` are special
on the replacement side of `${var//pat/rep}`, so substituted values are
backslash-escaped first — but only when that option is active, because
bash 3.2 substitutes replacements literally and the extra backslashes
would leak into the message there. A bumped file named `R&D.json` renders
identically on both generations (pinned in tests).

## Test mapping

`test/commit-template.bats` (19):

- R-TPL-1 — legacy byte-identical pin (unit + live), each placeholder
  renders, `${files}` matches the generated list (live), unknown
  placeholder passes through, precedence trio (env > rc > default,
  end-to-end dry-run).
- R-TPL-2 — `COMMIT_MSG_PREFIX` ignored when template set (unit + live
  whole-message assert).
- R-TPL-3 — `$(touch …)`/backtick templates stay literal and execute
  nothing (unit + live commit); `&`/`\` stay literal in template text and
  in substituted values (unit + live `-f R&D.json`), identically on bash
  3.2 and 5.2+.
- R-TPL-4 — annotated tag message unaffected (live).
- Renderer sharing — CHANGELOG bump entry equals the commit subject in
  flat and grouped styles; multi-line template keeps its body in the
  commit but logs only the subject line.

Modules: `lib/changelog.sh` (`render-commit-msg`, `do-changelog`),
`lib/git-actions.sh` (`do-commit`), `lib/config.sh` (`_CONFIG_KEYS`).
