# First Light Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Direction A — First Light for Room 1 exactly as approved in `docs/VISUAL-DIRECTIONS.md`, ending with the regenerated acceptance-shot set for Bob's sign-off.

**Architecture:** Data-first. The grade (camera, light, palette, post) and both M4 gaps (collectible, dust) are `content/` changes; fidelity replaces nine load-bearing meshes with agent-built `.glb`s in a new `studio/` pack. `game/room_renderer.gd` gains **no code** — it already reads every lever. Tests pin structure (scale, mesh existence, recolour landing, camera resolution); the art values themselves are judged by `tools/capture.gd` shots, the way M4 was.

**Tech Stack:** Godot 4.7.2-stable · GDScript · gdUnit4 6.2.1 · Blender 4.x Python API → glTF 2.0 (`.glb`) · JSON content.

**Spec:** `docs/VISUAL-DIRECTIONS.md` (Direction A, all nine elements). Approved style frame: `docs/reference/first-light-frame-v2.webp`.

**Pre-commit risk check — done, passes.** Direction A's one flagged risk was whether the Kenney kit's GLB material names are usable for recolouring. All ten mass models carry named, texture-free materials (`wood`, `metal`, `metalLight`, `metalDark`, `carpet`, `carpetWhite`, `glass`, `_defaultMat`, `lamp`); the Food Kit's single `colormap` texture is why existing entries use `"*"` and node names. No mesh-replacement fallback is needed for recolour.

---

## Global Constraints

- Godot **4.7.2-stable**; gdUnit4 **6.2.1** (`CLAUDE.md:87`).
- Desktop **Mobile** renderer; phone builds **Compatibility** — `renderer/rendering_method="mobile"`, `renderer/rendering_method.mobile="gl_compatibility"` (`project.godot:51-53`). No Forward+.
- Compatibility ceilings that bind every task: **8 omnis per mesh**, no PCSS, no decals, no debanding. **CPUParticles3D only** (`tests/game/effects_test.gd:68-75`).
- `content/` is data only; `game/` holds no art values; **no object ids in code** (`CLAUDE.md:8,14`).
- Brand-bearing colours are `$TOKEN` references to `game/theme/brand.gd`; never inline (`assets/README.md:63-74`; `game/visuals.gd:59-92`).
- `studio/` meshes: **1 unit = 1 m**, origin at footprint centre, y = 0 at floor (`docs/06:53`); `models.studio.metres_per_unit: 1.0` is mandatory or `_pack_scale` silently shrinks-to-fit (`game/room_renderer.gd:418-433`).
- `models.max_overhang_m` is **0.6** (`content/visuals.json:372`).
- Any `content/rules.json` change re-verifies every room (`CLAUDE.md:17`): `verify_all` must report **3 of 3** and tightness **47.1 / 62.0 / 66.0s** unchanged unless explained (`docs/M4-CLOSEOUT.md:101`).
- Art spend **$0** against the demo's **under-$100** budget (`docs/06:49`). No paid packs, no downloads without Bob's say-so.
- Screenshots **1920x1080** via `tools/capture.gd` (`docs/M4-CLOSEOUT.md:47`; `tools/capture.gd:53-62`).
- One PR, small commits, test-first where code changes (`CLAUDE.md:59-60`). Commit `.glb` **and** its generated `.glb.import` sidecar (all 140 pack models ship theirs).
- **Prerequisite:** Blender 4.x on the machine (`blender --version`). It is not on PATH today. Tasks 1–3 and 7 are data-only and proceed without it; Tasks 4–6 block until Blender exists, and installing it needs Bob's go-ahead.

## Review Focus

