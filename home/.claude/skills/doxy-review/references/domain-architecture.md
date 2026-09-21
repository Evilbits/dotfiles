# Domain architecture — what owns what

The purpose of this map is to answer one question fast: does this code live in
the layer that owns it. Most architectural findings in this domain are a
placement error rather than a coding error.

Authoritative in-repo sources, which win over this file when they disagree:
`libs/extensions/glossary.md`, `.cursor/rules/*.mdc`, and the docs under
`libs/extensions/*/docs/`.

## The layers

**Host** — doxy.me itself (`apps/frontend`, `apps/api-core`). Owns the call,
media, participants, clinic and tenant data, entitlements and billing. It is
the only layer allowed to know about Vonage, SIP, and the rest of the call
plumbing.

**Bridge** (`libs/extensions/bridge`, `-react`) — the host-side hub. Registers
capabilities and extension instances and routes messages between them. Host
code, and it should contain no knowledge of any individual app.

**Capability** (`libs/extensions/common/src/specs/capabilities/*`) — a generic
mechanism the host offers to *any* extension, expressed as actions, events and
payload types. This is a platform contract. Adding one widens the platform
permanently.

**Toolkit** (`libs/extensions/toolkit`, `-react`) — the app-side client for
talking to the bridge. Hooks such as `useInterpreter` live here.

**App / extension** (`apps/extensions/*`) — a product. Owns its own domain
logic, its own UI, its own vendor integrations, and its own backend when it
needs one. Vendor specifics belong here.

**api-extensions** — the API surface serving extensions.

**Hotpot SDK** (`libs/extensions/hotpot`, `-react`) — the app-facing library
over Hotpot, the Convex-backed per-Visit data store. The upstream Hotpot repo
lives at `~/dev/hotpot` and is also owned by this team. The SDK's job is to let
an app declare a schema and get a typed reactive store, with the library
absorbing the difficulty.

## The capability test

This is the check that catches the most consequential mistakes, because a
capability is a permanent platform contract and an app is not.

Ask, in order:

1. **Would a second, unrelated app plausibly use this?** If the honest answer is
   no, it belongs inside the app. A capability that only ever serves one app is
   an app feature wearing platform clothing.
2. **Does the name describe a mechanism or a product?** Every sound capability
   in the repo names a mechanism: `applets`, `controls`, `mediaControl`,
   `multiplayer`, `videoFrames`, `audioFrames`, `storage`, `notification`,
   `playSound`, `fileTransfer`, `fileService`, `navigationInterception`,
   `receiveContext`, `receiveTenantContext`, `appToken`, `extensionToken`,
   `featureFlag`, `postInstall`, `alertBanner`, `appEvents`, `photoCapture`,
   `pingPong`. A capability named after a product is the smell.
3. **Do the payloads carry vendor or product vocabulary?** Host contracts
   should not contain a vendor's prominence hints, a vendor's status strings, or
   a product's domain nouns.
4. **What does it let one app do to another?** If app B can invoke the
   capability, can B now act as app A, or cause billing against app A? A
   capability is available to every extension, so this follows automatically
   from adding it.
5. **Is there a precedent trap?** `interpreter` and `transcription` are existing
   capabilities named after products. They are the exception rather than the
   pattern, so neither is precedent for a third.

### Worked example — the `interpreter` capability

`libs/extensions/common/src/specs/capabilities/interpreter/interpreter.ts`
declares `id = 'interpreter'`, actions `interpreter:get-languages` and
`interpreter:request`, and a payload type `InterpreterLanguage` carrying
`favorite` and `weight` as vendor prominence hints plus vendor status strings
such as `no_interpreters`.

Every test above fails. No second app is likely to request an interpreter. The
name is the Interpreter product. The payload is vendor vocabulary in a platform
contract. And because any extension can use a capability, another app can now
request an interpreter and cause billing against the Interpreter app.

The correct shape is a capability named for the mechanism the host actually
owns, such as `dial-out` for bringing a third party into the call over SIP, with
LanguageLine and Voyce specifics living in the Interpreter app.

Note the legitimate part of the counter-argument, because a good finding
concedes it: the LanguageLine backend lives in `api-core` because the SIP and
Vonage plumbing exists only there, and duplicating that into `api-extensions`
would be worse. Placement of the backend work is defensible. The shape of the
contract exposed to apps is the problem.

## Placement tests

**api-core versus api-extensions.** Host plumbing that only exists in api-core
is a legitimate reason for backend code to live there. What still needs
challenge is the contract the apps see, and whether the capability wrapping it
is generic.

**The word "backend" is ambiguous and needs disambiguating on sight.** It can
mean api-core, api-extensions, or the extension's own service. The `backend`
capability (`.../capabilities/backend/backend.ts`) is the third of those: a
config carrying the extension's own `url`, `filter` and `isAuthRequired`. Any
doc or comment using the bare word should be made specific.

**Bridge cleanliness.** Bridge code naming a specific app is a placement error.

