---
name: implement
description: >-
    Start and run work on a Jira ticket in doxyme-core or hotpot, from the
    ticket URL to a branch, an understood scope, an approved design and plan,
    and in-session execution with tests and atomic commits. Use whenever the
    user says they are working on, starting, or picking up a ticket, task or
    feature, pastes a doxyme.atlassian.net/browse/PROD-… URL with intent to
    build it, asks to plan or implement a ticket, or types /doxy:implement. Also use
    when resuming a ticket that already has a design or plan in the spec folder.
---

# /doxy:implement — from ticket to shipped change

Input is the ticket URL plus whatever framing comes with it, or, for NOJIRA work, a brief in the spec folder whose Shape is Ticket; then the branch is `NOJIRA-<topic>` and the brief plays the ticket's part below. **The framing outranks the ticket text.** "We do not need to strictly follow the ticket", "implement it exactly like MR 1234", "the most important thing is…" are the instructions; the ticket is context. When they conflict, say so before acting.

Each step below prevents a failure that has happened: a redundant branch from a stale snapshot, a plan lost when the session closed, a plan executed before anyone checked it against the code, per-task approval prompts inside an approved plan.

## 1 — Fetch and read

Fetching the ticket is in scope by definition; do it without asking.

- The ticket, its epic, and any MRs or Slack threads it links, including its Acceptance Criteria field, which `getJiraIssue` returns only when requested (`customfield_10530`).
- The spec folder: `ls ~/.claude/specs/ | grep -i <ticket-id>`. A `-design.md` or `-plan.md` there means this is a **resume**: read it, say which steps it settles, and skip to the first unsettled one.
- **The colocated rules for the paths involved.** Rules live next to the projects they describe, not only at the root. Glob `**/.cursor/rules/*.mdc` (excluding `node_modules/` and `.worktrees/`). For anything under `apps/extensions/**` or `libs/extensions/**`, or about the SDK, a capability, the bridge or Hotpot data, read `apps/extensions/AGENTS.md` in full for the boundaries, vocabulary and decision tables (`00-sdk-guidelines.mdc` on branches from before it merged), then any nested rule whose `globs` or `description` match the ticket. Entitlements: `docs/guides/entitlements/concepts.md`. Hotpot: `libs/extensions/hotpot/docs/schema-decisions.md` and the hotpot repo's `ARCHITECTURE.md`. This prevents the "you are confusing two different concepts" round trip.
- A doxyme concept the user corrects during the ticket is a gap in one of those repo files. Note it, and at the end propose the addition to the file that should carry it, as its own small MR. Never record it privately.

## 2 — Branch, in a worktree

Run `git branch --show-current` and `git worktree list` **first**. The session-start git snapshot is a point-in-time capture and has been stale before, producing a redundant branch and a cleanup detour.

- Already on the ticket's branch (or a `-N` variant), or it already has a worktree: work there.
- Otherwise the branch is named **exactly the ticket ID**. If that name exists locally (`git branch --list '<ID>*'`) or on origin (`git branch -r --list 'origin/<ID>*'`), append `-1`, `-2`, … taking the next free number.
- **Always a worktree unless the user says otherwise.** `git fetch origin master`, then `git worktree add -b <branch> .worktrees/<branch> origin/master --no-track`, then the repo's worktree setup inside it (doxyme-core: `.claude/rules/worktree-setup.md`, the setup script then `pnpm install`). Basing on `origin/master` leaves the main checkout, its branch and its uncommitted changes untouched; a `git pull` there has failed on a dirty lockfile.
- The user asked for the main checkout: `git checkout master && git pull`, then create the branch there.

Confirm with `git branch --show-current` and state the branch and its path in one line.

## 3 — Understand and ask

State, in two sentences, what the change sets out to do and what the ticket defers. Then surface the decisions the ticket leaves open.

- **One question per message**, never a numbered list of questions.
- **Lettered options**, each with a one-line consequence. Replies read "Let's go with A", so options must be distinguishable at a glance; "expand on the question, I don't get it" means an option lacked its consequence.
- A question whose answer is in the code or the domain reference is not asked.

## 4 — Design and plan

Invoke `.cursor/skills/brainstorming/SKILL.md` (read and follow it; do **not** call the `superpowers:brainstorming` Skill tool). It asks one question at a time, prefers multiple choice, and refuses to write code before the design is approved. Its terminal step invokes `writing-plans`; let it, with the same overrides.

**Four overrides, stated before invoking and applied throughout:**

