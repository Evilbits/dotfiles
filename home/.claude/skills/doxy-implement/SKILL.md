---
name: doxy-implement
description: >-
    Start and run work on a Jira ticket in doxyme-core or hotpot, from the
    ticket URL to a branch, an understood scope, an approved design and plan,
    and in-session execution with tests and atomic commits. Use whenever the
    user says they are working on, starting, or picking up a ticket, task or
    feature, pastes a doxyme.atlassian.net/browse/PROD-… URL with intent to
    build it, asks to plan or implement a ticket, or types /doxy-implement. Also use
    when resuming a ticket that already has a design or plan in the spec folder.
---

# /implement — from ticket to shipped change

Input is the ticket URL plus whatever framing comes with it, or, for NOJIRA
work, a brief in the spec folder whose Shape is Ticket; then the branch is
`NOJIRA-<topic>` and the brief plays the ticket's part in every step below.
**The framing outranks the ticket text.** "We do not need to strictly follow the ticket",
"implement it exactly like MR 1234", "the most important thing is…" are the
instructions; the ticket is context. When the two conflict, say so before acting.

Sessions that skip the steps below have historically gone wrong in the same
places: a redundant branch created from a stale snapshot, a plan lost when the
session closed, an unnecessary full planning chain on a five-file change, and
per-task approval prompts inside an already-approved plan. Each step exists to
prevent one of those.

## 1 — Fetch and read

Fetching the ticket is in scope here by definition, so do it without asking.

- The ticket, its epic, and any MRs or Slack threads it links.
- The spec folder: `ls ~/dotfiles/home/.config/claude/specs/ | grep -i <ticket-id>`.
  A `-design.md` or `-plan.md` already there means this is a **resume**: read
  it, say which steps it settles, and skip to the first unsettled one.
- **The colocated rules for the paths involved.** Rules live next to the
  projects they describe, not only at the repo root. Glob
  `**/.cursor/rules/*.mdc` (excluding `node_modules/` and `.worktrees/`). For
  anything under `apps/extensions/**` or `libs/extensions/**`, or about the SDK,
  a capability, the bridge or Hotpot data, read
  `apps/extensions/.cursor/rules/00-sdk-guidelines.mdc` and
  `00-rule-interpretation.mdc` in full — they define the vocabulary and are
  `alwaysApply` — then any nested rule whose `globs` or `description` match the
  ticket. For entitlement work, `docs/guides/entitlements/concepts.md`. For
  Hotpot, `libs/extensions/hotpot/docs/schema-decisions.md` and the hotpot
  repo's `ARCHITECTURE.md`. Until those carry everything,
  `~/.claude/skills/doxy-review/references/domain-architecture.md` is a stopgap
  for the collision list and ownership map. This is what prevents the "you are
  confusing two different concepts" round trip.
- A doxyme concept the user corrects during the ticket is a gap in one of those
  repo files. Note it, and at the end propose the addition to the file that
  should carry it, as its own small MR. Never record it privately.

## 2 — Branch

Run `git branch --show-current` **first**. The session-start git snapshot is a
point-in-time capture and has been stale before, producing a redundant branch
and a cleanup detour.

- Already on the ticket's branch (or a `-N` variant of it): stay there.
- Otherwise: `git checkout master && git pull`, then create a branch named
  **exactly the ticket ID**. If a branch with that name exists locally
  (`git branch --list '<ID>*'`) or on origin
  (`git branch -r --list 'origin/<ID>*'`), append `-1`, `-2`, … taking the next
  free number.
- Another ticket is in flight in this checkout: offer a worktree under
  `.worktrees/<ID>` and the repo's worktree setup, rather than switching
  branches under it.

Confirm the result with `git branch --show-current` and state it in one line.

## 3 — Understand and ask

State, in two sentences, what the change sets out to do and what the ticket
explicitly defers. Then surface the decisions the ticket leaves open.

- **One question per message**, never a numbered list of questions.
- **Lettered options**, each with a one-line consequence. Replies here read
  "Let's go with A", so options need to be distinguishable at a glance, and
  "expand on the question, I don't get it" means an option lacked its
  consequence.
- A question whose answer is in the code or the domain reference is not asked.

## 4 — Design and plan

Invoke `.cursor/skills/brainstorming/SKILL.md` (read and follow it; do **not**
call the `superpowers:brainstorming` Skill tool). It asks one question at a
time, prefers multiple choice, and refuses to write code before the design is
approved, all of which is already right. Its terminal step invokes
`writing-plans`; let it, with the same override rules.

**Three overrides, stated before invoking and applied throughout:**

1. **Documents go to the spec folder, never the repo.** Design doc:
   `~/dotfiles/home/.config/claude/specs/YYYY-MM-DD-<ticket-id-lowercase>-<topic>-design.md`.
   Plan: same path with `-plan.md`. Ignore both skills' `docs/plans/` paths.
   **Never commit either document**, and skip any step that says to.
2. **Execution returns here.** Ignore writing-plans' execution handoff to
   `subagent-driven-development` or `executing-plans`. When the plan is
   approved, control comes back to step 5 of this skill. Omit the
   "Recommended dispatch" line writing-plans would insert, since nothing
   dispatches.
3. **Ask once before the plan.** At the point where brainstorming would invoke
   writing-plans, stop and ask a single question: write a full plan, or execute
   directly from the approved design. Give a recommendation based on the design
   as it turned out — roughly, a full plan when the change crosses systems or
   touches more than a handful of files, direct execution otherwise. Then do
   what was chosen. The design conversation runs on every ticket; the plan is
   the part behind the question.

## 5 — Execute

Runs in this session, sequentially, without subagents unless asked.

- **On Fable, stop here and ask before the first edit.** Fable is for planning;
  implementation needs explicit confirmation to continue on it, unless the user
  has granted an exception.
- **An approved plan or design is the approval.** Do not show a diff and ask
  "go ahead with task N?" before each task; that reads as regression. The
  checkpoints the user wants are the TDD cycle itself: failing test and its RED
  output, implementation, GREEN output, commit.
- **Stop and ask only when a task needs a decision the plan did not make.**
  Summarise deviations as you go rather than requesting permission for them.
- **Commit at every atomic boundary**, format
  `type(scope): <TICKET-ID> - description`, scope being the Nx project, subject
  under 50 characters, staged by file and never `git add .`. Do not let two
  logical units pile up uncommitted.
- Type-check with `tsc --noEmit` or the project's typecheck target, never
  `nx build frontend`.
- Without an approved plan (an ad-hoc change mid-ticket), the global rule
  applies: show the intended change with context and ask before making it.

## 6 — Hand off

When the plan is complete and verified:

- Offer a merge description, since that is the usual next request. Write it
  only if asked, keep the repo MR template verbatim, and lead with the benefit
  and the why.
- For the MR itself, follow `.cursor/skills/gitlab-merge-request/SKILL.md`.
- **Never mark the MR ready.** That is the user's call alone, and so is
  starting the next phase or the next MR.
- Do not offer to run a local stack; mention `blitz` only if verification needs
  the app running or the user asks.
