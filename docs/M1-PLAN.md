# `sim/` interface contracts

**Status: awaiting approval.** This was written before M1 as a proposal, was never approved, and M1, M2 and M3 shipped against it anyway. It has been rewritten to describe what the code actually is, with every divergence from the original proposal listed in §6 so the review that never happened can happen now.

Per `CLAUDE.md`, a `/goal` is not an approval. Nothing in `sim/` changes until this document is approved in words.

Contracts are stated as they exist today. Where a signature is wrong and should change, it says so and nothing has been changed yet.

---

## 1. The intent API — and the `rule_id` question

The only entry point. Presentation, tests and the solver all go through it; nothing else may mutate the world.

```gdscript
class SimWorld:
    func walk_to(cell: Vector2i) -> bool
    func verb_on(verb: String, target: Variant, rule_id: String = "") -> bool
    func wait(seconds: float) -> bool            # solver and tests only
```

- Returns `false` and mutates nothing when the intent is invalid. Never throws.
- An accepted intent **replaces** the player's queued plan: path to reach → occupy `duration_s` → apply effects.
- Time only advances in `step()`. Issuing intents advances nothing — that is what makes "wheel open = paused" free.

### The decision

`rule_id` was not in the original proposal. It was added during M1 because two rules can match one `(verb, object)`: locking the front door and chaining it are both `toggle`, and `first_match` always returns the lock. Without a selector the evade ending is unreachable.

**Keep `rule_id` in the intent API.** The solver needs to name a specific rule when it enumerates candidates, and tests need to assert that a particular rule fired rather than whatever happened to sort first.

**The wheel must never pass it.** A player clicking Toggle on a door should not be asked which of two rules they meant. That is a content bug wearing a UI costume. The invariant:

> For any `(verb, object, object-state, held item)`, at most one rule may be **choosable**.

Today `game/wheel.gd` violates this: when `SimVerbs.availability` returns more than one `rule_ids` entry it pops up a list of raw rule ids. That list should not exist.

### What the invariant costs, measured

I ran the real matcher — `SimVerbs.matching_rules`, not a re-implementation — over every object × every verb × every state assignment over the keys rules test × every held item. **13,680 combinations. 14 come back with more than one matching rule.**

| verb | object | rules that match | when |
|---|---|---|---|
| `open` | window | `open_window`, `open_close` | closed |
| `push` | bookshelf | `push_heavy`, `push` | any |
| `push` | bookshelf | `tip_first`, `push_heavy`, `push` | upright |
| `push` | bookshelf | `tip_second`, `push_heavy`, `push` | leaning |
| `push` | couch | `push_heavy`, `push` | any |
| `push` | fridge | `push_heavy`, `push` | any |
| **`toggle`** | **front_door** | **`toggle_lock`, `toggle_chain`** | **any** |
| `toggle` | light_switch | `toggle_light_switch`, `toggle_off` | on |
| `toggle` | light_switch | `toggle_light_switch`, `toggle_on` | off |
| `toggle` | sink | `toggle_wet_source`, `toggle_on` | off |
| `toggle` | sink | `toggle_wet_source_off`, `toggle_off` | on |
| `toggle` | stove | `toggle_gas_source`, `toggle_on` | off |
| `toggle` | stove | `toggle_stove_ignite`, `toggle_off` | on, unlit |
| `toggle` | stove | `toggle_burner_off`, `toggle_off` | on, lit |

Thirteen of these are not really ambiguous. They are a specific rule sitting above a general one in `rules.json`, and declaration order already picks correctly: a wet-source toggle *is* the toggle for a sink. Only the front door presents two genuinely different intentions.

### Proposal A — make shadowing explicit

Add an optional `shadows: [rule_id, ...]` field to a rule. A rule that shadows another says "when we both match, I am what the player meant." Matching is unchanged; the shadow list is used when reducing a match set to the choosable rules:

```
choosable(matches) = matches minus every rule shadowed by another rule in matches
```

The fifteen shadow declarations Room 1 needs:

| rule | shadows |
|---|---|
| `push_heavy` | `push` |
| `tip_first` | `push_heavy`, `push` |
| `tip_second` | `push_heavy`, `push`, `tip_first` |
| `open_window` | `open_close` |
| `toggle_light_switch` | `toggle_on`, `toggle_off` |
| `toggle_wet_source` | `toggle_on` |
| `toggle_wet_source_off` | `toggle_off` |
| `toggle_gas_source` | `toggle_on` |
| `toggle_stove_ignite` | `toggle_on`, `toggle_off` |
| `toggle_burner_off` | `toggle_off` |
| `call_help` | `toggle_on`, `toggle_off` |
| `throw_conductive_into_wet` | `throw_at_cell` |
| `throw_fragile_at_cell` | `throw_at_cell` |
| `place_in_container` | `drop` |

