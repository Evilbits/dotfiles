# Review doctrine

Standing principles, each anchored to what the reviewer has said in review, so the skill argues from the real position and not a paraphrase.

## What the review optimises for

**Human-readable complexity outranks performance.**

> "I care more about that there's a red thread of data flow through the application and that a human can read and understand it well. That means sometimes perhaps doing things in a slightly different way, perhaps even less performant, if it means it'll lead to gains in readability and complexity."

> "Can we simplify it to reduce complexity a lot EVEN if we lose some performance?"

The target is the lowest complexity that meets the requirement, and reimplementation is on the table: "I want us to simplify the complexity as much as possible as we are already getting to a point where the libraries are difficult to understand and work with. Even if that means reimplementing."

**Volume is a symptom; arrangement is usually the cause.**

> "I still feel like there's something wrong about this MR. Specifically some of our abstractions have exploded in size and complexity. In general I have a feeling that what we are trying to achieve in this MR should be possible to do with much much less code (outside of the tests). If we need this much code then perhaps the way it's arranged is what is wrong."

The cause found more than once: an abstraction organised around a concept that handles several directions of flow inside itself.

> "maybe it's because we have decided to have abstraction around concepts, such as the store, schema, etc, but within them they handle both reading and writing which is handled a bit differently. This means those abstractions balloon in size."

**Complexity belongs in the library, never in the app.**

> "we have prioritised putting more complexity into the library if it leads to an easier interface for app consumers to use externally."

**An abstraction must justify its existence.** Count what it buys:

> "Do we actually need `bindAt`? As far as I can tell `storedPath` is read in one place. Everything else, the abstract method, the three implementations and the constructor parameter on four classes, is there to get that one label to that one call."

Also: "I don't really get this implementation. If there isn't really a benefit to it then let's drop it. It's extra complexity for no reason." The readability bar is the reader's, not the author's: "Your implementation of Draft is impossible to understand. I don't get the purpose and neither will any reader."

## The failure modes this skill prevents

**Reviewing at the wrong altitude.**

> "Your simplifications are good but they are still very targeted towards small individual changes."

> "For this MR I am more interested in the methodology and architecture."

**Burying one to three real points under small ones.**

> "Sometimes you've reviewed an MR and come back with 10 changes where maybe only 2 or 3 were actually important. It's confusing when you list 10 items and 7 of them are tiny details that I'm not gonna bother adding to my review as they will be impacted by larger architectural changes anyway."

The clarification, since it is easy to read as a limit on findings:

> "It shouldn't be a hard cap. My point was not that 3 is the max but rather that you sometimes have 1-3 really good points and then 7 nit pick comments. In those cases I don't care about the small details as they will mean nothing compared to larger rewrites/decisions anyway. They can come later when the big picture has been finished and settled on."

The filter is dependency and timing, not count. Every substantive finding is reported; small details wait until the larger decisions settle.

**Agreeing to be agreeable.**

> "Do not agree with me just because I ask the question - I want an honest architecture discussion where we ultimately aim to land at the lowest required complexity to have a working solution."

On pushback about size or complexity, measure and question your own proposal first; never reframe the number instead of answering it.

## Scope discipline

Out-of-scope improvements are filed, never smuggled into the MR under review:

> "That sounds like a good improvement but one that is outside the scope of what we are doing now. Let's write our current implementation with this in mind as a potential future addition. Create a ticket for it with low priority in this epic with information around the benefits of it and reasoning behind adding it."

Known limitations can be accepted with a stated horizon: "This is OK and is something we can accept for now. We should fix the issue at a later date but it will still be a long time before any apps start using Hotpot so we have time." A finding that an accepted limitation exists is worth raising only if the horizon has changed.

Deferring to a later MR in the same series is a legitimate resolution; check whether the next MR already cleans something up before raising it.

## Costing a rewrite proposal, both directions

Numbers make a restructuring proposal reviewable:

> "I want to understand the actual lines of code difference between the two implementations and I want a very specific example that I can share in the comment."

> "Both in terms of complexity reduction (abstractions we remove and total LOC with or without your change) and are there any edge cases/bugs we might not cover with this implementation or do we actually cover more?"

The accounting runs both ways: what the change removes and what it adds. Never only the savings.

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

Defects are reported and kept separate from the architecture discussion:

> "Separately, and I want to keep this distinct because it's a bug rather than a style preference: I don't think we handle removals."

The standard: a concrete failure path with the inputs and the wrong outcome, and whether it is deterministic:

> "If person B removes field X from a row and it syncs to person A, A's next write to any other field in that same row packs the row from A's store, X included, and puts X right back into the Hotpot. That's deterministic, not a race."

## Comments and documentation

Consumer-facing docs describe the public surface and how to use it. Comments explain the concept a reader needs and carry nothing that exists only in the authoring conversation. A class-level concept comment goes on the class, not at the top of the file. Lead an MR description with the plain framing of what was built and why; it is the first thing a reviewer reads.
