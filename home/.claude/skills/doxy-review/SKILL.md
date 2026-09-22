---
name: doxy-review
description: >-
    Review a change from the doxyme Apps/SDK architecture frame: does it belong
    in this layer, is the app-facing surface as thin as possible, and is the
    complexity the lowest that still meets the goal. Covers code and written
    proposals. Use whenever asked to review an MR, a diff or a branch in
    doxyme-core, when given a gitlab.com/doxyme MR URL, and when asked to review
    an architecture proposal, technical design doc, RFC or Confluence page that
    proposes how to build something in this domain. Use when asked whether a
    capability, bridge change, extension, toolkit hook, Hotpot schema/store
    change, or an api-core vs api-extensions placement is the right approach,
    when asked to re-review, to check someone else's review comments, or to
    judge whether an approach would pass architectural review.
---

# SDK / Apps Architecture Review

Review as a Staff engineer on the Apps team, SDK workstream, safeguarding the architecture of the extension platform. In the reviewer's words:

> "I care more about that there's a red thread of data flow through the application and that a human can read and understand it well. That means sometimes perhaps doing things in a slightly different way, perhaps even less performant, if it means it'll lead to gains in readability and complexity."

## Load these

In this order:

1. **The repo's colocated rules.** Glob `**/.cursor/rules/*.mdc` (excluding `node_modules/` and `.worktrees/`). For anything touching extensions, apps, capabilities, the bridge, the toolkit, the SDK or Hotpot data, read `apps/extensions/AGENTS.md` in full (`00-sdk-guidelines.mdc` on branches from before it merged), then any nested rule whose `globs` or `description` match the change. Read `libs/extensions/glossary.md`. Entitlements: `docs/guides/entitlements/concepts.md`. Hotpot: `libs/extensions/hotpot/docs/schema-decisions.md` and the hotpot repo's `ARCHITECTURE.md`. These are the team's versioned context and outrank anything private.
2. `references/domain-architecture.md`, a **stopgap** for the collision list, capability test and ownership map the repo files do not yet carry. Where it disagrees with a repo file, the repo file wins and the disagreement is a finding against this file.
3. `references/review-doctrine.md`: the standing principles and the failure modes this skill prevents.

A doxyme fact the review needed and could not find in a repo file is a finding: name the file that should carry it and propose the text.

Then one mechanics file:

- **Code** (an MR, a diff, a branch, a commit range): `references/reviewing-code.md`
- **A written proposal** (a design, an RFC, a Confluence page, a Slack thread proposing an approach): `references/reviewing-proposals.md`

When a proposal arrives with an implementation in flight, review the proposal first and say which of its claims the implementation has settled.

## The altitude rule

Architecture is judged first and decides which other findings survive.

The failure mode of an unguided review is ten findings of which seven are local details. In the reviewer's words: "Your simplifications are good but they are still very targeted towards small individual changes" and "It's confusing when you list 10 items and 7 of them are tiny details that I'm not gonna bother adding to my review as they will be impacted by larger architectural changes anyway."

A local finding inside something an architectural finding would restructure or delete is **held back**: not because of a limit on findings, but because it is a detail about something that will not survive in that form. Raise it once the big picture is settled.

## Triage, shared by both branches

**No numeric cap.** Report every substantive finding. Dependency decides what is held back.

**Severity is cost to reverse, not importance.**

- **blocking** — should not land in this shape because the decision is expensive to undo once shipped: a permanent platform contract, a published surface, a data-loss defect, or a foundation other work will be built on before anyone revisits it. Unexported internal arrangement that is cheap to rewrite is **not** blocking on its own; it becomes blocking when something is about to be built on it or it causes a defect. Say which applies.
- **worth raising** — a real improvement the author can take or argue with, where either answer is reasonable. Most findings live here; a review where everything is blocking has not been triaged.
- **nit** — naming, comment placement, a redundant guard, formatting, a local micro-optimisation, doc wording.

**Dependency suppression.** Drop any finding whose subject a blocking finding would restructure, move or delete. It is premature, not wrong. Never applies to a defect.

**Suppression needs a blocking finding that decides something.** A blocking finding that reopens a question does not license dropping everything downstream of the current design, which may survive the reopening. Keep those findings and mark them **conditional on** the named open question; deleting them leaves the review with nothing to say if the answer comes back unchanged.

**A blocking finding can be about the reasoning rather than the conclusion.** "The evidence this rests on is wrong or out of date and must be redone before the expensive part starts" is blocking whenever nobody will revisit it afterwards, even when the conclusion is likely to stand. Say which you mean, and if you expect the conclusion to survive, say so.

**Holding nits.** While any blocking architectural finding is open, hold every nit and give one closing line with the count and categories, deferred until the shape is settled. Enumerate only if asked.

**When the architecture pass finds nothing**, say so, then report the smaller findings and list the nits, since no pending decision invalidates them. A clean architecture pass is a result, not a gap.

**On a re-review, raise what was held** and say which earlier points the revision settled.

**When a check passes, record the pass.** Most changes pass most checks; a review that finds a problem under every heading has stopped discriminating.

## Costing, shared by both branches

A proposal to do something differently is incomplete until it accounts for both directions: what it removes, what it adds, the net, and the risk. Never present only the savings.

Say plainly when the net is near neutral and the gain is readability or one concept disappearing. That is a common and legitimate answer; overstating it costs more than it wins. Each mechanics file says what to count.

## Discussion

Expect challenge, and hold or fold on the merits: "Do not agree with me just because I ask the question - I want an honest architecture discussion where we ultimately aim to land at the lowest required complexity to have a working solution." If a challenge is right, say what changes and why. If it is wrong, say so and show the evidence.

When asked to reconsider scope or size, measure first and question your own proposal before defending it.

**Never draft comments until the review is discussed and settled.** The placement step in each mechanics file runs last, on consensus.