1. **GLB export drift** — scale, Y-up, or origin wrong makes a model float, sink, or swallow its neighbours while every JSON key looks right. Bounded by the scale catalogue (Tasks 4–6), mesh existence (`tests/game/mesh_test.gd:25-35`), and the acceptance shots.
2. **Non-16:9 framing after the camera step** — the 4:3 plinth sits close to the frame edge today (`docs/screenshots/aspect_4x3.png`); a wrong margin crops the room on iPad. Pinned by the camera-resolution test (Task 1) and a fresh 4:3 capture (Task 8).
3. **Dead recolour rules** — a rule keyed to a material name that matches nothing paints nothing and looks like a design choice. Pinned by the coverage test (Task 3).
4. **Dust leaking into gameplay** — an unknown hazard layer must stay presentation-only. Pinned by the particle tests (Task 7) plus the unchanged solver report.
5. **Particles and banding on a phone** — CPUParticles3D only, one shadow-caster, grain as dither. Pinned by `effects_test` and the 320 px review (Tasks 7–8).

---

### Task 1: Camera step and the resolved-size guard

**Files:**
- Modify: `content/visuals.json` — `camera.frame_margin`
- Create: `tests/game/iso_camera_test.gd`

**Interfaces:**
- Produces: resolved orthographic size **11.0** (from 12.0). Consumed by `picking_test.gd:43` pixel maths and `RoomRenderer.outline_thickness()` (`game/room_renderer.gd:645-648`), both of which read `camera.size` = 11.0.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GdUnitTestSuite

## First Light §3: frame_margin -0.5 takes the resolved orthographic size from
## 12.0 to 11.0 (game/iso_camera.gd:11-12); the true-iso angles never move.

func test_the_camera_resolves_to_the_approved_size() -> void:
	var v := GameVisuals.load_table()
	var cam: IsoCamera = auto_free(IsoCamera.new())
	cam.setup(v, 12, 10)
	assert_float(cam.size).is_equal_approx(11.0, 0.01)
	assert_float(cam.rotation_degrees.x).is_equal_approx(v.number("camera.pitch_deg"), 0.01)
	assert_float(cam.rotation_degrees.y).is_equal_approx(v.number("camera.yaw_deg"), 0.01)
