# 03 — Player Progression

## 3.0 The governing principle

A new player must experience **competence before choice, choice before economy, economy before
meta**. Most games in this category invert that and open with a shop. We open with a bow.

Nothing that is not combat appears in the first 4 minutes. No login, no account, no currency
tutorial, no rate-us prompt, no notification permission request.

---

## 3.1 The first 30 minutes — beat sheet

Every beat below is scripted content in `assets/data/onboarding.json`, not procedural. It is
authored, playtested, and instrumented (see [18](18-analytics.md) — `tutorial_beat_complete`).

### 0:00 – 0:20 · Cold open

App opens to a 2-second logo, then **directly into a room**. No menu. The Warden stands on a
dim arena floor. The Spire burns behind her. One line of text fades in over the arena:

> *The sky is breaking. Hold the line.*

A single **Mote** (weakest enemy, 44 HP, slow, telegraphed) drifts toward the player. No UI
except a joystick hint pulsing at the bottom-left.

**Taught:** the game has already started. This is a game about shooting things.

### 0:20 – 1:10 · Movement and auto-fire

Player touches the joystick. Character moves. On release, the bow auto-fires at the nearest
enemy. Three more Motes spawn from different edges.

**Taught:** move with left thumb; you shoot automatically; you never manage aim.
**Instrumented:** if the player has not moved by 0:35, the joystick hint doubles in size. If not
by 0:50, a ghost thumb animates the gesture. Silent assist, never a modal.

### 1:10 – 2:00 · The Draw

A **Husk** spawns — 3× HP, visibly armoured, plates glowing. Player's Tier-I arrows visibly
*plink* off it (distinct clang SFX, no damage number). The Draw meter — a thin arc around the
character's feet — is introduced now, and only now, as it fills.

The moment the meter completes Tier III, the arrow punches through the plate with a heavy hit
and the Husk staggers.

