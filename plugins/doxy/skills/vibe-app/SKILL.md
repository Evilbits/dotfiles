---
name: vibe-app
description: >-
    Build a doxy.me app (an extension) for someone outside engineering, from
    an idea or a /doxy:feature ticket plus a design, into stacked merge
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

**Product words only.** As `/doxy:feature`: never SSL, data types, APIs, endpoints, schemas, tokens, components, hooks, services, or how anything is built. Say app, panel, page, call, waiting room, patient, provider, plan, setting, design. When a rule of the code has to be explained, say what apps can and cannot do in the product and stop there.

**Facts are yours to find, decisions are theirs to make.** Anything the code, the design or the ticket can answer is looked up, never asked. What the app should do is put to the person and waited for.

**Never the platform.** This skill never writes in the host (`apps/frontend`, `apps/api-core`), the bridge, a capability, the SDK (`libs/extensions/*`), or another app, whatever the reason. A need for that is a boundary hit (step 2) and goes to engineering as a spike. The shared places an app is expected to touch are not boundaries: the app's own module under `apps/api-extensions/src/<module>/` and its entries in that backend's configuration, the label sources under `libs/locale/`, the generated app types, the three CI registration files and the row in `docs/guides/ports.md`. The test is the precedent: whatever the last change of the same kind touched (the previous note type, the previous app), this one may touch too, and the self-review lists every file outside the app folder with the precedent that justifies it. Only a file with no precedent of that kind is a question for step 2.

## 0 — Load the map before the first question

Read, locally, in the checkout (this skill needs one; if the working directory is not a doxyme-core checkout, stop and say so in one sentence):

1. Every input the person gave: the ticket, the design link or files, a Slack thread, a doc. All of it, in full.
2. `apps/extensions/AGENTS.md` in full: what an app is and is not, the applet table, the data table, the capability tests. `libs/extensions/glossary.md`. `docs/guides/entitlements/concepts.md`.
3. The build rules: `apps/extensions/.cursor/rules/01-extension-architecture.mdc`, `03-communication-patterns.mdc`, `05-apps-common.mdc`; `libs/ui/.cursor/rules/00-ui-guidelines.mdc`, which covers every `.tsx` under `apps/extensions/`; `.cursor/skills/doxyme-design-system/SKILL.md` for tokens. The domain-driven design rule (`06`) is not applied: a new app does not have to use that layout.
4. The generator at `tools/plugins/extensions/src/generators/extension/`: its `files/` are what a new app looks like, and the next-steps list in `generator.ts` is the authoritative split between what this skill does (generate, ports row, CI registration files) and what an engineer does (register the manifest, deployment role, Datadog application). `docs/guides/ports.md` for a free port. `.gitlab/merge_request_templates/Default.md` for the merge request shape.
5. When the ask extends an existing app, that app's folder, manifest and docs in full.

**Premises.** Crossing one is a boundary hit (step 2). Product premises as in `/doxy:feature`: an app lives in its iframe and never draws on or reads a host surface (waiting room, patient card, control bar); an app never talks to another app; a capability is a mechanism for every app, never one product's feature; tenant data never mixes. Build premises, from the rules above: an app is styled with `@doxyme/ui-foundation` primitives, Emotion object styles and theme tokens, and nothing else; icons come from `@doxyme/icons/<name>` one file each; the generator's Vite config, including the fonts plugin, stays as generated; an app has one name used everywhere.

Something the code has no concept of yet is a gap, and a gap is ordinary work inside the app. Only a premise crossed is a boundary hit.

## 1 — The ticket, the interview, the design

**No ticket yet: run `/doxy:feature`, unchanged.** Read `${CLAUDE_PLUGIN_ROOT}/skills/feature/SKILL.md` and follow it word for word from its opening request through the prior-work pick, the restatement, the rounds, the boundary hits, the debrief loop, the ticket drafts and their creation in Jira. Nothing from this skill is added to or removed from that interview, and no question about the build is asked during it. The ticket must exist before any code, because the review spikes hang under it, the branches carry its key and the merge requests link to it.

**A ticket exists.** Read it in full; its user stories are settled and are not re-asked.

**Then the build questions**, in the feature skill's own format, rounds of at most four, numbered on from where the interview stopped, each with a recommended answer. Only what the ticket left open and a build needs: which applet kind, in the applet table's words (a panel in the call, a dialog, a full page, after the call, the dashboard, settings); what each participant sees and does at the same moment; what the app remembers and for how long; what happens when it cannot do its job. Any answer is checked against the map like every other, and a premise crossed is a boundary hit as in the feature skill. A question whose options differ only in how it is built is not asked.