**Host knowledge in an app.** An app reaching for host internals rather than a
capability is the mirror-image error.

## Hotpot SDK principles

These come from decisions already taken in review, so a change contradicting one
needs to argue against the decision rather than restate the problem.

**Thinnest possible app surface.** "We want the thinnest app surface possible",
and the library deliberately absorbs complexity: "we have prioritised putting
more complexity into the library if it leads to an easier interface for app
consumers to use externally." A symbol exported that a consumer must never
construct should be exported as a type only.

**Consumer vocabulary is fixed by the consumer's mental model.** `sensitive` was
kept over `hidden` because the consumer already knows what a sensitive value is
and should not have to learn a second term for the same idea.

**Ownership split inside the SDK.** Transport and reachability belong to
`HotpotSession`, which retries and then surfaces a terminal failure to the app
to handle explicitly. Schema and value validity belong to the compiler and its
plan. These two must not be conflated, and the plan delegates the actual write
to the session.

**One decision point per rule.** Whether a write is allowed should be decided in
one place, so the read path, the write path and the merge path cannot drift.

**Errors must reach the app.** A refusal swallowed by a detached promise leaves
the app showing a value that Hotpot will never hold.

**Never discard data.** A value the library accepted must be buffered and
survive a reconnect, with rehydration on reconnect as the recovery path.

**Row keys derive from the axis combination only**, never from the field list or
a schema hash, or adding a field changes the key and orphans everything
previously written. Only necessary rows are created, so a schema with no
sensitive fields creates no sensitive row.

**That four-row shape is the SDK's convention, not a Hotpot constraint**, and
the distinction matters whenever someone reasons about row granularity. Hotpot
identifies a row by `(visitId, extensionId, key)` where `key` is an arbitrary
string, so per-field or per-record rows are available at the platform level and
were contemplated in PROD-10890 as Candidate C, conditional on post-visit stash
trimming being designed in the same decision. Never present the axis-derived key
as a property of Hotpot, and never let a size or traffic estimate that depends
on the whole schema sharing one row stand as physics.

### Stash rows, and what actually conflicts

Get this right before reasoning about concurrent writes, because the intuitive
answer is wrong in both directions.

A stash row's content is **arbitrary JSON that Hotpot deliberately does not look
inside**. Indexing into a row was considered and rejected, in the form of a
`putStashAttribute(key, attribute, value)` call, on the grounds that Hotpot
would then have to know the paths and know what is sensitive. Convex offers no
guarantee inside the blob either, since its patches shallow-merge, so nested
objects do not hold up.

The consequence, in the Hotpot author's own words, is that **"two people
touching different fields inside one row can wipe each other"**, because a write
upserts the whole row content. This is the behaviour a review must assume for
any code path that has not opted into the mechanism below.

**The fix is in flight and has not landed. Verify its status before relying on
it in either direction.** As of 15 September 2026, Hotpot `main` has no
`revision` column and `writeStashEntry` upserts content wholesale, so the
silent-overwrite behaviour above is what actually ships today.

The agreed design is **compare-and-swap on a per-row `revision`**: a stale write
is refused with a typed conflict rather than silently winning, and the consumer
merges the newer state into its write and retries, because the consumer is the
only party that understands the data. Hotpot stays blind by design. The decision
was taken in PROD-10890 (closed), the Hotpot side is PROD-10904 with merge
request `doxyme/cooks/hotpot!559`, and the SDK side, retrying whole-row puts on
a revision conflict, is PROD-10905.

Once that lands **and a caller opts in**, the granularity to reason about
becomes **per attribute within the row content**: two writers on different
attributes both survive the merge, and only two writers on the same attribute
lose one. There is no CRDT or OT anywhere in this, so simultaneous edits to a
single value are last-writer-wins by design and are expected to be prevented by
the app itself.

**`expectedRevision` is optional, so this is opt-in and absence is the
default.** When reviewing a write path, check whether it actually sends a
revision. `libs/extensions/hotpot/src/stash/hotpotStashIo.ts` calls
`client.stash.put` and `putSensitive` with key, value and `writeAccess` only, so
the SDK has not opted in.

Both halves of this are live work, so treat every sentence above as a claim with
a date on it. Check `~/dev/hotpot` and the two tickets before asserting either
that writes clobber or that they no longer do.

### The Journal is not an app data store

The Journal is an **append-only log of call events for the provider's benefit**,
answering what happened in their call and when, with entries such as a call
being joined or a patient checking in.

Apps write to it only **generic, very high-level events**, and the deliberate
design is a single app event carrying metadata rather than a new event type per
app.

It is **not** a place for app state, per-object synchronisation, operation
streams, collaborative editing, or anything resembling a CRDT substrate.
Proposing it as a conflict-free write channel for app data misreads what it is.
App data belongs in the stash, under the rules above.

**Readiness before writes.** An app may write only once rehydration has
completed.

**Version skew between participants is real.** Two participants can run
different manifest versions of the same app. Routing across participants needs
both the extension identity and the manifest version, and extension ids are
append-only.