```

- [ ] **Step 2: Run it to see it fail**

Run: `tools/run_tests.sh --add tests/game/iso_camera_test.gd`
Expected: FAIL — `12.0` is not approx `11.0`.

- [ ] **Step 3: Apply the data**

`content/visuals.json` `camera.frame_margin`: **0.0 → -0.5**. Leave `camera.size` 11.0 and the angles untouched.

- [ ] **Step 4: Run tests to verify**

Run: `tools/run_tests.sh --add tests/game/iso_camera_test.gd`
Expected: PASS.
Run: `tools/run_tests.sh --add tests/game/picking_test.gd`
Expected: PASS. The picking harness used `camera.size` 11.0 while the real camera resolved to 12.0 — it was ~9% optimistic in area; it is now exact. If an object is newly reported thin, fix that object's mesh (Task 5/6), never lower `object.min_clickable_px` (`content/visuals.json:361`).

- [ ] **Step 5: Commit**

```bash
git add content/visuals.json tests/game/iso_camera_test.gd
git commit -m "feat: bring the camera in to the approved First Light framing"
```

---

### Task 2: Palette and post grade

**Files:**
- Modify: `content/visuals.json`
- Modify: `content/rooms/room_01_studio.json`

**Interfaces:**
- Produces: the graded values every later capture is judged against. No new keys beyond `object.by_tag.aerosol`.

- [ ] **Step 1: Apply the values**

`content/visuals.json`:

| key | old | new |
|---|---|---|
| `light.attenuation` | 1.1 | 1.4 |
| `ambient.energy` | 0.85 | 0.60 |
| `ambient.color` | [0.4, 0.46, 0.58] | [0.34, 0.40, 0.56] |
| `wall.color_far_x` | [0.62, 0.63, 0.66] | [0.58, 0.60, 0.64] |
| `wall.color_far_z` | [0.4, 0.42, 0.4] | [0.33, 0.36, 0.38] |
| `floor.color` | [0.52, 0.4, 0.3] | [0.56, 0.42, 0.30] |
| `post.saturation` | 0.62 | 0.55 |
| `post.contrast` | 1.06 | 1.10 |
| `vignette.strength` | 0.55 | 0.62 |
| `vignette.grain` | 0.03 | 0.035 |

`content/rooms/room_01_studio.json` `lighting.bulb`: `energy` **5.5 → 6.0**, `range` **17.0 → 14.0** (height 2.35 and cell [5,4] stay).

Append to `object.by_tag`, after `chainable`: `"aerosol": {"color": [0.70, 0.70, 0.72]}` so the hairspray stops resolving to the generic `carryable` grey (later tags win — `game/visuals.gd:108-119`).

Do **not** touch `dark.light_energy` 0.35 or `dark.ambient_energy` 0.14: the switch is pillar, not mood.

- [ ] **Step 2: Verify**

No test is written for the values themselves — they are judged in Task 8 against the approved style frame, the repo's M4 convention. Structure check:
Run: `tools/run_tests.sh --add tests/game/lighting_test.gd`
Expected: PASS — exactly one bulb, shadows on, the switch still darkens it, the room still declares its bulb.

- [ ] **Step 3: Commit**

```bash
git add content/visuals.json content/rooms/room_01_studio.json
git commit -m "feat: grade Room 1 for First Light - tighter pool, cold structure"
```

---

### Task 3: Recolour expansion with a coverage proof

**Files:**
- Modify: `content/visuals.json` — `models.recolor`
- Modify: `tests/game/recolor_test.gd`

**Interfaces:**
- Produces: ten new entries under `models.recolor`, keyed by `kenney/<model>`, matched by material name. Values: walnut `[0.45, 0.34, 0.22]`; wool `[0.36, 0.37, 0.40]`; steel `[0.62, 0.63, 0.64]` with `metallic: 0.4, roughness: 0.5`; ceramic `[0.60, 0.61, 0.60]`.

- [ ] **Step 1: Write the failing tests**

Add to `tests/game/recolor_test.gd`:

```gdscript
## Every rule must land on something. A rule keyed to a material that no longer
## exists paints nothing and looks like a design choice.
func test_every_recolour_rule_lands_on_a_rendered_surface() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var table: Dictionary = GameVisuals.load_table().get_value("models.recolor", {})
	for mesh_name in table:
		var id := ""
		for obj in world.objects.all():
			if str(obj.prop("mesh", "")) == mesh_name:
				id = obj.id
				break
		assert_str(id).override_failure_message(
			"%s is recoloured but no room object uses it" % mesh_name).is_not_empty()
		var painted := false
		for child in _descendants(renderer.object_node(id)):
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					if mi.get_surface_override_material(i) != null:
						painted = true
		assert_bool(painted).override_failure_message(
			"%s recolour matched no surface" % mesh_name).is_true()


func test_the_bed_cover_is_wool_and_the_frame_is_walnut() -> void:
	var bed := _rendered(F.world()).object_node("bed")
	var cover: Variant = _surface_albedo(bed, "cover")
	assert_object(cover).is_not_null()
	assert_bool((cover as Color).b > (cover as Color).r).override_failure_message(
		"the cover is not cool wool: %s" % [cover]).is_true()
	var wood: Variant = _surface_albedo(bed, "bedDouble(Clone)")
	if wood is Color:
		assert_bool((wood as Color).r > (wood as Color).b).override_failure_message(
			"the frame is not warm walnut: %s" % [wood]).is_true()
```

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh --add tests/game/recolor_test.gd`
Expected: FAIL — rules absent; the coverage loop finds nothing painted for the ten models.

- [ ] **Step 3: Add the entries**

For each model, paint by material name (leave `glass`/`lamp` alone):

| model | materials → family |
|---|---|
| `kenney/bedDouble` | `wood` → walnut; `carpet`, `carpetWhite` → wool |
| `kenney/loungeSofaLong` | `carpet` → wool; `wood` → walnut |
| `kenney/bookcaseClosedWide` | `wood` → walnut |
| `kenney/tableCoffee` | `wood` → walnut |
| `kenney/televisionModern` | `metalDark` → steel (roughness 0.45); `metal` → steel |
| `kenney/kitchenFridge` | `metalLight` → ceramic; `metalDark`, `metal` → steel |
| `kenney/kitchenStove` | `metal`, `metalDark` → steel; `wood` → walnut |
| `kenney/kitchenSink` | `wood`, `woodDark` → walnut; `metal`, `metalDark`, `metalLight` → steel; `_defaultMat` → ceramic |
| `kenney/sideTableDrawers` | `wood` → walnut; `_defaultMat` → ceramic; `metal` → steel |
| `kenney/lampRoundFloor` | `metal` → steel |

