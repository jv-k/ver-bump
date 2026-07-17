<!--
Title: <type>(<scope>): <subject> — imperative, lowercase, ≤ 70 chars.
  types:  feat fix refactor test chore docs ci
  scopes: ui errors config args version git-actions changelog json
          completions tests docs publish
Full conventions: docs/CODE_STYLE.md § Pull requests
-->

<!-- One-paragraph summary: what and why. -->

<!-- Bullet list of concrete changes, grouped by area if multi-scope. -->

<!-- Behavioural notes / edge cases / precedence rules touched (delete if none). -->

Tests: <!-- what was added — file + case count. "Full suite: N/N." when green. -->

Refs #<issue>.

---

- [ ] `pnpm lint` passes with zero warnings
- [ ] `pnpm tests:run` is green
- [ ] Bash 3.2+ compatible (no associative arrays / bash-4-isms)
- [ ] PR is scoped to one concern
