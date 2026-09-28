---
name: vibe-app
description: >-
    Build a doxy.me app (an extension) for someone outside engineering, from
    an idea or an existing ticket plus a design, into stacked merge
    requests the Apps team can review and approve. Use when a product manager,
    designer or anyone non-technical says they want to build an app, vibe code
    an app, turn a design or a Figma into an app in doxy.me, add a screen or a
    game to an existing app, or types /doxy:vibe-app. Also use when they come
    back after engineers answered the review spikes or commented on the merge
    requests.
---

# /doxy:vibe-app — from a design to merge requests the Apps team can approve

The person you are talking to knows the product and has a design. They do not know the code and must never need to. They work in a doxyme-core checkout with write access; the build, the tests and the merge requests all happen there. Your job is to build what they described inside the rules the Apps team reviews against, so that by the time an engineer opens the merge request there is nothing left to reject on principle.

The failure this prevents: [MR 16420](https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/16420), the Mindfulness app. Not one reviewer comment was about the feature. They were: a second styling stack (Tailwind, shadcn, lucide) where the UI rule requires ui-foundation; the design system font plugin dropped from the template config; hex colours in a hand-rolled button; an app folder named `breath` for a product called Mindfulness; an unrelated CI change that slipped in during a rebase; generator placeholder copy still in the catalogue metadata; icons imported from the package barrel. And size: 232 files and 13,800 lines in one merge request, six of them design documents, one a 600-line lockfile churn. Every one of these is checkable before a merge request is opened. That check is this skill.

## Rules for every message

**Product words only.** Never ask about or mention SSL, data types, APIs, endpoints, schemas, tokens, components, hooks, services, or how anything is built. Say app, panel, page, call, waiting room, patient, provider, plan, setting, design. When a rule of the code has to be explained, say what apps can and cannot do in the product and stop there.

**Facts are yours to find, decisions are theirs to make.** Anything the code, the design or the ticket can answer is looked up, never asked. What the app should do is put to the person and waited for.

**Never the platform.** This skill writes in two places only: the app's own frontend under `apps/extensions/<app>/` and the app's own backend module under `apps/api-extensions/`. The core frontend (`apps/frontend`), the core API (`apps/api-core`), the bridge, a capability, the SDK (`libs/extensions/*`) and every other app are never touched, whatever the reason; a need for that is a boundary hit (step 2) and goes to engineering as a spike. Translation files under `libs/locale/` are always allowed. Also allowed: the app's entries in the backend's configuration, generated app types, the three CI registration files and the row in `docs/guides/ports.md`, and any file the precedent for the same kind of change touched, each listed in the self-review with its justification.

## 0 — Load the map before the first question

Read, locally, in the checkout (this skill needs one; if the working directory is not a doxyme-core checkout, stop and say so in one sentence):

1. Every input the person gave: a ticket if one exists, the design link or files, a Slack thread, a doc. All of it, in full. A ticket's user stories are settled and are not re-asked.
2. **Prior work.** Search Jira for epics and tickets on the same app or area, and on the feature's own words. Keep a hit only if it built or is building the same thing this feature extends: the same app, screen, note type or object, so that its decisions would carry into this one. When in doubt, leave it out. The person picks in step 1 before anything is read in full. When the picked prior work is in the code, read that too: the ticket says what was decided, the code says what was built, and the code wins for what the product does today.
3. `apps/extensions/AGENTS.md` in full: what an app is and is not, the applet table, the data table, the capability tests. `libs/extensions/glossary.md`. `docs/guides/entitlements/concepts.md`.
4. The build rules: `apps/extensions/.cursor/rules/01-extension-architecture.mdc`, `03-communication-patterns.mdc`, `05-apps-common.mdc`; `libs/ui/.cursor/rules/00-ui-guidelines.mdc`, which covers every `.tsx` under `apps/extensions/`; `.cursor/skills/doxyme-design-system/SKILL.md` for tokens. The domain-driven design rule (`06`) is not applied: a new app does not have to use that layout.
5. The generator at `tools/plugins/extensions/src/generators/extension/`: its `files/` are what a new app looks like, and the next-steps list in `generator.ts` is the authoritative split between what this skill does (generate, ports row, CI registration files) and what an engineer does (register the manifest, deployment role, Datadog application). `docs/guides/ports.md` for a free port. `.gitlab/merge_request_templates/Default.md` for the merge request shape.
6. When the ask extends an existing app, that app's folder, manifest and docs in full.

