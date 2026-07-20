# 18 — Analytics Events

## 18.0 Principles

1. **Every event is a typed Dart class.** No raw string maps anywhere. The schema below is
   generated from those classes, so this document cannot drift from the code.
2. **Every event answers a question we have already written down.** An event nobody has a
   question for is deleted — unused events cost battery, bandwidth, and clarity.
3. **Queue locally, flush in batches.** Offline play must not lose data; the game must never
   block on a network call.
4. **No PII.** No email, no device advertising ID in the payload, no free text. The only
   identifier is the pseudonymous `player_id`.
5. **Opt-out is real.** `settings.analyticsOptOut` stops collection entirely, not just
   transmission.

**Global parameters** attached to every event automatically: `player_id`, `session_id`,
`app_version`, `build_number`, `platform`, `device_tier`, `account_level`, `chapter`,
`ascension_count`, `is_subscriber`, `days_since_install`, `locale`.

---

## 18.1 Lifecycle & funnel

| Event | Parameters | Question it answers |
|---|---|---|
| `app_open` | `cold_start`, `boot_ms` | Are we hitting the 3.2 s launch budget? |
| `session_start` | `source` (organic/push/deeplink) | What brings players back? |
| `session_end` | `duration_s`, `screens_visited`, `runs_played` | Are sessions the intended 11 min? |
| `bootstrap_failed` | `stage`, `error_code` | Launch reliability |
| `tutorial_beat_complete` | `beat_id`, `elapsed_ms`, `assists_shown` | **Where does the first 30 min leak?** |
| `tutorial_abandoned` | `beat_id`, `elapsed_ms` | The single most important churn event |
| `ftue_complete` | `total_ms`, `deaths`, `spire_purchased` | Did the loop close? ([03 §3.5](03-progression.md)) |

`tutorial_beat_complete` fires at each of the 12 beats in [03 §3.1](03-progression.md). The
drop-off curve across those 12 points is the primary D1 diagnostic and is dashboarded on its own.

## 18.2 Run events — the core of the game

| Event | Parameters |
|---|---|
| `run_start` | `chapter`, `stage`, `hero_id`, `hero_star`, `arrow_id`, `arrow_refine`, `mark_ids[]`, `vigor_cost`, `seed`, `is_retry`, `attempt_number` |
| `room_enter` | `run_id`, `room_index`, `room_type`, `arena_id`, `threat_budget`, `enemy_composition{}` |
| `room_clear` | `run_id`, `room_index`, `duration_ms`, `damage_taken_pct`, `confluences`, `max_confluence`, `tier3_shots`, `max_momentum` |
| `boon_offered` | `run_id`, `room_index`, `boon_ids[]`, `rarities[]`, `reroll_used` |
| `boon_chosen` | `run_id`, `boon_id`, `rarity`, `position` (0/1/2), `deliberation_ms` |
| `synergy_set_complete` | `run_id`, `set_id`, `room_index` |
| `boon_evolved` | `run_id`, `from_ids[]`, `to_id` |
| `shrine_visit` | `run_id`, `gold_available`, `action`, `gold_spent` |
| `boss_encounter` | `run_id`, `boss_id`, `attempt_number` |
| `boss_phase_change` | `run_id`, `boss_id`, `phase`, `elapsed_ms`, `player_hp_pct` |
| `boss_defeated` | `run_id`, `boss_id`, `duration_ms`, `deaths_before`, `hp_remaining_pct` |
| `run_complete` | `run_id`, `outcome`, `duration_ms`, `rooms_cleared`, `gold`, `materials{}`, `boon_ids[]`, `confluences`, `stars` |
| `run_abandoned` | `run_id`, `room_index`, `elapsed_ms` |
| `player_death` | `run_id`, `room_index`, `killer_enemy_id`, `killer_damage_type`, `hp_before_pct`, `boon_ids[]`, `arena_id`, `position{x,y}` |

**`player_death` is the highest-value event in the schema.** It powers the "What got you"
coaching on the defeat screen ([10 §10.9](10-ui-ux.md)), the anti-frustration triggers
([14 §14.3](14-level-design.md)), *and* the level-design heat maps ([14 §14.9](14-level-design.md)).
One event, three uses.

