# 02 — Technical Specification

Source of truth for engineering. Where this conflicts with the design doc, this wins on *how*; the design doc wins on *what*.

## 1. Engine and platform

- **Godot 4.x**, latest stable at project start. GDScript throughout. (Sim is written so it could be ported to a Rust GDExtension later if solver speed demands it — keep it free of engine types.)
- **Renderer: Mobile.** Set in `project.godot` on day one. Never Forward+. If web becomes a priority early, evaluate Compatibility; the art direction (one shadowed light, flat shading, vignette) works on both.
- **Targets:** desktop (Windows/macOS/Linux) first; test on a phone from Milestone 3 onward (wheel size, tap targets). Web export is a "demo link" channel only. Consoles are out of scope (third-party porting partner later).
- **Tests:** gdUnit4. **Headless runs:** `godot --headless -s tools/<script>.gd -- <args>`.

## 2. Architecture: three layers

```
┌────────────────────────────────────────────────────────┐
│ game/  (presentation — Nodes, scenes, UI, audio)        │
│   reads: sim state snapshots + event bus               │
│   writes: player intents (walk_to, verb_on)            │
├────────────────────────────────────────────────────────┤
│ sim/   (pure logic — RefCounted, deterministic)        │
│   grid · world · objects · rules · verbs · actors      │
│   attacker planner · events · outcome                  │
├────────────────────────────────────────────────────────┤
│ content/  (JSON — tags, rules, verbs, rooms,           │
│            attackers, campaigns, rubric defaults)      │
└────────────────────────────────────────────────────────┘
```

**Presentation never decides anything.** It sends intents; the sim validates, schedules, and emits events. The sim never references a Node. The solver and tests drive the sim with the same intent API the UI uses.

## 3. Time model

- Fixed tick: **10 Hz** (`dt = 0.1s`). `World.step()` advances one tick. Presentation interpolates between ticks.
- Loop timer counts down from `room.timer_s` (default 90). At 0 → `ArrivalPhase`.
- **Wheel open = sim paused.** Presentation simply stops calling `step()`. Inspect text is read from state without stepping.
- Every action has a `duration_s` (from the rule or verb). Actor performs: path to adjacency (walk speed in tiles/s from profile), then the action occupies `duration_s`, then effects apply. Actions are interruptible only by death/incapacitation.
- After arrival there is no hard end; the loop ends on death or on an ending condition. Safety cap: `room.max_loop_s` (default 300) → treated as Evade only if attacker has left; otherwise Disable if he's incapacitated; otherwise the loop is a loss ("he found you eventually" — should not normally trigger; solver flags rooms where it does).

## 4. Grid and space

- Tile grid, `width × height`, 1 tile = 1 m visually. Cells: `floor`, `wall`, `void`. Objects occupy 1+ cells (`footprint`). Doors and windows are objects placed on wall cells.
- **Zones**: named rectangles (`kitchen`, `living`, `bath`, `entry`, `bed`) used by systems (wet spread limits, search order categories, lure targets).
- **Pathfinding**: own A* on the grid (headless-safe, deterministic). Occupancy from object footprints; `movable` objects update occupancy when pushed.
- **Line of sight**: Bresenham between cell centers; blocked by walls and objects with `blocks-sight`. `hides-player` objects fully occlude an actor in `hidden` state.
- **Darkness**: `room.lit` boolean (toggled by light switch rules). Dark: attacker `sight_range` halved and `search_duration` doubled unless `has_flashlight`.
- **Hazard layers** (per-cell, per-tick): `wet`, `slippery`, `burning`, `gas`, `shock`. Spread rules per layer live in `content/systems.json` (rate in tiles/s, zone limits, decay).

## 5. Objects

Schema (`content/rooms/*.json`, `objects[]`):

