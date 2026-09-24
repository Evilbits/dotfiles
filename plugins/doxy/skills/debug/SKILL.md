---
name: debug
description: >-
    Investigate a doxyme bug report from the evidence to a short post mortem: what exactly
    failed, why, whether it reproduces, and how to fix it. Use when the user pastes a Slack
    thread, a Datadog link, an error message or a bug ticket and asks to debug, investigate,
    look into or explain an error, a failure or odd behaviour in production, staging or qa, or
    types /doxy:debug. Also use when a session that started as a question about an error turns
    into finding its cause.
---

# /doxy:debug — from a report to a post mortem

Input is a report: a Slack thread, a Datadog link, an error text, a ticket, or several of them. Output is a short post mortem the user reads first and may share as it is. Between the two sits one checkpoint: the known facts go to the user before anything is reproduced, because they often know the answer or the direction and a reproduction is the expensive step.

Each step below prevents a failure that has happened: an error counted three times before the user corrected the signature, a session that never left the logs to look at the RUM session or the trace, a reproduction attempted before anyone searched Slack for the earlier report, and a debrief that had to be asked for.

## 1 — Ground

Read every input in full before the first query: the whole Slack thread, the linked Datadog view, the ticket and what it links. Then pin down, one line each: the service, the environment (`dev`, `qa`, `staging`, `prod`, as `docs/guides/logging.md` names them in Datadog), the time window, the affected user or session when the report names one, and the exact error text.

**Confirm the signature before counting anything.** Quote the error text about to be searched for and ask whether that is the one. A count of a neighbouring error is confident data about the wrong problem.

Datadog is reached through its MCP server. If a call fails with 401, authenticate before anything else. Load `datadog/investigation-workflows`, then the skill for each source before querying it: `datadog/logs`, `datadog/traces`, `datadog/ddsql` for RUM, `datadog/error-tracking`, `datadog/change-tracking`. Queries are written from those guides, never from memory; a malformed call is retried once after re-reading the guide, then reported as a limit.

## 2 — Evidence, in this order

1. **Logs** for the signature in the window: count, first and last occurrence, spread over services, hosts and users. Every count is stated with the query that produced it.
2. **Error tracking** for the issue's history: when it first appeared and in which versions.
3. **The RUM session** of the affected user, when there is one: what they did before the error, browser, frontend version. The frontend service is `apollo`; its release version is the commit tag (`docs/guides/frontend-datadog-sourcemaps.md`).
4. **The APM trace** of the failing request, from the log's trace id: which span failed and with what.
5. **The code.** Read the path the evidence points at and name the suspect lines as file and line. `git log` on those lines says when they last changed and in which MR. This is a fact about the code, not yet the cause.
6. **What changed.** Change tracking for the window, plus the release tags and merge dates in GitLab, so it is known what was live when the report was filed and what landed just before (`docs/guides/deployments.md`). A report is evidence about the build it was filed against.
7. **Slack.** Search for the error text and the feature name across channels, beyond the pasted thread. Earlier mentions often carry the diagnosis or a workaround.

A source that cannot be reached is recorded as such, with the reason. A limit met in an earlier session is not inherited; it is re-tested.

## 3 — Known facts, then wait

Before any reproduction, post to the user:

- **Facts**, one line each, each with the link or query that proves it: counts, first occurrence, affected users, the suspect code and its last change, what deployed when.
- **Open questions**: what the evidence does not settle.
- **Leading hypothesis**, in one or two sentences, with what would confirm and what would refute it.

Then stop. The user decides the direction: a fact they can explain, a hypothesis to drop, a place to look, or a go for reproduction. This is a design conversation: one question at a time.

## 4 — Reproduce

Only after the user agrees. On a blitz stack (`/blitz`), following the report's steps when it has them, else the path the RUM session or the trace showed. When step 2 left gaps, reproduction is run to gather what it could not, and that purpose is stated first, with what is being looked for.

Record what was done and what was observed, as numbers and log lines. "Does not reproduce" is a result, reported with the build it was tried on. Bring the stack down afterwards.

## 5 — Cause and fix

The mechanism as file and line, the evidence for it and the evidence that does not fit, the fix location, and how the fix would be verified. What could not be verified is said plainly. When the cause is a decision rather than a defect, say so; that is a finding for the post mortem, not a reason to stop.

## 6 — Post mortem

Written for the user, who reads it first and often shares it, so it is short and every data point links to its query, thread, trace or commit. Sections, each a few lines:

- **What failed**: the error, where, since when, how often, for whom.
- **Cause**: the mechanism, as file and line, and what changed to trigger it.
- **Reproduction**: how, or why not, and on which build.
- **Fix**: what to change and how to verify it.
- **Next steps**: owner and action for each, or "none" when the fix is the only one.

Write it to `~/.claude/specs/YYYY-MM-DD-<topic>-postmortem.md`, one paragraph per line, and copy it to the clipboard with `pbcopy`. Jira keys are links. No claim without its source; no source without a link.

What comes after is the user's call: a ticket through `/doxy:ticket`, a fix through `/doxy:implement`, or the post mortem shared as it is.
