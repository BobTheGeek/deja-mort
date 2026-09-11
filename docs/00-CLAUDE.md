# CLAUDE.md — DÉJÀ MORT

You are working on DÉJÀ MORT (slug `deja-mort`; tagline: *You've died here before.*), a die-and-retry room-survival puzzle game in Godot 4 (GDScript). Full design and spec live in `/docs`. Read `docs/02-technical-spec.md` before touching `sim/`.

## Non-negotiable architecture

- `sim/` is **pure logic**. Classes extend `RefCounted`, never `Node`. No `get_tree()`, no signals to the scene tree, no `Input`, no rendering, no `randf()` without the injected `Rng`. The sim must run under `godot --headless -s` with zero scene loaded.
- `content/` is **data only** (`.json`). Rooms, objects, attacker profiles, rules, campaigns. No GDScript in `content/`.
- `game/` is **presentation**. It reads sim state and renders it. It never decides an outcome. If you find yourself writing game logic in `game/`, stop and move it to `sim/`.
- Communication from sim to presentation is the **event bus** (`sim/events.gd`): the sim emits typed event records; presentation subscribes. Sound, animation, and UI are all consumers of the same events the attacker's perception consumes.

## Hard rules

1. **No object-specific code.** Objects are `tags[] + state{}`. Behavior is `(verb, actor_holding_tags, target_tags, conditions) -> effects` in `content/rules.json`. Need a special case? Add a tag or a rule. Do not add `if object.id == "toaster"`.
2. **Determinism.** Same room + same action sequence + same seed = same outcome, always. The solver and tests depend on this.
3. **The solver must pass before a room merges.** `tools/solve.gd` must find every authored solution in `rooms/<room>.json` and report unauthored wins. Run it: `godot --headless -s tools/solve.gd -- content/rooms/room_01_studio.json`.
4. **Rule changes re-verify all rooms.** Any change to `content/rules.json`, `content/tags.json`, or `sim/` runs the full solver suite in CI. A broken authored solution is a failing build.
5. **Tuning numbers are data.** Durations, ranges, patience, spread rates all live in JSON, never as literals in GDScript.

## Project layout

```
project.godot
sim/            pure simulation (RefCounted only)
  grid.gd       tile grid, occupancy, LOS, pathfinding (own A*, not AStarGrid2D — headless-safe)
  world.gd      room state: objects, zones, timer, weather-like systems (wet spread, fire, gas)
  objects.gd    object model, tag queries
  rules.gd      rule table loading + matching + effect application
  verbs.gd      the eight verbs and availability computation
  actor.gd      shared actor state (player + attacker): position, holding, status effects
  player.gd
  attacker/
    perception.gd
    planner.gd  GOAP planner
    actions.gd  attacker action library
    memory.gd   none / notice / full
  events.gd     event records + bus
  outcome.gd    win/lose detection, star rubric evaluation, completion tracking
  rng.gd        injected seeded RNG
content/
  tags.json
  rules.json
  verbs.json
  attackers/*.json
  rooms/*.json
  campaigns/*.json
  rubric_defaults.json
game/           Godot scenes: iso camera, room renderer, wheel UI, HUD, notebook, win screen, audio
tools/
  solve.gd      headless solver
  verify_all.gd runs solver on every room
  lint_room.gd  schema + reference validation
tests/          gdUnit4 tests for sim
docs/           this handoff
```

## Working conventions

- One PR per task. Small. Include the solver output in the PR description when content changed.
- Write the test first for any sim change. `tests/` uses gdUnit4.
- Greybox first: cubes, capsules, and a light. No asset work until Milestone 3.
- When a spec is ambiguous, prefer the interpretation that keeps behavior in data. Flag the ambiguity in the PR rather than silently choosing.
- Do not add features not in the current milestone (`docs/07-milestones.md`). Note ideas in `docs/BACKLOG.md`.
- Never commit paid asset packs to the repo. `assets/paid/` is gitignored; document the source in `assets/README.md`.

## Godot specifics

- Godot 4.x latest stable. Renderer: **Mobile** (set in project.godot on day one; do not use Forward+).
- Headless runs: `godot --headless -s <script.gd>`. Sim scripts must not `preload` scenes.
- Camera: `Camera3D` orthographic, rotation (-35.264°, 45°, 0) for true isometric. One `DirectionalLight3D` or `OmniLight3D` with shadows. Vignette via a post-process quad or CanvasLayer shader.
- Input is a single pointer: mouse click, touch tap, or controller cursor. The wheel is the only action UI.