**Taught:** standing still winds a stronger shot; some enemies require it.
This is taught through *failure and discovery*, not a tooltip. The tooltip ("Hold still to
Draw") only appears if the player has not reached Tier III by 1:45.

### 2:00 – 3:00 · Momentum

Two **Lancers** spawn — fast, they charge along a telegraphed amber line. Standing still now
gets the player hit. Momentum stacks appear as chevrons on the character.

**Taught:** movement is also a reward, not just a retreat. The Draw/Momentum trade — the core
of the game — is now fully expressed and the player has felt both sides of it.

### 3:00 – 3:30 · First Boon

Room clears. Time slows, colour drains, and three cards rise:

- **Split Shot** — +1 arrow, −15 % damage each
- **Emberhead** — arrows apply Burn
- **Fleetfoot** — +12 % move speed, +1 max Momentum

All three are strong, none is a trap. This is the player's first real decision and it must feel
like a good one regardless of choice.

**Taught:** you build a different archer each run.

### 3:30 – 6:00 · Rooms 2–4, unassisted

No tutorial overlays. Difficulty is flat. Two more Boon choices. Enemy variety introduces the
**Spitter** (ranged) and **Weaver** (shielder), forcing target prioritisation.

### 6:00 – 7:30 · Windline, taught by accident

Room 5 is a narrow arena with a **Bulwark** — a stationary, high-HP enemy that must be killed to
open the exit, in a room whose geometry naturally routes the player's arrows across their own
previous shots. The first Confluence fires on its own, with a distinct chime, a white flash, and
a floating **"CONFLUENCE ×1"** label.

Only *after* it happens does a one-line card appear:

> *Your arrows leave a Windline. Fire through it.*

**Taught:** the depth mechanic, discovered rather than lectured. Telemetry
(`confluence_first_trigger_ms`) tells us whether the room geometry is working; if the median
player doesn't trigger it by 7:00, the arena is retuned. The mechanic is never mandatory.

### 7:30 – 9:00 · First boss — **The Cinder Choir**

Chapter 1 boss. Three phases, generous telegraphs, ~55 s. Fully beatable without Confluence.
Designed so a competent first-timer wins on attempt one and a distracted one wins on attempt two.

### 9:00 – 10:00 · Victory, first gold, the Spire

Victory screen counts up gold with a satisfying tick. Then — for the first time — the camera
pulls back and reveals **The Spire**: the meta hub. Exactly one node is unlocked and exactly one
purchase is affordable: **Warden's Might I** (+2 % attack, 60 gold).

**Taught:** runs make you permanently stronger. The reveal is deliberately delayed until the
player has already had fun, so the meta reads as a reward rather than a chore.

### 10:00 – 16:00 · Stage 2 and 3, the loop closes

Player runs stage 2 (0 Vigor — uncleared stages are free). Banks gold. Buys 2 more Spire levels
and *feels* the difference. This "run → upgrade → feel it" cycle closing successfully is the
single strongest predictor of D1 retention, and it must complete before minute 16.

### 16:00 – 20:00 · First defeat, engineered

Stage 4 is tuned to a ~70 % first-attempt loss rate. The defeat screen leads with **what you
kept** — "You banked 186 gold, 4 Ashwood, and reached room 5 of 7" — before offering anything.

The revive offer appears *below* that, and the first one is free.

**Taught:** death is not a loss of progress. This framing is why Quiverfall can afford
permadeath runs without churn.

### 20:00 – 26:00 · Second hero and the account

After clearing stage 5, **Kade** (Ember archer) is granted free. Two heroes = a loadout choice.

*Now* — 22 minutes in, after the player has decided they like the game — the account prompt
appears, framed as cloud save, with a prominent **"Later"**. Notification permission is
requested at 26 minutes, tied to "tell me when Vigor is full", and never re-prompted more than
once per 7 days.

### 26:00 – 30:00 · Vigor, quests, the exit

Vigor is introduced only when the player first *repeats* a cleared stage — its actual first
relevance. Daily quests surface (3 of 4 already complete from natural play, which is deliberate:
the first quest interaction is a claim, not a task).

Session ends with: 2 heroes, 6 Spire levels, one crafted arrow, chapter 1 cleared, chapter 2
open, and 3 daily quests claimed.

**Nothing has been sold to the player yet.** The first offer appears in session 2.

---

## 3.2 The first day (sessions 2–4)

| Session | When | Content | Systems opened |
|---|---|---|---|
| 2 | +2 h | Chapter 2, stages 1–8. First Astral Chest (free). | Chests, hero shards |
| 3 | +5 h | Chapter 2 boss. Arrow crafting unlocks at account level 6. | Fletching, materials |
| 4 | evening | Chapter 3 start. Research Lab unlocks (account level 9). | Insight, tier gates |

**Day-1 targets:** 3.2 sessions, 46 minutes total, chapter 3 reached, 12 Spire levels, 2 heroes,
1 crafted arrow, first daily-login claim. **The Starter Pact is offered exactly once**, at the
end of session 3, and never again that day.

## 3.3 The first week

| Day | Milestone | New system | Retention hook fired |
|---|---|---|---|
| 1 | Chapter 3 | Crafting, Research Lab | "I got stronger" |
| 2 | Chapter 4, hero #3 (Sela, shards) | Loadout slots, elements | "Builds are different" |
| 3 | Chapter 5, first Elite room | Elites, Shrine | "There's a real decision" |
| 4 | Chapter 6, **Battle Pass** | Season track | "There's a track to finish" |
| 5 | Chapter 7, first weekly event | Event mode + ladder | "There's competition" |
| 6 | Chapter 8, hero #4 | Star-ups | "My hero deepens" |
| 7 | **Day-7 anchor:** Prism Chest + chapter 8 boss | Guild-lite (leaderboard cohort) | "Others are here" |

The pacing rule: **a new system opens on days 1, 2, 3, 4, 5, and 7** — never two on the same day,
never a gap larger than one day. Week 1 churn in this genre is overwhelmingly "I have seen
everything"; the counter is a metered drip of novelty.

Week-1 targets: 14 sessions, 3.8 h total, chapter 8, 4 heroes, 34 Spire levels, account level 22.

## 3.4 Long-term progression (weeks 2–52)

| Window | Player state | Dominant motivation |
|---|---|---|
| Wk 2–3 | Chapters 9–12, first wall at ch. 11 | Optimisation — the wall forces build thinking |
| Wk 3–5 | **First Ascension** | Prestige — the reset re-opens the curve |
| Wk 5–10 | Ascensions 2–4, Emberdust tree | Compounding — each cycle is ~35 % faster |
| Wk 10–20 | Endless Descent mode, ladder climbing | Mastery + competition |
| Wk 20+ | Seasonal content, new heroes/chapters | Live-ops novelty |

**The first Ascension is the most dangerous moment in the game's lifetime.** Asking a player to
delete 3 weeks of progress is where prestige systems kill retention. Mitigations:

- Ascension is **offered, never required**. The gate is visible from week 1 as a locked door with
  its reward stated plainly.
- The first Ascension grants a **guaranteed Epic hero** and enough Emberdust that re-clearing
  chapters 1–8 takes ~90 minutes instead of ~6 hours. The player *feels* the multiplier within
  one session.
- Heroes, arrows, cosmetics, achievements, and account level **never reset**. Only Spire levels
  and gold.
- A one-time confirmation screen shows a side-by-side "before / after your first hour" projection
  with real numbers from the player's own save.

**Endless Descent** (unlocked after Ascension 1) is the terminal content: infinitely scaling
floors, weekly-seeded, with a ladder. It exists so that "finished the game" never happens.

## 3.5 Retention strategy

**Targets** (soft-launch gate; below these the game does not go worldwide):

| Metric | Target | Genre benchmark |
|---|---|---|
| D1 | 45 % | 38–42 % |
| D7 | 20 % | 14–17 % |
| D30 | 8 % | 5–6 % |
| Session length | 11 min | 8 min |
| Sessions/day | 3.1 | 2.4 |

### D1 — "Did the loop close?"

The whole of §3.1 is the D1 strategy. The measurable proxy: **did the player buy a Spire upgrade
and then play another run?** Telemetry shows this single event pair correlates with D1 retention
harder than any other. Levers if D1 misses:

- Move the Spire reveal earlier (currently 9:00).
- Lower first Spire node cost below the guaranteed first-run haul.
- Soften the engineered defeat from 70 % to 50 %.
- Push tutorial defeat later than minute 16.

### D7 — "Is there still something new?"

Driven by the day-1-through-7 system drip (§3.3) plus:
- **Daily quests** (4/day, ~18 min of play, completable inside one session)
- **Daily login** with visible day-7 and day-14 anchors
- **A push notification when Vigor fills**, at most 1/day, opt-in, sent at the player's own modal
  play hour rather than a global time
- **Battle Pass on day 4** — a 6-week commitment device introduced once the habit exists

### D30 — "Do I have a reason to be good at this?"

- **Ascension** lands in the week 3–5 window, precisely when the first curve flattens.
- **Weekly events** with a fresh modifier every Monday (see [14](14-level-design.md)).
- **Leaderboard cohorts of 50** players of similar power, re-drawn weekly, so a mid-tier player
  is always plausibly top-10 in their own cohort. Global-only ladders demotivate 99 % of players.
- **Mastery telemetry surfaced to the player**: a personal Confluence-rate stat and average TTK,
  trending over time. Showing a player their own improvement is the cheapest and most durable
  retention mechanic available to a skill-based game, and almost nobody in this category does it.

### Churn interception

| Signal | Intervention |
|---|---|
| 3 consecutive defeats on the same stage | Free Boon reroll next attempt + a *hint* naming the counter to that stage's threat |
| Session length dropping >40 % week-over-week | Surface a new hero's free trial run |
| No login for 3 days | Single push: "Your Vigor is full and the Cinder Choir has moved" |
| No login for 14 days | Returning-player bundle: free Epic shards, 3 days of Pact |
| Rage-quit mid-boss (app kill during boss) | Next launch resumes at the boss with full HP, once |

Every intervention is capped and logged. **We do not send more than 1 push per day or 4 per
week, ever.**
