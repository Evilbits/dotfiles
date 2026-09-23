# Reviewing a written proposal

Mechanics for a technical design, an RFC, a Confluence page or a Slack thread proposing an approach. `SKILL.md` carries the altitude rule, triage and severity; this file carries what is specific to reviewing a document.

Proposal stage is the highest-leverage moment this skill has. After implementation the shape is already paid for. A finding here costs a conversation; the same finding after merge costs a rewrite.

## 1 — Establish what is being decided

State in one or two sentences the problem the proposal claims to solve, the approach it lands on, and the alternatives it rejects. Then state the decision at stake, which is often narrower than the document's scope.

Separate three things, because documents blur them:

- **What is proposed** — the design.
- **What is asserted as fact** — claims about how existing systems behave. These are load-bearing and checkable.
- **What is assumed without being stated** — step 3.

Note what the author says is deliberate and what is deferred. A deliberate choice can still be wrong, and "this is deliberate, and here is why it is still wrong" is a stronger finding than one implying an oversight.

## 2 — Check the load-bearing claims at their source

**The highest-value step in a proposal review, with no equivalent in a code review.** A proposal that rules out an option rests on a claim about why that option cannot work. If the claim is wrong, or was true once and is no longer, the comparison collapses and the rejected option comes back.

For each claim the design depends on:

1. Name the claim and where the document makes it.
2. Verify it against the system that owns the behaviour, never against the code that consumes it, and never from memory. Hotpot semantics come from `~/dev/hotpot`, its merge requests and their discussions. Platform behaviour comes from the platform.
3. Establish **as of when** it is true. A limitation being fixed, or one that is opt-in and not yet adopted, is a dependency, not an impossibility; a design that treats it as permanent has closed off an option it should still weigh.
4. If a claim cannot be verified, say so and mark the finding as resting on it.

The failure this catches: new infrastructure justified by a limitation that a small adoption elsewhere would remove.

## 3 — What the proposal does not address

Absence is the characteristic defect of a design document and is invisible unless looked for. Record each:

- **Migration** from what exists today, and whether both can run at once.
- **Rollback.** If this ships and is wrong, what does undoing it cost, and is data written in the new shape still readable.
- **Version skew.** Two participants on different app versions; a client against an older backend.
- **Failure modes.** The new path unavailable, slow, or partially applied, and whether the app author has to handle it.
- **Who owns the new thing** once built, and whether that team agreed.
- **What the app author has to do**, since complexity pushed to the app is the cost this domain refuses to pay.
- **Scale and lifecycle.** Many objects, long sessions, reconnects, a participant who leaves and returns.

## 4 — Architecture pass

The code-review questions, asked of the design:

1. **Layer placement.** Does each responsibility land in the layer that owns it? Does the proposal put into the platform something that belongs in one app, or into an app something the platform owes every app?
2. **Capability genericity.** If it proposes a capability, run the five tests in `apps/extensions/.cursor/rules/02-capability-rules.mdc`. Ask whether a second app would ever use it.
3. **App-facing surface.** What does an app author see, and is it the thinnest thing that works? Complexity belongs in the library.
4. **Vocabulary.** Does the design introduce terms an app author must learn for ideas they already have words for?
5. **One decision point.** Does a single rule end up enforced in several components?
6. **New infrastructure versus existing capability.** Does this stand up something a system already owned would provide? Name the existing option, say what adopting it would cost, and compare; do not assume the proposal considered it.
7. **Cross-participant behaviour.** Concurrency, conflict, and who wins.

## 5 — Triage and present

Follow the primer's triage. Severity by cost to reverse applies with more force, because a proposal has shipped nothing: **blocking** means this should not be built in this shape.

Give each finding an ID and severity. Two prefixes: **`A`** for the shape of the design, **`C`** for a claim that is wrong or a mechanism that will not work as described. A wrong load-bearing claim is a `C`, since it must be resolved whichever design wins.

Anchor by quoting the exact text challenged, since there are no line numbers, and name the nearest heading. Load-bearing claims often sit in comparison tables; when the target is a cell, quote it and name the table and row.

Each finding gives: the claim in one sentence; the anchor; the **cause**; the consequence for the app author, the platform, or whoever maintains this next.

### Costing an alternative

Lines of code do not exist yet, so count concepts, and label them estimates:

- **Removed**: components that no longer need building, infrastructure not stood up, operational surface not taken on, app-facing concepts an author no longer learns.
- **Added**: new dependencies, adoption work elsewhere, new failure modes, concepts the design introduces.
- **Net**: the balance, including when it is close and the gain is that one system rather than two carries the behaviour.
- **Risk**: what the alternative makes harder, and what must be true for it to work. Name the dependency when the alternative only works once something else lands.

An alternative is worth proposing at this altitude only if it removes a component or a concept. One that rearranges the same parts is the low-altitude failure this skill prevents.

**Check your own alternative against the document's other rules before writing it up.** Step 2 verifies the author's claims at their source; this verifies yours against the design in front of you, and it is the step most easily skipped because the alternative feels obviously simpler. For every component or failure mode the alternative claims to remove, find the rule that governs it and confirm the removal follows. Rules interact; an invariant stated in one rule often survives a change to another, and a saving claimed against it is imaginary.

Distrust hardest a claim of the form "under my alternative, X becomes impossible by construction". Name the rule that makes X impossible. If the rule that produces X is untouched, X survives and the saving comes out of the costing.

Getting this wrong puts the author in the position of defending their own document against a reviewer who did not read it carefully, which costs more credibility than the finding was worth.

## 6 — Placement plan, only after consensus

When the review is settled:

**Inline comment on a quoted passage.** Anything challenging a specific claim or sentence. Give the heading, the exact text to attach to, and the comment.

**Page-level comment.** Anything about the shape of the proposal as a whole or spanning sections. Draft in full in the reviewer's voice: first person, question-led where the answer is open, hedged where uncertain, no lists, no em dashes, no AI cadence. Pipe each draft to the clipboard.

A proposal review often produces work that is not a comment: a ticket for a dependency the design needs, or a question for the team that owns a system it leans on. Separate those out.
