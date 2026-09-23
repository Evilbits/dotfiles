# Reviewing code

Mechanics for an MR, a diff, a branch or a commit range. `SKILL.md` carries the altitude rule, triage and severity; this file carries what is specific to reading a diff.

## 0 — Establish what is under review

Diff against the MR's target branch, never master by default. A title ending `(n/N)` is a stacked MR: when the target is a feature branch, the review covers `target..source` only. If the target has already merged and the diff still shows the parent's commits, the stack is unsynced: say so and stop, since every finding would land on the wrong MR.

## 1 — Establish the change's own goal

State in one or two sentences what the change sets out to achieve and what it defers. Every finding is judged against that goal; one that asks the change to solve a different problem is out of scope.

**The MR description is evidence of the author's intent and nothing more; on a merged MR it is often not even that.** Merged descriptions are rewritten to describe the design as it ended up, review changes included, so they can describe code that does not exist at the revision under review. Take what the change does from the commit trail and the code, and treat the description as a claim to check. On a historical revision, read the description last or not at all, and disclose it if you did.

Note what the author says is deliberate. A deliberate choice can still be wrong, and "this is deliberate, and here is why it is still wrong" is a stronger finding than one that reads as an oversight.

## 2 — Architecture pass

Before reading for bugs. Answer each question even when the answer is "fine". Where a question finds something a blocking finding would later suppress, record it inside the answer and mark it held.

1. **Layer placement.** Does every piece live in the layer that owns it? Run the ownership tests in `apps/extensions/AGENTS.md`: Where data lives, Where code lives, Capability or app feature.
2. **Capability genericity.** If a capability is added or extended, run the five tests in `apps/extensions/.cursor/rules/02-capability-rules.mdc`. **Most capabilities pass them**; `interpreter` and `transcription` are the named exceptions and not precedent. Record the verdict on each test, and if they pass, say so and move on.
3. **App-facing surface.** Is the public surface the thinnest that supports the use case? Two things fail: an export a consumer must never call, and an export no consumer uses today, type-only exports included, since a published type is permanent once an app imports it. Challenge hardest the types that describe the library's internal storage or wire model; hiding those is the library's purpose.
4. **Vocabulary.** Does every consumer-facing name match the consumer's existing mental model? A new term the consumer must learn needs to earn itself.
5. **One decision point.** Is each rule decided in one place? A rule enforced in three places drifts.
6. **Arrangement versus volume.** If the diff is large for what it achieves, ask whether the arrangement is the cause. **Measure before making this finding.** Volume alone is not evidence, and "this feels like a lot of code" is an impression. Count the non-comment lines of the thing called overgrown, or diff the two files called duplicates and count the lines that differ. If the number is unremarkable, drop the finding. The recurring cause is an abstraction organised by concept that handles several directions of flow at once, such as a store doing both read and write; splitting by direction shrinks it.
7. **Cross-participant and version skew.** Can two participants be on different versions, and does this behave when they are?
8. **Test coverage as a signal.** Not a coverage review, which `.cursor/skills/review-coverage` does. Here it is architectural evidence: a new file with no spec, or a component with far less coverage than the sibling it was copied from, says what the author considered load-bearing. Report the asymmetry, not a list of missing cases.

## 3 — Correctness pass

Read for defects. A correctness finding is reportable only when concrete: the inputs or sequence, and the wrong result. Deterministic failures outrank races. Say "this is a bug rather than a style preference" so it is not filed with the architecture discussion.

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

Drop any finding that does not survive. A confident wrong finding costs more trust than a missed nit.

## 5 — Present the review

Give each finding an ID and a severity, for example `[A1 — blocking]`.

Two prefixes: **`A`** for shape (layer placement, capability genericity, published surface, vocabulary, decision points, arrangement) and **`C`** for a defect. A defect whose fix is a restructure stays one `C` finding with its own two-way costing, never an `A` and a `C` cross-referencing each other.

Each finding gives, in order: the claim in one sentence; the `file:line` anchor; the **cause**, not the symptom; the consequence for the app consumer or a future reader.

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

Out-of-scope findings become ticket suggestions: the epic, a title and the reasoning, so the MR stays as scoped. Never ask an MR to absorb work that belongs in its own ticket.
