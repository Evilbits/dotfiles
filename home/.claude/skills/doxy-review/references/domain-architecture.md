# Domain architecture — what owns what

Answers one question fast: does this code live in the layer that owns it. Most architectural findings in this domain are placement errors.

Authoritative in-repo sources, which win over this file when they disagree: `libs/extensions/glossary.md`, `.cursor/rules/*.mdc`, and the docs under `libs/extensions/*/docs/`.

## The layers

**Host** — doxy.me itself (`apps/frontend`, `apps/api-core`). Owns the call, media, participants, clinic and tenant data, entitlements and billing. The only layer allowed to know about Vonage, SIP and the rest of the call plumbing.

**Bridge** (`libs/extensions/bridge`, `-react`) — the host-side hub. Registers capabilities and extension instances and routes messages between them. Host code; knows no individual app.

**Capability** (`libs/extensions/common/src/specs/capabilities/*`) — a generic mechanism the host offers any extension, as actions, events and payload types. A platform contract; adding one widens the platform permanently.

**Toolkit** (`libs/extensions/toolkit`, `-react`) — the app-side client for the bridge. Hooks such as `useInterpreter` live here.

**App / extension** (`apps/extensions/*`) — a product. Owns its domain logic, UI, vendor integrations, and its own backend when it needs one. Vendor specifics belong here.

**api-extensions** — the API surface serving extensions.

**Hotpot SDK** (`libs/extensions/hotpot`, `-react`) — the app-facing library over Hotpot, the Convex-backed per-Visit data store. The Hotpot repo is at `~/dev/hotpot` and is owned by this team. The SDK lets an app declare a schema and get a typed reactive store, with the library absorbing the difficulty.

## The capability test

Catches the most consequential mistakes, because a capability is a permanent platform contract and an app is not. Ask, in order:

1. **Would a second, unrelated app plausibly use this?** If not, it belongs inside the app. A capability that serves one app is an app feature wearing platform clothing.
2. **Does the name describe a mechanism or a product?** Every sound capability in the repo names a mechanism: `applets`, `controls`, `mediaControl`, `multiplayer`, `videoFrames`, `audioFrames`, `storage`, `notification`, `playSound`, `fileTransfer`, `fileService`, `navigationInterception`, `receiveContext`, `receiveTenantContext`, `appToken`, `extensionToken`, `featureFlag`, `postInstall`, `alertBanner`, `appEvents`, `photoCapture`, `pingPong`. A capability named after a product is the smell.
3. **Do the payloads carry vendor or product vocabulary?** A vendor's prominence hints or status strings, or a product's domain nouns, do not belong in a host contract.
4. **What does it let one app do to another?** Every extension can declare every capability, so if app B can invoke it, can B act as app A, or cause billing against A?
5. **Is there a precedent trap?** `interpreter` and `transcription` are existing capabilities named after products. They are the exception, not the pattern, and neither is precedent for a third.

### Worked example — the `interpreter` capability

`libs/extensions/common/src/specs/capabilities/interpreter/interpreter.ts` declares `id = 'interpreter'`, actions `interpreter:get-languages` and `interpreter:request`, and a payload type `InterpreterLanguage` carrying `favorite` and `weight` as vendor prominence hints plus vendor status strings such as `no_interpreters`.

Every test fails. No second app will request an interpreter. The name is the Interpreter product. The payload is vendor vocabulary in a platform contract. Any extension can use a capability, so another app can request an interpreter and cause billing against the Interpreter app.

The correct shape is a capability named for the mechanism the host owns, such as `dial-out` for bringing a third party into the call over SIP, with LanguageLine and Voyce specifics in the Interpreter app.

Concede the legitimate part of the counter-argument: the LanguageLine backend lives in `api-core` because the SIP and Vonage plumbing exists only there, and duplicating it into `api-extensions` would be worse. Placement of the backend is defensible; the shape of the contract exposed to apps is the problem.

## Placement tests

**api-core versus api-extensions.** Host plumbing that exists only in api-core is a legitimate reason for backend code to live there. What still needs challenge is the contract the apps see and whether the capability wrapping it is generic.

**"Backend" is ambiguous; disambiguate on sight.** It can mean api-core, api-extensions, or the extension's own service. The `backend` capability (`.../capabilities/backend/backend.ts`) is the third: a config carrying the extension's own `url`, `filter` and `isAuthRequired`. Any doc or comment using the bare word should be made specific.

**Bridge cleanliness.** Bridge code naming a specific app is a placement error.