```json
{
  "id": "toaster",
  "name": "Toaster",
  "tags": ["carryable", "throwable", "conductive", "plug-in", "blunt", "light"],
  "footprint": [[2,1]],
  "on": "counter",
  "state": { "plugged": true, "broken": false },
  "outlet": [2,1], "cord_range": 3,
  "inspect": "A cheap two-slot toaster. The cord is fraying.",
  "contains": [],
  "collectible": null
}
```

- `tags[]` — from `content/tags.json` only. Lint rejects unknown tags.
- `state{}` — free-form booleans/enums/numbers; rules read and write these. Common keys: `open`, `on`, `locked`, `chained`, `braced_by`, `broken`, `moved`, `tipped`, `burning`, `wet`, `plugged`.
- `on` / `contains[]` — containment hierarchy. Grabbing from a container requires it `open` if `openable`.
- `default_pos` recorded at load; `moved = pos != default_pos` (used by `notice` memory).
- Multi-cell objects have `push_axes` and can be `tips: {"dir": "S", "onto": [[1,6]]}` for tipping hazards.

## 6. Tag vocabulary (`content/tags.json`)

Grouped for humans; the sim treats them as a flat set.

**Handling:** `carryable` `light` `heavy` `movable` `throwable` `fragile` `breakable`
**Weapon:** `blunt` `sharp` `weapon-improvised`
**Spatial:** `blocks-door` `blocks-sight` `hides-player` `hides-object` `chokepoint` `entry` `exit` `climbable`
**Hazard:** `flammable` `ignites` `hot` `conductive` `plug-in` `pourable` `wet-source` `gas-source` `aerosol` `slippery-source`
**Signal:** `noisy` `bright` `lure` (emits sustained noise/light when `on`)
**Access:** `openable` `lockable` `chainable` `flimsy` `toggleable` `container`
**Comms:** `phone` `charger`
**Meta:** `collectible`

Adding a tag = adding it to `tags.json` + at least one rule that references it. Tags with no rules are lint warnings.

## 7. Rule table (`content/rules.json`)

A rule matches a verb against actor/target tags and conditions, and applies effects. **Rules are the only source of behavior.**

```json
{
  "id": "throw_conductive_into_wet",
  "verb": "throw",
  "held_tags": ["conductive", "plug-in"],
  "held_conditions": { "plugged": true },
  "target": { "cell_hazard": "wet" },
  "range_check": "cord_range",
  "duration_s": 0.5,
  "noise": 4,
  "effects": [
    { "hazard": "shock", "on": "connected_wet_cells", "for_s": 3 },
    { "held": "drop_at_target" },
    { "discovery": "water_and_current" }
  ]
}
```

Match fields: `verb`, `held_tags` (all required), `held_conditions`, `target_tags`, `target_conditions`, `target: {cell_hazard}`, `actor_conditions` (e.g. `hands_free`), `range_check`, `zone`.
Effect verbs: `set` (state), `move`, `tip`, `break`, `spawn_hazard`, `hazard`, `emit_noise`, `light`, `held: drop/consume/drop_at_target`, `hide_actor`, `status` (apply status effect to an actor in cell), `start_timer` (named world timer, e.g. `help_arrives`), `discovery`, `collect`.

Verb availability for the wheel = "does any rule match this verb, this actor's held item, and this target's current tags/state?" — computed by `sim/verbs.gd`, same function the solver uses.

**Initial rule set (Room 1 needs all of these; write them generically):**

