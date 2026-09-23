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

# /doxy-implement — from ticket to shipped change

Input is the ticket URL plus whatever framing comes with it, or, for NOJIRA work, a brief in the spec folder whose Shape is Ticket; then the branch is `NOJIRA-<topic>` and the brief plays the ticket's part below. **The framing outranks the ticket text.** "We do not need to strictly follow the ticket", "implement it exactly like MR 1234", "the most important thing is…" are the instructions; the ticket is context. When they conflict, say so before acting.

Each step below prevents a failure that has happened: a redundant branch from a stale snapshot, a plan lost when the session closed, a full planning chain on a five-file change, per-task approval prompts inside an approved plan.

## 1 — Fetch and read

Fetching the ticket is in scope by definition; do it without asking.

- The ticket, its epic, and any MRs or Slack threads it links.
- The spec folder: `ls ~/dotfiles/home/.config/claude/specs/ | grep -i <ticket-id>`. A `-design.md` or `-plan.md` there means this is a **resume**: read it, say which steps it settles, and skip to the first unsettled one.
- **The colocated rules for the paths involved.** Rules live next to the projects they describe, not only at the root. Glob `**/.cursor/rules/*.mdc` (excluding `node_modules/` and `.worktrees/`). For anything under `apps/extensions/**` or `libs/extensions/**`, or about the SDK, a capability, the bridge or Hotpot data, read `apps/extensions/AGENTS.md` in full for the boundaries, vocabulary and decision tables (`00-sdk-guidelines.mdc` on branches from before it merged), then any nested rule whose `globs` or `description` match the ticket. Entitlements: `docs/guides/entitlements/concepts.md`. Hotpot: `libs/extensions/hotpot/docs/schema-decisions.md` and the hotpot repo's `ARCHITECTURE.md`. This prevents the "you are confusing two different concepts" round trip.
- A doxyme concept the user corrects during the ticket is a gap in one of those repo files. Note it, and at the end propose the addition to the file that should carry it, as its own small MR. Never record it privately.

## 2 — Branch

Run `git branch --show-current` **first**. The session-start git snapshot is a point-in-time capture and has been stale before, producing a redundant branch and a cleanup detour.

- Already on the ticket's branch (or a `-N` variant): stay there.
- Otherwise: `git checkout master && git pull`, then create a branch named **exactly the ticket ID**. If that name exists locally (`git branch --list '<ID>*'`) or on origin (`git branch -r --list 'origin/<ID>*'`), append `-1`, `-2`, … taking the next free number.
- Another ticket is in flight in this checkout: offer a worktree under `.worktrees/<ID>` with the repo's worktree setup instead of switching branches under it.

Confirm with `git branch --show-current` and state it in one line.

## 3 — Understand and ask

State, in two sentences, what the change sets out to do and what the ticket defers. Then surface the decisions the ticket leaves open.

- **One question per message**, never a numbered list of questions.
- **Lettered options**, each with a one-line consequence. Replies read "Let's go with A", so options must be distinguishable at a glance; "expand on the question, I don't get it" means an option lacked its consequence.
- A question whose answer is in the code or the domain reference is not asked.

## 4 — Design and plan

Invoke `.cursor/skills/brainstorming/SKILL.md` (read and follow it; do **not** call the `superpowers:brainstorming` Skill tool). It asks one question at a time, prefers multiple choice, and refuses to write code before the design is approved. Its terminal step invokes `writing-plans`; let it, with the same overrides.

**Three overrides, stated before invoking and applied throughout:**

1. **Documents go to the spec folder, never the repo.** Design: `~/dotfiles/home/.config/claude/specs/YYYY-MM-DD-<ticket-id-lowercase>-<topic>-design.md`. Plan: same path with `-plan.md`. Ignore both skills' `docs/plans/` paths. **Never commit either**, and skip any step that says to.
2. **Execution returns here.** Ignore writing-plans' handoff to `subagent-driven-development` or `executing-plans`. When the plan is approved, control returns to step 5. Omit the "Recommended dispatch" line writing-plans would insert; nothing dispatches.
3. **Ask once before the plan.** Where brainstorming would invoke writing-plans, stop and ask one question: write a full plan, or execute from the approved design. Recommend based on the design as it turned out: a full plan when the change crosses systems or touches more than a handful of files, direct execution otherwise. Then do what was chosen. The design conversation runs on every ticket; the plan is the part behind the question.

## 5 — Execute

In this session, sequentially, without subagents unless asked.

- **On Fable, stop and ask before the first edit.** Fable is for planning; implementation on it needs explicit confirmation, unless the user has granted an exception.
- **An approved plan or design is the approval.** Do not show a diff and ask "go ahead with task N?" before each task; that reads as regression. The checkpoints are the TDD cycle: failing test and its RED output, implementation, GREEN output, commit.
- **Stop and ask only when a task needs a decision the plan did not make.** Summarise deviations as you go instead of requesting permission for them.
- **Commit at every atomic boundary**, format `type(scope): <TICKET-ID> - description`, scope the Nx project, subject under 50 characters, staged by file and never `git add .`. Do not let two logical units pile up uncommitted.
- Type-check with `tsc --noEmit` or the project's typecheck target, never `nx build frontend`.
- Without an approved plan (an ad-hoc change mid-ticket), the global rule applies: show the intended change with context and ask before making it.

## 6 — Hand off

Runs without asking once step 5 is complete and verified. The user has made this the standing next step.

1. **Push** the branch with `git push -u origin <branch>`. Never a force-push here.
2. **Open a draft MR** as `.cursor/skills/gitlab-merge-request/SKILL.md` describes: GitLab MCP `create_merge_request`, target `master`, title `Draft: <type>(<scope>): <TICKET-ID> - <summary>`; the `Draft:` prefix is what makes it a draft. Write the description into the repo template (`.gitlab/merge_request_templates/Default.md`) keeping every section: "Description of change" leads with what was built and why in plain language and links the ticket; "Type of change" and "Quality checklist" ticked only where true; "How to test" as bullets a reviewer can follow, including flags or setup; "Links" and "Screenshots" left as in the template unless there is something to put there. Nothing the code does not do. Surface the MR URL as a link.
3. **Review in a fresh context.** Spawn one general-purpose subagent whose only inputs are the MR URL, the description as written, the Jira ticket text, and the instruction to read `~/.claude/skills/doxy-review/SKILL.md` and run its implementer mode over `master..<branch>`. It gets nothing from this session: no plan, no design doc, no conversation. The point is a reader who knows only what a reviewer would know. It returns the findings list.
4. **Apply the review.** Verify each finding against the code before accepting it, as `superpowers:receiving-code-review` asks. Blocking and worth-raising findings that hold become further atomic commits, pushed to the same branch. Findings that do not hold get a one-line answer. A finding that reopens a design decision goes to the user; it is never implemented on the reviewer's say-so. One review round; a second only if the user asks.
5. **Report**: the MR link, what the review found, what changed, what was declined and why. **Never mark the MR ready.** That and the next phase are the user's call alone.

Do not offer to run a local stack; mention `blitz` only if verification needs the app running or the user asks.
