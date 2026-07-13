# Coding Standards

<!-- Loaded by the reviewer agent via @.sandcastle/CODING_STANDARDS.md. -->

The canonical standards document is [docs/CODE_STYLE.md](../docs/CODE_STYLE.md).
Read that file in full before reviewing or writing code — it covers Bash
style, UI/colour discipline, the exit-code contract, testing requirements,
module boundaries, PR conventions, and issue conventions.

Two rules worth restating for reviewers:

- Always exit via `fail <code> "<message>" "<hint>"` (`lib/errors.sh`);
  exit codes come from the contract table (0–5, 4 reserved).
- Every new flag, exit code, or UI change requires matching bats coverage
  (`test/*.bats`, one file per feature).