| id | verb | match | effects |
|---|---|---|---|
| inspect | inspect | any | reveals `inspect` text + tag hints; 0s; no noise |
| grab | grab | target `carryable`, hands free, container open if needed | held = target; 0.5s |
| drop | drop | holding | place on target/cell; 0.5s |
| place_in_container | drop | target `container` open | contains; 0.5s |
| push | push | target `movable`, not `heavy` | move 1 tile; 1s; noise 2 |
| push_heavy | push | target `movable`+`heavy` | move 1 tile; 2s; noise 3 |
| push_to_brace | push (resolved automatically) | `blocks-door` object moved adjacent to an `entry` door | door.braced_by = obj; discovery |
| tip_first | push | target has `tips`, not tipped | state leaning; 1.5s; noise 2 |
| tip_second | push | leaning | falls onto `tips.onto`; any actor there → status `pinned`; noise 5; discovery |
| open_close | open | target `openable`, not locked | toggle open; 0.5s; noise 1 |
| toggle_lock | toggle | target `lockable`, actor on inside | toggle locked; 0.5s |
| toggle_chain | toggle | target `chainable` | toggle chained; 0.5s |
| toggle_light_switch | toggle | target tag `light-switch` (object-level tag) | room.lit flips; 0.3s |
| toggle_on | toggle | target `toggleable` | flip on; 0.5s; if `lure`: sustained noise/light while on |
| toggle_wet_source | toggle | target `wet-source` | start wet spread from cell at `systems.wet.rate` limited to zone |
| toggle_gas_source | toggle | target `gas-source`, not lit | start gas accumulation in zone |
| toggle_stove_ignite | toggle | target `gas-source` → on | cell `hot` |
| hide | hide | target `hides-player`, actor adjacent | actor hidden in target; 1s; noise 1 |
| unhide | (auto on any other verb) | | leaves hiding; 0.5s |
| throw_at_cell | throw | holding `throwable`, target cell in range 5 | object lands; noise = weight-based (3–5); `fragile` → broken + shards `sharp` + noise 6 |
| throw_at_actor | throw | holding `throwable`, target actor in LOS range 4 | if `heavy`/`blunt` and target `vulnerable`: hit; else if `heavy`: status `stunned` 2s; noise 4 |
| throw_conductive_into_wet | throw | above | shock hazard on connected wet cells for 3s |
| strike | use-held-on | holding `weapon-improvised`/`blunt`/`sharp`, target actor adjacent | if target `vulnerable`: hit (−1 durability, extends vulnerability 2s); else: actor `exposed` (attacker attacks immediately) |
| pour_slippery | use-held-on | holding `pourable` (`slippery-source`), target floor cell | cell `slippery`; held consumed; 1s; discovery |
| cover_hazard | push/drop | `hides-object` (rug) moved onto a hazard cell | hazard `concealed` (attacker perception ignores it); discovery |
| ignite_flammable | use-held-on | holding `ignites`, target `flammable` | target burning → fire spreads per systems.fire; noise 3; light; discovery |
| aerosol_flash | use-held-on | holding `aerosol`, target `hot`/`burning` | cone 2 tiles: actors `blinded` 4s, `flammable` ignite; discovery |
| cut | use-held-on | holding `sharp`, target `cuttable` | state cut (curtains fall, rope) |
| break_glass | throw/use-held-on | holding `blunt`, target `breakable` | broken; shards; noise 6; window open |
| charge_phone | use-held-on | holding `charger`, target `phone` | phone.charging = true → after `systems.phone.charge_s` phone.charged |
| call_help | toggle | target `phone`, charged | start world timer `help_arrives` (`systems.help.delay_s`); discovery |
| plug_cord_trip | drop | `plug-in` object's cord crosses a `chokepoint` cell | cell `trip` hazard (actor entering → `prone` 2s) |
| open_window | open | target `window` | window open: ambient noise mask (attacker hearing −1) |

Hazard-to-actor effects (applied by `world.step()` to any actor entering/standing on a cell): `slippery` → `prone` 3s (unless already prone) · `shock` → `electrocuted` (player: death; attacker: −durability, `vulnerable` 4s; if durability ≤ 0: dead) · `burning` → `burning` status (player: death after 3s unless leaves; attacker: `vulnerable`, −1 durability/2s) · `gas` + ignition source → explosion in zone (all actors in zone: death) · `trip` → `prone` 2s · `pinned` (from tip) → attacker immobilized permanently (Disable ending) / player death if pinned during arrival.

**Vulnerability** = any of `prone`, `stunned`, `blinded`, `burning`, `electrocuted`, `pinned`. Exposed in state as `attacker.vulnerable: bool` and `vulnerable_until`.

## 8. Actors

