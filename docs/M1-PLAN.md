# M1 Plan — `sim/` interface contracts

Derived from `docs/02-technical-spec.md` §5–§10. **Contracts only.** Approve these before sim code is written; parallel agents build against them.

All classes extend `RefCounted`. All are prefixed `Sim` — collision-proof against Godot globals (`Object`, `Timer`, `World3D`) and makes "is this sim code?" readable at a glance. Ticks are the unit of time internally; seconds appear only at the API edge.

---

## 1. Files

| File | Class(es) | Owns |
|---|---|---|
| `sim/rng.gd` | `SimRng` | seeded deterministic randomness |
| `sim/grid.gd` | `SimGrid` | cells, zones, A*, LOS, distance |
| `sim/objects.gd` | `SimObject`, `SimObjectStore` | object model, tag queries, occupancy index |
| `sim/rules.gd` | `SimRule`, `SimRuleTable`, `SimRuleContext` | rule loading, matching, effect application |
| `sim/verbs.gd` | `SimVerbs` | the nine verbs, availability, valid-pair enumeration |
| `sim/actor.gd` | `SimActor`, `SimAction` | shared actor state, status, scheduled action |
| `sim/player.gd` | `SimPlayer` | player-only loop stats (`never_seen`, `damage_taken`) |
| `sim/hazards.gd` | `SimHazardField` | per-cell hazard layers and their spread **(new file — see §7.1)** |
| `sim/content.gd` | `SimContent` | loaded JSON bundle, injected into the world **(new file — see §7.1)** |
| `sim/events.gd` | `SimEvent`, `SimEventBus` | event records, the one bus |
| `sim/world.gd` | `SimWorld` | room state, 10 Hz stepping, the intent API |
| `sim/outcome.gd` | `SimOutcome` | **M2.** Declared, not implemented in M1 |
| `sim/attacker/*` | — | **M2.** Not touched in M1 |

---

## 2. The intent API (spec §8)

The **only** entry point for presentation, tests, and the solver. Nothing else may mutate the world.

```gdscript
class SimWorld:
    func walk_to(cell: Vector2i) -> bool
    func verb_on(verb: String, target) -> bool   # target: String object id, or Vector2i cell
    func wait(seconds: float) -> bool            # solver/tests only
```

- Returns `false` and mutates nothing when the intent is invalid: unknown verb, unreachable cell, no rule matches, actor incapacitated. Never throws.
- An accepted intent **replaces** the player's queued plan. It schedules: path to reach → occupy `duration_s` → apply effects.
- `verb_on` resolves adjacency itself. Callers never path manually.
- Time only advances in `step()`. Issuing intents advances nothing — that is what makes "wheel open = paused" free.

```gdscript
    func step() -> void                # exactly one tick (0.1 s)
    func step_seconds(seconds: float) -> void   # convenience; loops step()
    func snapshot_hash() -> int        # state hash: solver pruning + determinism tests
```

---

## 3. The event record (spec §10)

```gdscript
class SimEvent:
    var tick: int
    var type: String       # see list below
    var cell: Vector2i     # (-1,-1) when not spatial
    var loudness: float    # 0.0 unless type == "noise"
    var light: float       # 0.0 unless type == "light"
    var actor: String      # actor id, or "" 
    var object: String     # object id, or ""
    var rule_id: String    # rule that fired, or ""
    var meta: Dictionary   # typed per event type; never read by the sim itself
```

`type` ∈ `noise · light · state_change · hazard_spawn · actor_move · actor_status · attack · death · ending · discovery · interaction · timer`.

```gdscript
class SimEventBus:
    func emit(e: SimEvent) -> void          # sim only; presentation never emits
    func subscribe(cb: Callable) -> void    # cb(e: SimEvent)
    func unsubscribe(cb: Callable) -> void
    func log() -> Array[SimEvent]           # full ordered log for this loop
    func since(tick: int) -> Array[SimEvent]
    func to_lines() -> PackedStringArray    # stable text — determinism diffs compare these
```

**Determinism contract.** Within one tick, events are emitted in this fixed order, and this order is a test:

1. world timers firing · 2. player action resolution · 3. attacker action resolution (M2) · 4. hazard spread · 5. hazard-to-actor effects · 6. perception (M2) · 7. outcome check (M2).

Ties inside any stage break by declaration order — object order in room JSON, rule order in `rules.json`, neighbour order `N, E, S, W, NE, SE, SW, NW`. `SimRng` is the only randomness and is constructed with an explicit seed.

---

## 4. Objects and tags (spec §5–§6)

```gdscript
class SimObject:
    var id: String
    var name: String
    var tags: PackedStringArray
    var state: Dictionary            # free-form; rules read and write
    var origin: Vector2i             # top-left of footprint
    var default_pos: Vector2i        # recorded at load
    var footprint: Array[Vector2i]   # offsets from origin
    var on: String                   # container/support id, or ""
    var contains: PackedStringArray
    var inspect: String
    var props: Dictionary            # outlet, cord_range, tips, push_axes, hide_cells,
                                     # walk_over, weight, reach, collectible — data, never code

    func has_tag(t: String) -> bool
    func has_all_tags(t: PackedStringArray) -> bool
    func has_any_tag(t: PackedStringArray) -> bool
    func get_state(key: String, fallback = null) -> Variant
    func set_state(key: String, value) -> void
    func is_moved() -> bool          # origin != default_pos
    func cells() -> Array[Vector2i]

class SimObjectStore:
    func by_id(id: String) -> SimObject          # null if absent
    func at_cell(c: Vector2i) -> Array[SimObject]
    func with_tag(t: String) -> Array[SimObject] # declaration order
    func all() -> Array[SimObject]
    func move(obj: SimObject, new_origin: Vector2i) -> void   # reindexes occupancy
```

No method on `SimObject` ever branches on `id`. Behaviour comes from `tags` + `props` + the rule table, always.

---

## 5. Rules and verbs (spec §7)

```gdscript
class SimRuleContext:
    var verb: String
    var actor: SimActor
    var held: SimObject      # null when empty-handed
    var target: SimObject    # null for cell targets
    var cell: Vector2i
    var world: SimWorld

class SimRuleTable:
    static func from_json(data: Variant) -> SimRuleTable
    func matches(ctx: SimRuleContext) -> Array[SimRule]   # declaration order
    func first_match(ctx: SimRuleContext) -> SimRule      # null if none
    func apply(rule: SimRule, ctx: SimRuleContext) -> void  # runs effects, emits events
```

`SimRule` mirrors the JSON one-for-one: `id, verb, held_tags, held_conditions, target_tags, target_conditions, target_cell_hazard, actor_conditions, range_check, zone, duration_s, noise, effects`. Effect verbs per spec §7: `set · move · tip · break · spawn_hazard · hazard · emit_noise · light · held · hide_actor · status · start_timer · discovery · collect`.

```gdscript
class SimVerbs:
    const VERB_IDS := ["inspect", "grab", "push", "open", "toggle",
                       "hide", "throw", "use-held-on", "drop"]

    static func availability(world, actor, target) -> Dictionary
        # { verb_id: { "available": bool, "rule_id": String, "duration_s": float } }
        # every verb id present — the wheel needs the faded slots too
    static func is_available(world, actor, verb: String, target) -> bool
    static func valid_pairs(world) -> Array   # [{verb, object_id}] for the completion checklist
```

`availability()` is the **single** function behind the wheel, the solver's candidate generator, and the interactions checklist. One implementation, three consumers.

---

## 6. Actors, grid, hazards

