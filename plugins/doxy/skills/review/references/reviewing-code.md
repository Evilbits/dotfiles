# Reviewing code

Mechanics for an MR, a diff, a branch or a commit range. `SKILL.md` carries the altitude rule, triage and severity; this file carries what is specific to reading a diff.

## 0 — Establish what is under review

Diff against the MR's target branch, never master by default. A title ending `(n/N)` is a stacked MR: when the target is a feature branch, the review covers `target..source` only. If the target has already merged and the diff still shows the parent's commits, the stack is unsynced: say so and stop, since every finding would land on the wrong MR.

**Split the diff by blast radius before reading it.** List every changed path outside the change's own directory: `.gitlab/`, root configs, the lockfile beyond the change's own dependencies, shared libs, docs that describe other things. Each of those is reviewed as its own change with its own goal, consequence line and severity, because it lands on every project in the repo whatever the feature does. A repo-wide change riding in a feature MR is reported on its own even when it is correct.

**Decide the architecture gate from the same list.** The architecture reviewer runs when the diff carries any of these, and the decision is printed with its reasons before anything is spawned:

- A `Dockerfile`, anything under `.gitlab/`, Terraform, or a root config file.
- A new entry in a `dependencies` block, or a new system binary or native dependency.
- A new top-level folder or module in an app or service, or a new import across projects.
- A published lib's exports, a `.changeset/` file, a capability or manifest schema, a GraphQL schema, an entity or a migration.
- Changed paths in more than one project.
- Any path under `apps/extensions/**` or `libs/extensions/**`.

None of them present means the code reviewer runs alone: a fix inside one hook, a copy change or a component tweak does not pay for the architecture pass. "With architecture" in the request turns it on regardless.

**Read the existing threads** on the MR, human and bot, before spawning, and hand them to both reviewers so a point already raised is marked rather than rediscovered.

## 1 — Establish the change's own goal

State in one or two sentences what the change sets out to achieve and what it defers. Every finding is judged against that goal; one that asks the change to solve a different problem is out of scope.

**The MR description is evidence of the author's intent and nothing more; on a merged MR it is often not even that.** Merged descriptions are rewritten to describe the design as it ended up, review changes included, so they can describe code that does not exist at the revision under review. Take what the change does from the commit trail and the code, and treat the description as a claim to check. On a historical revision, read the description last or not at all, and disclose it if you did.

Note what the author says is deliberate, then set it aside; `SKILL.md` says why the author's framing carries no weight in severity. A deliberate choice can still be wrong, and "this is deliberate, and here is why it is still wrong" is a stronger finding than one that reads as an oversight.

## 2 — Spawn the reviewers

Two general-purpose subagents, read-only, in parallel, each with its brief read from this skill's directory: `brief-architecture.md` when the gate is on, `brief-code.md` always. Each prompt carries the diff command and base, the commit trail, the worktree or checkout path, the ticket text, the MR description labelled as the author's claims, the existing threads, and for the code reviewer the mock policy section of the testing rule for the touched paths. It carries nothing this session has concluded about the change, and neither reviewer sees the other's output.

The architecture brief holds the checks that used to be the architecture pass here: rules and precedent, the landed-decision rule, layer placement, capability genericity, app-facing surface, vocabulary, one decision point, arrangement, version skew, coverage as a signal. The code brief holds the correctness questions: during the wait, twice, re-created, never answers, which failure, contract, input shapes, performance, tests that cannot catch a regression. Read a brief when a finding comes back that needs its context to judge; do not run its checks here.

## 3 — Rate what came back

Both lists arrive raw with a deciding line or a trigger each. Rate every finding here by the severity table in `SKILL.md`, in one scale across both lists, and apply the altitude rule: an open Critical or High architecture finding holds the Medium and Low findings inside what it would restructure, and holds every Low. A walked defect is never held. A finding marked "already raised by X" keeps its level.

A correctness finding is reportable only when concrete: the inputs or sequence, and the wrong result. Deterministic failures outrank races. Say "this is a bug rather than a style preference" so it is not filed with the architecture discussion.

**A real bug is always reported, including one inside code an architectural finding would restructure.** State the relationship:

- The bug survives the restructure, so it needs fixing either way.
- The restructure eliminates the bug, which is the strongest evidence for the restructure. Say so, and give the minimal standalone fix too, so the bug stays fixable if the proposal is not taken.

A restructure argued without the defect it removes is arguing on aesthetics.

## 4 — Verification pass

Re-read the code behind every surviving finding against source, not memory of the diff.

**Establish the revision first**; getting it wrong produces confidently wrong findings:

- **Open MR** — the tip of the source branch.
- **Merged MR** — the merge commit against its parent. Never trust a local `origin/<branch>` ref; it is often stale or deleted after merge. Cross-check the file list against the MR's own.
- **A historical revision** — that commit against its merge base, reading nothing later, including the working tree, since later commits contain the outcome of the review being reproduced.

Then check:

- A thing claimed unused has no other caller. Grep, specs included, so "used only by its own test" is visible.
- A named alternative is simpler once written out, including what it adds.
- **A claim about another system's semantics comes from that system, never inferred from the code that consumes it.** How Hotpot resolves concurrent writes, what the Journal is for, what Convex guarantees inside a document: answered by the Hotpot repo at `~/dev/hotpot`, its merge requests and their discussions. The SDK's call sites say what this library does today, which differs from what the platform supports whenever a platform capability is opt-in. An unverified claim is stated as unverified.

Drop any finding that does not survive. A confident wrong finding costs more trust than a missed Low.

## 5 — Present the review

Two sections, **Architecture** and **Code**, so the two angles stay visible. Within each, give every finding an ID and a severity, for example `[C1 — Critical]`, and order Critical, High, Medium, Low. When the architecture lane did not run, say so and why in one line in its place; when it ran and found nothing, record that as the result it is.

Two prefixes: **`A`** for shape (layer placement, capability genericity, published surface, vocabulary, decision points, arrangement) and **`C`** for a defect. A defect whose fix is a restructure stays one `C` finding with its own two-way costing, never an `A` and a `C` cross-referencing each other.

Each finding uses the layout in `SKILL.md`, What reaches the MR: header with ID, level, anchor and claim, then **Consequence**, **Cause**, **Fix** on their own labelled lines. Cause is the mechanism, never the symptom restated. In a posted GitLab comment the labels are dropped and the three parts become its paragraphs, consequence first (layout in section 6).

### Costing a rewrite

- **Removed**: non-comment production lines, and the abstractions, states and branches that stop existing.
- **Added**: non-comment production lines, new abstractions or states, and any new invariant the reader must hold.
- **Net**: the balance.
- **Risk**: what it makes easier to get wrong, and the ordering constraints.

**Counting.** Non-comment production lines are the headline. Report the comment-line change separately when material, since removing machinery removes the comments explaining it and one combined number overstates the win. Exclude test LOC, since tests scale with surface, not complexity; when a proposal's main effect is that a large body of tests disappears, say so in words, since the headline number hides that.

**Precision.** A block that disappears can be counted exactly, so count it. A function kept but rewritten cannot be, so both its sides are estimates, and the replacement is always an estimate. Label estimates as estimates. Where the argument turns on the numbers being close, write enough of the alternative to make the estimate real.

**Check the alternative against the constraints already in the code.** For every piece of machinery the restructure deletes, find what forces it to exist and confirm the restructure removes the force, not just the machinery. An invariant enforced elsewhere, a guarantee another caller depends on, or a rule in a neighbouring comment often survives the change and drags its machinery back. "X becomes impossible" must name what made X possible and show the restructure removes it.

The reference standard for a costed architectural finding is in `review-doctrine.md`.

## 6 — Placement plan, only after consensus

When the review is settled, output where each comment goes.

**Inline, attached to code.** Anything naming a change to specific lines, and any architectural point about one service, class or file. Give `file:line` and text short enough for a diff thread.

**Unattached MR comment.** Anything about the shape of the change across files. Draft in full in the reviewer's voice: first person, question-led where the answer is open, hedged where uncertain, no lists, no em dashes, no AI cadence. Pipe each draft to the clipboard.

**Comment layout.** A posted comment is short paragraphs with a blank line between them, one idea each: what happens (the consequence, or the observation it rests on), then why (the cause), then the ask on its own at the end. Any comment longer than three sentences has at least two paragraphs. A hedge ("I might be wrong here") or a request to verify belongs with the ask, never folded into the cause. The body passed to GitLab carries the blank lines as real newlines. Every code-like token is in backticks: identifiers, hooks, components, props, types, package names, paths, config keys, commands and file names (`boardId`, `useBoardRecordSaved`, `@doxyme/extensions-hotpot`). Before posting, read the draft once for bare identifiers; a camelCase or PascalCase word outside backticks is the usual miss. A link is a markdown link on words that say where it goes, never a pasted URL.

Out-of-scope findings become ticket suggestions: the epic, a title and the reasoning, so the MR stays as scoped. Never ask an MR to absorb work that belongs in its own ticket.

**Review state.** The GitLab MCP posts comments and a summary note; it cannot set the reviewer state (Comment, Approve, Request changes) that GitLab's Submit review dialog sets, and a `verdict` passed to it is only text. Say so when handing over, and let the user set the state in the UI, or set it through `glab api graphql` with `mergeRequestUpdateReviewerState` when they ask.
