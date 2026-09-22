---
name: doxy-ticket
description: >-
    Write, amend or check Jira tickets in the PROD project from a design brief
    or a conversation: an epic with its tickets, a single ticket, or a spike,
    plus maintenance on existing tickets. Use when the user asks to create or
    write tickets, an epic, a story or a spike, to turn a brief or design into
    tickets, to add or rewrite acceptance criteria, to wire dependencies or
    links between tickets, or to reevaluate an existing ticket or epic: whether
    it is still required or already done, whether it is written correctly, what
    input or data it is missing, or whether the work could be done differently.
    Also use when /doxy-design has produced a brief with a Shape verdict and the
    next step is Jira.
---

# /doxy-ticket — from a brief to Jira, in the team's format

Reads the brief `/doxy-design` produced, or the design still in the session, and writes what its **Shape** verdict calls for. Nothing reaches Jira until the drafts are approved.

Four modes. Pick from the brief's Shape when there is one, say which mode and why, and let the user override:

- **epic** — an epic description plus its tickets.
- **single** — one ticket, no epic. Common and correct; do not wrap one change in an epic.
- **spike** — one Technical Spike ticket for the question that decides the shape, with what answering it settles.
- **reevaluate** — take an existing ticket or epic and answer four questions against their own sources: still required, written correctly, anything missing an implementer needs, could it be done differently. Section 4.

Maintenance requests on existing tickets (section 3) run in whichever mode fits.

## 0 — Ground

Read the brief in full if there is one (`~/dotfiles/home/.config/claude/specs/*-design.md` for the ticket or topic). Load the colocated rules for the domain as `/doxy-design` step 0 does, so tickets use doxyme vocabulary and not the generic meaning of "app", "feature", "capability" or "session". Fetch the epic and any tickets named as dependencies, so links point at real keys.

Code locations in the brief's **Verified facts** go into the tickets' Context. A fact the tickets depend on that is not in the brief is verified now against the code, and said so; a ticket never asserts something unchecked.

## 1 — Draft

### The epic description

Shape, from PROD-10779, the standard the team has seen:

1. **The problem**, in a paragraph an engineer outside the team can follow, with the evidence (a Datadog query, a Slack thread, a ticket) linked.
2. **What this epic does**, one paragraph.
3. **Rules of the design**, numbered from 0, each one sentence of rule and one or two of why. The invariants every ticket must be consistent with.
4. **A short table** of where the behaviour lives: where, what, why. Requested as "a SHORT and CONCISE way of showing these new places"; only the rows that matter.
5. **Known limitations**, as bullets, each a deliberate consequence with its reason and, where one exists, the condition for revisiting it.
6. **Decisions already made**, when the brief's rejected alternatives are likely to be re-raised: each with why it lost.

### A ticket

Shape, from PROD-10806 to PROD-10813:

- **Title**: `[Draft] [<area>] <imperative summary>`, area being the project or library, e.g. `[extensions-bridge]`, `[api-core]`, `[hotpot]`, `[frontend]`, `[ops]`. `[Draft]` stays until the user removes it; when the user says the tickets look good, drop it on the ones they name.
- **Context**: why this ticket exists, which rule of the epic it implements, the current code state with file anchors, and the consequence of not doing it. The safety rule a ticket enforces is stated here, in the epic's words.
- **Scope**: bullets of what is built. Include "Rollout compatibility" when a wire format or contract changes.
- **Acceptance criteria**: bullets, each independently testable, each an observable outcome. Include the failure paths and the "nothing changes for" cases. A test that pins a behaviour the team is unsure of is an AC in its own right: "we cannot know for sure how it works now with no test case".
- **Out of scope**: what a reader might expect here and will not find, with where it lives instead.
- **Depends on**: ticket keys, or "Nothing", and what this ticket blocks.

**Placement rules corrected before.** An implementation caveat the reviewer needs goes in the MR description, not the ticket. A product or scope caveat goes in the ticket. A question for product or security is a sentence in the ticket only when the answer changes the work; if settled informally, leave it out. Do not embed the authoring conversation: a reader who was not there must follow it.

