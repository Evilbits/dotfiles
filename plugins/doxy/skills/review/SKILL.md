---
name: review
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
2. `references/review-doctrine.md`: the standing principles and the failure modes this skill prevents.

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

**No numeric cap on finding.** Find every substantive issue; dependency decides what is held back, and the posting filter below decides what reaches the MR.

**Severity answers one question: should this merge as it stands?** Two things make the answer no, and each finding says which applies. *Consequence*: what a user, a patient's data or an operator would feel in production if it shipped. *Reversal cost*: who would have to change what, in which repos, to undo it later. Fix size decides nothing; a one-line fix for a defect users would feel is still Critical.

**Write the deciding line before picking the label.** For a `C` finding, the consequence in production and how sure the failure path is. For an `A` finding, the reversal cost and which rule it breaks. The label follows from that line, never the other way round.

- **Critical** — cannot merge as it stands. A real defect with a concrete failure path users or data would feel, a security or data-loss risk, an implementation that does not do what the change claims, or an architecture that breaks a rule in the repo's own `.mdc` files or `AGENTS.md`. Also a decision that costs more than one coordinated release in repos this team owns to undo: a contract apps outside the team will import, a data shape written into undeletable or PHI rows, a decision other work builds on with no later review point.
- **High** — an important bug or design fault that should be fixed before merge but does not fail the change outright: a defect with a real but narrow failure path, a published surface that will be awkward to live with, a rule bent rather than broken.
- **Medium** — a real improvement the author can take or argue with: doc and rule text that states a wrong or incomplete fact, a small defect whose failure path is unconfirmed or needs a very rare sequence, a wrong test fixture behind correct code, a simpler arrangement at neutral cost. If the deciding line reads "a release plus a pin bump", "edit a string table", "update a doc", "rewrite a code path nobody imports" or "simpler", the finding is Medium at most. Fewer lines, one concept gone or a simpler shape is never on its own a reason for Critical or High.
- **Low** — naming, comment placement, a redundant guard, formatting, a local micro-optimisation, doc wording.

A review where everything is Critical has not been triaged; most findings on a sound change land at Medium.

## What reaches the MR

Triage produces the full list; posting is a second filter. The MR thread is for three things: contracts not broken, bugs not introduced, and the architecture of the extension platform kept intact. That third one is the reason this skill exists, so an architecture finding posts on its own merits and is never filtered as "the author's call".

- **Critical and High** always post.
- **Medium** posts when it is one of: an `A` finding that fails a check in the architecture pass (wrong layer, a capability that fails the genericity tests, a published export or type that should not be public, a rule decided in more than one place, a name the consumer must newly learn, a rule in an `.mdc` or `AGENTS.md` bent); a contract stated wrongly in a rule, a doc, a type or the MR description; a data shape. A Medium that is only a fixture, a stale line, a rearrangement at neutral cost with no rule behind it, or an accepted limitation with a horizon, is given to the user in the session and posts only if they pull it in.
- **Low** never posts on its own. If a comment is already going on that file, one Low may ride along in it.

The expected comment count follows the risk and the architectural reach of the change, not its line count. A large MR with one defect and sound shape gets one substantive comment and a short summary. A re-review posts only what the revision changed or what was held, and says which earlier points are settled.

The full list, including what was filtered, is always given to the user before drafting, so they can pull anything back in. Every finding shown to the user, posted or held, uses the same layout, one labelled line each, consequence first because that is what the user gates on:

```
**[C1 — Critical]** `file:line` — the claim in one sentence. *Posts* / *Held: reason*.
**Consequence:** what a user, the data, an app author or the next reader experiences if this ships as is.
**Cause:** the mechanism behind it, in enough detail that a reader without the reviewer's context can follow it.
**Fix:** the concrete change, with its cost when it is a restructure.
```

The user does not have the reviewer's context, so a label or a file name on its own is never a finding, and the labels are never folded into one paragraph; the filter decides where a finding goes, never how much of it is written.

Close the session view with two lines: `**Low, held:**` naming each Low item in a clause, and `**Would post:**` listing the IDs going to the MR so the user can add or remove before drafting.

**Dependency suppression.** Drop any finding whose subject a Critical or High architectural finding would restructure, move or delete. It is premature, not wrong. Never applies to a defect.

**Suppression needs a deciding finding.** A Critical or High finding that reopens a question does not license dropping everything downstream of the current design, which may survive the reopening. Keep those findings and mark them **conditional on** the named open question; deleting them leaves the review with nothing to say if the answer comes back unchanged.

**A Critical or High finding can be about the reasoning rather than the conclusion**, but only when the conclusion, if wrong, meets the tests above. "The premise is undocumented" or "this supersedes the ticket's wording" is a request to record a decision, and that is Medium. Say which you mean, and if you expect the conclusion to survive, say so.

**Holding Low findings.** While any Critical or High architectural finding is open, hold every Low finding and give one closing line with the count and categories, deferred until the shape is settled. Enumerate only if asked.

**When the architecture pass finds nothing**, say so, then report the smaller findings and list the Low findings, since no pending decision invalidates them. A clean architecture pass is a result, not a gap.

**On a re-review, raise what was held** and say which earlier points the revision settled.

**When a check passes, record the pass.** Most changes pass most checks; a review that finds a problem under every heading has stopped discriminating.

## Costing, shared by both branches

A proposal to do something differently is incomplete until it accounts for both directions: what it removes, what it adds, the net, and the risk. Never present only the savings.

Say plainly when the net is near neutral and the gain is readability or one concept disappearing. That is a common and legitimate answer; overstating it costs more than it wins. Each mechanics file says what to count.

## Implementer mode

Used when `/doxy:implement`'s hand-off runs this skill in a subagent. Inputs are the MR URL, its description and the Jira ticket, and nothing from the authoring session. Run the code mechanics over `master..<branch>` with the description and ticket as the change's stated goal. Skip the placement plan and draft no comments; the reader is the implementer, not GitLab. Return each finding in the layout from What reaches the MR, consequence first, then the checks that passed, then held Low findings in one line. Mark any finding that would reopen a design decision, so the implementer routes it to the user instead of acting on it.

## Discussion

Expect challenge, and hold or fold on the merits: "Do not agree with me just because I ask the question - I want an honest architecture discussion where we ultimately aim to land at the lowest required complexity to have a working solution." If a challenge is right, say what changes and why. If it is wrong, say so and show the evidence.

When asked to reconsider scope or size, measure first and question your own proposal before defending it.

**Never draft comments until the review is discussed and settled.** The placement step in each mechanics file runs last, on consensus.