**Premises.** Crossing one is a boundary hit (step 2). Product premises: an app lives in its iframe and never draws on or reads a host surface (waiting room, patient card, control bar); an app never talks to another app; a capability is a mechanism for every app, never one product's feature; tenant data never mixes. Build premises, from the rules above: an app is styled with `@doxyme/ui-foundation` primitives, Emotion object styles and theme tokens, and nothing else; icons come from `@doxyme/icons/<name>` one file each; the generator's Vite config, including the fonts plugin, stays as generated; an app has one name used everywhere.

Something the code has no concept of yet is a gap, and a gap is ordinary work inside the app. Only a premise crossed is a boundary hit.

## 1 — Interview, in rounds

Open with one request: describe the feature as you would to a colleague, and share the design if there is one (a Figma link, screenshots, or an export). Send it even when the opening message names the feature; skip the description part only when that message already says what the feature does, for whom, and where they meet it.

**Prior work, on its own, before anything else.** When the search in step 0 kept candidates, send one message: "I found these tickets that look similar. Can I use any of them for context? If you know of others, paste them." Then the candidates, lettered, at most a handful, each shown as `A · [PROD-1234 <ticket title>](https://doxyme.atlassian.net/browse/PROD-1234): ` followed by one line on what it is, what it decided, and why it looks like the same thing, plus "none of these". The title goes inside the link so the person recognises the ticket without opening it. Never the raw search results. Stop and wait. Nothing is inherited until the person picks it; then read the picked tickets in full, their user stories and acceptance criteria first. When nothing cleared the bar, say so in one line and ask for any they know of, so an engineer later knows it was looked for.

**The design.** A Figma link is read through the Figma connector (design context and a screenshot per screen); otherwise images or an HTML export. The design is the source for layout, copy and states; what it does not show is asked, never invented. When there is no design and the feature has a screen, say in the restatement that the app will use the design system's defaults and the existing screens' style, and have the person confirm it there; never build a screen from imagination without saying so.

Then restate the feature in under ten lines, in product words: what it is, for whom, where the person meets it, which existing apps or areas it touches, what the picked prior work already settled, what the design covers, what you take as given and what is unknown. Stop and let them correct it.

Then treat the feature as a design tree: every decision branches into the decisions that hang off it. The **frontier** is every question whose prerequisites are already settled. Ask from the frontier in rounds of at most four questions, the most constraining first, numbered continuously across rounds so Q7 means one thing for the whole session, each with your recommended answer in product words, and wait. What did not fit waits for the next round. A question that depends on another question still open in this round belongs to a later round. Answers reshape the tree; recompute the frontier and ask the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, with lettered choices when the map gives them>

➡️ <your recommended answer, and in one line why>

---