**Vocabulary.** Every term as defined in the loaded rules. No new terminology. Every Jira key linked as `[PROD-1234](https://doxyme.atlassian.net/browse/PROD-1234)` wherever prose allows a link.

### Spike

Issue type **Technical Spike**. Context is the question and why it decides the shape; Scope is the investigation, time-boxed; Acceptance criteria are the written answer and what it unblocks. "Investigation only — no code expected" when true.

## 2 — Present and gate

Show every draft in full, epic first, tickets in dependency order, with the dependency graph in one line. Copy the set to the clipboard.

Then stop. **Nothing is created, edited or linked in Jira until the user approves**, and approval of the set is not approval to remove `[Draft]`. The user has said "I will create the epic in a bit — no need for you to do it"; respect that when it comes.

On approval, create through the Atlassian MCP in the PROD project. Issue types: `Epic`, `Story`, `Bug`, `Technical Debt`, `Technical Spike`, `Security Issue`, `Design story`. Children default to `Story`; `Technical Debt` or `Bug` when the brief says so. Set the epic as parent. Set **Medium priority on newly created tickets only**; never bulk-edit priority on existing ones. Add "blocks" / "is blocked by" links per the Depends-on sections. Read `getContentFormatGuide` before the first create so the description renders.

Report the created keys as links, and offer to remove `[Draft]` from the ones the user names.

## 3 — Maintenance modes

- **Add an AC to every ticket in an epic.** Fetch each child, append the criterion in the ticket's own voice, show the per-ticket diff, gate, apply.
- **Rewrite a ticket against the brief.** Show old and new side by side.
- **Wire dependencies or links.** Show the graph before and after.
- **Add a spike for an open question** raised mid-epic, in the epic, low priority unless told otherwise, with the benefit and reasoning recorded so the reader knows why it exists.
- **Remove `[Draft]`** from named tickets.

## 4 — Reevaluate mode

The most common Jira request in the user's history: "is this ticket still relevant with the current implementation?", "we need to rework some of these tickets", "is this already taken care of?". Given a ticket or epic and no brief, answer four questions, each against its own source, and record the answer even when it is "fine".

**1. Is it still required?** Ground truth is the code and the evidence the ticket links. Find the code the ticket describes and report **done**, **partly done**, **obsolete**, or **still valid**, with a file anchor per claim and, for partly done, what remains. Re-open every link the ticket rests on (the Datadog query, the Slack thread, the design doc, the parent epic's rules) and say whether each still supports the ticket. Stale evidence is reported separately from whether the work is done.

**2. Is it written correctly?** Ground truth is the house format in section 1 and the loaded vocabulary. Check: Context states why and the current code state with anchors; Scope and Acceptance criteria are separate and each criterion is testable; Out of scope and Depends on exist; terms match the rules; keys are linked; nothing from an authoring conversation leaked in; caveats sit where the placement rules put them. Report only what is wrong, as concrete edits.

**3. Is anything missing?** Ground truth is what an engineer with no context would need: an acceptance criterion for each failure path and each "nothing changes for X" case; a test that pins a behaviour nobody is sure of; file anchors for the current state; dependencies that exist in code but not in Depends on; a verified fact the ticket assumes without stating; an open question with an owner but no sentence. Anything the reader would have to ask the author is missing.

**4. Could it be done differently?** Only when the ticket prescribes an approach. Ground truth is the architecture frame: load `~/.claude/skills/doxy-review/SKILL.md` and its `reviewing-proposals.md`, treat the ticket as the proposal, and run the load-bearing-claims check and the architecture pass. A ticket that only states an outcome has nothing to reevaluate here, and that is the correct answer.

**Output.** One verdict line per question, then the proposed edited ticket for questions 1 to 3, gated as in section 2: shown in full, copied to the clipboard, nothing written to Jira until approved.

**If question 4 finds a different approach**, do not rewrite the ticket around it. State the finding and hand to `/doxy-design`, because a change of approach is a design conversation whose outcome may be a different ticket, an epic, or no ticket, and its Shape verdict returns through this skill. Rewriting an approach inside a ticket edit is how a design decision gets made without a discussion.

## Hand-off

Tickets exist. `/doxy-implement <key>` takes one to code. The brief stays in the spec folder and is never committed.
