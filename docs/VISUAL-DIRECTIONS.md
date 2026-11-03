# Visual Directions — Room 1

**Decision document, 3 Nov 2026.** Three committed directions for leveling up DÉJÀ MORT's look, each specified to the point of approval. Nothing in this document is implemented; no file outside it has changed. Bob picks one (or an order); a direction is approved only against a style frame before any code moves, and against the acceptance shots after.

Derived from the repo, the studio's own peers (`docs/06-art-and-audio-requirements.md:7` — Hitman GO, Monument Valley, Lara Croft GO; "keep the bones, change the mood") and `docs/reference/style-target.png`. Bob has no references of his own, so every proposal below is grounded in a value or a rule that already exists.

**Where the look lives today** (each delta below lands on one of these):

- `content/visuals.json` — `camera`, `light`, `ambient`, `dark`, `floor`/`wall`/`void`, `object.by_tag`, `models` (pack scale + `recolor`), `state_visual`, `hazard.layers`, `vignette`, `base`, `material`, `post`.
- `content/rooms/room_01_studio.json` — 40 objects (counted from `footprint` entries; the backlog's Sept-12 note reads "Thirty-nine objects in a twelve-by-ten room", `docs/BACKLOG.md:46`), `lighting.bulb` (cell [5,4], height 2.35, energy 5.5, range 17.0), three authored solutions.
- `game/room_renderer.gd` — reads all of the above; looks keyed by tags and state, meshes referenced from room JSON, never object ids.
- `assets/README.md` — Brand tokens, CC0/agent-built licence rules, pack scales (Kenney furniture 1 unit = 2 m, Food Kit ≈ 0.45 m).
- `docs/06` — the rules a direction is allowed to rewrite: palette, flat shading, one light, ~80% framing, import conventions.

**The pillars, fixed in all three:** darkness as gameplay (light is information); silhouette readability at phone size; amber `#D9A05B` on void `#0B0C0F`; diorama-in-the-void; Compatibility-renderer performance (`renderer/rendering_method.mobile = "gl_compatibility"`, `project.godot:53`).

**The two open M4 gaps** — every direction covers both: the collectible `bubble_token` (an amber greybox today, `docs/M4-CLOSEOUT.md:18`) and dust (nothing produces it; "a shelf hitting the floor is where it would go", `docs/M4-CLOSEOUT.md:16`).

**One shared plumbing item.** Agent-built models get a new `studio/` pack. `_pack_scale` looks up `models.<pack>.metres_per_unit` and *fits the model into its cells when the key is missing* (`game/room_renderer.gd:418-433`) — the exact doll-furniture failure of the last playtest. So every direction adds `content/visuals.json` `models.studio.metres_per_unit: 1.0` (a new key; only `kenney` and `kenney_food` exist today) and authors at 1 unit = 1 m, origin at footprint centre, y = 0 at floor, one flat material — the `docs/06:53` import convention.

---

## Direction A — FIRST LIGHT

*Near-pure-data: zero new renderer code. Everything below is `visuals.json`, room JSON, or `.glb` assets.*

**1 · Thesis.** The rig is already right; the room needs grading like a photograph — a tighter warm pool, cold structure around it, and every prop a member of a named material family.

**2 · What the player sees.** A quieter, darker room whose warm pool has narrowed to the working half: floor and counters amber-lit, walls falling to cold blue-grey with the corner split clearly drawn. The counter run reads as one built object — stove, drawer, sink and block each carry a handle and a family colour (walnut, wool grey, pale ceramic/steel). The collectible is a small glass bubble that glints when the toaster opens. When the shelf tips, a dust puff settles on the floor where it landed.

**3 · Delta from today.**

- `content/visuals.json` `light.attenuation`: 1.1 → 1.4 — steeper falloff turns a wash into a pool (read at `game/room_renderer.gd:112`; semantics per the Godot 4.7 class reference: 0 = flat brightness, 2 = inverse-square).
- `content/rooms/room_01_studio.json` `lighting.bulb.range`: 17.0 → 14.0 and `lighting.bulb.energy`: 5.5 → 6.0 — same wattage feel, tighter reach (read at `game/room_renderer.gd:110-111`).
- `content/visuals.json` `ambient.energy`: 0.85 → 0.60, `ambient.color`: [0.4, 0.46, 0.58] → [0.34, 0.40, 0.56] — the bulb dominates; shadows go colder (read at `game/room_renderer.gd:87-88`).
- `content/visuals.json` `wall.color_far_x`: [0.62, 0.63, 0.66] → [0.58, 0.60, 0.64]; `wall.color_far_z`: [0.4, 0.42, 0.4] → [0.33, 0.36, 0.38] — deepen the two-plane corner split the renderer already keys on (`game/room_renderer.gd:176-184`).
- `content/visuals.json` `floor.color`: [0.52, 0.4, 0.3] → [0.56, 0.42, 0.30] — the floor catches the pool (read at `game/room_renderer.gd:144`).
- `content/visuals.json` `post.saturation`: 0.62 → 0.55, `post.contrast`: 1.06 → 1.10 — a grade, not a repaint (read at `game/room_renderer.gd:93-94`).
- `content/visuals.json` `models.recolor` — today three keys (`knife-block`, `frying-pan`, `toaster`). Add one entry per mass model (`kenney/bedDouble`, `kenney/loungeSofaLong`, `kenney/bookcaseClosedWide`, `kenney/tableCoffee`, `kenney/televisionModern`, `kenney/kitchenFridge`, `kenney/kitchenStove`, `kenney/kitchenSink`, `kenney/sideTableDrawers`, `kenney/lampRoundFloor`), painting each into three families — walnut ~[0.45, 0.34, 0.22]; wool grey ~[0.36, 0.37, 0.40]; pale ceramic ~[0.60, 0.61, 0.60], steel patterned on the existing toaster entry (`metallic` 0.6, `roughness` 0.35). Repainting is surface-override so the flat shading survives (`game/room_renderer.gd:978-1008`).
- `content/visuals.json` `object.by_tag` — append an `aerosol` look (none exists; the table has 18 keys) after `chainable`, so the hairspray stops resolving to the generic `carryable` grey; later tags win (`game/visuals.gd:108-119`).
- `content/visuals.json` `camera.frame_margin`: 0.0 → -0.5 — the orthographic size resolves as `max(camera.size, 12 + 2 x margin)` (`game/iso_camera.gd:11-12`), so this takes the *resolved* size from 12.0 to 11.0 (~8% closer) without touching the true-iso angles or `camera.size` 11.0.
- `content/visuals.json` `vignette.strength`: 0.55 → 0.62; `vignette.grain`: 0.03 → 0.035 — keeps the tube, adds dither (read at `game/main.gd:170-172`; Compatibility has no debanding, Godot 4.7 renderer docs, so grain is doing real work).
- `content/rooms/room_01_studio.json` `objects[].mesh` swaps to the new `studio/*` models (bullets below), e.g. `stove` `"mesh": "kenney/kitchenStove"` → `"studio/counter_stove"`; `toaster` `"kenney/toaster"` → `"studio/toaster"`; `bubble_token` gains `"mesh": "studio/bubble_token"` (it has none today). Mesh props are presentation-only; the sim never reads them.
- New `room_renderer.gd` capability: **none**. This is the direction's point.

**4 · Asset plan.** Blender-authored `.glb` replacements (agent-built, committed with the generating script, `assets/README.md` Rules — no licence cost). All at 1 unit = 1 m, origin footprint-centre, y = 0 at floor, one flat material.

- `studio/bubble_token.glb` — **gap #1, the collectible**: 0.16 m tall glass bubble (sized against the Food Kit's soda can at 0.16 m, `assets/README.md:89`). Keeps `object.by_tag.collectible` emission 1.4 (`content/visuals.json:281-286`) so it still catches the light (`tests/game/effects_test.gd:130-133`).
- `studio/counter_stove.glb`, `studio/counter_drawer.glb`, `studio/counter_sink.glb`, `studio/counter_block.glb` — the counter run as one family, each 1.0 m wide x 0.6 m deep x 0.9 m tall (footprint is 1 m; real depth overhangs, capped by `models.max_overhang_m` 0.6). Replace `kenney/kitchenStove`, `kenney/kitchenCabinetDrawer`, `kenney/kitchenSink`, `kenney/kitchenCabinet`.
- `studio/toaster.glb` — 0.29 x 0.19 x 0.19 m, replacing `kenney/toaster`.
- `studio/bookshelf.glb` — 1.8 x 0.8 x 0.3 m, replacing `kenney/bookcaseClosedWide` (`mesh_yaw` 90, 1x2 footprint; load-bearing for the `disable_shelf` solution).
- `studio/frying_pan.glb` — 0.46 m across, matching the Food Kit pan measurement (`assets/README.md:89`), replacing `kenney_food/frying-pan`.
- Stays from the packs (CC0, licences at `assets/models/kenney/LICENSE.txt`, `assets/models/kenney_food/License.txt`, `assets/models/quaternius/LICENSE.txt`): bed, sofa, tub, toilet, fridge, doors, window, rug, nightstands, boxes, lamps, the Quaternius figures, the food props.
- Dust (**gap #2**) — data-only, reusing the hazard pipeline. `content/visuals.json`: new `hazard.layers.dust` block with a `particles` spec in the same shape as `hazard.layers.wet` (`content/visuals.json:574-593`). `content/rules.json`: append `{"op": "hazard", "layer": "dust", "where": "tips_onto", "for_system": "dust_s"}` to `tip_second.effects` (today: `tip` + `status`, `content/rules.json:111-123`). `content/systems.json`: new `"dust_s": 0.8` beside `"forever_s": 9999`. The renderer materialises any declared layer with zero code (`game/room_renderer.gd:1019-1052`); the sim applies nothing to a layer missing from `hazard_effects` (`sim/world.gd:764-778`) and the attacker only notes layers he is configured for (`sim/perception.gd:109-119`). Rule change means the full solver suite re-runs (`CLAUDE.md:17`).

**5 · Clutter position.** **Better models** — the second of the backlog's three exits (`docs/BACKLOG.md:48-50`). The counter run gets authored; the mass furniture gets family recolours; no object is removed or moved, so no solver re-verify is owed and the completion counts stay put (the backlog's warning about counts applies only when counts move). Still run `tools/lint_room.gd` and the screenshot set, per `CLAUDE.md:75-84`. Ten stacked objects remain, but each reads by family and handle — which is the second half of Bob's sentence ("Often I can't tell what I am looking at", `docs/BACKLOG.md:44`).

**6 · Phone check.** Everything here is already on the Compatibility path: `StandardMaterial3D` at `material.roughness` 1.0 / `metallic` 0.0 / `specular` 0.0 (unchanged), one shadow-casting omni (unchanged count; Compatibility gives 8 omnis per mesh and multi-pass shadow blending, Godot 4.7 renderer docs), CPUParticles3D only (`game/room_renderer.gd:1055`, enforced by `tests/game/effects_test.gd:68-75`), and Environment adjustments are supported in Compatibility, so the grade survives the phone. Low shadow quality: `light.shadow_bias` 0.04 unchanged; check for acne after the attenuation change and raise the bias in data if seen. No desktop-only effect.

**7 · Cost + risk.** ~4.5–7 agent-days: grade 0.5–1; recolour archaeology 1–1.5; nine Blender models 2.5–4; shots + sign-off 0.5. Money: **$0** — CC0 and agent-built only, deep inside "plausibly under $100" (`docs/06:49`). Single risk: the recolour lever dies where the pack's GLB material names are indistinguishable (the mechanism matches by surface/material name or node name, `game/room_renderer.gd:978-1008`) — inspect the material names of the five heaviest models *before* committing; if they are mush, price those as mesh replacements instead.

**8 · Style frame** (copy-paste; 16:9; no text):

> isometric cutaway diorama of a cramped studio apartment at night, two back walls only, floating on a thin pale plinth in pure black void, low-poly, flat matte shading, no textures, warm amber single bulb pool of light over a kitchen counter run, cold blue-grey walls with two visibly different planes, walnut wood, grey wool and pale ceramic material families, kitchen stove drawer sink and toaster reading as one built run, fridge in the corner by the front door, glass bubble token glinting, bookshelf and couch in muted wool, double bed in the far corner, narrow bathroom with bathtub behind an interior wall, floor lamp, quiet vignette and fine grain, tilt-shift miniature feel, 16:9, no text, no watermark

**9 · Acceptance shots.** Regenerate the M4 set — `m4_lit`, `m4_dark`, `m4_flood`, `m4_fire`, `m4_tipped`, `m4_death` and `m4_secured` (`docs/M4-CLOSEOUT.md:49-56`, `:43`) — via `tools/capture.gd` (the set was produced with `--intents`, `tools/capture.gd:53-62`). Right looks like: in `m4_lit` a viewer can name stove, drawer, sink and block in one glance and the pool is visibly a pool; in `m4_dark` the two wall planes still separate; in `m4_tipped` the dust puff is visible where the shelf landed; every shot survives a 320 px-wide downscale with its story intact.

---

## Direction B — SIGNAL

*Light as information: the room speaks in beacons, and the rig knows its budget.*

**1 · Thesis.** Darkness is the puzzle, so light should be the language — brighter tells for everything that matters, a cold fill that keeps silhouettes in the dark, and a cap so the language survives on a phone.

**2 · What the player sees.** The lit room is dimmer and moodier than today, but every information-bearing state glows louder: the stove ring, a charging phone, the locked door, a burning cell. A real pendant bulb hangs from the cord over the room, giving the pool a body; a faint cold fill keeps furniture edges legible when the room's own light is off. Fire and shock throw more colour; nothing outruns what a phone can draw.

**3 · Delta from today.** Five new capabilities, named and sized, plus data:

- **New capability (S): bulb fixture mesh.** `_build_bulb` (`game/room_renderer.gd:102-115`) gains an optional `lighting.bulb.mesh` — today the light hangs on nothing (`lighting.bulb` carries only cell/height/energy/range). Room 1 sets `studio/bare_bulb`. A rig node, not a sim object: no tags, no solver work.
- **New capability (S): cold fill light.** A second rig light from a new `fill` block (token colour, low energy, no shadows) beside `_build_bulb`; the bulb stays the only shadow-caster. `docs/06:11` says "One light source per room ... with real shadows. Minimal ambient." — rewritten to *one story light, plus a rig fill; ambient stays minimal.*
- **New capability (S): environment glow from data.** `_build_environment` (`game/room_renderer.gd:81-97`) sets background, ambient and adjustments today; it gains `post.glow_*` keys so emissive tells can bloom slightly (Compatibility supports Glow — Godot 4.7 renderer docs).
- **New capability (M): light budget clamp.** One pass keeps at most `light.budget` dynamic lights (proposed 8 — Compatibility's default omni cap per mesh, adjustable via `rendering/limits/opengl/max_lights_per_object`) by dimming the least central state/hazard lights first. Nothing caps count today: every burning cell (`game/room_renderer.gd:1042-1043`; spec `content/visuals.json:624-632`) and every `on`/`lit` object (`game/room_renderer.gd:948-958`) adds one.
- **New capability (M): state particles.** Any `state_visual` entry may carry a `particles` block, attached like `StateLight` (`game/room_renderer.gd:948-958`) via the existing `_make_particles` (`game/room_renderer.gd:1057-1073`). Dust lands at the object's own feet: `state_visual.tipped.particles` (today `tipped` holds only `roll_deg: 82.0`, `content/visuals.json:465-467`).
- `content/visuals.json` `ambient.energy`: 0.85 → 0.55; `post.contrast`: 1.06 → 1.16; `post.brightness`: 1.0 → 0.96 — the lit room dims so tells and pool carry the information.
- `content/visuals.json` `dark.ambient_energy`: 0.14 → 0.20 — the dark state keeps a whisper more tone so silhouettes hold (`dark.light_energy` 0.35 stays; `game/room_renderer.gd:770-776`).
- `content/visuals.json` `state_visual.on.light.energy`: 1.1 → 1.5 and `.range`: 4.0 → 5.5; `state_visual.lit.light.energy`: 1.6 → 2.0 and `.range`: 5.0 → 6.5 — switching anything on gets louder (read at `game/room_renderer.gd:948-958`).
- `content/visuals.json` `hazard.layers.burning.light.energy`: 2.2 → 2.6; `.alpha`: 0.8 → 0.9 — fire gets louder (spec at `content/visuals.json:603-632`).
- `content/visuals.json` `vignette.strength`: 0.55 → 0.68; `vignette.softness`: 0.6 → 0.45 — a tighter tube pulls the eye to the middle.
- **New Brand token (addition, never inline):** `Brand.COLD_FILL` — proposed `#4A5A70` — added to `game/theme/brand.gd` and the table in `assets/README.md:67-74`; referenced as `$COLD_FILL` (resolution `game/visuals.gd:66-68`).
- Rule rewrite (`docs/06:11`, quoted above). Post line `docs/06:14` gains "a whisper of bloom on emissives only".

**4 · Asset plan.** Light is this direction's spend, so the asset set is deliberately lean (agent-built, project-owned, generating script committed).

- `studio/bubble_token.glb` — **gap #1**: 0.16 m tall glass bubble, same spec as Direction A; keeps collectible emission 1.4.
- `studio/bare_bulb.glb` — the pendant: cord 1.25 m + shade 0.35 m across, hung at the authored height 2.35 m (`content/rooms/room_01_studio.json:1468-1470`); one flat material, the bulb face emission-capable. Drawn by the bulb-fixture capability, not a sim object.
- Stays from the packs (CC0, licences as above): everything else, including the counter run's current Kenney meshes. Fidelity stays where M4 left it.
- Dust (**gap #2**): covered by the `state_visual` particles capability (`state_visual.tipped.particles`, shape mirroring `hazard.layers.burning.particles`, `content/visuals.json:611-623`) — no `rules.json` change, no solver re-verify for dust.
- Scale/licence shared plumbing: `models.studio.metres_per_unit: 1.0` (preamble); all new assets $0 and CC0/project-owned.

**5 · Clutter position.** **Fewer objects** — the first backlog exit (`docs/BACKLOG.md:48`) — but by containment first: audit how many of the ten stacked-on objects can *start inside a closed container*, the pattern the room already uses (`counter_drawer` contains the charger and the oil; `fridge` contains the cans). Moves are room-JSON data that change what is visible at rest. Nothing is deleted unless the solver report allows it; if any object count does move, re-run `tools/solve.gd` / `verify_all` and re-take completion counts (`docs/BACKLOG.md:48`), and `verify_all` must still report "3 of 3 authored solutions, tightness 47.1 / 62.0 / 66.0s" (`docs/M4-CLOSEOUT.md:101`) before the direction ships.

**6 · Phone check.** The fill adds one non-shadow directional (8 allowed everywhere — Godot 4.7 renderer docs), account for it in the budget clamp; the clamp exists *for* Compatibility's 8-omnis-per-mesh default. Glow is supported in Compatibility but costs fill rate — ship it low, and if frames drop the `post.glow_*` values simply go to zero (data). CPUParticles3D only. Low shadow quality: the shadow-casting count is unchanged (bulb only). The busiest phone scene is fire + fill + shadows at once; the budget clamp is the guard. No desktop-only effect — but this is the direction that changes the phone risk profile, so it needs the device check M3 never got.

**7 · Cost + risk.** ~5.5–8 agent-days: caps (fixture 0.5, fill 0.5, glow 0.5, budget clamp 1.5–2, state particles 1–1.5); data pass 1; two assets 0.5–1; shots 0.5. Money: **$0**. Single risk: light-noise — more, brighter lights can bloom into mush at phone size and push GL fill rate; if the tells plus the pool read as a headache at 320 px rather than a language, the direction's own answer (darkness as information) is what failed.

**8 · Style frame** (copy-paste; 16:9; no text):

> dim isometric cutaway diorama of a studio apartment at night in a black void, hanging pendant bulb with visible cord and shade glowing warm amber over the room centre, faint cold blue fill from above keeping furniture edges readable, heavy shadow, small bright tells: stove ring glowing hot amber, phone charging, door chain and lock glinting amber, toaster slots warm, burning curtain corner throwing orange light and a spark shower, low-poly, flat shading, no textures, deep blacks, one warm accent against blue-grey, tighter vignette and fine grain, 16:9, no text, no watermark

**9 · Acceptance shots.** Same set regenerated (`m4_lit`, `m4_dark`, `m4_flood`, `m4_fire`, `m4_tipped`, `m4_death`, `m4_secured`). Right looks like: `m4_dark` is the hero — at 320 px the door, shelf, tub and each glowing tell are still identifiable and the room's shape holds; `m4_lit` shows the pendant and a visibly quieter room with louder tells; `m4_fire` shows the budget holding (no flickering or mush); `m4_tipped` shows the dust at the shelf; `verify_all` still reports 3 of 3 if containment moved anything.

---

## Direction C — INK

*At phone size you read silhouettes, not surfaces — so draw the room.*

**1 · Thesis.** Phone size reads edges, not materials: ink the contours of every hero object, straighten the build with seams, crop closer, and let one ember colour the drawing.

**2 · What the player sees.** Room 1 becomes a drawn plate: every hero object carries a fine dark contour with clean structural lines — drawer separations, cushion seams, shelf slats — over flatter, paler surfaces quantised into a few tones. The camera steps closer, so the room nearly fills the frame and the drawing holds at phone size. The bulb's ember and the black void do all the colour that's left; in the dark state the room is silhouette-first by construction, and the contours merge into it.

**3 · Delta from today.** Two new capabilities, named and sized, plus data:

- **New capability (M): hero outlines.** A permanent inverted-hull contour for objects whose model declares it: a `models.outline` block (colour token, `pixels` ~1.4), built once at object build time using the pattern the hover ring already ships — grown mesh copies, unshaded material, cull-front (`game/room_renderer.gd:651-689`), with thickness constant in screen pixels through the existing `outline_thickness()` maths (`game/room_renderer.gd:645-648`). The hover ring stays amber and interactive (`object.highlight_color` `$ACCENT`, `highlight_pixels` 2.0, `content/visuals.json:364-365`); the ink is quieter and permanent. Applied to ~12 hero models only.
- **New capability (S): post posterise.** The existing vignette shader (`game/main.gd:150-172`) gains `vignette.quantize_steps` (0 = off today; propose 10–12) with grain as dither (`vignette.grain` 0.03 → 0.04). Banding is accepted as print texture; Compatibility has no debanding and this direction leans on it deliberately (Godot 4.7 renderer docs).
- `content/visuals.json` `camera.frame_margin`: 0.0 → -0.5 — resolved orthographic size 12.0 → 11.0 (~8% closer; `game/iso_camera.gd:11-12`). [uncertain] anything closer than this: the 4:3 evidence shot `docs/screenshots/aspect_4x3.png` shows the plinth already close to the frame edge at the current size, so a stronger zoom is gated on a fresh iPad capture. The verifiable alternative shipped here is exactly this 8% step.
- Rule rewrite (`docs/06:21`): "Size tuned so a 12×10 room fills ~80% of a 16:9 frame" → *"fills ~90% of a 16:9 frame; the plinth may sit near the edge; 4:3 is re-checked with every camera change."* This deliberately takes the backlog's third exit — "A closer camera, or one that can be nudged, which changes the diorama framing `docs/06` is built on" (`docs/BACKLOG.md:50`).
- `content/visuals.json` `post.contrast`: 1.06 → 1.18; `post.saturation`: 0.62 → 0.70 — flatter and crisper, toward print.
- `content/visuals.json` `wall.color_far_x`: [0.62, 0.63, 0.66] → [0.70, 0.71, 0.72]; `wall.color`: [0.45, 0.46, 0.48] → [0.53, 0.54, 0.55] — paper-pale planes for the ink to sit on.
- `content/visuals.json` `floor.color`: [0.52, 0.4, 0.3] → [0.58, 0.48, 0.38] — pale wood.
- `content/visuals.json` `ambient.energy`: 0.85 → 1.0 — the print is evenly lit; the dark state keeps `dark.light_energy` 0.35 / `dark.ambient_energy` 0.14, so the light switch keeps its meaning (`game/room_renderer.gd:770-776`).
- `content/rooms/room_01_studio.json` `objects[].mesh` swaps to the authored hero set (below); `bubble_token` gains `"mesh": "studio/bubble_token"`.
- `content/visuals.json` `models.recolor` — entries for the hero set's un-authored parts if any; packs keep their flat shading otherwise.

**4 · Asset plan.** Authored hero set (agent-built, project-owned, 1 unit = 1 m, origin footprint-centre, y = 0 at floor), built *for ink*: shallow bevels and inset seam faces so the contour traces a clean edge rather than every facet.

- `studio/bubble_token.glb` — **gap #1**: 0.16 m tall glass bubble; keeps collectible emission 1.4.
- `studio/counter_stove.glb`, `counter_drawer.glb`, `counter_sink.glb`, `counter_block.glb` — 1.0 x 0.6 x 0.9 m each, one family, handle insets and unit seams.
- `studio/toaster.glb` — 0.29 x 0.19 x 0.19 m.
- `studio/bookshelf.glb` — 1.8 x 0.8 x 0.3 m (slat gaps read in ink; load-bearing for `disable_shelf`).
- `studio/couch.glb` — 1.9 x 0.9 x 0.75 m, replacing `kenney/loungeSofaLong` (2x1 footprint), cushion seams.
- Stays from the packs (CC0): bed, tub, toilet, fridge, doors, window, nightstand, rug, lamps, boxes, the Quaternius figures, food props — outlined by the same capability wherever they are hero.
- Dust (**gap #2**): the data-only hazard path from Direction A (new `hazard.layers.dust` + `tip_second` effect + `"dust_s"`), no extra capability. If Direction B ships first, its `state_visual.tipped.particles` supersedes this for the shelf.
- Licence status: $0; all CC0 or agent-built, recorded per `assets/README.md` Rules.

**5 · Clutter position.** **Closer camera** — the third exit (`docs/BACKLOG.md:50`), taken head-on. At ~8% closer every object gains ~17% screen area, and the picking floor `object.min_clickable_px` 400 (`content/visuals.json:361`) only improves; re-run `tests/game/picking_test.gd` to re-baseline. The ink layer then separates overlapping silhouettes by drawing each object's own edge — the direct answer to "the layout of the room is too cluttered making it hard to see things" (`docs/BACKLOG.md:44`). No object counts move, so no solver re-verify is owed; the tests that must re-run are the picking/scale pair, and `docs/06:21` is rewritten as quoted above.

**6 · Phone check.** Outlines are the same pattern the hover ring already ships on every target (unshaded material, cull-front, grown copies — `game/room_renderer.gd:651-689`): geometry, not an engine feature; ~12 hero objects double their draw calls only. Posterise is canvas-shader work with no feature beyond RGBA8; Compatibility has no MSAA 2D and no debanding (Godot 4.7 renderer docs), hence grain. Low shadow quality: unchanged (bulb only shadow-caster). The honest [uncertain] is ink weight after the camera nudge at 21:9 and 4:3 — gate the camera change on an `aspect_4x3.png`-style recapture before merging. The ink colour `$BG_DARK` disappears in the dark state by design (the room is already silhouette); `m4_dark` checks that this reads as intentional, not as missing lines.

**7 · Cost + risk.** ~5–7 agent-days: outlines 1.5–2; posterise 0.5; data 0.5; eight authored models 2–3.5; shots 0.5. Money: **$0**. Single risk: ink-noise — wrong line weight or facet tracing makes the drawing buzz at phone size; mitigation is baked seams in the hero set, ink at ~1.4 px, a capped outlined set, and a 320 px check on every outlined object before shipping.

**8 · Style frame** (copy-paste; 16:9; no text):

> drawn low-poly isometric diorama of a cramped studio apartment, two-wall cutaway on a pale plinth in a black void, fine dark contour lines around every object, flat pale surfaces in two or three tones, structural seam lines on drawers cushions and shelf slats, one ember amber lamp glowing warm, otherwise cold grey ink palette, closer crop with the plinth near the frame edge, quiet print grain, risograph-meets-miniature, no textures, 16:9, no text, no watermark

**9 · Acceptance shots.** Same set regenerated, plus an `aspect_4x3`-style recapture for the camera change. Right looks like: at 320 px every hero object is identifiable by contour alone; `m4_dark` keeps deliberate shape (contours merged, silhouettes readable); `m4_lit` shows the posterised plate with the ember working; `m4_tipped` shows the shelf contour plus the dust puff; the 4:3 recapture proves no crop; `m4_secured`'s door marks are still the loudest thing on the door.

---

## Recommendation

**Ship Direction A — First Light — first.** It is the smallest reversible commit that answers the literal complaint: every change is a value in `content/visuals.json`, a mesh name in the room file, or a `.glb`, so it cannot break the phone path, cannot move the solver, and can be walked back key by key. It also front-loads the exact Blender pipeline `docs/06` already sanctions *and that every direction needs anyway* — the collectible model and the counter run are shared costs, not A's cost. And it leaves the pillars untouched, which matters most right now: M4's sign-off has been open since September, and a direction that keeps the rig instead of re-architecting it is the one that can actually close.

**What A sacrifices:** it does not fix overlapping silhouettes in the dark state — light separates objects less than ink lines or state tells do — and it leaves the object count untouched, so if a later playtest still says "too crowded", A has no answer below a structural edit. Its riskiest step is recolour archaeology; if the pack's material names are uncooperative, A degrades to "better models only" and some family reads stay muddy.

**Sequencing after A:** C is the natural second (fidelity plus composition — two of the backlog's three exits, still with no sim change; its outlines reuse a pattern that already ships). B is the one to reach for only when the failure is specifically "in the dark I cannot read the room" — it is the most powerful direction and the only one that rewrites `docs/06`'s one-light rule and changes the phone risk profile, so it deserves the device check M3 never got.

## Decision guide

What Bob compares across the three, in one screen:

| | **A — First Light** | **B — Signal** | **C — Ink** |
|---|---|---|---|
| One-line promise | A graded photograph of the same room | The room speaks in light | The room as a drawing |
| Backlog exit taken | Better models | Fewer objects (containment) | Closer camera |
| New renderer code | None | 2 x M + 3 x S | 1 x M + 1 x S |
| Solver risk | None (mesh props only) | Possible (containment moves) | None; picking/scale tests re-run |
| `docs/06` rules rewritten | None | One-light rule (line 11), post list (line 14) | Framing (line 21) |
| Money | $0 | $0 | $0 |
| Agent-days | 4.5–7 | 5.5–8 | 5–7 |
| Fails if | Pack material names are mush | Light turns into noise on a phone | Ink buzzes at phone size |

**The comparison test.** Put the three style frames side by side at 320 px wide and ask one question: *which focal object can you name fastest?* A wins if it is the counter run or the token; B if it is the door chain or the stove ring in a dark house; C if it is the couch or the shelf by shape alone.

**Then the sign-off test.** Whichever direction is picked, the M4 acceptance shot set is regenerated and judged the way `docs/M4-CLOSEOUT.md:39` left it: against the style target, at phone size. One sentence must disappear for the direction to have worked — for A and C it is "Often I can't tell what I am looking at" (`docs/BACKLOG.md:44`); for B it is the untested half of M3, "he can locate the attacker by ear while hidden" has a visual twin — *in the dark I can read the room but not the lights that matter* (`docs/M4-CLOSEOUT.md:68`).