**`boon_chosen.deliberation_ms`** is the clearest signal of a card being obviously correct: a card
chosen in under 600 ms consistently is a card with no decision in it, and gets flagged by the
78 %-pick-rate rule in [09 §9.5](09-skills.md).

## 18.3 Mechanic mastery events

The events that make Quiverfall's core loop measurable — and, unusually, that we show back to the
player.

| Event | Parameters | Question |
|---|---|---|
| `confluence_first_trigger` | `elapsed_since_install_ms`, `room_index`, `was_accidental` | **Is the chapter-1 teaching arena working?** ([03 §3.1](03-progression.md)) |
| `confluence_triggered` | *(aggregated per room, not per hit)* `count`, `max_stack`, `avg_stack` | Mastery trend |
| `draw_tier_distribution` | *(per room)* `t1_pct`, `t2_pct`, `t3_pct` | Is anyone actually using the Draw? |
| `momentum_distribution` | *(per room)* `avg_stacks`, `max_reached`, `pct_time_moving` | Is the Draw/Momentum trade live, or is one side dead? |
| `ultimate_used` | `hero_id`, `room_index`, `enemies_hit`, `damage_dealt_pct` | Ultimate balance across 20 heroes |
| `mark_progress` | `mark_id`, `progress`, `unlocked` | Mastery pacing |

**`confluence_triggered` is aggregated per room, never per hit.** A skilled player triggers it
40+ times a room; per-hit events would be the single largest source of analytics volume in the
app for almost no additional insight.

**`draw_tier_distribution` is the health check on the entire core mechanic.** If the median player
spends 85 % of their time at Tier I, the Draw is not working and the game needs redesign, not
tuning. This metric is a soft-launch gate.

## 18.4 Progression

| Event | Parameters |
|---|---|
| `chapter_unlocked` / `stage_first_clear` | `chapter`, `stage`, `attempts`, `total_elapsed_s`, `stars` |
| `stage_wall_detected` | `chapter`, `stage`, `consecutive_failures` — fires at 3 |
| `spire_upgrade` | `node_id`, `from_level`, `to_level`, `gold_spent`, `gold_remaining` |
| `tier_gate_unlocked` | `node_id`, `band`, `insight_spent` |
| `research_completed` | `research_id`, `insight_spent` |
| `hero_unlocked` | `hero_id`, `method` (shards/gems/reward/bundle) |
| `hero_level_up` / `hero_star_up` | `hero_id`, `to_level`/`to_star`, `cost` |
| `talent_chosen` | `hero_id`, `star_tier`, `branch_id` |
| `arrow_crafted` / `arrow_refined` | `arrow_id`, `to_refine`, `cost{}` |
| `affix_rerolled` | `arrow_id`, `slot`, `from_affix`, `to_affix`, `cost`, `reroll_index` |
| `loadout_changed` | `hero_id`, `arrow_id`, `mark_ids[]` |
| `account_level_up` | `to_level` |
| `ascension_performed` | `ascension_count`, `chapter_at_ascend`, `emberdust_gained`, `days_since_last` |
| `ascension_offered_declined` | `chapter`, `times_declined` |
| `endless_run_end` | `floor_reached`, `modifiers[]`, `duration_s` |

**`ascension_offered_declined`** is deliberately tracked. The first Ascension is the most
dangerous moment in the game's lifetime ([03 §3.4](03-progression.md)); knowing how many players
look at the door and walk away tells us whether the framing is working before the retention data
does.

## 18.5 Economy

| Event | Parameters |
|---|---|
| `currency_earned` | `currency`, `amount`, `source`, `balance_after` |
| `currency_spent` | `currency`, `amount`, `sink`, `balance_after` |
| `economy_snapshot` | *(once per session)* `gold`, `gems`, `vigor`, `insight`, `emberdust`, `materials{}`, `next_spire_cost` |
| `vigor_depleted` | `chapter`, `runs_this_session` |
| `vigor_refilled` | `method` (time/gems/ad/pact), `cost` |
| `chest_opened` | `chest_type`, `cost`, `contents[]`, `pity_counter_before`, `hit_pity` |

