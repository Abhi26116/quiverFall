# ADR 0069 — Halden's own boss half, unblocked by Phase 11's completion

**Phase** 10 (hero behaviours), unblocked by Phase 11
**Date** 2026-09-05
**Status** Resolved. Halden is the fifth hero (after Sable, Kade, Corvin,
Lira) with nothing deferred in `pendingHeroBehaviourWork`.
**Severity** Medium. The first ledger entry Phase 11's own completion
directly unblocked, exactly as its own comment predicted.

---

## What was missing

docs/07 §7.3, Halden, *the Judgement*: **"Passive — Verdict: +40 % damage
to bosses and elites. Boss attacks deal −15 % to Halden."** Four talents
build on the boss half specifically: *Zealot* (T1a, "boss damage bonus
rises to +55 %"), *Warded* (T1b, "boss damage taken reduction rises to
−28 %"), *Sentence* (T3a, "Ultimate marks the boss: +20 % damage taken
10 s"), *Swift Judgment* (T3b, "Ultimate charges 40 % faster on bosses").
Every one of these was blocked before now: `EnemyStore` had no `isBoss`
check, only `isElite`, since Phase 11 (bosses) had not built any yet.

## Decision — the blocker named in the ledger's own comment is gone

`pendingHeroBehaviourWork`'s own entry for these four named the exact
condition that would unblock them: *"needs an `isBoss` check `EnemyStore`
does not have before Phase 11."* `EnemyStore.isBoss` (`bossIndex >= 0`)
has existed since Phase 11's own first commit (ADR 0017) and Phase 11's
own boss roster is now complete (ADRs 0059-0068) — the condition is met,
so this ledger entry was the first one Phase 11's completion directly
unblocked, not a coincidence of picking hero work at random.

**Verdict's own offensive half** extends the existing elite check with an
independent boss check in the same `boonSum` composition
(`ProjectileSystem._applyHit`) — both can be true at once in principle,
though no entity in this roster is ever both. *Zealot* replaces only the
boss number (40 % → 55 %); the elite number is untouched, matching the
card's own wording exactly.

**Verdict's own defensive half — "boss attacks deal −15 % to Halden" —
had never been built at all, elite or boss**, since the card names only
bosses for this clause. `DamageResolver.applyDamageReduction2`'s own
second parameter existed for exactly this shape (a second, independent
reduction source composed multiplicatively with Momentum's) and had a
single call site passing a hardcoded `0` — unused infrastructure, the
same "already built, waiting for a second caller" pattern this session
keeps finding (`Curves.endlessHp`, `EnemyStore.adaptTo`). *Warded* raises
15 % to 28 % at that same call site.

**Sentence** needed the one genuinely new piece: knowing *which* landed
hit is the Judgment Spear's own, since the Ultimate fires as an ordinary
arrow through the same collision path as any other shot. `ProjectileStore
.willMarkBoss` — set at release, the identical "decided once at the bow"
shape `willChain`/`willBleed` already use — answers it without touching
target-selection logic at all. The mark itself reuses `EnemyStore.
markedRemaining`, the same field Vane's own *Marked* already drives; the
two triggers (a shot from beyond 8 u; a landed Judgment Spear) never
coexist, since only one hero is ever equipped, so the bonus amount is
read hero-conditionally at the one place both already share.

**Swift Judgment** scales the damage fed into `HeroRuntime.
chargeFromDamage` by 1.40 for a boss hit — composing correctly with
armour, pierce falloff, and every other term already folded into the
value that function receives, rather than adding charge directly and
risking double-counting.

## A real test-writing lesson, not a sim bug

Every failure caught while writing this pass was in the test itself, not
the implementation:

- Setting `bossIndex` on an ordinary enemy to fake "this is a boss" needs
  a *real* boss catalogue behind it — every boss system's own per-tick
  scan unconditionally indexes `content.bosses.all[bossIndex]` before
  checking archetype, so doing this against `hero_behaviour_test.dart`'s
  own boss-less `content` crashed the very next tick. Fixed with a
  second, boss-aware `ContentLibrary` used only by these tests, and by
  choosing Umbral Twin's own catalogue index specifically — its own
  system (ADR 0066) is a confirmed no-op, so nothing else reacts to the
  mote suddenly looking like a boss's own primary.
- `Curves.heroStat` scales with `stars`, so comparing a star-0 "common"
  baseline against a star-1 "boss" measurement (to reach a T1 talent)
  silently mixed a stat-growth difference into what was meant to isolate
  Zealot's own bonus. Fixed by levelling the baseline to the identical
  star count with no talent chosen.
- The Judgment Spear's own multi-thousand-percent share overkilled the
  arena's own 1000-HP mote outright, and reading `markedRemaining` off a
  slot that had just been reset read 0 regardless of whether the mark
  had actually been set. Fixed with a real boss-sized health pool.
- Firing an ordinary "before" hit via `autoFire`, then switching it off
  to fire the Ultimate, could leave an earlier ordinary arrow still
  in flight — `firstDamageDealt`'s own "whichever hit lands first" scan
  then had no way to know if it had caught the Spear's own hit or a
  straggler. Split into two tests instead: one firing only the Ultimate
  (no ambiguity about which arrow is in flight), one setting the mark
  directly to measure what it is worth, without the Spear's own travel
  in between.

## Verified end to end

Nine new tests: Verdict's own +40 % boss bonus; Zealot raising it to
+55 % while leaving the elite bonus alone; Verdict's own −15 % damage
taken from a boss attack, raised to −28 % by Warded, and confirmed absent
against a common enemy's attack; Sentence marking a struck boss for 10 s;
that mark's own +20 % stacking additively on Verdict's +40 %; Sentence
never marking a non-boss target; and Swift Judgment's 40 % faster charge
from a boss hit. All nine passed once the four test-construction issues
above were found and fixed — none were sim bugs.

## Consequences

`pendingHeroBehaviourWork` drops from 44 to 40. Halden joins Sable, Kade,
Corvin, and Lira as heroes with nothing deferred. The remaining 40 entries
are unaffected by this pass; several (Zea's Skyhawk/Falconry, Mirelle's
Hall of Mirrors) are blocked on a companion-entity primitive nothing in
the sim has built yet, the next natural candidate for a "does Phase N's
own completion unblock this" check the way Phase 11 just did here.
