# 17 — Monetization Design

## 17.0 The thesis

**Fairness is the product.** In a category defined by energy walls and mid-run interstitials, an
honest economy is a positioning wedge, not just an ethical stance. Players who believe the game
is fair subscribe to *support pace*; players who feel extorted churn and leave one-star reviews
naming the exact moment.

Four commitments, stated in the store listing and honoured in code:

1. **No mid-run ads.** Ever. Structurally enforced ([12 §12.9](12-architecture.md)).
2. **No progression paywall.** Uncleared stages always cost 0 Vigor ([02 §2.2](02-economy.md)).
3. **No loot box for combat power.** Chests contain heroes (sidegrades), materials, gold, and
   cosmetics — never direct damage upgrades.
4. **Two currencies cannot be bought at any price** — Insight and Emberdust, the spine of
   long-term progression.

**Targets:** conversion 3.5–5 %, ARPPU $14–18/month, ARPDAU $0.09–0.13, ads ~35 % of revenue,
IAP ~65 %.

## 17.1 Rewarded ads

All opt-in, all clearly labelled, all delivering the reward before the ad UI dismisses.

| Placement | Reward | Cap/day | Where |
|---|---|---|---|
| Double Haul | ×2 gold + materials | 5 | Victory screen, secondary button |
| Vigor refill | Full bar | 1 | Vigor tap, Level Select |
| Iron Chest | 1 chest | 3 | Shop → Daily |
| Boon reroll | 1 reroll | 2 | **Between rooms only** |
| Revive | Full-HP continue | 1 | Defeat screen |
| Shop gem drop | 15 gems | 1 | Shop → Daily |
| Offline haul doubler | ×2 idle gold | 1 | Menu, on return |

**16 ads/day maximum, ≈ 190 gems of daily value.** At a $12 eCPM that is roughly $0.19/DAU from a
fully-engaged ad watcher — and critically, ads pay **multipliers on earned gold, never flat
amounts** ([02 §2.11](02-economy.md)), so ad watching cannot outrun the economy.

**The Boon-reroll and Revive placements are between-room and post-death only.** The rewarded ad
button never appears while a fight is live, and `AdsPort.showRewarded()` no-ops if a run is
active. This is a code-level guarantee, not a UX guideline.

## 17.2 Interstitial ads

**There is exactly one interstitial placement in the entire game:**

> On returning to the Main Menu after **abandoning** a run (not after victory, not after defeat),
> at most **once per 25 minutes**, never in the first **3 days** after install, never for
> subscribers or Remove-Ads owners.

That is it. Interstitials on victory punish success; on defeat they punish frustration; mid-run
they destroy the game. On abandonment they interrupt nothing the player cared about.

Expected yield is small — low single-digit percent of ad revenue. We take that trade knowingly,
and the four commitments in §17.0 are worth more in retention than interstitials are worth in
revenue.

## 17.3 Banner ads

None during gameplay. A single anchored banner appears **only** on the Shop and Leaderboard
screens, removed permanently by any purchase of $4.99+ or by the Pact. Banners are the lowest-
value, highest-annoyance format; they exist here only as a mild conversion nudge on screens the
player is already browsing.

## 17.4 In-app purchases

### Consumables

| SKU | Price | Contents |
|---|---|---|
| Gems S | $4.99 | 500 (+75 first purchase) |
| Gems M | $9.99 | 1,150 |
| Gems L | $24.99 | 3,200 |
| Gems XL | $49.99 | 7,000 |
| Gems XXL | $99.99 | 15,000 |

Standard ladder with an honest value curve — the "best value" tag sits on the SKU that is
genuinely the best value per dollar.

### One-time offers

| SKU | Price | Contents | Trigger |
|---|---|---|---|
| **Starter Pact** | $2.99 | 800 gems + Kade + 5,000 gold | Once, end of session 3 |
| Remove Ads | $6.99 | No banners, no interstitial, keeps rewarded ads available | Shop, always |
| Chapter Bundle | $4.99–$19.99 | Materials + gold + shards scaled to the player's chapter | Contextual, max 1 active |
| Hero Bundle | $9.99 | A specific Epic hero at ★3 + shards | On hero screen, for locked heroes only |
| Returning Warden | $4.99 | Catch-up pack | After 14 days away |

