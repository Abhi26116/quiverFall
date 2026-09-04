# ADR 0056 — Mother of Motes: the fourth pure-spawner boss, one mechanic across three phases

**Phase** 11
**Date** 2026-09-04
**Status** Resolved. Mother of Motes (docs/06 §6.3, Endless Descent boss
#19) is fully built — the first Endless-tier boss in the roster.
**Severity** Low-medium. The first boss built this session with no
per-phase mechanical breakdown in the GDD at all — a genuinely different
shape of gap from every campaign boss, where docs/06 always names three
distinct things.

---

## What was missing

docs/06 §6.3, Mother of Motes: "×70 HP. Spawns 200+ Motes over the
fight. Pure crowd-clear check and the game's designated 'look how strong
I've become' power fantasy — the fight exists so that a maxed build
feels absurd, on purpose." One paragraph, no P1/P2/P3 breakdown — unlike
every campaign boss, and unlike Ashen Choir's own Elite remix, which at
least named per-phase differences.

## Decision — one mechanic, escalating rate across the generic three phases

`BossPhaseSystem`'s own three-phase machinery applies to every boss
regardless of what its own card says (`bosses.json` already carries the
standard `[0.66, 0.33]` thresholds for this entry) — so rather than
inventing three distinct mechanics docs/06 never describes, the phases
are read as the *same* spawn cycle intensifying as the fight wears on:
P1 spawns a Mote every 0.8s, P2 every 0.4s, P3 every 0.2s. "Look how
strong I've become" reads naturally as the swarm visibly thickening
toward the end of the fight, not as three qualitatively different
attacks.

**No new sim primitive at all — the fourth pure-spawner boss in this
roster.** The cycle is the Rift Maw's own (`RiftbornTree._riftMaw`),
verbatim: `EnemySpawner.spawn`/`EnemyStore.liveAdds`/`EnemySpawner.
atEnemyCap`/`EnemySpawner.ringPoint`, the identical machinery Arclight's
Swarmlings, the Green Mother's Knitters, and the Weeping Gate's own
roster already use (ADR 0027/0028/0030) — spawning nothing but Motes,
docs/05's own first-introduced, plainest archetype, which is "pure
crowd-clear" read as literally as possible: no elemental gimmick, no
status effect, no line hazard, just volume. The body itself deals no
direct damage, the same "P1 has no attack at all" shape Skarn's, the
Weeping Gate's, and the Green Mother's own spawn-only phases already
established (ADR 0022/0028/0030).

## "200+ Motes over the fight" is a lifetime count, not a cap

`liveAdds` already tracks the *simultaneous* on-screen count, capped at
16 like every other spawner boss — but the card's own "200+" is
describing the fight's *total volume*, a number that keeps climbing
regardless of how many are alive at once. `comboStep` (free — nothing
else in this system touches it) tallies every Mote ever summoned,
unbounded. Nothing mechanical keys off reaching 200 specifically —
docs/06 states no on-screen behaviour change at that count, only that
the fight's own scale reaches it — so this pass does not gate or check
for the threshold itself, only tallies toward it. Verified directly: a
test kills every Mote the instant it spawns (holding the simultaneous
count at zero, so the 16-cap can never gate anything) and confirms the
lifetime total still climbs well past 16 over enough ticks — proving the
two counters are genuinely independent, not the same number read twice.

## What's authored, not GDD-stated

The exact escalation rate (0.8s → 0.4s → 0.2s) has no anchor in docs/06,
and unlike a campaign boss, Endless bosses carry no stated fight length
to size a rate against at all (`targetDurationSeconds` is nullable for
this whole tier, ADR 0017's own flagged gap) — real tuning is a Phase 14
balance-harness question, the same honesty every other authored,
unverified cadence in this roster already carries.

## Consequences

The Endless Descent tier (docs/06 #17-20) now has its first real fight.
Mother of Motes was deliberately picked first among the four: the other
three each need a genuinely new capability this pass does not attempt —
The Loom (#17) needs player Windlines to interact with and cut a
separate, hazard-owned line structure; Coilspine (#18) needs a
24-segment chain-following body with per-segment destruction changing
its own movement; The Last Warden (#20) needs, across five phases, an
AI that reads and applies the player's own live Boon set, a terrain
system where the floor is removed and the player's own fired arrows
become solid platforms, and telemetry-driven boss-echo summons — by far
the largest remaining scope in the whole boss roster. Mother of Motes
needed none of that, the same "check whether an existing primitive
already covers this before inventing one" discipline that has closed
most of this roster's own gaps so far.