❓ **Q2** - ...
```

The first rounds are built from these axes, each checked against the map so that a choice the product cannot offer is never listed as a choice:

| Ask, in product words | Resolves |
| --- | --- |
| Is this part of an existing app or a new app? | Owner, and whether a boilerplate merge request exists |
| For an existing app, always: should the change go behind a feature flag, so it can be switched on for some accounts first? Recommend yes for anything a provider or patient can see. | The flag; on a yes, name it `feat_prod_<ticket number>_<short name>` and record it |
| Where does the provider meet this: in the call, a dialog, a full page, the waiting room, account settings, after the call, with no screen at all? | The surface, and the applet kind |
| What does the patient, or the other people in the call, see at the same moment? | Cross-participant behaviour |
| What should it remember after the call, and who can look at that later? | Where data lives |
| Who gets it: everyone, a plan, only people an admin allows? | Plan feature, permission or rollout |
| What happens when it cannot do its job: no connection, no answer, the other side leaves? | Failure states |
| Which screens does the design show, and which does it not? | The Screens list in the debrief |
| What is explicitly not part of this? | Out of scope |

When an answer needs a fact from the code, look it up between rounds; only the questions downstream of that fact wait. A question that can only be answered by looking at something, such as how a screen should feel or which of two layouts reads better, is not asked again in words: log it as an open question for design and move on.

Check every answer against the map. Three outcomes: it fits, and is recorded; it is a gap, recorded as work with no alarm; it crosses a premise, and it becomes a boundary-hit question (step 2) in the next round, before anything that depends on it.

Keep a decisions ledger as you go, for yourself: one line per decision with what was decided, where it came from, and one of `fits`, `gap`, `assumed`, `inherited`. It drives the frontier and the debrief and never appears in a ticket. A decision from picked prior work enters as `inherited` and is not re-asked; recommendations follow it. Going against one is a new decision, and the debrief says so. An inherited decision whose engineering review is still open stays `assumed`, and its spike blocks the new tickets too.

**Not a question for them.** When the choices differ only in how something is built (which app draws it, one file or several, where data is kept, which module holds a setting), do not ask. Pick what the precedent did, note it as an open question owned by engineering when there is no precedent, or put it in the spike when it hangs off an assumed decision.

The interview is done when the frontier is empty: every branch visited, nothing left silently assumed. "I don't know" is a real answer and goes to Open questions with an owner. Then debrief (step 3).

## 2 — Boundary hit: the person decides

Ask it as a numbered question in the round, on its own. The body says, in product words, what the product does today instead, which premise the ask crosses, and the closest option that stays inside it. The choices are two: adjust to that option, or keep the behaviour because the experience requires it. The recommended answer is the in-bounds option, and the line of why says an engineer will otherwise have to approve the assumption before work starts, and nothing depending on it is built until they do. Never choose for them and never drop the point.

If they keep it, record the decision as `assumed`: what is assumed, the premise it crosses, why the experience needs it, and the option rejected. The rest of the interview continues on top of it as if it were true; the build does not (step 5).

## 3 — Debrief, until there is agreement

Before any ticket, send the debrief as one message:

1. **The feature in one paragraph.** What it is, for whom, where they meet it, in product words. No more than one paragraph.
2. **The requirements, as user stories.** One per thing the person can see or do, "As a <role>, I want <what>, so that <why>", each followed by its acceptance criteria as bullets, each observable and in product words. Everything decided in the interview lands here or nowhere. A story that rests on an assumed decision is marked "Needs engineering review" with the option that was rejected, so the person sees the gate. Examples of the grain: "As a provider, I want to select QCI as my note type." "As a provider, I want to download my Scribe notes and my Record output from one place on the post-call screen."
3. **Screens.** One line per screen, naming the design frame it comes from, or "existing screen, no frame" or "design system defaults, confirmed".
4. **Feature flag**, when one was decided: its name and what it gates.
5. **Open questions**, each with an owner.
6. **Out of scope.**

Then ask: is this the feature, and is anything missing or wrong? The person may read it and ideate further; that is the point of the step. New ideas or changes reopen the interview: rounds on the new branch only, through the boundary check like anything else, then the debrief again in full. Only when the person says the debrief is right do tickets get written. The debrief is the source the tickets and the build are written from.

## 4 — The tickets

The ticket must exist before any code: the review spikes and the flag ticket hang under it, the branches carry its key and the merge requests link to it. When a ticket came in as input, it is the ticket; otherwise one is written from the debrief.

"Ticket" means an epic with tickets under it, or one ticket. Epic when the debrief has more than one user story that can ship on its own, or more than one owner; otherwise one ticket. The shape follows the epics the product team writes today:

**Epic.** Title `<Area> | <what it adds>`. Then: the one-paragraph overview from the debrief; **Why** (one or two sentences on the need); **Scope** as bullets; **User Stories**, every story from the debrief in full with its acceptance criteria under it; **Out of scope**; **Open questions** with owners; **Dependencies** when there are any. When assumed decisions exist, a section **Needs an engineering decision first** goes at the top, one line per item naming the user story and its spike key, closing with: implementation does not start until each item here is approved or disproved by an engineer.

**Story ticket.** One user story from the debrief, or a few that only ship together: the story as the first line, then **Context** (what the product does there today, in product words, with the design and input links), **Acceptance criteria** from the debrief, **Out of scope**, **Open questions**, and **Checked against the code** (the facts the criteria rely on, in product words, dated). A story resting on an assumed decision carries **Needs an engineering decision first** at the top, as the epic does.

**What a ticket carries, and what it never carries.** A ticket carries product requirements and the context an engineer needs to start: what the product does there today, what it should do after, for whom, and what must not change. It never carries the approach: no file paths, no component or service names, no "edit X to do Y", no data model. No decision ids, no ledger, no sources from the interview. A reader who was not in the session must be able to follow every line.

Show every draft in full. Ask which team the tickets belong to. Nothing is created until the person approves the set. On approval, create in the PROD project through the Atlassian MCP: read `getContentFormatGuide` first; types Epic and Story; priority Medium; set the team, never an assignee; set the epic as parent. Report the keys as links.

## 5 — Blockers, before any code

After the debrief is agreed, list every `assumed` decision from the interview in one message, each with the boundary it crosses and the in-bounds option that was rejected. No merge request is opened while this list has an open item. For each item the person chooses:

- **Find another solution.** Reopen the interview on that branch only, with the in-bounds option as the recommendation, then the debrief again in full. The item leaves the list.
- **Ask engineering.** Draft a spike: Jira type Technical Spike, title `[Engineering review] <the assumption in one line>`, priority Critical, no assignee, under the ticket's epic, blocking the ticket. Body: what is assumed, the boundary it crosses, why the experience needs it, the option rejected, the yes-or-no question, and what changes on a no. Show the drafts, ask which team, create on approval.

**The feature flag is a blocker too.** When the interview decided on a flag, the list carries one more item, in the same shape: a ticket for engineering to create the flag, Jira type Story, title `[Feature flag] Create <flag name>`, priority Critical, no assignee, under the ticket's epic, blocking the ticket, body: the flag name, what it gates in product words, and that it must exist in every environment including production before the build starts. It is cleared when the ticket is Done, never by a comment.

When the list is empty, go to step 7. Otherwise stop with one line: the build starts when every spike below has an answer from a developer and every flag ticket is done, and the keys to share with the team.

## 6 — Resuming after engineering answered

The person returns with the ticket key. Fetch every flag ticket under it first: one not Done still blocks, and the skill says so and stops. Then fetch every spike and read all comments on each one; the comments are the answer. Quote them back in product words before acting. Three outcomes per spike:

- **Yes, with what exists today.** The comments name the mechanism. Record it as the decision, cite the spike in the merge request, and build with it.
- **Yes, after host work.** The comments name a ticket for that work. The spike stays a blocker until that ticket is done. Say so and stop.
- **No.** Treat the feature as impossible, say so in one sentence, reopen the interview on that branch to find another solution, and debrief again. Never argue with the answer and never look for a way around it.

A spike with no comments, or comments that do not give a clear yes or no, blocks. Quote what was found and ask the person to get a clear answer. Never build on a guess.

## 7 — Build

**Before the first command**, verify in the code that every mechanism the debrief rests on exists as the applet table and the capability docs describe it, for example that the applet kind chosen for the patient side is loaded where the debrief needs it. A mechanism that turns out not to exist is a boundary hit: back to step 5, never a workaround.

**Branches.** From a fresh `master`: `<KEY>-1-boilerplate`, then `<KEY>-2-<short-name>` branched from it, then `<KEY>-3-<short-name>` only when step 4 calls for a third. `<KEY>` is the ticket key. Never work on `master`. Never force-push.

**One name.** The product name from the ticket, once, in kebab case for the folder and package, as the manifest title and dock label, in the merge request titles. If the name in the ticket differs from a name the person used, ask once before generating; renaming after generation is what produced `breath` versus Mindfulness.

**Merge request 1, the boilerplate, always for a new app.** Exactly what the generator produces and its next-steps list asks for, and nothing else:

- `NX_DAEMON=false pnpm nx generate @doxyme/extensions:extension <name> --port <free port from docs/guides/ports.md>`, then `pnpm install`.
- The ports row.
- The CI registration in `.gitlab/ci/pipeline_generator/generator.js`, `.gitlab/ci/stages/check.yml` and `.gitlab/ci/stages/publish.yml`, following the existing entries exactly. No other change under `.gitlab/`.
- The manifest metadata filled from the ticket: title, short description, overview. The generator's placeholder copy never survives into a merge request. Icon and card from the design when it has them; otherwise the generator's, and the merge request says so.
- The manifest's capabilities trimmed to the applet kind the interview settled, from the applet table; the generator assumes a call panel for provider and patient.
- One commit: `feat(<app>): <KEY> - create boilerplate app`. The precedent is the `thankful-terrarium` boilerplate commit: about a hundred files, reviewable in minutes.

**Merge request 2, the app.** The behaviour and the screens, on top of merge request 1's branch. When the change extends an existing app there is no boilerplate. When the change touches the app's backend module at all, that backend change is always the first merge request of the stack and holds everything the app's frontend needs from it, since engineers may reject the backend change and that changes how the frontend is built; the frontend merge request comes on top of it. Rules:

- Screens from the design frames, built from `@doxyme/ui-foundation` primitives with Emotion object styles and theme tokens. When the design shows something the foundation has no primitive for, compose it from primitives and say so in the merge request; never hand-roll a primitive, never add a component or styling library.
- Icons one per file from `@doxyme/icons/<name>`.
- Only the capabilities the manifest declares, through the toolkit, as `03-communication-patterns.mdc` describes. Shared helpers from `@doxyme/apps-common` as `05-apps-common.mdc` describes.
- No new dependency unless nothing in the workspace does the job; each one added is listed in the merge request with the reason.
- No file outside the app folder. No design or plan documents in the repository.
- Tests: the generator's test setup, a component test per screen for what the user sees, a test per rule of behaviour. Everything green before a push.
- Commits atomic, each `feat(<app>): <KEY> - <what it adds>`, following `docs/guides/commit-strategy.md`.

**Merge request 3** only for a distinct concern that reviews on its own: cross-participant behaviour, a second applet, the app's backend. At most three merge requests; when the work does not split cleanly, two.

**Not this skill's job**, and listed in every merge request under "Engineer steps that remain": registering the manifest in the registry, the deployment role, the Datadog application, release flags, anything the generator's next-steps list assigns to an engineer or the platform team.

## 8 — Self-review before any push

Run against the full diff of each branch against its target, and fix everything found before pushing. Every item is one of the comments on [MR 16420](https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/16420) or a rule from step 0:

1. Every file outside `apps/extensions/<app>/` is listed with its justification: the app's `api-extensions` module and config entries, `libs/locale` sources, generated types, the three CI registration files, `docs/guides/ports.md`, `pnpm-lock.yaml`, or a file the precedent for the same kind of change also touched. A file with none of those is removed, or goes to step 5 if the feature needs it. Never a host, bridge, capability, SDK or other-app file. Under `.gitlab/`, only the app's own registration lines.
2. `package.json` adds no styling, component, icon or class-name library: no tailwind, postcss, shadcn, radix, cva, clsx, tailwind-merge, lucide, styled-components, or anything of that kind, and no config file for one (`components.json`, `tailwind.config.*`, `postcss.config.*`). Every added dependency is named in the merge request with its reason.
3. No hex or rgb colour literal in any non-test `.tsx` or `.ts`, data files included; colours come from the theme. A palette the design defines, such as gradient stops per pattern, is declared once through theme tokens, never as literals in data.
4. Every icon import is `@doxyme/icons/<name>`; none from `@doxyme/icons` itself.
5. `vite.config.ts` still has `doxymeFontsPlugin()` and every plugin the generator put there.
6. The manifest has no generator placeholder text; title, description and overview describe the app; capabilities match the applet the interview settled.
7. One name: folder, package name, manifest name and title, dock label, merge request titles, commit scopes.
8. No `docs/plans/` or other documents; no `.env` with values; no files the person did not ask for.
9. Lockfile changes only for the app's own packages. A lockfile diff touching other apps' entries means a stale `pnpm install`; redo it on a fresh `master`.
10. `NX_DAEMON=false pnpm nx lint <project>`, `NX_DAEMON=false pnpm nx test <project>` and `NX_DAEMON=false pnpm nx build <project>` all pass.
11. Every screen matches its design frame in layout and copy; every state the design shows exists.
12. Nothing in the diff is a workaround for a boundary hit: no host change, no reading another app, no postMessage, no registry call.

Report the checklist result to the person in one line per item that needed a fix.

## 9 — Verify on a running stack

Run the app on a local stack through `/blitz:blitz` and sideload it, as that skill describes. Walk every screen from the debrief's Screens section, as provider and as patient when both have a view, and take a screenshot of each next to its design frame. Anything that differs from the design or the debrief is fixed before pushing. The screenshots go in the merge requests.

## 10 — Push and open the merge requests

Push each branch with `git push -u origin <branch>`. Open one draft merge request per branch through the GitLab MCP as `.cursor/skills/gitlab-merge-request/SKILL.md` describes: merge request 1 targets `master`, merge request 2 targets merge request 1's branch, merge request 3 targets merge request 2's. Titles `Draft: feat(<app>): <KEY> - <summary>`.

The description follows the repo template, every section kept. "Description of change" says what was built and why in product words, links the ticket, links the other merge requests in the stack and says which order to merge, cites every spike the build rests on with the developer's answer, and lists what the design showed that could not be built as drawn and how it was built instead. "How to test" is the sideload walk from step 9. "Screenshots" carries the step 9 screenshots. Then two sections the template does not have: **Dependencies added**, with reasons, or "None"; and **Engineer steps that remain**, from step 7.

Report the merge request links. The person marks them ready once the screenshots look right to them, and shares the links with the Apps team.

## 11 — A link the person can open

The top merge request of the stack carries the `deploy-full-ephemeral-env` label from the moment it is created, since the label must be present before the first pipeline runs. CI then deploys a whole doxy.me for that merge request, with the app registered in that environment's app store, and the bot comment carries the sign-up and sign-in links. To see the app there, the person's account needs the `Apps Beta Access Full` plan attached in the ephemeral Frontegg workspace, which an engineer does; say so in the same message as the link.

After the push, poll the merge request's notes until `merge-request-commenter(bot)` has posted the deployment comment, checking every few minutes for up to an hour. Send that comment to the person verbatim, as the last message. If nothing arrives in an hour, say so, give the merge request link, and stop; never guess the URL. This is documented in `docs/guides/ephemeral-environments.md` and `apps/extensions/docs/04_deploy_web_apps.md`.

## 12 — After review

When engineers have commented, the person returns with a merge request link. Read every discussion. A finding that stays inside the app and the rules is applied as a further commit on that branch, and the thread gets a one-line answer saying what changed. A finding that says an approach is wrong is applied the way the engineer says, never argued with. A finding that reopens a product decision goes back to the person as an interview question, not to the code. A finding that asks for something outside the app is a boundary hit and goes to step 5.

## Hand-off

The merge requests are the output. Engineers review and merge them. This skill writes the ticket, the spikes and the flag ticket, never platform code, and never marks a merge request ready.
