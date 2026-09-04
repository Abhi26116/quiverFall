# ADR 0044 — The Quiverfall's own P2: "The Choir Reforms" as a small vocabulary of echoes

**Phase** 11
**Date** 2026-09-04
**Status** Resolved for P2. P3 ("Quiverfall" — 40 fragments, Confluence-
gated invulnerability) is not built — a known, flagged gap; see ADR 0032.
**Severity** High. The last remaining P2 gap across all twelve campaign
bosses, and the one ADR 0032 flagged as needing "a real 'echo' primitive
this pass does not attempt to generalise from eleven bespoke, already-
built systems." This ADR is that generalisation.

---

## What was missing

docs/06 §12, The Quiverfall (chapter 12, campaign finale): P1 (ADR 0032,
this session) already resolved the converging spoke sweep. P2 — "The
Choir Reforms": "All eleven previous bosses appear as 12s echoes, one at a
time, using a single signature attack each. A greatest-hits phase that
only lands emotionally because the player fought all of them." As of this
session's own sweep through the P2 backlog (Skarn through Hollow Warden,
ADRs 0034–0043), every one of those eleven prior bosses now has a real,
built signature attack for the first time — the precondition ADR 0032
named for this piece to even be attemptable.

## Decision — a small vocabulary, not eleven literal call-throughs

