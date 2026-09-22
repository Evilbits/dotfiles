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

**Write the reversal cost before picking the label.** For every candidate finding, state in one line who would have to change what, in which repos, after this ships. The label follows from that line, never the other way round.

- **blocking** — undoing it after it ships costs more than one coordinated release in repos this team owns: a contract apps outside the team will import, a data shape written into undeletable or PHI rows, a data-loss or security defect, or a decision other work builds on with no later review point. The finding carries its reversal-cost line. If that line reads "a release plus a pin bump", "edit a string table", "update a doc", "rewrite a code path nobody imports" or "record the decision somewhere durable", the finding is worth raising, whatever it would remove. Fewer lines, one concept gone or a simpler shape is the ordinary content of worth raising and is never on its own a reason for blocking.
- **worth raising** — a real improvement the author can take or argue with, where either answer is reasonable. Most findings live here; a review where everything is blocking has not been triaged.
- **nit** — naming, comment placement, a redundant guard, formatting, a local micro-optimisation, doc wording.

**Dependency suppression.** Drop any finding whose subject a blocking finding would restructure, move or delete. It is premature, not wrong. Never applies to a defect.

**Suppression needs a blocking finding that decides something.** A blocking finding that reopens a question does not license dropping everything downstream of the current design, which may survive the reopening. Keep those findings and mark them **conditional on** the named open question; deleting them leaves the review with nothing to say if the answer comes back unchanged.

**A blocking finding can be about the reasoning rather than the conclusion**, but only when the conclusion, if wrong, meets the reversal-cost test above. "The premise is undocumented" or "this supersedes the ticket's wording" is a request to record a decision, and that is worth raising. Say which you mean, and if you expect the conclusion to survive, say so.

**Holding nits.** While any blocking architectural finding is open, hold every nit and give one closing line with the count and categories, deferred until the shape is settled. Enumerate only if asked.

**When the architecture pass finds nothing**, say so, then report the smaller findings and list the nits, since no pending decision invalidates them. A clean architecture pass is a result, not a gap.

**On a re-review, raise what was held** and say which earlier points the revision settled.

**When a check passes, record the pass.** Most changes pass most checks; a review that finds a problem under every heading has stopped discriminating.

## Costing, shared by both branches

A proposal to do something differently is incomplete until it accounts for both directions: what it removes, what it adds, the net, and the risk. Never present only the savings.

Say plainly when the net is near neutral and the gain is readability or one concept disappearing. That is a common and legitimate answer; overstating it costs more than it wins. Each mechanics file says what to count.

## Implementer mode

Used when `/doxy-implement`'s hand-off runs this skill in a subagent. Inputs are the MR URL, its description and the Jira ticket, and nothing from the authoring session. Run the code mechanics over `master..<branch>` with the description and ticket as the change's stated goal. Skip the placement plan and draft no comments; the reader is the implementer, not GitLab. Return each finding with its ID, severity, `file:line`, claim, cause and the concrete change proposed, then the checks that passed, then held nits in one line. Mark any finding that would reopen a design decision, so the implementer routes it to the user instead of acting on it.

## Discussion

Expect challenge, and hold or fold on the merits: "Do not agree with me just because I ask the question - I want an honest architecture discussion where we ultimately aim to land at the lowest required complexity to have a working solution." If a challenge is right, say what changes and why. If it is wrong, say so and show the evidence.

When asked to reconsider scope or size, measure first and question your own proposal before defending it.

**Never draft comments until the review is discussed and settled.** The placement step in each mechanics file runs last, on consensus.