**Host knowledge in an app.** An app reaching for host internals instead of a capability is the mirror error.

## Hotpot SDK principles

Decisions already taken in review; a change contradicting one argues against the decision, not the problem.

**Thinnest possible app surface.** "We want the thinnest app surface possible", and the library absorbs complexity: "we have prioritised putting more complexity into the library if it leads to an easier interface for app consumers to use externally." A symbol a consumer must never construct is exported as a type only.

**Consumer vocabulary is fixed by the consumer's mental model.** `sensitive` was kept over `hidden` because the consumer already knows what a sensitive value is and should not learn a second term for the same idea.

**Ownership split inside the SDK.** Transport and reachability belong to `HotpotSession`, which retries and then surfaces a terminal failure for the app to handle. Schema and value validity belong to the compiler and its plan. The two are never conflated, and the plan delegates the write to the session.

**One decision point per rule.** Whether a write is allowed is decided in one place, so the read, write and merge paths cannot drift.

**Errors must reach the app.** A refusal swallowed by a detached promise leaves the app showing a value Hotpot will never hold.

**Never discard data.** A value the library accepted is buffered and survives a reconnect, with rehydration as the recovery path.

**Row keys derive from the axis combination only**, never from the field list or a schema hash, or adding a field changes the key and orphans everything written. Only necessary rows are created: a schema with no sensitive fields creates no sensitive row.

**The four-row shape is the SDK's convention, not a Hotpot constraint.** Hotpot identifies a row by `(visitId, extensionId, key)` where `key` is an arbitrary string, so per-field or per-record rows are available at the platform level and were contemplated in PROD-10890 as Candidate C, conditional on post-visit stash trimming being designed in the same decision. Never present the axis-derived key as a property of Hotpot, and never let a size or traffic estimate that depends on the whole schema sharing one row stand as physics.

### Stash rows, and what conflicts

Get this right before reasoning about concurrent writes; the intuitive answer is wrong in both directions.

A stash row's content is **arbitrary JSON that Hotpot does not look inside**. Indexing into a row, as a `putStashAttribute(key, attribute, value)` call, was rejected because Hotpot would then have to know the paths and what is sensitive. Convex offers no guarantee inside the blob either: its patches shallow-merge, so nested objects do not hold up.

The consequence, in the Hotpot author's words: **"two people touching different fields inside one row can wipe each other"**, because a write upserts the whole row content. Assume this for any code path that has not opted into the mechanism below.

**The fix is in flight and has not landed. Verify its status before relying on it in either direction.** As of 15 September 2026, Hotpot `main` has no `revision` column and `writeStashEntry` upserts content wholesale, so the silent overwrite above is what ships today.

The agreed design is **compare-and-swap on a per-row `revision`**: a stale write is refused with a typed conflict, and the consumer merges the newer state into its write and retries, because only the consumer understands the data. Hotpot stays blind by design. Decided in PROD-10890 (closed); Hotpot side PROD-10904, merge request `doxyme/cooks/hotpot!559`; SDK side, retrying whole-row puts on a revision conflict, PROD-10905.

Once that lands **and a caller opts in**, the granularity becomes **per attribute within the row content**: two writers on different attributes both survive the merge, and only two writers on the same attribute lose one. There is no CRDT or OT, so simultaneous edits to a single value are last-writer-wins by design, to be prevented by the app.

**`expectedRevision` is optional, so this is opt-in and absence is the default.** When reviewing a write path, check whether it sends a revision. `libs/extensions/hotpot/src/stash/hotpotStashIo.ts` calls `client.stash.put` and `putSensitive` with key, value and `writeAccess` only, so the SDK has not opted in.

Both halves are live work; every sentence above is a claim with a date. Check `~/dev/hotpot` and the two tickets before asserting either that writes clobber or that they no longer do.

### The Journal is not an app data store

The Journal is an **append-only log of call events for the provider**: what happened in their call and when, such as a call being joined or a patient checking in.

Apps write only **generic, high-level events**, and the design is a single app event carrying metadata, not a new event type per app.

It is **not** a place for app state, per-object synchronisation, operation streams, collaborative editing, or a CRDT substrate. Proposing it as a conflict-free write channel for app data misreads it. App data belongs in the stash, under the rules above.

**Readiness before writes.** An app may write only once rehydration has completed.

**Version skew between participants is real.** Two participants can run different manifest versions of the same app. Routing across participants needs the extension identity and the manifest version, and extension ids are append-only.