**Re-run with those declarations applied: 14 ambiguous pairs become 1.** The only survivor is `toggle front_door`.

`SimVerbs.availability` then returns the single choosable rule per verb, and the wheel's `_show_choices` list is deleted.

### Proposal B — the front door's chain becomes its own object

The chain is a physical thing on the wall, not a mode of the door. Give it an object:

```json
{ "id": "door_chain", "name": "Door chain", "tags": ["chainable"],
  "footprint": [[0, 2]], "state": { "chained": false },
  "guards": "front_door",
  "inspect": "A chain. It would hold for a few seconds." }
```

`front_door` drops `chainable` and keeps `lockable`. Then `toggle front_door` matches `toggle_lock` alone and `toggle door_chain` matches `toggle_chain` alone. Both choosable sets are size one, the invariant holds with no UI, and the player gets two visible things to interact with instead of one thing with a hidden second meaning.

**This is not free.** A `guards` reference means the attacker has to find barriers attached to an entry rather than reading the entry's own state. Everything that touches it:

| File | Line | What it does today |
|---|---|---|
| `sim/attacker/planner.gd` | 191 | `entry.get_state("chained")` decides whether to plan `breach_chain` |
| `sim/attacker/actions.gd` | 77 | clears `chained` on the entry when the breach completes |
| `tools/solver.gd` | 322 | scores a chained door in the Mode B heuristic |
| `content/rules.json` | `toggle_chain` | unchanged — it already matches on the `chainable` tag |
| `content/rooms/room_01_studio.json` | `front_door` | move `chained` onto the new object |

`breach_costs.chained` in the attacker profile and `attacker.breach_noise.chained` in `systems.json` keep their names. The generalisation is small: "barriers on an entry" = the entry plus any object whose `guards` names it.

### Proposal C — a lint that fails ambiguous pairs

`tools/lint_room.gd` gains a check that runs the sweep above against every room and fails the build when any `(verb, object, state, held)` leaves more than one choosable rule. It reports the verb, the object, the rule ids and an example state, exactly as the table above does.

This is the part that matters long-term. The front door is one instance; the lint is what stops the next room authoring another one, and it is cheap — 13,680 combinations took under a minute.

**None of A, B or C is implemented.** They are the proposal this document is asking approval for.

---

## 2. Files, as shipped

The proposal named twelve files. There are twenty-five. Most of the growth is Godot allowing one `class_name` per file, which the original plan did not account for.

| File | Class | Notes |
|---|---|---|
| `sim/rng.gd` | `SimRng` | the only randomness in `sim/` |
| `sim/events.gd` | `SimEvent` | the record |
| `sim/event_bus.gd` | `SimEventBus` | **split out** — one `class_name` per file |
| `sim/content.gd` | `SimContent` | loaded JSON bundle |
| `sim/grid.gd` | `SimGrid` | cells, zones, A*, LOS |
| `sim/objects.gd` | `SimObject` | |
| `sim/object_store.gd` | `SimObjectStore` | **split out** |
| `sim/rules.gd` | `SimRule` | matching only |
| `sim/rule_table.gd` | `SimRuleTable` | **split out** |
| `sim/rule_context.gd` | `SimRuleContext` | **split out** |
| `sim/effects.gd` | `SimEffects` | **new** — effect application, ~30 ops |
| `sim/verbs.gd` | `SimVerbs` | availability |
| `sim/actor.gd` | `SimActor` | |
| `sim/action.gd` | `SimAction` | **split out** |
| `sim/player.gd` | `SimPlayer` | |
| `sim/hazards.gd` | `SimHazardField` | |
| `sim/world.gd` | `SimWorld` | the clock and the intent API |
| `sim/outcome.gd` | `SimOutcome` | M2 |
| `sim/predicate.gd` | `SimPredicate` | **new** — the rubric expression language |
| `sim/attacker/profile.gd` | `SimAttackerProfile` | M2 |
| `sim/attacker/perception.gd` | `SimAttackerPerception` | M2 |
| `sim/attacker/planner.gd` | `SimAttackerPlanner` | M2 |
| `sim/attacker/actions.gd` | `SimAttackerActions` | M2 |
| `sim/attacker/memory.gd` | `SimAttackerMemory` | M2 |
| `sim/attacker/attacker.gd` | `SimAttacker` | M2, `extends SimActor` |

