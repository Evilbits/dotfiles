---
name: blitz-test
description: >-
    Test a change that has a draft MR on a fresh blitz stack, in real browsers, and report what was
    tested and what was found. Use after /doxy:implement has opened a draft MR and the user asks to
    test it, try it out, QA it, verify it in blitz, check it in a browser, or types /doxy:blitz-test,
    and when they come back to test more on a stack this skill brought up.
---

# /doxy:blitz-test — from a draft MR to a testing overview

Input is a ticket, an MR or a branch, usually right after `/doxy:implement`. Output is a testing overview the user reads first: what was tested, what was found, with evidence, and the links to the stack, which stays up for more testing.

Each step below prevents a failure that has happened: a test run that reused a stale stack, scenarios taken only from the spec while the edge cases agreed in the implementation conversation were lost, a "not covered" list where the new edge cases should have been, timings reported with no question behind them, and an overview with no links, so the user had to ask for them.

## 1 — Gather what was agreed

Read all of it before planning a single scenario:

- **The ticket, its epic and their Acceptance Criteria** (`getJiraIssue` with `customfield_10530`). An epic without criteria still gives scenarios through its rules and known limitations.
- **The MR**: its description, its "How to test" and its notes. Then the diff against the MR's target branch. A stacked MR targets its parent branch, so the diff against master carries the parent's work too.
- **The spec folder**: `ls ~/.claude/specs/ | grep -i <ticket-id>` for the design and the plan. Their assumptions, known limitations and "test that breaks it" lines are scenarios.
- **The implementation conversation.** When this session ran `/doxy:implement`, it is already in context. Otherwise find it with `grep -rl --include='*.jsonl' <ticket-id> ~/.claude/projects` and pick the transcript where the ticket was implemented. Read only the user messages and assistant text, never the tool results. When one transcript covers several tickets, read from the message that starts this ticket to the one that starts the next. Every edge case, worry or "what if" raised there is a scenario, and so is every finding of the fresh-context review and of the plan review, held or declined. Those findings live only in the transcript.
- **The colocated rules** for the touched paths, as `/doxy:implement` step 1 lists them, so the scenarios use the domain's words.

## 2 — The scenario list

Write it down before starting the stack. It has two parts, and both are required.

**Agreed scenarios.** Each acceptance criterion, each case from the design, the plan, the conversation and the review, in one line each, with where it came from.

**New edge cases.** At least five that no source above names, each with the reason it could break. Look for them along these axes, in order:

1. **Identity and lifecycle**: the object re-created rather than reopened, a reload mid-action, a second tab, the provider and the patient in a different order.
2. **Timing**: double clicks, two actions in quick succession, the action during a load or a reconnect, a slow or dropped network (Playwright's `context.setOffline`, `page.route` with a delay).
3. **Who**: Free and Premium, clinic owner and Member, the patient side, a second patient, the waiting room.
4. **What else is running**: other apps open, none open, a headless or overlay app, a paused call, the feature flag off.
5. **Platform**: WebKit (`browserName: 'webkit'`) and a mobile viewport, when the change touches the call or a layout.

A source's "out of scope" items are tested when they are cheap. The result then says whether they fail and how, since out of scope does not mean safe.

**Who is needed.** This decides how many browsers run:

| Change | Browsers |
|---|---|
| Dashboard, settings, account, billing, an app opened outside a call | Provider only |
| Anything during a call, the waiting room, check-in, an app inside the call | Provider and patient |
| Clinic, roles, Members | The owner and a Member; add a patient only if the call is involved |

**Performance.** Decide in one line whether the change can cost time, and say why. It can when it adds work to a render path, a call start or end, a polling loop, a query or the bundle. When it can, measure the user-facing latency of the changed action over at least five runs. When the ticket, its criteria or the design promise it is no slower than today, or the ticket is about speed, compare against a second fresh stack cut from the target branch (`-base`). Otherwise compare the variants on this stack, such as with and without an app open, and say that the baseline still runs the new code. When it cannot cost time, say so and skip it.

## 3 — A fresh stack

Load the `blitz:blitz` skill with the Skill tool and follow it, and Blitz's own docs where it points, for the setup check, creating the workstream, bringing the apps up, seeding accounts, signing in and the URLs. This skill adds only the following:

- **Always a new workstream**, cut from the MR's pushed branch: `<ticket-id-lowercase>-test`, or the next free `-test-N`. Never reuse or drop one that already exists; those hold other work.
- Bring up what the scenarios need: the apps they open, and hotpot when any of them uses it.
- Seed the provider-side accounts the "who is needed" table asks for. A patient needs no account; they check in through a room's check-in URL.
- When the change depends on an unmerged branch of hotpot or an app, the stack runs that branch; Blitz's docs say how.
- This overrides the `blitz:blitz` skill's advice to reuse a workstream made for the task, because a test needs a stack in a known state.

## 4 — Test in real browsers

Use Playwright, headless, from the workstream's own e2e install. Never the user's Chrome.

- Put the scripts in the workstream folder, outside its worktrees, so nothing lands in the branch. Write them as `.cjs` and run them with `NODE_PATH=<core worktree>/e2e/v2/node_modules node <script>.cjs`, so they resolve that install's Playwright.
- Use one browser context per person. Run Chromium with fake camera and microphone (`--use-fake-ui-for-media-stream`, `--use-fake-device-for-media-stream`) and grant both permissions.
- Sign in and check in the way Blitz documents. The page objects in `e2e/v2/pages/` show the selectors.
- For each scenario, note its start and end time, and record the console output, the failed requests, and the lines of the stack's log files (their paths are in `status --json`) between those times.
- When the change writes data, read the rows back from where they land, Postgres through the database link or Hotpot through its Convex dashboard, and quote them as evidence. Take a screenshot at the moment that proves the result, and always on a failure, and keep them next to the scripts.
- Then run the existing e2e suites for the touched areas through `blitz <name> e2e`. They are the regression net, never the main test.

A failure is retried once, to tell a flaky one from a real one. When a finding is a bug, write it down and keep testing. This skill never fixes code.

## 5 — The testing overview

Written for the user, short, with every result backed by its evidence. Sections, in this order:

1. **Verdict**, in two lines: works, works with findings, or broken, and the most important finding.
2. **Links**:
   - Every URL Blitz reports for the workstream: the app, its control UI page (where the user can sign in as any seeded account), each seeded account with its room, the patient check-in URLs, the database, and the Convex dashboard when hotpot runs.
   - Separately, the MR's ephemeral environment (`https://core-<mr-number>.doxy-ephemeral.me`) when the MR carries a deploy label. It is closer to prod and is where other people test, so the overview never treats it as this run's stack.
3. **Findings**, the most severe first. Each one has its consequence, its steps to reproduce, the evidence (a log line, a screenshot path or a request) and the suspected cause as `file:line` when it is known.
4. **Agreed scenarios**: a table with the scenario, its source, the result and the evidence.
5. **New edge cases**: the same table, with the reason each could break in place of the source.
6. **Performance**: the numbers with the runs and what they were compared against, or the one line saying why it was skipped.
7. **e2e suites**: each with its result.
8. **Not tested**, and why.

Show the screenshots that prove a finding by reading them into the conversation. Name the rest by path.

## Afterwards

The stack stays up. Never `down` or `drop` it unless the user asks. When the user asks for more testing, use the same workstream and the same scripts, and add each new result to the overview as its own section.
