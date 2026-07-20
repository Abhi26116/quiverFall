# QUIVERFALL — Game Design Document

**Version** 1.0 (pre-production)
**Date** 2026-07-19
**Status** Awaiting approval. No implementation code exists yet.
**Working title** Quiverfall (placeholder — rename is a one-line change until Phase 0 ships)

---

## What this is

A production Game Design Document for an original action-roguelike archer game built in
Flutter + Flame, targeting Google Play and the App Store.

The design references the *structural* lessons of Archero (room-clear roguelite loop),
Survivor.io (build-craft escalation), and Supercell's live-ops discipline — but the core
combat mechanic, economy, cast, and art direction are original.

## Reading order

| # | Document | Covers |
|---|---|---|
| 01 | [Game Vision](01-vision.md) | Loop, audience, USP, competitive analysis, retention thesis |
| 02 | [Economy Design](02-economy.md) | All currencies, costs, reward tables, inflation control |
| 03 | [Player Progression](03-progression.md) | First 30 min / day / week / long-term, D1–D30 |
| 04 | [Upgrade Systems](04-upgrades.md) | The Spire, heroes, arrows, research, Ascension |
| 05 | [Enemy Design](05-enemies.md) | 26 enemy types, full stat and AI spec |
| 06 | [Boss Design](06-bosses.md) | 20 bosses, phases, mechanics, scaling |
| 07 | [Hero Design](07-heroes.md) | 20 heroes, passives, ultimates, trees |
| 08 | [Arrow System](08-arrows.md) | 12 arrow types, damage formula, crafting |
| 09 | [Skill System](09-skills.md) | 112 run Boons, rarity, synergy, balance |
| 10 | [UI / UX](10-ui-ux.md) | Every screen, layout, states |
| 11 | [Screen Flow](11-screen-flow.md) | Navigation graph, routing contract |
| 12 | [Technical Architecture](12-architecture.md) | Folders, DI, game loop, state, pooling |
| 13 | [Database Structure](13-database.md) | All models, local + cloud schema |
| 14 | [Level Design System](14-level-design.md) | Handcrafted + procedural, difficulty curve |
| 15 | [Art Direction](15-art-direction.md) | Full asset manifest |
| 16 | [Audio Direction](16-audio-direction.md) | Music, SFX, mix bus |
| 17 | [Monetization](17-monetization.md) | Ads, IAP, bundles, subscription |
| 18 | [Analytics](18-analytics.md) | Every event, params, funnels |
| 19 | [Performance](19-performance.md) | 60 FPS budget, low-end Android |
| 20 | [Roadmap](20-roadmap.md) | 18 implementation phases |

## The one-paragraph pitch

You are a Warden of the last standing Spire, and the sky is falling in shards. Each run is a
descent through collapsing arenas: you move to survive, you root to escalate. Standing still
winds your bow through three **Draw** tiers, each shot heavier than the last. Every arrow you
fire leaves a glowing **Windline** hanging in the air for a second — and threading a new arrow
through your own trail causes **Confluence**, merging the shots into something bigger. Master
archers don't just dodge; they weave a lattice and fire through it. Between rooms you take one
of three **Boons**, building a different archer every run. Between runs you carry gold back to
the Spire and make the *next* Warden permanently stronger.

## Design laws

These are the non-negotiable invariants every later balance change must respect.

1. **TTK Law.** A common enemy dies in 0.8–1.6 s at every point in the game, for a
   correctly-progressed player. All power and HP curves are derived from this band.
2. **No paywall, only pace.** Anything purchasable with money is also reachable with time.
   Money buys ~3–4× velocity, never exclusive power.
3. **Skill ceiling above spend ceiling.** A free player who threads Confluence reliably
   out-damages a paying player who does not.
4. **Every screen is two taps from play.** Meta depth must never bury the run button.
5. **60 FPS on a 2019 budget Android.** A feature that cannot hold frame does not ship.
6. **No dark patterns.** No fake timers, no bait interstitials mid-run, no loot box for
   direct combat power, no countdown that lies.