The tempting reading was to literally invoke each of the eleven other
systems' own private tick methods against this boss's own primary slot,
letting it "become" each boss in turn. Reading those methods closely
(the same survey this ADR's own research pass did across all eleven
files) ruled that out: several are entangled with bespoke child entities
that only exist because that boss's own `spawn()` placed them (Cinder
Choir's three effigies, Silversong's pillars, Thrall's nine sigils,
Green Mother's root anchors) — reusing them for a twelfth boss would mean
spawning and despawning a fresh batch of children every 12 seconds, a
real new source of the exact room-clear and telegraph-ownership bugs this
session already found and fixed twice this phase (ADR 0032's own spoke
anchors, ADR 0036's pillars).

Instead, "a single signature attack" is read as one of the small
vocabulary of telegraphed shapes this game's own `EnemyAttack` already
provides — a rotating multi-line sweep, a circle slam, a cone, a line/
beam, a bolt, a portal spawn — with each boss's own echo picking whichever
member of that vocabulary its own actual mechanic is closest to, and
**reusing that boss's own already-established numbers** (damage, radius,
angle, timing) rather than inventing new ones. Three generic, parametrised
tick methods (`_tickCircleSlamEcho`, `_tickConeEcho`, `_tickLineEcho`)
cover eight of the eleven; two bespoke methods (`_tickHollowWardenEcho`,
reusing `EnemyAttack.fireBolt` directly; `_tickWeepingGateEcho`, reusing
`EnemySpawner.spawn`) cover the two whose own signature isn't a
telegraph-then-hit shape at all; and the very first echo reuses `_tickSweep`
— this boss's own P1 method — verbatim, since Chapter 1's own signature
move is mechanically identical to what this finale's own P1 already is
(ADR 0032's own point, now closing a full circle).

## The boss-by-boss mapping

| # | Boss | Shape | Numbers (source) |
|---|------|-------|-------------------|
| 0 | Cinder Choir | sweep (`_tickSweep`, literally reused) | this boss's own P1 |
| 1 | Gaunt | circle slam | windUp 1.8s, radius 5.0, damage 0.09×2.10, cooldown 2.0s (ADR 0035) |
| 2 | Silversong | cone → `applyDrawLock`, not damage | windUp 0.6s, cooldown 2.5s, lock 2.5s (Silversong's own P1) |
| 3 | Hollow Warden | bolt (`fireBolt` directly) | speed 8.0, range 14.0, damage 0.06×2.10 (ADR 0031) |
| 4 | Vermillion | line → damage | windUp 0.6s, length 6.0, damage 0.09×2.10, cooldown 3.0s (ADR 0037) |
| 5 | Rimefather | cone → damage | windUp 0.6s, cooldown 1.5s, damage 0.09 (Rimefather's own P1) |
| 6 | Arclight | line → damage | windUp 0.6s, cooldown 0.6s, damage 0.09 (Arclight's own P1) |
| 7 | Green Mother | line → real Toxin, ticked every tick | windUp 0.6s, length 5.0, cooldown 3.0s (ADR 0040) |
| 8 | Thrall of the Nine | cone → damage | windUp 0.6s, cooldown 1.0s, damage 0.09 (ADR 0029) |
| 9 | The Weeping Gate | portal (`EnemySpawner.spawn` directly) | windUp 0.5s, interval 4.0s, the same 4 Riftborn ids (ADR 0042) |
| 10 | Skarn the Unmade | circle slam | windUp 1.8s, radius 3.0, damage 0.09×2.10, cooldown 2.0s (ADR 0034) |

Two of the eleven turned out to be genuinely *not* raw-damage attacks —
Silversong's own cone Draw-locks, and the Green Mother's own root applies
a real, independently-ticking Toxin stack rather than an instant hit —
and both are echoed faithfully rather than flattened to "just deal
damage," which is what makes the greatest-hits read as a real replay
rather than eleven reskins of one hit.

## Field reuse, and the free seamless transition

Every echo shares the primary's own `state`/`stateTimer`/`attackCooldown`
— the same fields P1's own sweep leaves untouched (it only uses
`bossSweepAngle`/`attackCooldown`) — reset via a new `_clearCurrentAttack`
whenever the active echo changes. `comboStep` (free — nothing in P1 reads
it) holds the current echo index; `bossTimer` (also free — P1's own sweep
never uses it) holds elapsed time in the current 12s window. The eight
spoke-anchor children P1 already spawns are reused as-is for echo 0's own
sweep — no entity is spawned or despawned per echo.

Because `comboStep` and `bossTimer` both default to zero and P1 never
touches either, the P1→P2 transition has **no visible seam**: the boss is
already mid-sweep (echo 0) when `bossPhase` reaches 1, and simply keeps
going. This was not deliberately engineered so much as discovered while
tracing the field reuse — a genuinely pleasant accident this ADR is happy
to take credit for anyway.

## What's deliberately simplified

- **No echo physically moves or grows extra bodies.** The primary's own
  position never changes; every echo's shape is centred on (or aimed
  from) wherever the boss already stands. Vermillion's own echo does not
  physically charge across the room the way the real Vermillion does —
  the line itself carries the threat, matching every other echo staying
  anchored.
- **Hollow Warden's own echo skips the Draw ramp entirely** — replicating
  a second live `DrawState` for a 12-second cameo was judged not worth
  it; a flat, authored wind-up/cooldown stands in for what the real boss
  earns by standing still.
- **The 25°/5.0u cone and the generic line width are shared constants**
  across every cone/line echo, since Silversong's, Rimefather's, and
  Thrall's own P1 cones already happen to agree on that exact shape, and
  Vermillion's/Arclight's/the Green Mother's own P1 lines are close
  enough in spirit that reusing one width (`SimConfig.windlineHitWidth`,
  the same generic Windline-hazard width every boss already shares) reads
  as consistent rather than arbitrary.

None of this changes P1's own already-shipped behaviour; every number
above is either read directly from the cited ADR/system or an authored,
flagged stand-in for something this pass judged not worth replicating in
full for a 12-second cameo.

## Verified per-echo, not just structurally

Nineteen tests, one group per phase: the pre-existing P1 group is
untouched; a new "P2" group covers the seamless transition, the 12s
rotation itself (`comboStep` advancing after exactly 720 ticks at the
fixed step), and one targeted test per echo — Gaunt's and Vermillion's
own echoes both landing the exact derived-heavy-hit health (81.1, from
0.09×2.10), Silversong's own echo confirmed to Draw-lock with *zero*
health loss, the Green Mother's own echo confirmed to apply a real,
independently-ticking `toxinStacks` entry rather than an instant hit, the
Weeping Gate's own echo confirmed to actually spawn a tracked add, and a
dedicated test placing the player at 4u specifically to tell Gaunt's own
5.0-radius echo and Skarn's own 3.0-radius echo apart by whether the same
hit lands at all. All nineteen passed on the first real run once one
arithmetic slip in a test's own expected value (0.09×2.10 is 18.9%, not
21%) was caught and fixed.

## Consequences

**All twelve campaign bosses now have P1+P2 built.** Phase 11's own
remaining scope is P3 work across the roster (this boss's own P3, the
only fight requiring Confluence, chief among them — it now has every
other boss's own signature move sitting right next to it as reference for
"a mechanic genuinely different from any timer or live-count this session
has built a boss's defence from before"), the Elite/Event tier (#13-16,
of which only Ashen Choir exists and only as an unintegrated remix), and
the three remaining Endless/Warden bosses (#17-19, The Last Warden).