1. **Documents go to the spec folder, never the repo.** Design: `~/.claude/specs/YYYY-MM-DD-<ticket-id-lowercase>-<topic>-design.md`. Plan: same path with `-plan.md`. Ignore both skills' `docs/plans/` paths. **Never commit either**, and skip any step that says to.
2. **Execution returns here.** Ignore writing-plans' handoff to `subagent-driven-development` or `executing-plans`. When the plan is approved, control returns to step 5. Omit the "Recommended dispatch" line writing-plans would insert; nothing dispatches.
3. **Always a full plan, reviewed by a subagent, then execute.** Let brainstorming invoke writing-plans on every ticket. When the plan is written, spawn one general-purpose subagent, read-only, with the design and plan paths, the worktree, the ticket text with its Acceptance Criteria, and the rules for the touched paths. It checks the plan against the code: every stated fact, callers and mocks the plan misses, ordering and lifecycle, edge cases, and whether each test is feasible under the testing rules and breaks when its assumption does. Fix the plan for each finding that holds; a finding that reopens a design decision goes to the user. Then go straight to step 5 without asking for plan approval: the reviewed plan is the approval.
4. **Check the assumptions the design rests on.** Before approval, name what the design assumes about identity, keys, ordering and lifecycle (what something is keyed by, whether that survives the object being re-created, which step runs first), check each in the code, and give each a test that breaks it on purpose: a re-created instance, not only a reopened one.

## 5 — Execute

In this session, sequentially, without subagents unless asked.

- **On Fable, stop and ask before the first edit.** Fable is for planning; implementation on it needs explicit confirmation, unless the user has granted an exception.
- **The reviewed plan is the approval.** Do not show a diff and ask "go ahead with task N?" before each task; that reads as regression. The checkpoints are the TDD cycle: failing test and its RED output, implementation, GREEN output, commit.
- **Stop and ask only when a task needs a decision the plan did not make.** Summarise deviations as you go instead of requesting permission for them.
- **Commit at every atomic boundary**, format `type(scope): <TICKET-ID> - description`, scope the Nx project, subject under 50 characters, staged by file and never `git add .`. Do not let two logical units pile up uncommitted.
- Type-check with `tsc --noEmit` or the project's typecheck target, never `nx build frontend`.
- Without an approved plan (an ad-hoc change mid-ticket), the global rule applies: show the intended change with context and ask before making it.

## 6 — Hand off

Runs without asking once step 5 is complete and verified. The user has made this the standing next step.

1. **Push** the branch with `git push -u origin <branch>`. Never a force-push here.
2. **Open a draft MR** as `.cursor/skills/gitlab-merge-request/SKILL.md` describes: GitLab MCP `create_merge_request`, target `master`, title `Draft: <type>(<scope>): <TICKET-ID> - <summary>`; the `Draft:` prefix is what makes it a draft. In doxyme-core, create it with the label `deploy-full-ephemeral-env`, which deploys the branch's whole stack, including its extension apps published to the environment's own registry and its own Hotpot, at `https://core-<mr-number>.doxy-ephemeral.me` for the reviewer to try. The label must be there before the first pipeline; `deploy-ephemeral-env` deploys the frontend only, so apps changed in the MR are not in it. Write the description into the repo template (`.gitlab/merge_request_templates/Default.md`) keeping every section: "Description of change" leads with what was built and why in plain language and links the ticket; "Type of change" and "Quality checklist" ticked only where true; "How to test" as bullets a reviewer can follow, including flags or setup; "Links" and "Screenshots" left as in the template unless there is something to put there. Nothing the code does not do; every "covered" or "handles" claim names the test that pins it, and a claim without one is removed. Surface the MR URL as a link.
3. **Review in a fresh context.** Spawn one general-purpose subagent whose only inputs are the MR URL, the description as written, the Jira ticket text, and the instruction to invoke the `doxy:review` skill with the Skill tool and run its implementer mode over `master..<branch>`. It gets nothing from this session: no plan, no design doc, no conversation. The point is a reader who knows only what a reviewer would know. It returns the findings list.
4. **Apply the review.** Verify each finding against the code before accepting it, as `superpowers:receiving-code-review` asks. Blocking and worth-raising findings that hold become further atomic commits, pushed to the same branch. A finding caused by a shape (an argument convention, a shared pattern) is applied by fixing the shape and sweeping for its other instances; patching the one reported site is not applying it. Findings that do not hold get a one-line answer. A finding that reopens a design decision goes to the user; it is never implemented on the reviewer's say-so. One review round; a second only if the user asks.
5. **Report**: the MR link, what the review found, what changed, what was declined and why. **Never mark the MR ready.** That and the next phase are the user's call alone.

Do not offer to run a local stack; mention `blitz` only if verification needs the app running or the user asks.
