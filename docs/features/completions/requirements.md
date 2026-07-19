# Shell completions

Tab completion for every flag, in bash/zsh/fish, plus a one-shot installer.

| ID | Requirement | Status |
| --- | --- | --- |
| R-COMP-1 | Emitted bash passes `bash -n`; zsh passes `zsh -n` **and** survives a live `_arguments` completion run (zpty-driven — `zsh -n` can't catch bad option specs); fish passes `fish -n` when available. | ✅ shipped — `test/completions-syntax.bats` |
| R-COMP-2 | Completions offer every short and long flag. | ✅ shipped |
| R-COMP-3 | After `-f`/`--file`, restrict to `*.json`. | ✅ shipped |
| R-COMP-4 | After `--completions`, offer `bash zsh fish`. | ✅ shipped |
| R-COMP-5 | Registered for `VerBump`, lowercase `verbump` (case-insensitive filesystems run `VerBump` for it, but completion matches the literal word), and `verbump.sh`. | ✅ shipped |
| R-COMP-6 | `--install-completions [shell]` auto-detects from `$SHELL` (exit `2` if detection fails); installs to user scope — zsh: `~/.local/share/zsh/site-functions` with omz-aware hint (`61016d3`). | ✅ shipped — `test/install-completions.bats` (10); issue #42 |
| R-COMP-7 | `--install-completions` honours `--dry-run` regardless of flag order; accepts both `=shell` and space-form (`c12147c`). | ✅ shipped |

`--completions` and `--install-completions` require no `package.json` or git
repo — they run and exit before preconditions (`emit-completions` exits `1`
on an unknown shell per R-OPT-5).

Modules: `lib/completions.sh`. Tests: `test/args.bats`,
`test/completions-syntax.bats`, `test/install-completions.bats`.