Every one extends `RefCounted`, except `SimAttacker` and `SimPlayer` which extend `SimActor`. `tests/sim/architecture_test.gd` enforces that, and that no file here touches `get_tree`, `Input`, `Time` or a bare RNG.

---

## 3. The event record and the tick order

```gdscript
class SimEvent:
    var tick: int
    var type: String       # noise · light · state_change · hazard_spawn · actor_move
                           # actor_status · attack · death · ending · discovery
                           # interaction · timer
    var cell: Vector2i     # NO_CELL = (-1,-1) when not spatial
    var loudness: float
    var light: float
    var actor: String
    var object: String
    var rule_id: String
    var meta: Dictionary   # typed per event type; the sim never reads it back
```

```gdscript
class SimEventBus:
    func emit_event(e: SimEvent) -> void     # sim only; presentation never emits
    func subscribe(cb: Callable) -> void
    func unsubscribe(cb: Callable) -> void
    func log_all() -> Array[SimEvent]
    func since(tick: int) -> Array[SimEvent]
    func of_type(type: String) -> Array[SimEvent]
    func to_lines() -> PackedStringArray     # determinism diffs compare these
    func clear() -> void
```

**Determinism contract.** `SimWorld.step()` in order, and this order is a test:

1. `tick += 1`
2. world timers firing
3. player action resolution
4. **attacker: perceive, then plan, then act**
5. **object systems** — gas filling a zone, lures making noise, fire catching
6. hazard spread
7. hazard-to-actor effects, after status expiry
8. outcome check

Ties inside any stage break by declaration order: object order in the room JSON, rule order in `rules.json`, neighbour order `N, E, S, W, NE, SE, SW, NW`. `SimRng` is the only randomness and is constructed with an explicit seed.

---

## 4. The rest of the surface

Only the parts a caller needs. Full signatures are in the files.

**`SimObject`** — `id · name · tags · cells · default_cells · state · on · contains · inspect · props`, with `has_tag · has_all_tags · has_any_tag · add_tag · remove_tag · get_state · set_state · prop · origin() · occupies · is_moved · blocks_movement · blocks_sight · reach_connectivity · reset_to_default`. No method branches on `id`, and none ever may.

**`SimObjectStore`** — `by_id · has · all · with_tag · at_cell · container_of · is_loose · move_to · translate · take_from_container · put_in_container`.

**`SimRuleTable`** — `from_json · by_id · ids · matches · first_match(ctx, rule_id := "")`. Effect application lives in `SimEffects.apply_rule`, not here.

**`SimRule`** match fields — `verb · trigger · internal · reach · held_tags · held_conditions · target_kind · target_tags · target_conditions · target_cell_hazard · target_cell_no_hazard · subject_tags · subject_conditions · subject_adjacent · actor_conditions · target_actor_conditions · requires_container_open · range_check · zone`, plus `duration_s · noise · effects · discovery`.

`trigger` is `verb` (on the wheel), `follow_up` (fires automatically after any action — bracing a door, concealing a hazard, a cord across a chokepoint) or `manual` (the world calls it, e.g. leaving a hiding spot).

**`SimVerbs`** — `verb_ids · availability · is_available · matching_rules · valid_pairs`. One implementation behind the wheel, the solver's candidate generator and the completion checklist, so they cannot disagree.

**`SimActor`** — `id · role · pos · facing · holding · hidden_in · status · status_since · hazard_since · hazard_last_damage · durability · walk_speed · alive · death_cause · action · path · walk_progress`, with `configure · has_status · apply_status_until · clear_status · expire_statuses · status_names · is_vulnerable · is_hidden · hands_free · cancel_action`. `role` is `player` or `attacker`; hazard specs key off role, never off an id, so a new attacker profile needs no code.

**`SimGrid`** — `in_bounds · cell_type · is_floor · distance` (Chebyshev) `· neighbours · is_adjacent · path · has_los · line · zone_names · zone_rect · zone_of · zone_cells · zone_center · is_marker_zone · in_zone`. Object-dependent questions arrive as `Callable`s, so pathing is testable without a world. Marker zones tag cells without being places.

**`SimHazardField`** — `has · at · cells · count · spawn · clear · clear_layer · connected · start_spread · stop_spread · spread_active · add_gas · gas_level · step`.

**`SimWorld`** — beyond the intent API: `create · system · ticks · time_s · timer_remaining_s · walkable · blocked · blocks_sight · actors · actor_by_id · actor_at · add_actor · inside_cell_of · reach_cells · emit · record_discovery · record_interaction · set_room_state · collect · apply_status · damage_actor · kill_actor · start_timer · timer_remaining · fire_manual · step · step_seconds · step_until_idle · idle · snapshot_hash`.