**The design**, asked once, at the start of the build questions. A Figma link is read through the Figma connector (design context and a screenshot per screen); otherwise images or an HTML export. The design is the source for layout, copy and states. What the design does not show is asked, never invented. When there is no design and the app has a screen, say that the app will use the design system's defaults and ask the person to confirm that before building; never build a screen from imagination without saying so.

The build questions end with a short debrief addendum: the **Screens** list, one line per screen naming the design frame it comes from, and any decision the build questions added, in the same user-story form. The person confirms it before step 2.

## 2 — Blockers, before any code

After the debrief is agreed, list every `assumed` decision from the interview in one message, each with the boundary it crosses and the in-bounds option that was rejected. No merge request is opened while this list has an open item. For each item the person chooses:

- **Find another solution.** Reopen the interview on that branch only, with the in-bounds option as the recommendation, then the debrief again in full. The item leaves the list.
- **Ask engineering.** Draft a spike as `/doxy:feature` does: Jira type Technical Spike, title `[Engineering review] <the assumption in one line>`, priority Critical, no assignee, under the ticket's epic, blocking the ticket. Body: what is assumed, the boundary it crosses, why the experience needs it, the option rejected, the yes-or-no question, and what changes on a no. Show the drafts, ask which team, create on approval.

When the list is empty, go to step 4. Otherwise stop with one line: the build starts when every spike below has an answer from a developer, and the keys to share with the team.

## 3 — Resuming after engineering answered

The person returns with the ticket key. Fetch every spike under it and read all comments on each one; the comments are the answer. Quote them back in product words before acting. Three outcomes per spike:

- **Yes, with what exists today.** The comments name the mechanism. Record it as the decision, cite the spike in the merge request, and build with it.
- **Yes, after host work.** The comments name a ticket for that work. The spike stays a blocker until that ticket is done. Say so and stop.
- **No.** Treat the feature as impossible, say so in one sentence, reopen the interview on that branch to find another solution, and debrief again. Never argue with the answer and never look for a way around it.

A spike with no comments, or comments that do not give a clear yes or no, blocks. Quote what was found and ask the person to get a clear answer. Never build on a guess.

## 4 — Build

**Before the first command**, verify in the code that every mechanism the debrief rests on exists as the applet table and the capability docs describe it, for example that the applet kind chosen for the patient side is loaded where the debrief needs it. A mechanism that turns out not to exist is a boundary hit: back to step 2, never a workaround.

**Branches.** From a fresh `master`: `<KEY>-1-boilerplate`, then `<KEY>-2-<short-name>` branched from it, then `<KEY>-3-<short-name>` only when step 4 calls for a third. `<KEY>` is the ticket key. Never work on `master`. Never force-push.

**One name.** The product name from the ticket, once, in kebab case for the folder and package, as the manifest title and dock label, in the merge request titles. If the name in the ticket differs from a name the person used, ask once before generating; renaming after generation is what produced `breath` versus Mindfulness.

**Merge request 1, the boilerplate, always.** Exactly what the generator produces and its next-steps list asks for, and nothing else:

- `NX_DAEMON=false pnpm nx generate @doxyme/extensions:extension <name> --port <free port from docs/guides/ports.md>`, then `pnpm install`.
- The ports row.
- The CI registration in `.gitlab/ci/pipeline_generator/generator.js`, `.gitlab/ci/stages/check.yml` and `.gitlab/ci/stages/publish.yml`, following the existing entries exactly. No other change under `.gitlab/`.
- The manifest metadata filled from the ticket: title, short description, overview. The generator's placeholder copy never survives into a merge request. Icon and card from the design when it has them; otherwise the generator's, and the merge request says so.
- The manifest's capabilities trimmed to the applet kind the interview settled, from the applet table; the generator assumes a call panel for provider and patient.
- One commit: `feat(<app>): <KEY> - create boilerplate app`. The precedent is the `thankful-terrarium` boilerplate commit: about a hundred files, reviewable in minutes.

**Merge request 2, the app.** The behaviour and the screens, on top of merge request 1's branch. Rules:

- Screens from the design frames, built from `@doxyme/ui-foundation` primitives with Emotion object styles and theme tokens. When the design shows something the foundation has no primitive for, compose it from primitives and say so in the merge request; never hand-roll a primitive, never add a component or styling library.
- Icons one per file from `@doxyme/icons/<name>`.
- Only the capabilities the manifest declares, through the toolkit, as `03-communication-patterns.mdc` describes. Shared helpers from `@doxyme/apps-common` as `05-apps-common.mdc` describes.
- No new dependency unless nothing in the workspace does the job; each one added is listed in the merge request with the reason.
- No file outside the app folder. No design or plan documents in the repository.
- Tests: the generator's test setup, a component test per screen for what the user sees, a test per rule of behaviour. Everything green before a push.
- Commits atomic, each `feat(<app>): <KEY> - <what it adds>`, following `docs/guides/commit-strategy.md`.

**Merge request 3** only for a distinct concern that reviews on its own: cross-participant behaviour, a second applet, the app's backend. At most three merge requests; when the work does not split cleanly, two.

**Not this skill's job**, and listed in every merge request under "Engineer steps that remain": registering the manifest in the registry, the deployment role, the Datadog application, release flags, anything the generator's next-steps list assigns to an engineer or the platform team.

## 5 — Self-review before any push

Run against the full diff of each branch against its target, and fix everything found before pushing. Every item is one of the comments on [MR 16420](https://gitlab.com/doxyme/code/doxyme-core/-/merge_requests/16420) or a rule from step 0:

1. Every file outside `apps/extensions/<app>/` is listed with its justification: the app's `api-extensions` module and config entries, `libs/locale` sources, generated types, the three CI registration files, `docs/guides/ports.md`, `pnpm-lock.yaml`, or a file the precedent for the same kind of change also touched. A file with none of those is removed, or goes to step 2 if the feature needs it. Never a host, bridge, capability, SDK or other-app file. Under `.gitlab/`, only the app's own registration lines.
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

## 6 — Verify on a running stack

Run the app on a local stack through `/blitz:blitz` and sideload it, as that skill describes. Walk every screen from the debrief's Screens section, as provider and as patient when both have a view, and take a screenshot of each next to its design frame. Anything that differs from the design or the debrief is fixed before pushing. The screenshots go in the merge requests.

## 7 — Push and open the merge requests

Push each branch with `git push -u origin <branch>`. Open one draft merge request per branch through the GitLab MCP as `.cursor/skills/gitlab-merge-request/SKILL.md` describes: merge request 1 targets `master`, merge request 2 targets merge request 1's branch, merge request 3 targets merge request 2's. Titles `Draft: feat(<app>): <KEY> - <summary>`.

The description follows the repo template, every section kept. "Description of change" says what was built and why in product words, links the ticket, links the other merge requests in the stack and says which order to merge, cites every spike the build rests on with the developer's answer, and lists what the design showed that could not be built as drawn and how it was built instead. "How to test" is the sideload walk from step 6. "Screenshots" carries the step 6 screenshots. Then two sections the template does not have: **Dependencies added**, with reasons, or "None"; and **Engineer steps that remain**, from step 4.

Report the merge request links. The person marks them ready once the screenshots look right to them, and shares the links with the Apps team.

## 8 — A link the person can open

The top merge request of the stack carries the `deploy-full-ephemeral-env` label from the moment it is created, since the label must be present before the first pipeline runs. CI then deploys a whole doxy.me for that merge request, with the app registered in that environment's app store, and the bot comment carries the sign-up and sign-in links. To see the app there, the person's account needs the `Apps Beta Access Full` plan attached in the ephemeral Frontegg workspace, which an engineer does; say so in the same message as the link.

After the push, poll the merge request's notes until `merge-request-commenter(bot)` has posted the deployment comment, checking every few minutes for up to an hour. Send that comment to the person verbatim, as the last message. If nothing arrives in an hour, say so, give the merge request link, and stop; never guess the URL. This is documented in `docs/guides/ephemeral-environments.md` and `apps/extensions/docs/04_deploy_web_apps.md`.

## 9 — After review

When engineers have commented, the person returns with a merge request link. Read every discussion. A finding that stays inside the app and the rules is applied as a further commit on that branch, and the thread gets a one-line answer saying what changed. A finding that says an approach is wrong is applied the way the engineer says, never argued with. A finding that reopens a product decision goes back to the person as an interview question, not to the code. A finding that asks for something outside the app is a boundary hit and goes to step 2.

## Hand-off

The merge requests are the output. Engineers review and merge them; `/doxy:implement` is not involved. This skill never writes tickets beyond the spikes, never writes host code, and never marks a merge request ready.
