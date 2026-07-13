# Non-interactive mode

`-y` / `--yes` lets CI (US-4) and scripts run ver-bump with no prompts.
Resolved PRD Q-1 in favour of shipping in 2.0.

| ID | Requirement | Status |
| --- | --- | --- |
| R-YES-1 | `-y`/`--yes` auto-accepts the version prompt (suggestion or `-v` value) and the push confirmation. | ✅ shipped — `test/args.bats` |
| R-YES-2 | `FLAG_YES` settable via `.ver-bumprc`; honoured by `--undo`'s confirmation. | ✅ shipped — `test/config.bats`, `test/undo.bats` |

Modules: `lib/args.sh`, `lib/version.sh` (version prompt),
`lib/git-actions.sh` (push + undo confirmations), `lib/config.sh`.
