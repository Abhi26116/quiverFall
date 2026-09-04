# ADR 0019 — Cinder Choir P2: the tether sweep is spokes, not edges

**Phase** 11
**Date** 2026-09-04
**Status** Resolved.
**Severity** Medium. One real geometric interpretation call, plus four
reused-not-invented numbers — none anchored in docs/06 itself.

---

## What was missing

docs/06 §1 P2: "Tethers become damaging crimson lines that sweep the arena at
45°/s." The three effigies are fixed in place (ADR 0018 built no reason for
them to move), so "the tethers" — read literally as the triangle's own three
edges, each connecting two adjacent, stationary effigies — would barely sweep
anything: each edge is a short (~2.2 u) segment rotating in place around the
triangle's own small footprint, nowhere close to "the arena."

## Decision — three spokes, not three edges

**The tether lines are represented as three spokes radiating from the
primary's own position** (the triangle's centre), one per effigy, each at
that effigy's own base angle plus a shared, continuously-advancing sweep
angle — not as the three edges directly connecting the (still fixed)
effigies. "Sweep the arena" reads as broad coverage; detaching the lines
from their triangle-sized anchor points is what actually delivers that,
and it costs nothing mechanically since the plate/rotation puzzle (ADR
0018) never depended on the tethers being literal edges — "joined by
burning tethers" is establishing shot flavour, not a geometry contract.

Built on `EnemyAttack.playerOnLine`/`beginLine` — already the exact
primitive the Lancer's charge and every other line-shaped attack in the
roster uses. No new hit-test or telegraph shape was needed, only a system
that recomputes three endpoints every tick and asks the existing machinery
about them, the same way `_thresher`'s aura recomputes and asks about a
circle every tick.

**Each spoke's telegraph is tracked on its own effigy's own
`telegraphSlot`/`telegraphSerial`** — fields every ordinary enemy already
carries one of, here repurposed as "which of my three children owns which
spoke" rather than adding three new parallel arrays.

## Four numbers, none in docs/06, all reused from an existing anchor

Consistent with this session's own established preference (ADR 0008, ADR
0018) — reuse an existing number before inventing a new one:

| What | Value | Reused from |
|---|---|---|
| Spoke width | `SimConfig.windlineHitWidth` (0.14 u) | ADR 0008 — Kade's Pyre Line had the identical "no stated width" gap |
| Spoke length | 9.0 u (authored) | Sized against `SimWorld`'s own default 16x9 arena — no boss arena exists yet (ADR 0017) |
| Damage per hit | 9% max HP | The Thresher (docs/05) — "a permanent aura," the closest existing analogue to a continuous rotating lethal zone |
| Hit cooldown | 0.6 s | The Thresher's own `attackCooldown` |
| Warning window before it turns lethal | 0.6 s | Reuses the cooldown's own magnitude rather than inventing a third number |

The warning window is the one addition with no existing line-hazard
precedent to reuse, because no other line hazard in the roster *begins* at
a specific moment the player must react to — the Lancer telegraphs its own
individual charge every time; the Thresher's aura has existed, visibly,
since the enemy spawned. Cinder Choir's sweep does neither: it switches on,
once, mid-fight, at the P1→P2 transition. docs/06 rule 2 — "every attack is
telegraphed in amber before it exists... no boss ever damages the player
with something they could not have seen" — is the single most repeated
rule in the whole document, so this got its own (short) warning rather than
skipping straight to lethal on the Thresher's own exemption, which does not
actually apply here.

**Implementation note on that transition:** a live telegraph's severity has
no in-place setter (`TelegraphStore.add` sets it once); the system detects
the warning→lethal moment by comparing the desired severity against
`TelegraphStore.severityAt` each tick and calls `beginLine` again exactly
when they diverge — `_begin` already ends whatever was there first, so this
needed no new store method.

## What's deliberately not built here

**P3's own attacks are still not built** (ADR 0018's own gap, unchanged).
Entering P3 now explicitly clears any live tether telegraph rather than
leaving a frozen line on screen — a correctness fix this pass added since P2
now has something live to leave behind, not a new deferred gap.

**The sweep does not yet respect Draw-lock, freeze, or any other player
status that might make "step out of the way" harder or easier** — it reads
`ctx.playerX/Y` directly, the same as every other `EnemyAttack.playerOnLine`
caller, so this is existing behaviour, not a new gap, but worth naming since
a boss fight is the first place in the game several such statuses might
overlap at once.

## Consequences

Skarn, Coilspine, Thrall and Cinder Choir's own P3 will each want their own
answer to "what does a sweeping/rotating attack look like when several
bodies are involved" — this ADR's spokes-from-a-shared-centre answer is one
option, not a prescription; a boss whose bodies genuinely move (Coilspine's
segments) will need geometry that follows them instead of a fixed anchor.
