---
name: doxy-design
description: >-
    Work an idea into a written design brief for the doxyme Apps/SDK domain:
    the need, the proposal, what was considered and rejected, verified facts
    and open questions, for a team reader. Use when the user wants to ping-pong
    or brainstorm an idea, define requirements, outline a proposal, write an
    epic description or a Confluence/Slack design note, plan an approach before
    tickets exist, or says "help me think through…" about extensions, apps,
    capabilities, the bridge, the toolkit, Hotpot data, entitlements or Scribe.
    Also use when a design conversation is already underway and needs to end in
    a document. Ends with the document; does not write tickets or code.
---

# /doxy-design — from an idea to a brief the team can discuss

The conversation engine is the repo's brainstorming skill, which already asks
one question at a time, prefers multiple choice, and refuses to design past the
user's intent. What this skill adds is what that skill lacks in this domain:
grounding before the first question, a restatement checkpoint, the brief's
shape, and a way to feed every correction back into the repo.

The failure this exists to prevent: reasoning from the generic meaning of a word
that has a doxyme meaning. "App" is an installed extension release addressed by
manifest id. A "feature" may be a Frontegg plan entitlement and not a flag. A
"capability" is a mechanism the host owns, never a product. "Sideloaded" means
this session only. The Journal is a provider-facing call log, not an app store.
161 corrections over seven months were this one failure in different words, and
almost every one of them was answered somewhere in the repo already.

## 0 — Ground before asking anything

Read, in this order, before the first question and before the restatement:

1. **Every input the user gave.** Slack threads, Loom transcripts, existing
   proposals, tickets, the libraries named. All of it, in full, first. "I think
   you are conflating two things in your question" has always meant a question
   was asked before an input was read.
2. **The colocated rules for the domain.** Glob `**/.cursor/rules/*.mdc`
   (excluding `node_modules/` and `.worktrees/`). For anything touching
   extensions, apps, capabilities, the bridge, the toolkit or the SDK, read
   `apps/extensions/.cursor/rules/00-sdk-guidelines.mdc` and
   `00-rule-interpretation.mdc` in full — they define the vocabulary and are
   `alwaysApply` — then any nested rule whose `globs` or `description` match.
   Read `libs/extensions/glossary.md`.
3. **Domain guides that the rules do not yet route to:**
   - Hotpot: `libs/extensions/hotpot/README.md`,
     `libs/extensions/hotpot/docs/schema-decisions.md`,
     `apps/extensions/docs/06_hotpot_data_sdk/index.md`, and in `~/dev/hotpot`
     the `ARCHITECTURE.md`, `SECURITY_MODEL.md` and `STRATEGY.md`. Hotpot
     semantics come from that repo and its merge requests, never inferred from
     the SDK that consumes it, and several are live work with dates on them.
   - Entitlements: `docs/guides/entitlements/concepts.md`, which opens with the
     three systems the word "entitlement" names and the six Frontegg
     primitives, then `features.md` for naming.
   - Until those guides carry it, the collision list and ownership map in
     `~/.claude/skills/doxy-review/references/domain-architecture.md` is a
     stopgap. Anything learned there belongs in the repo, see step 4.

A question whose answer is in any of the above is not asked.

## 1 — Restate, then wait

Before the first design question, write a restatement of the problem in doxyme
terms, under ten lines:

- What is being proposed, in one sentence.
- Which layer owns each part: host, bridge, capability, toolkit, app, api-core,
  api-extensions, registry, Hotpot.
- The terms about to be used, each with the meaning it has here.
- What is asserted as fact, what is proposal, and what is unknown.

Then stop. The user corrects it once, cheaply, in one place. This is the turn
that replaces the corrections that otherwise arrive embedded in question four,
eight and twelve. Do not proceed to brainstorming until the restatement stands,
and carry every correction into step 4.

## 2 — Brainstorm

Read and follow `.cursor/skills/brainstorming/SKILL.md`. Do not call the
`superpowers:brainstorming` Skill tool. Four overrides, stated before starting:

1. **The document it writes is the brief in step 3**, at
   `~/dotfiles/home/.config/claude/specs/YYYY-MM-DD-<ticket-id-lowercase-or-topic>-design.md`.
   Ignore its `docs/plans/` path. **Never commit it**; skip any step that says to.