Surface overrides sit under the state repaint layer, so burning/broken still read (`game/room_renderer.gd:978-1008`).

- [ ] **Step 4: Run tests to verify**

Run: `tools/run_tests.sh --add tests/game/recolor_test.gd`
Expected: PASS, including the three existing recolour tests (knife block, pan, toaster).

- [ ] **Step 5: Commit**

```bash
git add content/visuals.json tests/game/recolor_test.gd
git commit -m "feat: recolour the room's mass furniture into the First Light families"
```

---

### Task 4: Studio pack + the collectible (first authored asset)

**Files:**
- Create: `tools/blender/bubble_token.py`
- Create: `assets/models/studio/bubble_token.glb` (+ `.glb.import`)
- Modify: `content/visuals.json` — `models.studio.metres_per_unit`
- Modify: `content/rooms/room_01_studio.json` — `bubble_token.mesh`
- Modify: `tests/game/scale_test.gd`, `tests/game/mesh_test.gd`

**Interfaces:**
- Produces: `models.studio.metres_per_unit: 1.0` (consumed by every later mesh swap); mesh id `studio/bubble_token`. The collectible look repaints it amber at emission 1.4 (`content/visuals.json:281-286`; `game/room_renderer.gd:1011-1016`), so **shape is the deliverable** — the glass read comes from silhouette, not material.

- [ ] **Step 1: Write the failing tests**

`tests/game/scale_test.gd`:

```gdscript
func test_the_studio_pack_declares_its_scale() -> void:
	var per_unit := GameVisuals.load_table().number("models.studio.metres_per_unit", 0.0)
	assert_float(per_unit).override_failure_message(
		"agent-built models must declare 1 unit = 1 m, or they shrink to fit").is_equal(1.0)
```

`tests/game/mesh_test.gd` — change the greybox test's object from `bubble_token` to `umbrella`, then add:

```gdscript
func test_the_collectible_is_a_model_now() -> void:
	var bare := F.world().objects.by_id("bubble_token")
	assert_str(str(bare.prop("mesh", ""))).is_equal("studio/bubble_token")
	assert_int(_mesh_instances(_rendered(F.world()).object_node("bubble_token"))).is_greater(0)
```

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh --add tests/game/scale_test.gd`
Expected: FAIL — no `models.studio` key.
Run: `tools/run_tests.sh --add tests/game/mesh_test.gd`
Expected: FAIL — `bubble_token` names no mesh.

- [ ] **Step 3: Author the model**

Prerequisite: `blender --version` succeeds. The script is committed with the asset (`assets/README.md:8`) and writes its output relative to the repo root (`Path(__file__).resolve().parents[2]`).

Spec: a bubble token **0.16 m tall, 0.13 m wide** (sized against the Food Kit's soda can, `assets/README.md:89`), rounded body with a short neck, one flat material, origin at footprint centre, base at z = 0, front +Z. Export GLB to `assets/models/studio/bubble_token.glb`.

Run: `blender -b --python tools/blender/bubble_token.py`

- [ ] **Step 4: Wire it**

Add `content/visuals.json` `models.studio.metres_per_unit: 1.0`. Set `content/rooms/room_01_studio.json` `bubble_token` `"mesh": "studio/bubble_token"` (it has none today). Run `godot --headless --import`; commit the `.glb` and its `.glb.import`.

- [ ] **Step 5: Run tests to verify**

Run: `tools/run_tests.sh --add tests/game`
Expected: PASS — mesh exists and namespaced, the pack scale is declared, the collectible still declares emission > 0.

- [ ] **Step 6: Commit**

```bash
git add tools/blender/bubble_token.py assets/models/studio/bubble_token.glb assets/models/studio/bubble_token.glb.import content/visuals.json content/rooms/room_01_studio.json tests/game/scale_test.gd tests/game/mesh_test.gd
git commit -m "feat: add the studio pack and a real model for the bubble token"
```

---

### Task 5: The kitchen set (counter run, toaster, pan)

**Files:**
- Create: `tools/blender/{counter_stove,counter_drawer,counter_sink,counter_block,toaster,frying_pan}.py`
- Create: `assets/models/studio/{counter_stove,counter_drawer,counter_sink,counter_block,toaster,frying_pan}.glb` (+ `.import`)
- Modify: `content/rooms/room_01_studio.json` — `stove`, `counter_drawer`, `sink`, `counter_knife`, `toaster`, `frying_pan`: `mesh` + `mesh_yaw: 0`
- Modify: `tests/game/scale_test.gd`, `tests/game/recolor_test.gd`

**Interfaces:**
- Produces: mesh ids `studio/counter_{stove,drawer,sink,block}`, `studio/toaster`, `studio/frying_pan`. All authored front **+Z**, so every swapped object sets `mesh_yaw: 0` (today: stove 0, drawer 0, sink 0, block 0, toaster 0, pan none — the yaw is made explicit for the family).

- [ ] **Step 1: Write the failing tests**

`tests/game/scale_test.gd` — add to `REAL_SIZES`:

```gdscript
"stove": {"axis": "height", "min": 0.80, "max": 1.00},
"sink": {"axis": "height", "min": 0.75, "max": 0.95},
"counter_drawer": {"axis": "height", "min": 0.80, "max": 1.00},
"frying_pan": {"axis": "floor", "min": 0.35, "max": 0.55},
```

`tests/game/recolor_test.gd` — the pan and toaster become authored models, so their tests read the shipped materials instead of overrides: add `_base_albedo(node, child_name, surface)` (same walk as `_surface_albedo`, reading `mi.mesh.surface_get_material(i)`), then assert the pan's darkest value < 0.2 and the toaster has ≥ 2 distinct surface values with the brightest > 0.7. Keep the knife-block and oil tests untouched.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh --add tests/game/recolor_test.gd`
Expected: FAIL — the Kenney pan/toaster do not read as authored flat materials.
(The scale ranges are guards; some may already pass with the pack models — they bound the new meshes.)

- [ ] **Step 3: Author the six models**

| model | dimensions (m) | read |
|---|---|---|
| `counter_stove` | 1.0 × 0.6 × 0.9 | ceramic body, dark worktop, four burner discs |
| `counter_drawer` | 1.0 × 0.6 × 0.9 | walnut front, two drawer seams + handles, ceramic carcass |
| `counter_sink` | 1.0 × 0.6 × 0.9 | ceramic carcass, recessed basin, short tap |
| `counter_block` | 1.0 × 0.6 × 0.9 | walnut cabinet, five knife slots on top |
| `toaster` | 0.29 × 0.19 × 0.19 | silver body `[0.70, 0.71, 0.73]`, dark slot `[0.12, 0.12, 0.13]` |
| `frying_pan` | 0.46 across × 0.05 + handle | carbon `[0.09, 0.09, 0.10]` |

Flat materials only, no textures; 2–3 materials per model where a part must read (the shipped kit does this: `bedDouble` carries four). Origin footprint-centre, base z = 0, front +Z. Run each script with `blender -b --python <script>`, then `godot --headless --import`.

- [ ] **Step 4: Swap the meshes**

Set the six room objects' `mesh` to the `studio/...` ids and `mesh_yaw: 0`. The counter's footprint is 1 m per unit; the authored depth 0.6 m leaves a 0.2 m air gap at the wall, matching the pack's own placement and inside `models.max_overhang_m` 0.6.

- [ ] **Step 5: Run tests to verify**

Run: `tools/run_tests.sh --add tests/game`
Expected: PASS — real sizes within range, no thin targets, authored materials read right, every named mesh exists.

- [ ] **Step 6: Commit**

```bash
git add tools/blender assets/models/studio content/rooms/room_01_studio.json tests/game/scale_test.gd tests/game/recolor_test.gd
git commit -m "feat: author the kitchen counter run, toaster and pan for First Light"
```

---

### Task 6: The bookshelf

