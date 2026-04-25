// Plan → Implement (parallel) → Review → Merge
//
// Three-phase pipeline modelled on @ai-hero/sandcastle's reference setup,
// adapted for ver-bump (Bash, bats, shellcheck — no TypeScript build step).
//
// Phase 1 (Plan):     orchestrator agent reads `ready-for-agent` issues,
//                     diffs against the host's dirty paths, emits a JSON
//                     <plan> of non-conflicting issues to attempt this round.
// Phase 2 (Impl×N):   up to MAX_PARALLEL implementer agents run in parallel,
//                     each on its own `sandcastle/issue-<n>-<slug>` branch.
//                     Each implementer is followed by a reviewer that may
//                     refine the diff and opens the PR.
// Phase 3 (Merge):    a single merger agent integrates all branches that
//                     produced commits back into `feat/v2.0`, resolving
//                     conflicts and verifying tests + shellcheck after each.
//
// The planner refuses to schedule any issue whose touched files overlap
// with `git status --porcelain` on the host. This is the guard against the
// `SyncError` failure mode where the SDK's auto-merge collides with
// uncommitted host edits.
//
// Usage:
//   npx tsx .sandcastle/main.mts

import * as sandcastle from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const MAX_ITERATIONS = 10;
const MAX_PARALLEL = 4;

const hooks = {
  sandbox: { onSandboxReady: [{ command: "pnpm install --frozen-lockfile" }] },
};
const copyToWorktree = ["node_modules"];
const agent = sandcastle.claudeCode("claude-opus-4-6");

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------

for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
  console.log(`\n=== Iteration ${iteration}/${MAX_ITERATIONS} ===\n`);

  // -------------------------------------------------------------------------
  // Phase 1: Plan
  // -------------------------------------------------------------------------
  const plan = await sandcastle.run({
    sandbox: docker(),
    name: "planner",
    agent,
    promptFile: "./.sandcastle/plan-prompt.md",
  });

  const planMatch = plan.stdout.match(/<plan>([\s\S]*?)<\/plan>/);
  if (!planMatch) {
    throw new Error(
      "Planner did not produce a <plan> tag.\n\n" + plan.stdout,
    );
  }

  const { issues } = JSON.parse(planMatch[1]) as {
    issues: { number: number; title: string; branch: string }[];
  };

  if (issues.length === 0) {
    console.log("Planner returned no issues. Nothing to do.");
    break;
  }

  console.log(`Planner selected ${issues.length} issue(s):`);
  for (const i of issues) console.log(`  #${i.number} ${i.title} → ${i.branch}`);

  // -------------------------------------------------------------------------
  // Phase 2: Implement (parallel) → Review (sequential, per branch)
  // -------------------------------------------------------------------------
  let running = 0;
  const queue: (() => void)[] = [];
  const acquire = () =>
    running < MAX_PARALLEL
      ? (running++, Promise.resolve())
      : new Promise<void>((resolve) => queue.push(resolve));
  const release = () => {
    running--;
    const next = queue.shift();
    if (next) {
      running++;
      next();
    }
  };

  const settled = await Promise.allSettled(
    issues.map(async (issue) => {
      await acquire();
      try {
        const impl = await sandcastle.run({
          hooks,
          copyToWorktree,
          sandbox: docker(),
          branchStrategy: { type: "branch", branch: issue.branch },
          name: `implementer-${issue.number}`,
          maxIterations: 100,
          agent,
          promptFile: "./.sandcastle/implement-prompt.md",
          promptArgs: {
            ISSUE_NUMBER: String(issue.number),
            ISSUE_TITLE: issue.title,
            BRANCH: issue.branch,
          },
        });

        if (impl.commits.length === 0) {
          console.log(`  #${issue.number} produced no commits — skipping review`);
          return { issue, branch: impl.branch, committed: false };
        }

        await sandcastle.run({
          hooks,
          copyToWorktree,
          sandbox: docker(),
          branchStrategy: { type: "branch", branch: issue.branch },
          name: `reviewer-${issue.number}`,
          maxIterations: 1,
          agent,
          promptFile: "./.sandcastle/review-prompt.md",
          promptArgs: {
            BRANCH: issue.branch,
            ISSUE_NUMBER: String(issue.number),
            ISSUE_TITLE: issue.title,
          },
        });

        return { issue, branch: impl.branch, committed: true };
      } finally {
        release();
      }
    }),
  );

  for (const [i, outcome] of settled.entries()) {
    if (outcome.status === "rejected") {
      console.error(
        `  ✗ #${issues[i].number} (${issues[i].branch}) failed: ${outcome.reason}`,
      );
    }
  }

  const merged = settled
    .filter(
      (o): o is PromiseFulfilledResult<{
        issue: (typeof issues)[number];
        branch: string;
        committed: boolean;
      }> => o.status === "fulfilled" && o.value.committed,
    )
    .map((o) => o.value);

  if (merged.length === 0) {
    console.log("No branches produced commits. Skipping merge phase.");
    continue;
  }

  // -------------------------------------------------------------------------
  // Phase 3: Merge
  // -------------------------------------------------------------------------
  await sandcastle.run({
    sandbox: docker(),
    name: "merger",
    maxIterations: 10,
    agent,
    promptFile: "./.sandcastle/merge-prompt.md",
    promptArgs: {
      BRANCHES: merged.map((m) => `- ${m.branch}`).join("\n"),
      ISSUES: merged
        .map((m) => `- #${m.issue.number}: ${m.issue.title}`)
        .join("\n"),
    },
  });

  console.log(`\nMerge phase complete for ${merged.length} branch(es).`);
}

console.log("\nAll iterations done.");
