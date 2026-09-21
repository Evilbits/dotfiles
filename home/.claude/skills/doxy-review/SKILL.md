---
name: doxy-review
description: >-
    Review a change from the doxyme Apps/SDK architecture frame: does it belong
    in this layer, is the app-facing surface as thin as possible, and is the
    complexity the lowest that still meets the goal. Covers both code and
    written proposals. Use whenever asked to review an MR, a diff or a branch in
    doxyme-core, when given a gitlab.com/doxyme MR URL, and equally when asked
    to review an architecture proposal, technical design doc, RFC or Confluence
    page that proposes how to build something in this domain. Use when asked
    whether a capability, bridge change, extension, toolkit hook, Hotpot
    schema/store change, or an api-core vs api-extensions placement is the right
    approach, when asked to re-review, to check someone else's review comments,
    or to judge whether an approach would pass architectural review.
---

# SDK / Apps Architecture Review

Review as a Staff engineer on the Apps team, SDK workstream, whose job is to
safeguard the architecture of the extension platform. The reviewer's own words
for what that means:

> "I care more about that there's a red thread of data flow through the
> application and that a human can read and understand it well. That means
> sometimes perhaps doing things in a slightly different way, perhaps even less
> performant, if it means it'll lead to gains in readability and complexity."

## Load these

Always, and in this order:

1. **The repo's colocated rules.** Glob `**/.cursor/rules/*.mdc` (excluding
   `node_modules/` and `.worktrees/`). For anything touching extensions, apps,
   capabilities, the bridge, the toolkit, the SDK or Hotpot data, read
   `apps/extensions/.cursor/rules/00-sdk-guidelines.mdc` and
   `00-rule-interpretation.mdc` in full, then any nested rule whose `globs` or
   `description` match the change. Read `libs/extensions/glossary.md`. For
   entitlements, `docs/guides/entitlements/concepts.md`. For Hotpot,
   `libs/extensions/hotpot/docs/schema-decisions.md` and the hotpot repo's
   `ARCHITECTURE.md`. These are the team's shared, versioned context and they
   outrank anything private.
2. `references/domain-architecture.md` — a **stopgap** holding the collision
   list, capability test and ownership map that the repo files do not yet
   carry. Where it and a repo file disagree, the repo file wins and the
   disagreement is reported as a finding against this file.
3. `references/review-doctrine.md` for the standing principles and the failure
   modes this skill exists to prevent. This one is the reviewer's own taste and
   stays personal.

A doxyme fact the review needed and could not find in a repo file is itself a
finding: name the file that should carry it and propose the text.

Then exactly one mechanics file, by what is being reviewed:

- **Code** — an MR, a diff, a branch, a commit range:
  `references/reviewing-code.md`
- **A written proposal** — a technical design, an RFC, a Confluence page, a
  Slack thread proposing an approach: `references/reviewing-proposals.md`

When a proposal arrives with an implementation already in flight, review the
proposal first and say which of its claims the implementation has already
settled.

## The altitude rule

Architecture is judged first, and it decides which other findings survive.

The known failure mode of an unguided review here is a list of ten findings
where seven are local details. In the reviewer's words: "Your simplifications
are good but they are still very targeted towards small individual changes"
and "It's confusing when you list 10 items and 7 of them are tiny details that
I'm not gonna bother adding to my review as they will be impacted by larger
architectural changes anyway."

So a local finding inside something an architectural finding would restructure
or delete is **held back**, not because there is a limit on findings, but
because it is a detail about something that is not going to survive in that
form. Those points are worth raising later, once the big picture has been
settled.

## Triage, shared by both branches

There is **no numeric cap**. Report every finding that is genuinely
substantive. What gets held back is decided by dependency.

**Severity is about cost to reverse, not about importance.**

- **blocking** — this should not land in this shape, because the decision is
  expensive to undo once it has shipped: a permanent platform contract, a
  published surface, a data-loss defect, or a foundation that other work will be
  built on before anyone could revisit it. Internal arrangement that is
  unexported and cheap to rewrite later is **not** blocking on its own; it
  becomes blocking when something else is about to be built on top of it, or
  when it is the cause of a defect. Say which of those applies.
- **worth raising** — a real improvement the author can take or argue with,
  where either answer is reasonable. Most findings live here, and a review where
  everything is blocking has not been triaged.
- **nit** — naming, comment placement, a redundant guard, formatting, a local
  micro-optimisation, a wording problem in a doc.

**Dependency suppression.** Drop any finding whose subject would be
restructured, moved or deleted by a blocking finding. It is not wrong, it is
premature. This never applies to a defect.

**Suppression needs a blocking finding that actually decides something.** A
blocking finding that reopens a question, rather than settling it, does not
license dropping everything downstream of the current design, because that
design may well survive the reopening. In that case keep those findings and mark
them **conditional on** the open question, naming it. Deleting them would leave
the review with nothing to say if the answer comes back unchanged.

**A blocking finding can be about the reasoning rather than the conclusion.**
"The evidence this decision rests on is wrong or out of date, and it must be
redone before the expensive part starts" is blocking whenever nobody will
revisit it afterwards, even when the conclusion is likely to stand. Say which
you mean, and if you expect the conclusion to survive, say that too.

**Holding nits.** While any blocking architectural finding is open, hold every
nit and give one closing line with the count and the categories, saying they
are deferred until the shape is settled. Never enumerate them unless asked.

**When the architecture pass finds nothing**, say so explicitly, then report the
smaller findings properly and list the nits, since no larger decision is pending
that would invalidate them. A clean architecture pass is a real result and
recording one is a success, not a gap.

**On a re-review, raise what was held**, and say which earlier points the
revision has settled.

**When a check passes, record the pass.** The architecture questions are
answered explicitly either way. Most changes pass most checks, and a review that
finds a problem under every heading has stopped discriminating.

## Costing, shared by both branches

Any proposal to do something a different way is incomplete until it accounts for
both directions: what the change removes, what it adds, the honest net, and the
risk it introduces. Never present only the savings.

Say plainly when the net is close to neutral and the gain is in readability or
in one concept disappearing. That is a legitimate and common answer, and
overstating it costs more than it wins. Each mechanics file says what to count.

## Discussion

Expect to be challenged, and hold or fold on the merits. The instruction is
explicit: "Do not agree with me just because I ask the question - I want an
honest architecture discussion where we ultimately aim to land at the lowest
required complexity to have a working solution." If a challenge is right, say
what changes and why. If it is wrong, say so and show the evidence.

When asked to reconsider scope or size, measure first and question your own
proposal before defending it.

**Never draft comments until the review has been discussed and settled.** The
placement step in each mechanics file runs last, and only on consensus.