Shared (`actor.gd`): `pos`, `facing`, `holding: object_id|null`, `hidden_in: object_id|null`, `status: {effect: until_tick}`, `hp/durability`, `walk_speed` (player 3 tiles/s, attacker per profile).

**Player intents** (the only API presentation or the solver may call):
- `walk_to(cell)`
- `verb_on(verb, target_id_or_cell)` — sim validates availability, paths, schedules.
- `wait(seconds)` — solver/tests only; UI "waits" by not acting.

## 9. Attacker

### 9.1 Profile schema (`content/attackers/*.json`)

```json
{
  "id": "tenant_knife",
  "display": "the Tenant",
  "entries": ["front_door"],
  "weapon": "knife",
  "walk_speed": 2.5,
  "sight_range": 6,
  "hearing_sensitivity": 1.0,
  "has_flashlight": false,
  "patience_s": 40,
  "memory": "none",
  "memory_loops": 0,
  "durability": 1,
  "strength": 1,
  "breach_costs": { "locked": 4, "chained": 3, "braced_light": 6, "braced_heavy": 10, "flimsy_door": 5, "window": 5 },
  "search_order": ["closet", "behind_furniture", "curtains", "bed", "bathroom"],
  "search_duration_s": 3,
  "attack_range": 1,
  "attack_duration_s": 0.5
}
```

`weapon: gun` → `attack_range` = sight range, attack requires LOS; `knife`/`hands` → adjacency.

### 9.2 Perception (`perception.gd`), each tick

