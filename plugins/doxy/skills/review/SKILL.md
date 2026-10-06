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

## Two reviewers, one judgement

On code, the review is gathered by two subagents with different briefs and judged here. Each sees the artefact and the contract: the diff against the right base, the commit trail, the callers and consumers, the ticket, the rules for the touched paths. Neither sees the author's claims as claims to trust (the description is handed over as "what the author says it does, to be checked"), the other's output, or anything this session has concluded. A reviewer handed a conclusion reads for confirmation.

**The architecture reviewer** runs `references/brief-architecture.md`: the rules and precedent check, layer placement, published surface, vocabulary, decision points, arrangement, version skew. It is allowed to come back with nothing; on most changes it should.

**The code reviewer** runs `references/brief-code.md`: defects with their trigger sequence, failure paths, lifecycle and timing, the contract with the other side quoted from that side's code or merged MR, performance, and tests that cannot catch the regression they claim to cover. It gets no doctrine and no architecture questions.

**The gate.** The architecture reviewer runs only when the diff carries a decision. Step 0 of `references/reviewing-code.md` lists the signals (a Dockerfile, CI, Terraform or root config; a new runtime dependency or system binary; a new top-level folder or module in an app; a new cross-project import; a published lib's exports, a changeset, a capability or manifest schema, a GraphQL schema, an entity or a migration; more than one project touched; anything under `apps/extensions/**` or `libs/extensions/**`). Any one of them turns the lane on. Print the decision and its reasons before spawning: "Architecture lane on: Dockerfile, new runtime dependency" or "Architecture lane off: one component under `apps/frontend`". The user can turn it on with "with architecture" in the request. The code reviewer always runs.

Spawn both in parallel with the Agent tool, general-purpose, read-only. Each brief says what to read and where to stop reading, and returns raw findings in the layout below, each marked **walked** (every step traced in the code) or **suspected** (a step assumed, named). Nothing a child returns is a verdict; this session rates, verifies and presents.

## The altitude rule

Architecture is judged first and decides which other findings survive.

The failure mode of an unguided review is ten findings of which seven are local details. In the reviewer's words: "Your simplifications are good but they are still very targeted towards small individual changes" and "It's confusing when you list 10 items and 7 of them are tiny details that I'm not gonna bother adding to my review as they will be impacted by larger architectural changes anyway."

A local finding inside something an architectural finding would restructure or delete is **held back**: not because of a limit on findings, but because it is a detail about something that will not survive in that form. Raise it once the big picture is settled.

**The author's framing carries no weight.** An MR description, a commit message or a code comment saying a choice was deliberate, flagged for discussion, or shared with a sibling is evidence of intent and nothing else. The reviewer exists so the user can counter the architecture; a review that grades a decision to the author's tone has taken that ability away. Every decision is judged against the repo's rules, the siblings and the platform's contracts as if the author had said nothing about it, and the finding then quotes what the author said so the user can see both sides. "Deliberate, and here is why it is still wrong" is the expected shape, never a reason to soften the label.

**Decisions outrank defects.** A decision that sets a direction for the repo, such as a new dependency class, a second way of doing something the repo already does one way, a change to a shared file every project uses, or a data shape or contract others will build on, is the first thing reported and the one the user most needs to be able to counter. A bug is easier to find and cheaper to fix than a direction, so a review that leads with bugs and files the direction under them has reviewed at the wrong altitude even when every bug is real.

**A walked defect is never held.** A defect whose trigger sequence has been traced step by step is reported at its own level however rare the sequence and whatever architecture finding is open; it is marked as surviving or dying with the restructure, as step 3 of `references/reviewing-code.md` says. Only Low findings and Medium findings about code an open Critical or High finding would restructure are held.

**A thread already covering a point lowers nothing.** When a human or a bot has raised the same thing, the finding keeps its level and its place in the ranking and carries "already raised by X" in its header. Agreement with that thread is worth saying when the review adds evidence; the posting filter decides whether that is a reply, a new comment or nothing.

## Triage, shared by both branches

**No numeric cap on finding.** Find every substantive issue; dependency decides what is held back, and the posting filter below decides what reaches the MR.

**Severity answers one question: should this merge as it stands?** Two things make the answer no, and each finding says which applies. *Consequence*: what a user, a patient's data or an operator would feel in production if it shipped. *Reversal cost*: who would have to change what, in which repos, to undo it later. Fix size decides nothing; a one-line fix for a defect users would feel is still Critical.

**Write the deciding line before picking the label.** For a `C` finding, the consequence in production and how sure the failure path is. For an `A` finding, the reversal cost and which rule it breaks. The label follows from that line, never the other way round.

**A decision the diff lands is this change's decision.** A Dockerfile, a dependency, infrastructure, a schema or a published export in the diff ships when the MR merges, whatever the description says will move later. It is graded as landed, with its reversal-cost line, and "it will be moved in the batch ticket" is recorded as a claim next to it, never as a reason to defer. The reference miss: a folder placement was ranked above system Chromium added to a shared service's image, because the description said the batch would run elsewhere later; the deciding lines ("move files" against "a release of its own") would have ordered them the other way.

- **Critical** — cannot merge as it stands. A real defect with a concrete failure path users or data would feel, a security or data-loss risk, an implementation that does not do what the change claims, or an architecture that breaks a rule in the repo's own `.mdc` files or `AGENTS.md`. Also a decision that costs more than one coordinated release in repos this team owns to undo: a contract apps outside the team will import, a data shape written into undeletable or PHI rows, a decision other work builds on with no later review point.
- **High** — an important bug or design fault that should be fixed before merge but does not fail the change outright: a defect with a real but narrow failure path, a published surface that will be awkward to live with, a rule bent rather than broken.
- **Medium** — a real improvement the author can take or argue with: doc and rule text that states a wrong or incomplete fact, a small defect whose failure path is unconfirmed or needs a very rare sequence, a wrong test fixture behind correct code, a simpler arrangement at neutral cost. If the deciding line reads "a release plus a pin bump", "edit a string table", "update a doc", "rewrite a code path nobody imports" or "simpler", the finding is Medium at most. Fewer lines, one concept gone or a simpler shape is never on its own a reason for Critical or High.
- **Low** — naming, comment placement, a redundant guard, formatting, a local micro-optimisation, doc wording.

A review where everything is Critical has not been triaged; most findings on a sound change land at Medium.

## What reaches the MR

Triage produces the full list; posting is a second filter. The MR thread is for three things: contracts not broken, bugs not introduced, and the architecture of the extension platform kept intact. That third one is the reason this skill exists, so an architecture finding posts on its own merits and is never filtered as "the author's call".

- **Critical and High** always post.
- **Medium** posts when it is one of: a decision with precedent effect (a first-of-its-kind choice, a published export or type that should not be public, a change to a shared file, a data shape, a runtime footprint the service did not carry before); a contract stated wrongly in a rule, a doc, a type or the MR description. Every other Medium, including a rule bent inside the change's own code, a wrong layer for one file, a duplicated definition, a missing env wiring, a fixture, a stale line, a rearrangement at neutral cost, or an accepted limitation with a horizon, is given to the user in the session and posts only if they pull it in. While any High architecture finding is open, every Medium that is not a decision or a contract is session-only.
- **Low** never posts on its own. If a comment is already going on that file, one Low may ride along in it.

The expected comment count follows the risk and the architectural reach of the change, not its line count. A large MR with one defect and sound shape gets one substantive comment and a short summary. A re-review posts only what the revision changed or what was held, and says which earlier points are settled.

The full list, including what was filtered, is always given to the user before drafting, so they can pull anything back in. The reader is a human scanning a terminal, so the view gives the overview before any detail, and no part of it is a dense paragraph. The layout, in this order:

```
**!<iid> at `<sha>`** · architecture lane on (<reasons>) / off (<reason>)

**Goal:** one or two sentences: what the change sets out to do, and what it defers.

**Verdict:** one sentence: merge as it stands, or not, and the one reason.

| | Level | Where | Finding | |
|---|---|---|---|---|
| A1 | Critical | `file:line` | the claim in one line | posts |
| C2 | High | `file:line` | the claim in one line | posts |
| L3 | Low | `file` | the claim in one line | held |

A: a decision about the shape of the change · C: a defect in the code · L: low, held until the shape is settled

### A1 — Critical · the claim, as in the table

- **Breaks:** what a user, the data, an app author or the next reader experiences if this ships as is. Deterministic or not. One or two sentences.
- **Why:** the mechanism, in one or two sentences a reader without the reviewer's context can follow.
- **Fix:** the concrete change and the test that pins it, with the cost when it is a restructure. One or two sentences.
- **Evidence:** the `file:line`s, quoted contracts, library internals and spec names behind the finding, as a list of references, skippable.

**Held:** the IDs given to the user only. **Would post:** the IDs going to the MR.
Full findings: `<scratchpad>/review-<iid>-<short sha>.md`
```

IDs are assigned in table order, with the prefix saying what kind of finding it is. Every finding has a row in the table; only a finding that posts has a section below it. A held finding's full text lives in the saved file named on the last line, and the user pulls it into the view or the MR by its ID. **Nothing posts unseen.** A finding reaches the MR only after its full section has been in the view the user read; "post", "post these" and "post all of these" mean the Would post set and nothing else. A held ID the user names is first shown in full in chat and posts only on a second, separate go. Before publishing, list the IDs about to go up and check each one against the sections the view carried; an ID that was only a table row stays out. The passes are not in the view; the reviewer records them and gives them when asked. The quotes and internals that justify a finding live only on its Evidence line, never in Breaks or Why. A finding whose Breaks or Why runs past two sentences is cut, and the cut material goes to Evidence or is dropped.

**Dependency suppression.** Drop any finding whose subject a Critical or High architectural finding would restructure, move or delete. It is premature, not wrong. Never applies to a defect.

**Suppression needs a deciding finding.** A Critical or High finding that reopens a question does not license dropping everything downstream of the current design, which may survive the reopening. Keep those findings and mark them **conditional on** the named open question; deleting them leaves the review with nothing to say if the answer comes back unchanged.

**A Critical or High finding can be about the reasoning rather than the conclusion**, but only when the conclusion, if wrong, meets the tests above. "The premise is undocumented" or "this supersedes the ticket's wording" is a request to record a decision, and that is Medium. Say which you mean, and if you expect the conclusion to survive, say so.

**Holding Low findings.** While any Critical or High architectural finding is open, hold every Low finding and give one closing line with the count and categories, deferred until the shape is settled. Enumerate only if asked.

**When the architecture reviewer finds nothing, or did not run**, say so, then report the Code findings and list the Low findings, since no pending decision invalidates them. A clean architecture pass is a result, not a gap.

**On a re-review, raise what was held** and say which earlier points the revision settled. A re-review is a code review: the gate is decided again on the delta and both reviewers are spawned on it with the threads, never replaced by this session reading the delta itself.

**When a check passes, record the pass** for yourself and give it when asked; it stays out of the view. Most changes pass most checks; a review that finds a problem under every heading has stopped discriminating.

## Costing, shared by both branches

A proposal to do something differently is incomplete until it accounts for both directions: what it removes, what it adds, the net, and the risk. Never present only the savings.

Say plainly when the net is near neutral and the gain is readability or one concept disappearing. That is a common and legitimate answer; overstating it costs more than it wins. Each mechanics file says what to count.

## Implementer mode

Used when `/doxy:implement`'s hand-off runs this skill at the end of a ticket, in the implementing session. The two reviewers are the fresh contexts: their briefs get the MR URL, the description as written, the Jira ticket and the diff over `master..<branch>`, and nothing from the session, no plan, no design doc, no conversation. Skip the placement plan and draft no comments; the reader is the implementer, not GitLab. Return the view from What reaches the MR as it stands, table and sections, then the checks that passed in one line, since the implementer acts on those too. Mark any finding that would reopen a design decision, so the implementer routes it to the user instead of acting on it.

## Discussion

Expect challenge, and hold or fold on the merits: "Do not agree with me just because I ask the question - I want an honest architecture discussion where we ultimately aim to land at the lowest required complexity to have a working solution." If a challenge is right, say what changes and why. If it is wrong, say so and show the evidence.

When asked to reconsider scope or size, measure first and question your own proposal before defending it.

**Never draft comments until the review is discussed and settled.** The placement step in each mechanics file runs last, on consensus.
