# ADR 0004 — docs/09 §9.1 contradicts itself, twice

**Phase** 9
**Date** 2026-07-20
**Status** Resolved. Both conflicts decided in favour of the precise half.
**Severity** Low mechanically, high for trust in the spec.

---

## What was found

Building the Boon draw against docs/09 turned up two places where §9.1
disagrees with itself. Neither is dangerous; both would have been silently
"resolved" by whichever half I happened to implement first, which is the
problem.

### 1. The rarity counts do not match the catalogue

§9.1's header table states a count per rarity. §9.2's catalogue authors 112
individual cards, each with its own rarity. They disagree:

| Rarity | §9.1 header | §9.2 catalogue |
|---|---|---|
| Common | 46 | **36** |
| Rare | 34 | **36** |
| Epic | 20 | **25** |
| Legendary | 9 | **10** |
| Mythic | 3 | **5** |
| **Total** | **112** | **112** |

Both sum to 112, which is why it survived review: the number everyone checks is
correct.

### 2. The depth-scaling prose does not match the depth-scaling formula

§9.1 gives an exact formula:

```
w_rare      = 0.27 + 0.018·(r−1)
w_epic      = 0.11 + 0.014·(r−1)
w_legendary = 0.035 + 0.006·(r−1)
w_mythic    = 0.005 + 0.0015·(r−1)
w_common    = 1 − (the above)
```

Four lines below it, the prose says: *"At room 1 the draw is 58 % Common; by
room 9 it is ~35 % Common and ~19 % Epic."*

Room 1 checks out. Room 9 does not:

| Room | Common | Epic |
|---|---|---|
| 1 | 58.0 % | 11.0 % |
| **7** | **34.3 %** | **19.4 %** |
| **9** | **26.4 %** | **22.2 %** |

The prose's "room 9" figures are what the formula produces at **room 7**.

## Decision

**The catalogue wins for counts. The formula wins for weights.** In both cases
the specific, mechanical half beats the summarising half.

For counts, this is nearly free: **rarity is rolled first and the card second**,
so the weights describe how often a player *sees* an Epic regardless of how many
Epics exist. The count column is informational. Implementing it as authored
would have meant either inventing ten Commons or demoting nine cards, both of
which change real content to satisfy a summary line.

For weights, the formula is what an implementation can be held to, and the
steeper escalation it produces is what the sentence immediately after the prose
actually asks for — *"Runs therefore escalate — the build gets loud near the
end, which is where the power fantasy belongs."* 26.4 % Common at room 9 is a
louder ending than 35 %.

`test/game/boon_pool_test.dart` asserts the formula's values at rooms 1 and 9,
and carries a **separate, explicitly-named test** pinning room 7 to the prose's
numbers. If someone later decides the prose was the intent and the coefficients
are too steep, that test tells them exactly which room the prose was describing
instead of leaving them to re-derive it.

## Consequences

- `docs/09` should be corrected rather than left as the authority on two things
  it gets wrong. Until it is, `assets/data/boons.json` carries a comment
  pointing here, and so does the pool test.
- The count column being wrong has one real effect worth naming: with 36
  Commons rather than 46, **Commons repeat sooner within a run**. A player
  taking mostly Commons will hit max copies on their favourites a little
  earlier than the document implies. That is a tuning observation for the
  Phase 12 harness, not a bug.
- Five Mythics rather than three means the 0.5 % Mythic weight is spread over
  five cards, so any *particular* Mythic is rarer than the document suggests.
  *Perpetual* (#58) is the card this matters most for — docs/09 §9.2 C calls it
  "the single most powerful card in the game", and it is now a ~0.1 % roll at
  room 1 rather than ~0.17 %.

## What this says about the rest of the spec

This is the second time a GDD section has turned out to be internally
inconsistent in a way only implementation surfaced — ADR 0002 was the first, and
it was much more expensive. Both were found by writing something precise enough
to disagree with. **The tests are the place these disagreements get recorded**,
because a test that cites the document and the room number survives longer than
a note in a commit message.