- **Sight:** LOS to player within `sight_range` (halved if dark and no flashlight). Hidden player is invisible. Seeing the player sets `last_known_pos` and `target_visible`.
- **Hearing:** each `noise` event with loudness `L` at distance `d` is heard if `L * hearing_sensitivity - d - mask >= 0` (`mask` = 1 if window open). Heard noise → `investigate_target = event.cell` with suspicion = loudness. Sustained `lure` objects emit periodic noise while on.
- **Hazard awareness:** he sees uncovered `slippery`/`burning`/`shock` cells in LOS and paths around them (cost +50). `concealed` hazards are invisible to him. Wet cells are walked through freely (he doesn't know about the toaster).
- **Memory hooks:** `notice` → objects with `moved == true` add suspicion to hiding spots within 2 tiles; `full` → previous-loop player positions at arrival time and the previous loop's winning trap cell seed `search_order` and avoidance.

### 9.3 Planner (`planner.gd`) — GOAP

Goal stack: `locate_player → reach_player → neutralize_player`. Replan on: precondition failure, new perception, status effect end.

Action library (`actions.gd`), each with preconditions, cost (seconds), effects:

| action | pre | cost | effect |
|---|---|---|---|
| `enter(entry)` | at entry, entry passable | 2 | inside |
| `breach_lock` | entry locked | breach_costs.locked | unlocked; noise 4 |
| `breach_chain` | chained | breach_costs.chained | unchained; noise 5 |
| `breach_brace` | braced | braced_light/heavy | brace object displaced; noise 6 |
| `breach_flimsy` | flimsy door locked | flimsy_door | open; noise 6 |
| `switch_entry` | current entry cost > alt entry cost | walk | at alt entry |
| `move_to(cell)` | path exists | path_len / walk_speed | at cell |
| `investigate(cell)` | heard noise | walk + 1 | at cell, suspicion cleared |
| `search(spot)` | spot in search_order, unsearched | walk + search_duration (×2 dark) | reveals hidden player if in spot |
| `attack` | player in range, LOS/adjacent | attack_duration | player dead |
| `leave` | elapsed_search ≥ patience or `help_arrived` | walk to entry | ending: Evade |

Planner picks the lowest-cost plan to the current goal; A* over actions with heuristic = walking distance to best candidate. When `target_visible`, `reach_player` dominates. When no target and no noise, iterate `search_order` (memory can reorder). Ties broken deterministically by declaration order.

**Symmetry:** the attacker moves through `world.step()` like the player and suffers hazard-to-actor effects identically. He does not know your plan; he only knows the visible room.

### 9.4 Memory (`memory.gd`)

- `none`: fresh every loop.
- `notice`: at arrival, scan objects with `moved == true`; add suspicion to `hides-player` objects within 2 tiles (searched first); avoid cells adjacent to a `tipped/leaning` object.
- `full`: store per loop `{player_pos_at_arrival, hidden_in, trap_cells, death_cause}` for last `memory_loops`. Seed: search `hidden_in` spots first; path cost +100 on `trap_cells`; if killed by `shock` last loop, avoid `wet` cells; if by `tip`, avoid `tips.onto` cells.

## 10. Events (`events.gd`)

Typed records: `{tick, type, cell, loudness, light, actor, object, rule_id, meta}`. Types: `noise`, `light`, `state_change`, `hazard_spawn`, `actor_move`, `actor_status`, `attack`, `death`, `ending`, `discovery`, `interaction`, `timer`.

Consumers: attacker perception (noise/light), outcome tracker (interaction/discovery/death/ending), presentation (all — sound, animation, notebook, HUD). **One bus.** Presentation subscribes; it never emits.

## 11. Outcome, stars, completion (`outcome.gd`)

- **Endings**: `evade` (attacker `left`), `disable` (attacker `pinned`/`trapped`/`incapacitated` for ≥ `systems.disable_hold_s`), `kill` (`attacker.dead`), `escape` (player crosses an `exit` in `exits_locked: false` rooms). `player.dead` → loss, with `death_cause` from the killing event/rule.
- **Star rubric** evaluated on the end state. Predicate language: dotted state paths, comparison, `&&`/`||`/`!`. Room may set `rubric.two` (override) and `rubric.three` (signature). Defaults in `content/rubric_defaults.json`:
  - `two`: `"loop.damage_taken == 0 || ending != 'kill' || loop.index <= 6"`
  - `three`: `"player.never_seen"`
- **Completion**: `interactions` = set of `(verb, object_id)` pairs from `interaction` events ∪ authored `valid_pairs` computed at load (rule table × objects); `discoveries` from `discovery` events (list of ids per room from rules the room can fire, computed at load); `deaths` from `death` events' `death_cause`; `endings` from `ending` events; `collectible` from `collect`. Mastery = all sets complete.
- **Notebook lines** generated from templates in `content/notebook_templates.json` keyed by event type/rule id. Deadpan. Example: `death.stabbed.hidden_in=closet` → "Hid in the closet. He looked in the closet."

## 12. Room schema (`content/rooms/*.json`)

```json
{
  "schema_version": 1,
  "id": "room_01_studio",
  "title": "Studio",
  "fantasy": "A cramped studio apartment, 2 AM. In 90 seconds someone with a knife comes through the front door.",
  "timer_s": 90,
  "max_loop_s": 300,
  "exits_locked": true,
  "lit": true,
  "grid": { "width": 12, "height": 9, "cells": ["############", "..."] },
  "zones": { "kitchen": [[1,1],[5,3]], "living": [[2,4],[7,8]], "bath": [[9,1],[10,3]], "entry": [[1,5],[2,8]], "bed": [[8,5],[10,8]] },
  "attacker": "tenant_knife",
  "objects": [ ... ],
  "systems": { "wet": { "rate_tiles_per_s": 0.25, "zone": "kitchen" }, "phone": { "charge_s": 30 }, "help": { "delay_s": 75 } },
  "rubric": { "three": "attacker.death_cause == 'shock' && player.never_seen" },
  "collectible": { "id": "bubble_token", "in": "toaster" },
  "authored_solutions": [ { "id": "evade_phone", "ending": "evade", "stars": 1, "actions": [ ... ] } ],
  "meta": { "attacker_archetype": "knife", "tag_families": ["water","electricity","fire","slip"], "entries": 1, "exits": 0 }
}
```

`authored_solutions[].actions` is a list of `{t, intent, args}` where `t` is the earliest tick to issue the intent (the solver issues it at `t` or when the previous action completes, whichever is later).

## 13. The solver (`tools/solve.gd`)

Purpose: prove every room is solvable, verify authored solutions still work, find unauthored wins, estimate difficulty. Runs headless, in CI, on every room.

**Mode A — verify:** for each `authored_solutions[]`, run the action sequence against the room; assert the declared ending occurs; report stars earned under the rubric. Fail the build if any authored solution no longer wins.

**Mode B — explore:** bounded search over intent sequences.
- Action candidates at each decision point = valid `(verb, target)` pairs from `verbs.gd` + `walk_to` zone centers + `wait`.
- Prune: dominated states (hash of world state), sequences exceeding `timer_s`, repeated no-op interactions.
- Budget: `--max-actions 8 --max-states 200000` (tunable). Beam search ordered by a heuristic (number of hazards armed, barrier seconds bought, hiding quality) is fine; exhaustive within budget is better if it fits.
- Output: every distinct winning sequence, its ending, stars under rubric, and whether it matches an authored solution. Unauthored wins are listed under `IMPROVISED` for designer review.
- Difficulty estimate: `{solutions_found, min_actions_to_win, min_loops_estimate, tightness = min over solutions of (timer_s - total_action_time)}`. Written to `content/rooms/<id>.solver.json` (committed, so diffs show difficulty drift).

**Mode C — deaths:** enumerate reachable `death_cause` values to seed the "Ways to die" checklist count.

Determinism requirement: identical results across runs. Any nondeterminism is a P0 bug.

## 14. Testing strategy

- `tests/sim/` — unit tests per rule (each rule id has at least one test), hazard spread, LOS, pathing, verb availability, status effects.
- `tests/attacker/` — planner chooses expected action given a state; breach cost accounting; patience → leave; memory reorders search.
- `tests/rooms/` — each room's authored solutions via the solver (Mode A) as a test.
- `tests/determinism/` — run Room 1 solution twice with same seed, assert identical event logs.
- CI: lint all content (`tools/lint_room.gd`), run gdUnit4, run `tools/verify_all.gd`. Any change under `sim/` or `content/rules.json`/`tags.json`/`systems.json` → full room re-verify.

## 15. Save data

Per room: `{stars, endings_found[], interactions_done[], discoveries[], deaths[], collectible, loops_total, best_loop_count, notebook[]}`. Global: `{campaign_progress, cosmetics_unlocked[], settings}`. JSON in `user://`. Schema versioned; migrations in `game/save_migrations.gd`.

## 16. Presentation contracts (`game/`)

- `RoomRenderer` builds the scene from room JSON: floor/wall meshes from `grid.cells`, one placeholder mesh per object keyed by `object.mesh` (greybox: box sized to footprint), lights per room `lighting` block. Object state → visual via a small mapping table (`open`, `broken`, `tipped`, `on`, `burning`), never bespoke per object.
- `Wheel` renders eight fixed slots; availability from `sim.verbs.available(actor, target)`; opening pauses stepping.
- `HUD`: timer (big), loop counter, held item, hidden indicator.
- `Notebook`, `WinScreen` read outcome/completion state.
- `AudioDirector` subscribes to events; maps `(event.type, rule_id, object.tags)` → sound cue; positional by cell. Attacker footsteps emitted as `actor_move` events. See `06-art-and-audio-requirements.md`.

## 17. Tuning constants (starting values; all in JSON)

Player walk 3 tiles/s · attacker walk 2.5 · tick 0.1s · timer 90s · wet spread 0.25 tiles/s (kitchen floods in ~40s) · phone charge 30s · help arrives 75s after call · patience 40s · search 3s (×2 dark) · sight 6 tiles (3 dark) · throw range 5 · cord range 3 · disable hold 10s · prone 3s · stunned 2s · blinded 4s · shock 3s.

These are guesses. The solver's `tightness` metric and playtesting tune them. Never hardcode.