---

## 5. Ambiguities the proposal resolved, and how they landed

All seven were implemented as written.

| # | Resolution | Shipped |
|---|---|---|
| 1 | `content/systems.json` for global tuning, room block overrides per key | yes |
| 2 | nine verb ids; `inspect` goes through the rule table like any other | yes |
| 3 | Chebyshev distance everywhere | yes |
| 4 | `range_check` reads any numeric key in `props` | yes, and grew: `{from, max, max_prop, max_system}` |
| 5 | `props.reach: 4 \| 8` | yes |
| 6 | `props.walk_over` excludes a footprint from occupancy | yes |
| 7 | statuses stored as `until_tick`; seconds only at the boundary | yes |

---

## 6. Where the proposal and the code disagree

Everything below shipped without review. Each row is a thing to accept or reject.

### Contract changes

| # | Proposed | Shipped | Why |
|---|---|---|---|
| 1 | `verb_on(verb, target)` | `verb_on(verb, target, rule_id := "")` | two rules can match one pair; see §1 |
| 2 | `SimEventBus.emit(e)` | `emit_event(e)` | `emit` collides with GDScript's signal emit |
| 3 | `SimEventBus.log()` | `log_all()` | `log` is too close to the global `log()` |
| 4 | `SimObject.origin: Vector2i` + `footprint` as offsets | `cells: Array[Vector2i]` absolute, `origin()` a method | the room schema in `02-technical-spec.md` §5 gives absolute footprints |
| 5 | `SimObject.default_pos` | `default_cells` | follows from #4 |
| 6 | `SimRuleTable.apply(rule, ctx)` | `SimEffects.apply_rule(rule, ctx)` | thirty effect ops did not belong on the match table |
| 7 | perception at stage 6, after hazards | perception inside stage 4, before he plans | at stage 6 he acts on last tick's view and walks into a trap he already saw |
| 8 | seven tick stages | eight — `object systems` added | gas fill, lure noise and fire catching are per-tick and tag-driven, and had no home |

### Fields and methods the proposal never mentioned

| Area | Added |
|---|---|
| `SimRule` | `trigger`, `internal`, `reach`, `subject_tags`, `subject_conditions`, `subject_adjacent`, `target_actor_conditions`, `requires_container_open`, `target_cell_no_hazard`, `discovery` |
| `SimRuleContext` | `subject` — the object an internal rule reacts to |
| `SimActor` | `role`, `status_since`, `hazard_since`, `hazard_last_damage`, `path`, `walk_progress`, `death_cause`, `configure()` |
| `SimPlayer` | `seen_count`, `collected`, `found_in` |
| `SimGrid` | `is_floor`, `neighbours`, `is_adjacent`, `line`, `zone_names`, `zone_rect`, `zone_cells`, `is_marker_zone`, `in_zone` |
| `SimHazardField` | `count`, `clear_layer`, `connected`, `start_spread`, `stop_spread`, `spread_active`, `add_gas`, `gas_level` |
| `SimObjectStore` | `has`, `container_of`, `is_loose`, `translate`, `take_from_container`, `put_in_container` |
| `SimVerbs` | `verb_ids`, `matching_rules` |
| effects | a per-effect `requires_state` guard, so one rule can carry a conditional step without a second rule id |

### Files not in the proposal

`sim/effects.gd`, `sim/predicate.gd`, `sim/event_bus.gd`, `sim/object_store.gd`, `sim/rule_table.gd`, `sim/rule_context.gd`, `sim/action.gd`, and the six under `sim/attacker/`.

### Process

| Proposed | What happened |
|---|---|
| three parallel agent tracks (§7.5: grid/actors · objects/rules · tests/lint) | built solo and sequentially |
| tests first for sim changes | implementation first, tests after, for the whole of M1. Every rule has a passing test now, but the order was wrong and `CLAUDE.md` asks for the opposite |
| this plan approved before sim code | not approved; M1 started on a `/goal` |

---

## 7. What approval means

Approving this accepts §1's `rule_id` decision, the eight contract changes in §6, and the additions listed there — as the contract for M4 onwards.

It does **not** implement §1's Proposals A, B or C. Those are a separate PR, and they touch `sim/`, so they wait for the word.

If any row in §6 should be reverted instead of accepted, say which. Reverting #1 means the evade ending needs a different answer. Reverting #7 changes attacker behaviour and the solver's numbers with it.