**Files:**
- Create: `tools/blender/bookshelf.py`, `assets/models/studio/bookshelf.glb` (+ `.import`)
- Modify: `content/rooms/room_01_studio.json` — `bookshelf` `mesh` + `mesh_yaw: 0`
- Modify: `tests/game/scale_test.gd`

**Interfaces:**
- Produces: `studio/bookshelf` — 0.8 × 0.3 × 1.8 m, five slats; load-bearing for the `disable_shelf` ending and the only tipping mesh in the set.

- [ ] **Step 1: Write the failing guard**

Add `"bookshelf": {"axis": "floor", "min": 0.60, "max": 1.20}` to `REAL_SIZES`.

Run: `tools/run_tests.sh --add tests/game/scale_test.gd`
Expected: PASS or FAIL depending on the Kenney piece; the guard exists for the authored mesh.

- [ ] **Step 2: Author and swap**

0.8 wide × 0.3 deep × 1.8 tall, walnut, five shelf slats, front +Z, origin footprint-centre, base z = 0. Swap the room mesh (today `kenney/bookcaseClosedWide`, `mesh_yaw` 90) and set `mesh_yaw: 0`. Import.

- [ ] **Step 3: Run tests to verify**

Run: `tools/run_tests.sh --add tests/game/scale_test.gd tests/game/tipping_test.gd tests/game/picking_test.gd`
Expected: PASS — the shelf measures within range, tips the same way, still clickable.

- [ ] **Step 4: Commit**

```bash
git add tools/blender/bookshelf.py assets/models/studio/bookshelf.glb assets/models/studio/bookshelf.glb.import content/rooms/room_01_studio.json tests/game/scale_test.gd
git commit -m "feat: author the bookshelf that carries the disable ending"
```

---

### Task 7: Dust, the data-only way

**Files:**
- Modify: `content/visuals.json` — `hazard.layers.dust`
- Modify: `content/rules.json` — `tip_second.effects`
- Modify: `content/systems.json` — `dust_s`
- Modify: `tests/game/effects_test.gd`

**Interfaces:**
- Produces: hazard layer `"dust"` (visual only) and system key `"dust_s": 0.8`. The renderer materialises any declared layer (`game/room_renderer.gd:1019-1052`). Dust must stay out of `sim/attacker/perception.gd:6` `HAZARD_LAYERS` and out of the `hazard_effects` system table — no gameplay effect, no solver drift.

- [ ] **Step 1: Write the failing tests**

`tests/game/effects_test.gd` — add `"dust"` to the `test_the_lively_hazards_declare_particles` loop, and add:

```gdscript
func test_a_dust_cell_puffs_on_screen() -> void:
	var world := F.world()
	world.hazards.spawn("dust", Vector2i(1, 3), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	assert_int(_particle_systems(renderer)).override_failure_message(
		"a dust cell produced no puff").is_greater(0)
```

Run: `tools/run_tests.sh --add tests/game/effects_test.gd`
Expected: FAIL — no `dust` layer in `hazard.layers`.

- [ ] **Step 2: Add the layer**

`content/visuals.json` `hazard.layers.dust`:

```json
"dust": {
  "color": [0.58, 0.54, 0.48],
  "alpha": 0.08,
  "particles": {
    "amount": 10, "lifetime": 0.8, "velocity": 0.6, "spread": 18.0,
    "scale": 0.12, "gravity": 0.25, "color": [0.62, 0.58, 0.52]
  }
}
```

- [ ] **Step 3: Trigger it from the shelf landing**

Append to `tip_second.effects` in `content/rules.json` (today: `tip` + `status`): `{"op": "hazard", "layer": "dust", "where": "tips_onto", "for_system": "dust_s"}`. Add `"dust_s": 0.8` to `content/systems.json` beside `"forever_s": 9999`.

- [ ] **Step 4: Verify the suite and the solver**

Run: `tools/run_tests.sh --add tests/game/effects_test.gd`
Expected: PASS.
Run: `godot --headless -s tools/lint_room.gd`
Expected: PASS, 0 errors.
Run: `godot --headless -s tools/rule_coverage.gd`
Expected: PASS, 38 of 38.
Run: `godot --headless -s tools/verify_all.gd`
Expected: PASS, 3 of 3 authored solutions, tightness 47.1 / 62.0 / 66.0s. If tightness moves, stop and report — dust is meant to be inert.