2. **Its terminal step does not run.** Brainstorming ends by invoking
   writing-plans. Here it ends with the document. Plans and tickets are
   `/doxy-implement` and `/doxy-epic`, invoked only if the user asks.
3. **Every option is phrased in doxyme vocabulary** as loaded in step 0, with a
   one-line consequence each. Options are lettered; replies here read "Let's go
   with A".
4. **Track three lists as the conversation runs**, because they become sections
   of the brief: decisions taken, alternatives considered and rejected with the
   reason, and facts verified against code or a source with where they were
   verified and as of when.

## 3 — The brief

Reader: the team, and often someone outside it. The instruction was explicit:
"I don't care about implementation details really. What I want is to outline
the need we have and our proposal. What does it solve, how will it solve it, and
what did we consider but ultimately decided against? This is what a discussion
with the team benefits from."

Sections, in this order, each earning its place:

- **Need.** What is wrong or missing today, for whom, with the evidence.
- **Proposal.** What it solves and how, at the level of layers and ownership.
  Implementation detail only if the user asks for it.
- **Considered and rejected.** Each alternative with the reason it lost and the
  condition under which it would be revisited.
- **Verified facts.** Anything the proposal depends on being true, with the file,
  merge request or ticket it was checked against and the date. Opt-in or
  in-flight platform behaviour is labelled as such.
- **Open questions.** Each with the person or team that owns the answer.
- **Out of scope.** Named, so nobody argues it in the discussion.
- **Shape.** Mandatory, one of four, with the reasoning in two sentences.
  `/doxy-ticket` reads this to decide what to write, so be concrete:
  - **Epic** — the work splits into several changes that are each reviewable
    on their own, or spans more than one system or owner, or has an ordering
    the tickets must carry. List the candidate tickets by one-line title.
  - **Ticket** — one change, one MR, one owner. Say why it does not split.
  - **Spike** — an open question dominates and the answer decides the shape.
    Name the question and what answering it would settle.
  - **No ticket** — the discussion concluded against doing it, or it is already
    done. Say what settled it.
  A brief that ends "Ticket" is common and correct; do not inflate a single
  change into an epic to look thorough.

Writing rules that came from corrections on exactly this kind of document:
define a term before using it as shared vocabulary; describe a proposal in the
conditional, since "would gain" reads as though it exists; state what a system
does today separately from what it could do; no sentence that merely announces
the section, no filler, no "nothing changes for X" reassurance unless it is a
real claim with a source. Keep each paragraph on one line.

Offer to copy the document to the clipboard.

## 4 — Feed the corrections back to the repo

Every doxyme concept the user corrected during this session is a gap in the
repo's AI-readable context, and it is fixed there rather than in a private file.

List each correction, and for each name the repo file that should carry it and
the exact text to add:

- SDK and platform vocabulary → `apps/extensions/.cursor/rules/00-sdk-guidelines.mdc`
  or `libs/extensions/glossary.md`.
- Capability rules → `apps/extensions/.cursor/rules/02-capabilities.mdc`.
- Hotpot → a colocated rule under `libs/extensions/hotpot/.cursor/rules/` and
  `libs/extensions/hotpot/docs/`; platform semantics go to the hotpot repo.
- Entitlements → `docs/guides/entitlements/` and a root rule globbed to the
  entitlement code paths.
- Anything about how rules are found → `docs/guides/ai-tooling/cursor-rules.md`.

Present the proposed additions and ask before writing any of them; they ship as
an MR the team can see. `00-rule-interpretation.mdc` already asks for this:
"if you detect any changes that impact what's written in these rules you must
prompt the user to consider updating these rules."

## Hand-off

The brief is the end of this skill. From here: `/doxy-ticket` reads the Shape
verdict and writes an epic with tickets, a single ticket, or a spike;
`/doxy-implement` takes a ticket, or a NOJIRA brief, to code. When the brief
is done, say which Shape it landed on and offer the next skill in one line.

**A request to build, branch, or start is the hand-off, never permission to
implement here.** "Let's build this", "put it on a NOJIRA branch", "go ahead"
all mean: stop, and invoke `/doxy-implement` with the brief. That skill owns
the branch ritual, the plan-or-execute question and the commit cycle, and
skipping it takes a decision away from the user. This happened once, on the
AI-context restructure, and the work had to be reviewed after the fact.
