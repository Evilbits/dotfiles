# Reviewing code

Mechanics for an MR, a diff, a branch or a commit range. The primer in
`SKILL.md` carries the altitude rule, triage and severity; this file carries
everything specific to reading a diff.

## 1 — Establish the change's own goal

State in one or two sentences what the change sets out to achieve and what it
explicitly defers. Every later finding is judged against that goal, and a
finding that asks the change to solve a different problem is out of scope by
definition.

**The MR description is evidence about the author's intent and nothing more,
and on a merged MR it is frequently not even that.** A merged description is
often rewritten to describe the design as it ended up, including changes made in
response to review, so on a merged or revised MR it can describe code that does
not exist at the revision under review. Prefer the commit trail and the code
itself for what the change actually does, and treat the description as a claim
to check. When reviewing a historical revision, read the description last, or
not at all, and disclose it if you did.

Note what the author says is deliberate. A deliberate choice can still be wrong,
and saying "this is deliberate, and here is why it is still wrong" is a stronger
finding than one that reads as though the author overlooked it.

## 2 — Architecture pass

Do this before reading for bugs, and answer each question explicitly even when
the answer is "fine". Where a question turns up something real that a blocking
finding would later suppress, record it inside the answer and mark it held. That
honours both the explicit answer and the suppression rule.

1. **Layer placement.** Does every piece live in the layer that owns it? Run the
   ownership tests in `domain-architecture.md`.
2. **Capability genericity.** If a capability is added or extended, run the
   five-part capability test. Note that **most capabilities pass it**: the
   worked example in the reference is an outlier chosen because it fails every
   test, and it is not the expected outcome. Walk the five tests, record the
   verdict on each, and if they pass, say so and move on rather than hunting for
   a technicality.
3. **App-facing surface.** Is the public surface the thinnest that supports the
   use case? Two things fail. Anything exported that a consumer must never call,
   and anything exported that no consumer actually uses today, including
   type-only exports, since a published type is permanent once an app imports
   it. Types describing the library's internal storage or wire model are the
   ones to challenge hardest, because hiding those is the library's purpose.
4. **Vocabulary.** Does every consumer-facing name match the consumer's existing
   mental model? A new term the consumer must learn needs to earn itself.
5. **One decision point.** Is each rule decided in exactly one place? A rule
   enforced in three places will drift.
6. **Arrangement versus volume.** If the diff is large for what it achieves, ask
   whether the arrangement is the cause. **Measure before making this finding.**
   Volume alone is not evidence, and "this feels like a lot of code" is an
   impression. Count the non-comment lines of the thing you are calling
   overgrown, or diff the two files you are calling duplicates and count how
   many lines actually differ. If the number comes back unremarkable, drop the
   finding. The recurring cause found this way is an abstraction organised by
   concept that handles several directions of flow at once, for example a store
   doing both read and write, so splitting by direction shrinks it.
7. **Cross-participant and version skew.** Can two participants be on different
   versions, and does this behave when they are?
8. **Test coverage as a signal.** Not a full coverage review, which
   `.cursor/skills/review-coverage` does properly. Here it is architectural
   evidence: a new file with no spec at all, or a component with far less
   coverage than the sibling it was copied from, says something about what the
   author considered load-bearing. Report the asymmetry, not a list of missing
   cases.

## 3 — Correctness pass

Read for real defects. A correctness finding is reportable only when it is
concrete: name the inputs or sequence, and the wrong result. Deterministic
failures outrank races, and "this is a bug rather than a style preference" is
worth saying out loud so it is not filed with the architecture discussion.

**A real bug is always reported, including one inside code an architectural
finding would restructure.** State the relationship in one of two forms:

- The bug survives the restructure, so it needs fixing either way.
- The restructure eliminates the bug, which makes it the strongest evidence for
  the restructure. Say so, and give the minimal standalone fix too, so the bug
  remains fixable on its own terms if the architectural proposal is not taken.

A restructure argued without the defect it removes is left arguing on
aesthetics, which is weaker than the evidence supports.

## 4 — Verification pass