- [ ] **Step 5: Commit**

```bash
git add content/visuals.json content/rules.json content/systems.json tests/game/effects_test.gd
git commit -m "feat: dust when the shelf lands, through the hazard layer"
```

---

### Task 8: Acceptance shots and sign-off pack

**Files:**
- Modify: `docs/screenshots/m4_{lit,dark,flood,fire,tipped,death,secured}.png`
- Modify: `docs/screenshots/aspect_4x3.png` (and `aspect_19x9.png` if the set carries it)
- Modify: `docs/VISUAL-DIRECTIONS.md` — status line only

**Interfaces:**
- Consumes: every task above. Produces: the artefacts Bob judges, and nothing else.

- [ ] **Step 1: Run all four CI commands**

```bash
godot --headless --import
godot --headless -s tools/lint_room.gd
tools/run_tests.sh
godot --headless -s tools/rule_coverage.gd
godot --headless -s tools/verify_all.gd
```

Expected: lint 0 left; tests 0 failures; coverage 38 of 38; verify_all 3 of 3 with tightness 47.1 / 62.0 / 66.0s.

- [ ] **Step 2: Capture the seven shots at 1920x1080**

Use `tools/capture.gd` and reproduce each M4 state; record the exact command for every shot in the PR description. Verify each against the capture's own `state:` line (`tools/capture.gd:160-179`):

- `m4_lit` — default scene, ~2 s.
- `m4_dark` — toggle `light_switch` (cell 0,7), capture after.
- `m4_flood` — toggle `sink` (cell 4,1), wait ≥ 27 s.
- `m4_fire` — open nightstand (10,5), grab `lighter`, use-held-on `curtains` to ignite, capture while burning.
- `m4_tipped` — push `bookshelf` `tip_first` at (1,7), wait, `tip_second`; capture after landing (dust visible).
- `m4_death` — no input, `--speed` until `alive=false`, mid-beat.
- `m4_secured` — lock `front_door`, chain `door_chain`; capture.

Then the aspect recapture: `godot --path . --resolution 1440x1080 -s tools/capture.gd -- aspect_4x3 2.0` (the capture tool owns the window; a `--resolution` on the command line is how the aspect set was made). Confirm no crop.

- [ ] **Step 3: Judge against the doc**

Downscale each to 320 px wide (`sips -Z 320`) and check § A.9: stove/drawer/sink/block nameable in one glance; two wall planes separate in the dark; dust visible in `m4_tipped`; every shot's story survives.

- [ ] **Step 4: Update the status line, not the verdict**

In `docs/VISUAL-DIRECTIONS.md`, change the status paragraph to: style frame approved; acceptance shots regenerated on <date>; **awaiting Bob's sign-off**. Do not write "approved" — only Bob can.

- [ ] **Step 5: Commit and present**

```bash
git add docs/screenshots docs/VISUAL-DIRECTIONS.md
git commit -m "feat: regenerate the acceptance shot set for First Light sign-off"
```

Hand Bob the seven image paths plus the doc's per-shot "right looks like" list. Stop.

---

## Notes for the executor

- Tasks 1–3 and 7 are data-only and independently shippable; they carry most of the visible change and none of the Blender dependency.
- No object is added, removed or moved. The solver is re-verified only because `content/rules.json` changes (Task 7), and it must stay 3 of 3.
- Tasks 4–6 are blocked on `blender --version`. Until Bob approves installing Blender, do them last — or leave them out of the PR and file the rest as "First Light, data pass".
- The M4 shot commands are not recorded in the repo; they are rebuilt from the states named in `docs/M4-CLOSEOUT.md:49-56` and verified by the `state:` line. Put the intents arrays in the PR so the set is reproducible next time.
- Do not touch `dark.*`, `camera.size`, `object.min_clickable_px`, `state_visual`, `hazard.layers` for anything except adding `dust`, or `game/room_renderer.gd`.