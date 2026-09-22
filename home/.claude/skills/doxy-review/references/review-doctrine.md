# Review doctrine

Standing principles, each taken from what the reviewer has said in review. Two are kept verbatim because the wording is the standard; the rest are stated as rules.

## What the review optimises for

**Human-readable complexity outranks performance.** A red thread of data flow a human can read is worth a slower or less direct implementation. Simplifying to cut complexity is right even at a performance cost.

**The target is the lowest complexity that meets the requirement, and reimplementation is on the table** when a library has become difficult to understand and work with.

**Volume is a symptom; arrangement is usually the cause.** When an MR needs far more code than its goal suggests, the way it is arranged is the suspect. The cause found more than once: an abstraction organised around a concept (store, schema) that handles both reading and writing inside itself, so it balloons.

**Complexity belongs in the library, never in the app.** More complexity in the library is accepted when it gives app consumers an easier interface.

**An abstraction must justify its existence.** Count what it buys. The reference case: `bindAt`, an abstract method, three implementations and a constructor parameter on four classes, all to deliver one `storedPath` label to one call. An implementation with no benefit is dropped as complexity for no reason.

**The readability bar is the reader's, not the author's.** Code the author understands but no reader will is a finding.

## The failure modes this skill prevents

**Reviewing at the wrong altitude.** Simplifications targeted at small individual changes miss what the reviewer wants: methodology and architecture first.

**Burying one to three real points under small ones.** Verbatim, because it defines the altitude rule and is easy to misread as a cap:

> "Sometimes you've reviewed an MR and come back with 10 changes where maybe only 2 or 3 were actually important. It's confusing when you list 10 items and 7 of them are tiny details that I'm not gonna bother adding to my review as they will be impacted by larger architectural changes anyway."

> "It shouldn't be a hard cap. My point was not that 3 is the max but rather that you sometimes have 1-3 really good points and then 7 nit pick comments. In those cases I don't care about the small details as they will mean nothing compared to larger rewrites/decisions anyway. They can come later when the big picture has been finished and settled on."

The filter is dependency and timing, not count. Every substantive finding is reported; small details wait until the larger decisions settle.

**Agreeing to be agreeable.** A question is not a request for agreement. The aim is an honest architecture discussion that lands at the lowest complexity for a working solution. On pushback about size or complexity, measure and question your own proposal first; never reframe the number instead of answering it.

## Scope discipline

**Out-of-scope improvements are filed, never smuggled into the MR under review.** Write the current implementation with the improvement in mind, and create a low-priority ticket in the epic carrying its benefit and reasoning.

**Known limitations can be accepted with a stated horizon**, for example because no app will use Hotpot for a long time yet. A finding that an accepted limitation exists is worth raising only if the horizon has changed.

**Deferring to a later MR in the same series is a legitimate resolution.** Check whether the next MR already cleans something up before raising it.

## Costing a rewrite proposal, both directions

**Numbers make a restructuring proposal reviewable.** The reviewer wants the actual lines-of-code difference between the two implementations, a specific example that can be shared in a comment, the abstractions removed, and whether the alternative covers fewer or more edge cases and bugs. The accounting runs both ways: what the change removes and what it adds. Never only the savings.

### The shape that worked

The reviewer's comment on the Hotpot write MR is the reference standard for a costed architectural finding. The order: numbers, cause, sketch, the machinery that stops existing, the ordering constraint that must hold, the interaction with another finding.

> "First the numbers so it's clear what we'd save: I count roughly 150 fewer production lines in this MR (`stashSync` goes from ~280 to somewhere around 130), and more importantly we'd remove `writingPaths`, the `flushing` mutex with its waiter loop, the snapshot-and-clear step on the queue, `RowOutcome` with its `stop` flag, `refusedPaths`, and the `writePaths`/`writeRow` split. What remains is three fields with one writer each.
>
> The cause as I see it: every trigger runs its own `flush()`. A `set`, the ready transition and `close()` each start an invocation, and those invocations then have to coordinate with each other. That's what all the machinery is for.
>
> If we invert it so there is one loop that drains the queue, and triggers just add work and start it if it isn't running, all of that coordination stops having a reason to exist.
>
> One detail that matters: the paths have to be removed from the queue before the put and re-added on failure. If we removed them after, a `set` landing during the put would be invisible and its value never sent."

What that comment did not state, and this skill must add, is the other side of the ledger: the production lines the new `drain` loop introduces, the `running` promise and `writingRow` state that replace the removed machinery, and the new invariant the reader must hold about queue ordering. Say when the net is near neutral on lines and the gain is readability.

## Correctness findings

**Defects are reported and kept separate from the architecture discussion**, introduced as a bug rather than a style preference.

**The standard is a concrete failure path**: the inputs, the wrong outcome, and whether it is deterministic. The reference case: B removes field X from a row and it syncs to A; A's next write to any other field in that row packs the row from A's store, X included, and puts X back into Hotpot. Deterministic, not a race.

## Comments and documentation

Consumer-facing docs describe the public surface and how to use it. Comments explain the concept a reader needs and carry nothing that exists only in the authoring conversation. A class-level concept comment goes on the class, not at the top of the file. Lead an MR description with the plain framing of what was built and why; it is the first thing a reviewer reads.