Re-read the code behind every surviving finding and confirm it against source
rather than against memory of the diff.

**Establish the revision first**, because getting it wrong produces confidently
wrong findings:

- **Open MR** — the tip of the source branch.
- **Merged MR** — the merge commit against its parent. Never trust a local
  `origin/<branch>` ref, which is frequently stale and often deleted after
  merge. Cross-check the file list against the MR's own.
- **A specific historical revision** — that commit against its merge base, and
  read nothing later, including the current working tree, since later commits
  contain the outcome of the review being reproduced.

Then check:

- A thing claimed to be unused really has no other caller. Grep for it, and
  include specs so "used only by its own test" is visible.
- A named alternative really is simpler once written out, including what it adds.
- **A claim about another system's semantics comes from that system, never
  inferred from the code that consumes it.** How Hotpot resolves concurrent
  writes, what the Journal is for, what Convex guarantees inside a document:
  these are answered by the Hotpot repo at `~/dev/hotpot`, its merge requests
  and the discussions around them. Reading the SDK's call sites tells you what
  this library does today, which is a different question from what the platform
  supports, and the two drift whenever a platform capability is opt-in. If such
  a claim has not been verified at the source, say so rather than asserting it.

Drop any finding that does not survive. A confident finding that turns out to be
wrong costs more trust than a missed nit costs.

## 5 — Present the review

Give each finding a referenceable ID and a severity, for example
`[A1 — blocking]`.

Two prefixes only: **`A`** for shape, covering layer placement, capability
genericity, published surface, vocabulary, decision points and arrangement; and
**`C`** for a defect. A defect whose fix is itself a restructure stays a single
`C` finding carrying its own two-way costing, rather than being split across an
`A` and a `C` that cross-reference each other.

Each finding gives, in order: the claim in one sentence; the `file:line` anchor;
the **cause** rather than the symptom; and the consequence for the app consumer
or for a future reader.

### Costing a rewrite

- **Removed**: non-comment production lines, and the named abstractions, states
  and branches that stop existing.
- **Added**: non-comment production lines, new abstractions or states, and any
  new invariant the reader must hold.
- **Net**: the honest balance.
- **Risk**: what it makes easier to get wrong, and the ordering constraints.

**Counting rules.** Non-comment production lines are the headline. Report the
comment-line change separately when material, since removing machinery usually
removes the comments explaining it and one combined number overstates the win.
Exclude test LOC, because tests scale with surface rather than complexity —
and when a proposal's main effect is that a large body of tests disappears, say
so in words, since that is real value the headline number deliberately hides.

**Precision.** A whole block that disappears can be counted exactly, so count
it. A function that is kept but rewritten cannot be, so both its sides are
estimates. The replacement is always an estimate. Label estimates as estimates
and never present one in the voice of a count. Where the argument turns on the
numbers being close, write enough of the alternative to make the estimate real.

**Check the alternative against the constraints already in the code.** For every
piece of machinery the restructure claims to delete, find what forces that
machinery to exist and confirm the restructure removes the force rather than
just the machinery. An invariant enforced elsewhere, a guarantee another caller
depends on, or a rule stated in a neighbouring comment will frequently survive
the change and drag its machinery back. A claim that some failure mode "becomes
impossible" must name the thing that made it possible and show the restructure
removes it.

The reference standard for a costed architectural finding is in
`review-doctrine.md`.

## 6 — Placement plan, only after consensus

When the review is settled, and not before, output where each comment goes.

**Inline, attached to code.** Anything naming a specific change to specific
lines, and any architectural point genuinely about one service, class or file.
Give `file:line` and text short enough to read in a diff thread.

**Unattached MR comment.** Anything whose subject is the shape of the change
across several files. Draft these in full, in the reviewer's voice: first
person, question-led where the answer is genuinely open, hedged where uncertain,
no lists, no em dashes, no AI cadence. Pipe each draft to the clipboard.

Out-of-scope findings become ticket suggestions rather than review comments:
give the epic, a title and the reasoning, so they can be filed and the MR stays
as scoped. Never ask an MR to absorb work belonging in its own ticket.
