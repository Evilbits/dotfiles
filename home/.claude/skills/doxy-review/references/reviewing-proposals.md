# Reviewing a written proposal

Mechanics for a technical design, an RFC, a Confluence page or a Slack thread
proposing an approach. The primer in `SKILL.md` carries the altitude rule,
triage and severity; this file carries everything specific to reviewing a
document.

Reviewing at proposal stage is the highest-leverage moment this skill has.
Arriving after the implementation means the shape is already paid for, and the
review has nowhere to go. A finding here costs a conversation; the same finding
after merge costs a rewrite.

## 1 — Establish what is actually being decided

State in one or two sentences the problem the proposal claims to solve, the
approach it lands on, and the alternatives it rejects. Then state the decision
that is genuinely at stake, which is often narrower than the document's scope.

Separate three things explicitly, because documents blur them:

- **What is being proposed** — the design.
- **What is asserted as fact** — claims about how existing systems behave. These
  are the load-bearing parts and they are checkable.
- **What is assumed without being stated** — see step 3.

Note what the author says is deliberate, and what they say is deferred. A
deliberate choice can still be wrong, and "this is deliberate, and here is why
it is still wrong" is a stronger finding than one implying an oversight.

## 2 — Check the load-bearing claims at their source

**This is the highest-value step in a proposal review, and it has no equivalent
in a code review.** A proposal that rules out an option rests on a claim about
why that option cannot work, and if the claim is wrong, or was true once and is
no longer, the whole comparison collapses and the rejected option comes back.

For each claim the design depends on:

1. Name the claim and where the document makes it.
2. Verify it against the system that owns the behaviour, never against the code
   that consumes it, and never from memory. Hotpot semantics come from
   `~/dev/hotpot`, its merge requests and the discussions around them. Platform
   behaviour comes from the platform.
3. Establish **as of when** it is true. A limitation being actively fixed, or
   one that is opt-in and merely not adopted yet, is a dependency rather than an
   impossibility, and a design that treats it as permanent has closed off an
   option it should still be weighing.
4. If a claim cannot be verified, say so and mark the finding as resting on it,
   rather than asserting either way.

The failure this catches: significant new infrastructure justified by a
limitation that a small adoption elsewhere would remove.

## 3 — What the proposal does not address

Absence is the characteristic defect of a design document, and it is invisible
unless looked for deliberately. Work through these and record each explicitly:

- **Migration** from whatever exists today, and whether both can run at once.
- **Rollback.** If this ships and is wrong, what does undoing it cost, and is
  data written in the new shape still readable.
- **Version skew.** Two participants on different app versions, and a client
  against an older backend.
- **Failure modes.** What happens when the new path is unavailable, slow, or
  partially applied, and whether the app author has to handle it.
- **Who owns the new thing** once built, and whether that team agreed.
- **What the app author has to do**, since complexity pushed to the app is the
  cost this domain most consistently refuses to pay.
- **Scale and lifecycle.** What happens with many objects, long sessions,
  reconnects, or a participant who leaves and returns.

## 4 — Architecture pass

The same questions as a code review, asked of the design:

1. **Layer placement.** Does each responsibility land in the layer that owns it?
   Does the proposal put into the platform something that belongs in one app, or
   into an app something the platform owes every app?
2. **Capability genericity.** If it proposes a capability, run the five-part
   test in `domain-architecture.md`. Most proposals that reach for a capability
   should be asked whether a second app would ever use it.
3. **App-facing surface.** What does an app author see, and is it the thinnest
   thing that works? Complexity belongs in the library.
4. **Vocabulary.** Does the design introduce terms an app author must learn for
   ideas they already have words for?
5. **One decision point.** Does a single rule end up enforced in several
   components?
6. **New infrastructure versus existing capability.** Does this stand something
   up that a system already owned would provide? Name the existing option, say
   what adopting it would cost, and compare honestly rather than assuming the
   proposal considered it.
7. **Cross-participant behaviour.** Concurrency, conflict, and who wins.

## 5 — Triage and present

Follow the primer's triage. Severity by cost to reverse applies with more force
here, because a proposal has shipped nothing: **blocking** means this should not
be built in this shape.

Give each finding an ID and severity. Two prefixes: **`A`** for the shape of the
design, **`C`** for a claim that is wrong or a mechanism that will not work as
described. A wrong load-bearing claim is a `C`, since it has to be resolved
regardless of which design wins.

Anchor to the document by quoting the exact text being challenged, since there
are no line numbers, and name the nearest heading. Load-bearing claims often sit
in comparison tables rather than prose, so when the target is a table cell,
quote the cell and name the table and the row it belongs to.

Each finding gives: the claim in one sentence; the anchor; the **cause**; and
the consequence for the app author, for the platform, or for whoever maintains
this next.

### Costing an alternative

Lines of code do not exist yet, so count concepts instead, and be explicit that
these are estimates:

- **Removed**: components that no longer need building, infrastructure not stood
  up, operational surface not taken on, and app-facing concepts an author no
  longer has to learn.
- **Added**: new dependencies, adoption work elsewhere, new failure modes, and
  concepts the design introduces.
- **Net**: the honest balance, including when it is close and the gain is that
  one system rather than two carries the behaviour.
- **Risk**: what the alternative makes harder, and what has to be true for it to
  work at all. Name the dependency explicitly when the alternative only works
  once something else lands.

An alternative is only worth proposing at this altitude if it removes a
component or a concept. Naming one that merely rearranges the same parts is the
low-altitude failure this skill exists to prevent.

**Check your own alternative against the document's other rules before writing
it up.** Step 2 verifies the author's claims at their source; this verifies
yours against the design in front of you, and it is the step most easily
skipped because the alternative feels obviously simpler. For every component or
failure mode you claim the alternative removes, find the rule or constraint that
governs it and confirm the removal actually follows. A design's rules interact,
so an invariant stated in one rule frequently survives a change to another, and
a saving claimed against it is imaginary.

A claim of the form "under my alternative, X becomes impossible by
construction" is the one to distrust hardest. Name the rule that makes X
impossible. If the rule that produces X is untouched by the alternative, X
survives and the saving must come out of the costing.

Getting this wrong is expensive in a way an ordinary miss is not: it puts the
author in the position of defending their own document against a reviewer who
did not read it carefully, which costs more credibility than the finding was
ever worth.

## 6 — Placement plan, only after consensus

When the review is settled, and not before:

**Inline comment on a quoted passage.** Anything challenging a specific claim or
sentence. Give the heading, the exact quoted text to attach to, and the comment.

**Page-level comment.** Anything about the shape of the proposal as a whole, or
spanning several sections. Draft these in full, in the reviewer's voice: first
person, question-led where the answer is genuinely open, hedged where uncertain,
no lists, no em dashes, no AI cadence. Pipe each draft to the clipboard.

A proposal review often produces work that is not a comment at all: a ticket for
a dependency the design needs, or a question for the team that owns a system the
design leans on. Separate those out rather than burying them in page comments.
