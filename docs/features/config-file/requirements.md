# Config file (.ver-bumprc)

Repo- or home-level defaults without repeating flags. Shipped in 2.0
(originally a PRD non-goal; the PRD was reconciled — see §5.10).

| ID | Requirement | Status |
| --- | --- | --- |
| R-CFG-1 | Discovered by walking up from `$PWD` to `/`; first match wins; absence is not an error. | ✅ shipped — `_find-rc-upward` |
| R-CFG-2 | Supported keys: `TAG_PREFIX`, `REL_PREFIX`, `PUSH_DEST`, `COMMIT_MSG_PREFIX`, `FLAG_NOBRANCH`, `FLAG_NOCHANGELOG`, `FLAG_CHANGELOG_PAUSE`, `FLAG_YES`. Unknown keys warn on stderr. | ✅ shipped |
| R-CFG-3 | Precedence: CLI > env > `.ver-bumprc` > built-in default, end-to-end. | ✅ shipped (`f6d66b4`) — `test/config-env.bats` |
| R-CFG-4 | Refused (exit `3`) if world-writable, group-writable, or not owned by the invoking user. | ✅ shipped (`6a37077`) |
| R-CFG-5 | Shell-sourced, not parsed; sourcing failures exit `3` with the shell error as context. | ✅ shipped |
| R-CFG-6 | CLI-only switches (`DO_RELEASE`, `BUMP_LEVEL`) reset before parsing — env/rc can never force a bump or release. | ✅ shipped (`783f457`) |

Precedence is enforced by call ordering in `main()`
(`load-config` → `apply-config-defaults` → `process-arguments`) — don't
reorder, don't add a fifth tier (see `docs/CODE_STYLE.md`).

Modules: `lib/config.sh`. Tests: `test/config.bats` (11),
`test/config-env.bats` (4).