**`economy_snapshot`** is the inflation alarm from [02 §2.11](02-economy.md). The dashboard
watches `gold / next_spire_cost` by chapter: sustained above 3.0 means inflation, sustained below
0.3 means the curve is a wall. Both page the live-ops team.

## 18.6 Monetization

| Event | Parameters |
|---|---|
| `store_opened` | `tab`, `source` |
| `offer_shown` | `offer_id`, `price_usd`, `context`, `trigger` |
| `offer_dismissed` | `offer_id`, `time_shown_ms` |
| `purchase_initiated` | `sku`, `price_usd`, `currency_code`, `context` |
| `purchase_completed` | `sku`, `price_usd`, `transaction_id`, `is_first_purchase` |
| `purchase_failed` | `sku`, `error_code`, `stage` |
| `purchase_restored` | `sku_count` |
| `subscription_started` / `renewed` / `cancelled` / `lapsed` | `sku`, `period`, `days_active` |
| `battlepass_purchased` | `season_id`, `tier_at_purchase` |
| `battlepass_tier_claimed` | `season_id`, `tier`, `track` |
| `ad_requested` / `ad_shown` / `ad_completed` / `ad_failed` | `placement`, `ad_unit`, `fill_ms`, `reward_granted`, `error_code` |
| `ad_reward_lost` | `placement`, `reason` — **must be near-zero; a non-zero rate is a bug** |

**`purchase_failed.stage`** distinguishes store-side failure from our verification failing. The
second is our bug and must be paged; the first is not.

## 18.7 Technical health

| Event | Parameters |
|---|---|
| `perf_frame_report` | *(per room)* `avg_fps`, `p95_frame_ms`, `p99_frame_ms`, `dropped_frames`, `entity_peak`, `quality_tier` |
| `perf_jank_spike` | `frame_ms`, `system`, `entity_count`, `room_context` — fires above 50 ms |
| `memory_warning` | `resident_mb`, `screen` |
| `load_time` | `asset_tier`, `duration_ms` |
| `crash` / `non_fatal` | via Crashlytics, with the last 20 breadcrumbs |
| `save_written` / `save_recovered` / `save_migration_failed` | `schema_version`, `slot`, `duration_ms` |
| `cloud_sync` | `direction`, `outcome`, `conflict_resolution` |
| `device_benchmark` | `score`, `assigned_tier`, `gpu`, `ram_mb` |

**`perf_frame_report` per room, segmented by `device_tier`, is the 60 FPS law's enforcement
mechanism** ([19](19-performance.md)). A build where p95 frame time on low-tier devices exceeds
16.6 ms does not ship.

## 18.8 Settings & accessibility

`setting_changed { setting_key, from, to }` for every toggle. Specifically watched:
`auto_aim` distribution (validates the four-option design), `reduce_motion` and `colorBlindMode`
adoption (validates that accessibility work is reaching people), and `damage_numbers` (a high
opt-out rate would suggest the combat HUD is too noisy).

## 18.9 Core dashboards

| Dashboard | Key metrics | Owner |
|---|---|---|
| **Acquisition & retention** | D1/D7/D30, session length, sessions/day, by source | Product |
| **FTUE funnel** | 12 tutorial beats, drop-off per beat, time per beat | Design |
| **Core mechanic health** | Draw-tier distribution, Confluence rate over player age, momentum split | **Design — the game's vital signs** |
| **Progression** | Time per chapter, attempts per stage, wall detection heat map | Design |
| **Economy** | `gold / next_spire_cost` by chapter, currency flows, sink/source balance | Economy |
| **Balance** | Boon pick rates, hero win rates and usage, arrow win rates, boss clear rates | Balance |
| **Monetization** | Conversion, ARPPU, ARPDAU, offer CTR, ad fill and completion | Product |
| **Technical** | FPS by device tier, crash-free rate, load times, save failures | Engineering |

## 18.10 Volume and cost control

Estimated **~120 events per session**, ~350/DAU. Controls:

- Per-hit events are aggregated to per-room. This alone cuts volume by roughly 30×.
- `perf_frame_report` and `draw_tier_distribution` are sampled at **10 % of sessions** outside
  soft launch (100 % during it).
- Batched flush: every 30 s, on background, or at 50 queued events.
- A remote **killswitch per event category**, so a runaway event can be disabled without a client
  release.