```gdscript
class SimActor:
    var id: String                # "player" or the attacker profile id
    var pos: Vector2i
    var facing: Vector2i
    var holding: String           # object id, or ""
    var hidden_in: String         # object id, or ""
    var status: Dictionary        # { effect_name: until_tick }
    var durability: int
    var walk_speed: float         # tiles/s, from JSON
    var alive: bool
    var action: SimAction         # current scheduled action, or null

    func has_status(name: String) -> bool
    func apply_status(name: String, for_s: float) -> void
    func is_vulnerable() -> bool  # prone | stunned | blinded | burning | electrocuted | pinned

class SimPlayer extends SimActor:
    var never_seen: bool
    var damage_taken: int

class SimGrid:                    # pure geometry; knows nothing about objects
    func in_bounds(c: Vector2i) -> bool
    func cell_type(c: Vector2i) -> int                  # FLOOR | WALL | VOID
    func distance(a: Vector2i, b: Vector2i) -> int      # Chebyshev — see §7.2
    func path(from, to, blocked: Callable, extra_cost: Callable) -> Array[Vector2i]
    func has_los(from, to, blocks_sight: Callable) -> bool   # Bresenham
    func zone_of(c: Vector2i) -> String
    func zone_center(name: String) -> Vector2i

class SimHazardField:
    func at(c: Vector2i) -> Dictionary   # {wet, slippery, burning, gas, shock, trip, concealed}
    func cells(layer: String) -> Array[Vector2i]
    func spawn(layer: String, c: Vector2i, for_s: float) -> void
    func step(world) -> void             # spread per content/systems.json
```

`SimGrid` takes object-dependent queries as `Callable`s. That keeps geometry independently testable and stops object knowledge leaking into pathing.

---

## 7. Decisions to approve

### 7.1 Two files not listed in `CLAUDE.md`

- **`sim/hazards.gd`** — `CLAUDE.md` puts hazard spread in `world.gd`. Six layers with their own spread rules is enough surface to own a file and be unit-tested without a world. `SimWorld` owns the instance; the layout is unchanged in spirit.
- **`sim/content.gd`** — the injection point for `tags.json`, `rules.json`, `verbs.json`, `systems.json`, `rubric_defaults.json`. Without it every constructor grows five arguments.

### 7.2 Ambiguities, resolved the data-driven way

| # | Ambiguity | Chosen reading |
|---|---|---|
| 1 | `content/systems.json` appears in spec §4 and §14 but not in `CLAUDE.md`'s content list | Create it. Global tuning defaults; a room's `systems` block overrides per key. |
| 2 | M1 says "the eight verbs"; the wheel is 8 slots **plus** Inspect at centre | Nine verb ids. `inspect` is a verb like any other and goes through the rule table. |
| 3 | Range metric for "throw range 5", "sight 6" | Chebyshev (8-connected) distance everywhere. One metric, no per-site choice. |
| 4 | `range_check: "cord_range"` names a property on the held object | Generalised: `range_check` is *any* numeric key in `props`. No toaster-shaped code. |
| 5 | Room 1 §5.1: counter objects reach 8-connected, floor objects 4-connected | Object property `props.reach: 4 \| 8`, default `4`, authored in room JSON. |
| 6 | Rugs are walkable but are objects with a footprint | Object property `props.walk_over: true` excludes the footprint from occupancy. |
| 7 | Status durations are seconds; the sim runs in ticks | Stored as `until_tick`. Seconds cross the boundary only at `apply_status()`. |

### 7.3 M1 boundaries

In: grid · A* · LOS · objects · tags · rules · verbs · actors · scheduling · hazards · events · timer · RNG · `tools/play_headless.gd` · Room 1 JSON + the full rule set.
Out: attacker (`sim/attacker/`), `outcome.gd`, the solver, anything in `game/`.

### 7.4 Acceptance, restated as tests

- One gdUnit4 test per rule id in `rules.json`.
- `tests/determinism/` — same room, same intents, same seed, run twice, `events.to_lines()` identical.
- Loading Room 1 prints the valid `(verb, object)` pair count (spec target ≈ 70).
- Sink on → kitchen wet cells fill in ~40 s in the event log.
- Toaster thrown into wet → `hazard_spawn` shock events on the connected wet cells.

### 7.5 Split

**Agent A** grid, LOS, A*, actors, action scheduling. **Agent B** objects, tags, rules, verbs, hazards. **Agent C** tests as A and B land, `lint_room.gd` schema rules, `tools/play_headless.gd`. Shared first commit: `sim/events.gd` + `sim/rng.gd` + `sim/content.gd`, so both agents have the bus and the seed before they diverge.