**Remove Ads does not remove rewarded ads.** Players who buy it still want the Double Haul button.
Removing their ability to opt in would be punishing a paying customer, which happens depressingly
often in this category.

### Warden's Pact — the strategic centre

**$7.99/month**, auto-renewing:

- ×1.5 gold from all runs
- +10 max Vigor
- 100 gems per day (3,000/month — a $24 value)
- 1 free continue per day
- No banners, no interstitial
- Exclusive Windline colour set (cosmetic, rotating monthly)

**Deliberately absent: any raw combat power.** The Pact buys pace, gems, and convenience. A
subscriber and a free player at the same chapter have the same damage numbers; the subscriber
just got there ~2.5× faster.

**Grace period, restore, and cancellation are handled properly.** Cancelling never revokes gems
already granted, never removes a hero, and never locks progress behind the subscription. A
lapsed subscriber returns to a normal, fully-functional game.

### Battle Pass

**$9.99 per 6-week season.** 60 tiers.

- **Free track:** ~300 gems, materials, gold, 1 hero's shards, 1 cosmetic.
- **Premium track:** ~2,600 gems (a $25 value at the M-pack rate), 4 cosmetics, 2 heroes' shards,
  a Windline skin, and an avatar frame.

Progress comes from **playing** — XP from runs, bosses, and Confluences — not from a daily-quest
treadmill that punishes missing a day. A player who plays 40 minutes a day finishes the track
comfortably in 6 weeks with ~10 days to spare. **Tiers can be bought for gems** (60 gems each),
but the pass is designed so nobody needs to.

## 17.5 Cosmetics

Purely visual, permanently owned, never a stat.

| Type | Price | Notes |
|---|---|---|
| Hero skins | 600–1,800 gems | 2–3 per hero eventually |
| **Windline colour sets** | 400–900 gems | The signature cosmetic — the player's own trail |
| Arrival / death effects | 300–600 gems | |
| Avatar frames, titles | 200–500 gems | Many earned free from achievements |

**Windline skins are the best cosmetic in the game commercially**, because Windlines are on screen
constantly and are the visible signature of skilled play. A player who has mastered Confluence
*wants* their lattice to look distinct, and that desire is honest to monetise.

## 17.6 What we will not do

Written down so it cannot quietly erode:

- No energy gate on uncleared content.
- No mid-run ads of any kind.
- No loot box containing direct combat power.
- No hidden gacha odds, and no odds shown only where legally required — always, everywhere.
- No fake countdown timers, no "last chance" that returns next week.
- No streak-loss punishment on daily rewards.
- No pay-to-win PvP (there is no PvP — leaderboards are asynchronous, seeded, and validated).
- No selling Insight, Emberdust, or Marks.
- No offer interrupting a run, a boss, or a victory screen.
- No dark-pattern purchase flows (pre-checked upsells, confusing currency conversions,
  "cancel" styled as the affirmative button).
- No selling or brokering player data. Analytics are aggregate and opt-out-able.

## 17.7 Offer pacing

| Day | Offers shown |
|---|---|
| 0 | **None.** |
| 1 | Starter Pact, once, at end of session 3 |
| 2–3 | None beyond the permanently-available Shop |
| 4 | Battle Pass introduction (first season) |
| 7 | Pact introduction, once |
| 8+ | Max **1 contextual offer per day**, max 3 active bundles, never during a run |

**Day 0 has zero offers.** The first session's only job is to prove the game is good. A player who
is sold to before they have had fun converts worse *and* retains worse — this is measurable and
we design around it rather than arguing about it.

## 17.8 Compliance

- Odds disclosure on every randomised purchase, in every region.
- Pity counters visible on the item, not buried in a legal sheet.
- Age gate before any purchase flow; under-13 accounts have IAP disabled entirely and see no ads
  beyond non-personalised.
- ATT (iOS) and UMP/GDPR (EU) consent requested contextually, not on first launch, and re-openable
  from Settings.
- COPPA/GDPR-K: no behavioural ad targeting for minors, no data collection beyond what gameplay
  requires.
- Subscription terms, price, renewal cadence, and cancellation instructions shown **before**
  purchase, on the purchase screen itself.
- Full purchase history and a working "Restore Purchases" available in Settings.
- Account deletion is self-service in Settings and completes within 24 h.
