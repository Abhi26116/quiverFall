# ADR 0005 — docs/07's hero unlock costs are inconsistently specified

**Phase** 10
**Date** 2026-07-21
**Status** Resolved. Missing numbers filled from docs/04's stated default; ambiguous wording read literally.
**Severity** Low. Cosmetic/economy numbers, not mechanics.

---

## What was found

Authoring `heroes.json` against docs/07-heroes.md's twenty per-hero unlock lines
surfaced two kinds of gap, neither large on its own, both worth recording so a
future pass over the real numbers starts from a documented list rather than
rediscovering the same nine heroes.

### 1. Three heroes name a shard cost with no number

| Hero | docs/07's exact line |
|---|---|
| Sela | "chapter 4 chest shards" |
| Halden | "Weeping Gate shards" |
| Ashlin | "Ashen Choir shards" |

Every other shard-unlocked hero states a figure — "40 shards (Astral chests)"
for Nyx, "40 shards" for Iris and Rook, and so on. These three do not.

docs/04-upgrades.md §4.3 states the number generally: *"40 to unlock, then
30 / 80 / 180 / 400 / 900."* — the same 40 every other shard-unlocked hero in
docs/07 uses. `heroes.json` uses **40** for these three, sourced from §4.3
rather than invented, with a `note` field on each recording that the per-hero
line omitted it.

### 2. "Chapter N" without "shards" is ambiguous between two unlock shapes

Nine heroes' unlock lines take one of these forms:

- Explicit chapter-clear language: Bram "clear chapter 2", Kestrel "clear
  chapter 3", Ovrin "clear chapter 2 (shards from Gaunt)".
- Bare chapter numbers with no verb: Torv "chapter 7", Sable "chapter 8", Lira
  "chapter 6", Vane "chapter 9", Thane "chapter 10".
- "Chest" with no "shards": Corvin "chapter 5 chest".

The bare and chest forms could plausibly mean either "clear this chapter and
the hero unlocks" (matching Bram/Kestrel) or "this hero's shards start
dropping from this chapter" (matching the explicitly shard-based heroes one
tier up). Both readings appear in docs/07 for heroes of the same rarity, so
neither is the obvious default.

## Decision

**Read literally: no word "shards" means no shard cost.** All nine are encoded
as `chapterClear` grants, matching Bram and Kestrel's unambiguous phrasing
exactly. This is the reading that requires the least inference — it takes each
line at what it says rather than assuming an unstated mechanic — and it keeps
every Rare hero's unlock shape internally consistent within its own doc
section rather than mixing two systems inside §7.2 with no stated rule for
which hero gets which.

Ovrin's parenthetical, "(shards from Gaunt)", is kept as descriptive `note`
text rather than folded into the unlock cost — it describes where his
*post-unlock* star-up shards come from, a separate fact from how he is
unlocked in the first place, and `HeroUnlock` now has a `note` field for
exactly this shape of detail.

## Consequences

- If actual game balance intends Torv/Sable/Lira/Vane/Thane/Corvin to be
  shard-gated like the Epic tier, `heroes.json`'s five `note` fields and this
  ADR are the list of exactly which six entries to revisit — the interpretation
  is recorded, not silently baked in.
- None of this affects anything mechanical. Unlock cost has no bearing on a
  hero's stats, passive, ultimate, or talents — Phase 12's balance harness does
  not touch it, and nothing in the simulation reads `HeroUnlock` at all.
