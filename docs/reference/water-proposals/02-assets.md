# PAINTED WATER — the puddle as a drawn asset

*Environment-art proposal, lane: authored geometry / materials / textures / sourcing. Read-only pass: I changed nothing and ran nothing.*
*Expert session: `ses_e58d2207cffeKaw4RUIMD8L13m` · 4 November 2026 · the shared brief is `docs/reference/water-target-spec.md`.*

---

## 0. What I measured first (this is the whole argument)

I sampled the acceptance image (2714×1536) and the current build's frames pixel-by-pixel rather than eyeballing them:

| Sample | TARGET (mockup) | CURRENT BUILD |
|---|---|---|
| Puddle body, mid | `#545a68` | `#746062` — **warm mauve, not blue** |
| Puddle body, near the sink | `#5c7189` | `#646c74` |
| Foam edge line | pale blue-white core (`#6a7184` → `#8d9ab0`) | `#aa9683` — **beige** |
| Cascade sheet | `#90a3b3`, p90 255 | pale blue boxes, α 0.62, no whites |
| Droplets | flat white splats, 6–12 cm | shaded 3D spheres → **read as pebbles** (visible in `water-late-closeup.png`) |
| Rings | 5 thin broken arcs, r ≈ 0.15/0.30/0.45/0.62/0.75 m from the splash point | 3 arcs, r 0.30/0.47/0.66, α 0.45→0.23, 25 mm wide — barely there |
| Rim geometry | bright core ~2 px **+ soft halo ~8–10 px** | one hard 50 mm band, outside the body |

Two hard conclusions fall out of this:

1. **The current water is mauve because it is lit by an amber bulb and then crushed by `post.saturation: 0.55`.** `light.color` is `$ACCENT` `#D9A05B`; a shaded blue surface under amber light goes warm-grey, and the frozen grade takes the rest. No amount of albedo tuning fixes this — a *shaded* blue at the mockup's brightness (lum ≈ 90–110 at the sink) is not reachable. The water must be **self-lit (unshaded)** and its albedo **pre-compensated for the grade**.
2. **The mockup's body is not `#4a90e2`; it measures `#545a68`–`#5c7189`.** The saturation and the "luminous" read live in the *whites* — the foam line, the rings, the cascade, the spray — against the warm floor. Any proposal that chases a saturated blue *body* is aiming at a colour the acceptance image does not contain. (Computed check: authoring the spec's own `#3f7fd4` as an unshaded albedo lands at ≈`#5373b3` after `adjustment_saturation` 0.55 + `contrast` 1.1 — the mockup's blue at a slightly higher key. Arithmetic assumes Godot applies adjustments in linear space before the final sRGB blit; **[verify]** with one capture.)

## 1. Approach

**PAINTED WATER.** Water stops being a translucent lit surface and becomes a *drawn asset*: five small Blender-authored meshes (a flared cascade sheet, a wobbled ripple ribbon, a flat teardrop, a spray burst, a sheen blob) carrying five alpha-masked brush textures baked by a committed tool, all rendered **unshaded** so the frozen amber rig and the 0.55 saturation crush cannot reach them, with the water's own brightness tied to the bulb so the darkness pillar survives. Nothing in `sim/` moves, nothing in the room changes, and every number — width, radius, count, colour, darkness scale — is a key in `content/visuals.json` under `hazard.layers.wet` and `object.by_tag["wet-source"].stream`, exactly where the water's look already lives.

## 2. Exact mechanism

### 2.1 New authored models — `assets/models/studio/` (pack exists, `metres_per_unit: 1.0`)

Five scripts in `tools/blender/`, each one file, following `counter_sink.py`/`studio_kit.py` (flat primitives, `join()` bakes transforms, `export()` writes GLB):

| Script → asset | Dimensions (authored, 1 u = 1 m) | Parts / material names | Tris |
|---|---|---|---|
| `water_cascade.py` → `studio/water_cascade.glb` | 1.0 W × 1.0 H × 0.12 deep; **origin at bottom-centre of the sheet plane**, +Z away from the cabinet. Runtime scales (width, height, 1.0) | `sheet` (9×7 grid, scalloped top ±0.02, sides flare 0.44→0.62 of unit W, forward belly 0.12 at v=0.45) · `lip` (0.06 roll over the top) · `rill_a..rill_d` (inset grooves) · `foot` (0.16 fan) — material `water_sheet`; lip/rills/foot are `water_foam` | ≈ 460 |
| `water_ripple.py` → `studio/water_ripple.glb` | unit radius 1.0, 96 segments, ribbon 0.045 mean (0.020–0.080), radius wobble ±0.035 from two baked sines (3 and 7 cycles) | `ring`, UV u = arc/0.9 m, v across — `water_foam` | 190 |
| `water_drop.py` → `studio/water_drop.glb` | flat teardrop in the floor plane, 0.10 × 0.055 × 0.004, 7 verts | `drop`, UV 0–1 — `water_white` | 5 |
| `water_spray.py` → `studio/water_spray.glb` | 5-point burst, 0.05 across, 0.004 thick | `spray`, UV 0–1 — `water_white` | 10 |
| `water_sheen.py` → `studio/water_sheen.glb` | irregular flat blob 1.1 × 0.75 × 0.004 | `sheen`, UV 0–1 — `water_sheen` | 10 |

All five are referenced **by tag look, never by object id**: `stream.sheet_mesh`, `stream.sheen_mesh`, `overflow.rings.mesh`, `particles.mesh`. The sheet is placed by `_build_pour` at `(cx, floor_y, front_z)` — no new placement logic.

### 2.2 New textures — `assets/water/` (new directory, ~180 KB total, RGBA8, committed with `.import`)

Baked by a new committed headless tool **`tools/make_water_textures.gd`**, run as `godot --headless -s tools/make_water_textures.gd` — the exact precedent of `tools/make_icon_layers.gd` (generated art, committed generator, project-owned, $0).

| File | Size | Content |
|---|---|---|
| `foam_strip.png` | 1024×128 | tileable-in-u foam brush: bright core at v≈0.45 with thickness varying 6–16 % of height, feathered to both v edges, dashes/gaps every 90–180 px, a few bubbles. Used by **both** the edge band and the rings |
| `sheet_streaks.png` | 512×1024 | vertical falling-water streaks: white bands on a `[0.55,0.72,0.92]` ground, outer 12 % of u fading to α 0.25 (the blue edges the mockup shows) |
| `drop.png` | 64×64 | soft white teardrop, one flat side |
| `spray.png` | 64×64 | soft 5-point burst |
| `puddle_mottle.png` | 256×256 | tileable ±6 % luminance mottle so the body is not a flat fill |

Import: `filter = linear with mipmaps`, `repeat = on` for `foam_strip`/`puddle_mottle`, `compress = lossless`.

### 2.3 New data keys — `content/visuals.json`

`hazard.layers.wet`:

| Key | Was | Becomes |
|---|---|---|
| `color` | `[0.25,0.50,0.85]` | `[0.25,0.50,0.83]` (the spec's `#3f7fd4`) |
| `alpha` | 0.45 | **0.85** (the mockup hides the floor completely) |
| `emission` | 0.04 | 0.0 — replaced by ↓ |
| `shading` *(new)* | — | `"unshaded"` |
| `dark_scale` *(new)* | — | 0.30 |
| `body_texture`, `texture_scale` *(new)* | — | `res://assets/water/puddle_mottle.png`, 0.25 (world-space UVs, 1 tile / 4 m) |
| `rim_width` | 0.05 | **0.09** |
| `rim_color` | `[0.72,0.86,0.96]` | `[0.86,0.93,1.0]` |
| `rim_alpha` | 0.55 | 0.90 |
| `rim_texture`, `rim_straddle`, `uv_per_metre` *(new)* | — | `foam_strip.png`, 0.35 (fraction of the band inside the loop), 0.9 |
| `sheen_width`, `sheen_color`, `sheen_alpha` *(new)* | — | 0.34, `[0.55,0.72,0.95]`, 0.22 — a second **surface inside the body mesh**, not a second node |
| `particles` | amount 10, scale 0.06, `unshaded false`, colour `[0.45,0.62,0.8]` | amount **26**, lifetime 3.0, scale **0.075**, `unshaded true`, `alpha 0.95`, colour `[1,1,1]`, `mesh "studio/water_drop"`, `texture drop.png` |

`object.by_tag["wet-source"].stream`:

| Key | Was | Becomes |
|---|---|---|
| `radius` / `alpha` / `shading` | 0.016 / 0.9 / — | 0.018 / 0.92 / `"unshaded"` |
| `sheet_mesh`, `sheet_texture` *(new)* | — | `studio/water_cascade`, `sheet_streaks.png` |
| `sheen_mesh` *(new)* | — | `studio/water_sheen` |
| `overflow.width` / `spread` / `alpha` / `shading` | 0.40 / 1.5 / 0.62 / — | 0.44 / 1.45 / 0.82 / `"unshaded"` |
| `overflow.rings.radii` | `[0.30,0.47,0.66]` | **`[0.16,0.32,0.48,0.64]`** (measured off the mockup) |
| `overflow.rings.centre_z` *(new)* | hard-coded `front_z + 0.14` | 0.30 — rings centre on the **landing point**, as the mockup does |
| `overflow.rings.width` / `alpha` / `falloff` | 0.025 / 0.45·0.72ⁱ / — | **0.045** / 0.85 / 0.88ⁱ |
| `overflow.rings.mesh`, `.texture`, `.yaw_deg` *(new)* | — | `studio/water_ripple`, `foam_strip.png`, `[0,47,118,201]` (same mesh, four yaws — a painter's trick, not four assets) |
| `splash` | 14 @ scale 0.055, `unshaded false` | 22 @ scale 0.06, `unshaded true`, `mesh studio/water_spray`, `texture spray.png`, `billboard true` |

### 2.4 Renderer changes — `game/room_renderer.gd` (no `sim/` change, no solver re-verify)

- `_edge_band(points, width, y, colour, alpha, texture, straddle, uv_per_metre)` — emits `ARRAY_TEX_UV` (u = cumulative arc length, v = 0 inner → 1 outer) and offsets the inner edge by `-straddle·width`. Still one node named **`Waterline`** (test contract).
- `_polygon_mesh(points, offset, colour, alpha, emission, texture, uv_scale)` — UVs from world XZ; gains a **second surface** (`ARRAY_INDEX` 2) for the sheen band, so the sheen adds **zero** new sorted objects.
- `_ring_band(...)` — UVs; when `mesh` is set, instantiates `studio/water_ripple` scaled by radius and yawed, instead of the 40-segment annulus. Node names stay `SplashRing`, `SplashRing2`, … (Godot de-dupes; `get_node_or_null("SplashRing")` in `water_test.gd:110` still finds the first).
- `_build_pour(shape)` — when `shape.has("sheet_mesh")`, instantiate and scale the authored sheet; **the existing box assembly stays as the fallback path**, so a future wet-source with no authored sheet still pours.
- `_make_particles(spec, box)` — reads `spec.mesh` / `spec.texture` / `spec.billboard`; new `_particle_meshes: Dictionary` cache keyed by path (**required** by `effects_test.gd:144-157`, which asserts mesh *and* material identity is shared across cells), and `_particle_material`'s cache key extended from `"unshaded|alpha"` to `"unshaded|alpha|mesh|texture|billboard"`.
- New `_water_materials: Dictionary` built once in `build()` (mirroring `_particle_material_cached`) so a region rebuild never allocates a material or reloads a texture.
- `_apply_lighting(lit)` — additionally sets every cached water material's `albedo_color` to `colour × water_scale`, where `water_scale = clampf(bulb_energy() / _lit_energy, hazard.layers.wet.dark_scale, 1.0)`. `bulb_energy()` already exists (`game/room_renderer.gd:751`) and already carries the death flicker, so the puddle dims with the bulb **and** flickers with it for free.
- Material recipe for all water: `SHADING_MODE_UNSHADED`, `cull_mode = CULL_DISABLED`, `transparency = ALPHA`, `texture_filter = LINEAR_WITH_MIPMAPS`, `render_priority` 1 (foam) / 2 (body) / 3 (rings) as belt-and-braces on top of the depth ladder.

**The depth ladder is deliberate and must stay in data:** foam `y = height×0.85` (0.017), body `y = height×1.05` (0.021), rings `y = floor_y + 0.006` (0.026), sheen baked into the body mesh. The foam sits **under** the body, so the body's 85 % blue veils the foam's inner half — which is exactly the mockup's read: a bright line on the floor side, blue just inside.

### 2.5 Sourcing, licences, cost

- Everything above is **agent-built, project-owned, $0** — five `.glb` committed with their five generating scripts, five PNGs committed with `tools/make_water_textures.gd`, all four rows added to the Pack table and the Studio-set paragraph in `assets/README.md`.
- Optional, free: **Kenney Particle Pack** (kenney.nl/assets/particle-pack, **CC0 1.0**) if a hand-painted spray/droplet sprite set is preferred over baked ones — drop-in replacements for `drop.png`/`spray.png`, $0.
- Optional, paid: the ~$20 Kenney all-in-one bundle `docs/06:45` already names. **Not required.** The art budget stays untouched.
- No new library, no addon, no shader file. Compatibility ceilings: no decals (hence the sheen is *geometry*), no SSR, glow not used at all (glow would also brighten the frozen room).

### 2.6 The `docs/06` rewrite — stated explicitly

Two lines must change, and I am asking for it rather than working around it:

- **`docs/06:13`** — "**Flat shading, no textures.** Vertex color or a single material with a color ramp." → *"**Flat shading on solids, no textures.** Furniture, fixtures and props are flat-shaded, one material per model. The water is the one exception: its foam, rings, spray and sheet are alpha-masked brush textures over flat geometry, because at phone size water has to read as a drawn line, not a lit surface. No texture is ever applied to a solid."*
- **`docs/06:35`** — `wet (cell) | darker floor tint + specular` is already stale (the implementation is an outline mesh). → *"one smoothed puddle body with a foam edge, ripple rings and spray — see `hazard.layers.wet` in `content/visuals.json`."*

## 3. Feature-by-feature

| # | Target feature | How PAINTED WATER delivers it |
|---|---|---|
| 1 | **Saturated blue body** | Unshaded, `alpha 0.85`, albedo the spec's own `#3f7fd4`, pre-compensated for `post.saturation 0.55` + `contrast 1.1` → lands ≈`#5373b3`, the mockup's blue at a higher key. The bulb's amber and the grade can no longer touch it. `puddle_mottle.png` at 6 % keeps it from reading as flat paint; `dark_scale 0.30` keeps the darkness pillar honest. |
| 2 | **Foam edge line** | `_edge_band` widened 0.05 → **0.09 m** (~6 px at 720p, ~9 px at 1080p), straddling the boundary (35 % in, 65 % out), `rim_alpha 0.90`, near-white `[0.86,0.93,1.0]`, UV-mapped with `foam_strip.png` at 0.9 tiles/m. The texture supplies the measured two-part profile — a bright 2 px core plus a soft 8–10 px halo — and the varying thickness and gaps that make it hand-painted instead of a vector offset. |
| 3 | **Ripple rings** | Four rings at the **measured** radii `[0.16,0.32,0.48,0.64]`, re-centred on the landing point (`rings.centre_z 0.30`, was `front_z + 0.14`), 0.045 m wide, α 0.85 falling 0.88ⁱ, near-white, over the puddle *and* the bare floor at y 0.026. Each is `studio/water_ripple.glb` (baked ±0.035 wobble, 3+7 cycles) at a different yaw, textured with the same foam brush → thin, broken, tapering arcs like the mockup, not perfect annuli. |
| 4 | **Cascade** | `studio/water_cascade.glb` scaled to 0.44 m wide × 0.88 m tall at `front_z`, with a 0.12 m authored belly so the sheet **hangs away from the cabinet and lands ~0.34 m out** (where the mockup's sheet lands, and where the rings now centre). Scalloped lip and foot, four rill grooves, `sheet_streaks.png` for the white streaks on a pale-blue ground with blue edges, α 0.82, unshaded — so it is the brightest thing in the room, as in the mockup. `studio/water_sheen.glb` (1.1 × 0.75 m, α 0.22) sits flat at the foot, doing the job a decal would do — which Compatibility cannot. |
| 5 | **Droplets/spray** | `hazard.layers.wet.particles` becomes 26 flat teardrops (`studio/water_drop.glb`, 5 tris) on `drop.png`, **unshaded, pure white, α 0.95**, scale 0.075 → 6–12 cm, which is what the mockup measures. `stream.splash` becomes 22 billboarded `studio/water_spray.glb` bursts at the foot with gravity. Both CPUParticles3D — no GPU particles anywhere (`tests/game/effects_test.gd:68-75`). |
| 6 | **Illustrated register** | Every water surface is unshaded and either textured or flat, so it reads as a painted plate over a lit room; nothing about the water reacts to the bulb, so it cannot pick up the amber cast that turns the current puddle mauve. The rest of the room is untouched: no data change outside `hazard.layers.wet`, `object.by_tag["wet-source"]`, and `post` — which I do not touch at all. |

## 4. Pipeline notes

**Blender must generate:** the five meshes in §2.1, from five ~30–70 line scripts in `tools/blender/` using `studio_kit.py`'s `box`/`cyl`/`join`/`material`/`export` (plus one small `ribbon()` helper for the ripple). Constraints the scripts must honour: metres, origin at bottom-centre, base at z = 0, `shade_flat()`, **UVs authored explicitly** (the whole proposal stands on them), **no runtime scale baked into the mesh** (the renderer scales the sheet to `width`/`height` and the ring to each radius), and one placeholder material per part so the GLB previews sanely — the renderer overrides materials by **part node name** (`sheet`, `lip`, `rill_*`, `foot`, `ring`, `drop`, `spray`, `sheen`), the same matching rule `_recolour_model` already uses.

**The renderer must accept:** `shading`, `dark_scale`, `rim_texture`/`rim_straddle`/`uv_per_metre`, `sheen_*`, `body_texture`/`texture_scale`, `sheet_mesh`/`sheet_texture`/`sheen_mesh`, `rings.mesh`/`.texture`/`.yaw_deg`/`.centre_z`/`.falloff`, and `particles.mesh`/`.texture`/`.billboard` — every one optional with today's behaviour as the default, so `water_test.gd` and `effects_test.gd` pass untouched except for one new assertion I would add (that the foam band's mesh carries UVs, and that a rebuilt region reuses the same `StandardMaterial3D` instance).

**Import conventions:** models stay `assets/models/studio/<name>.glb` (pack already declared, `metres_per_unit: 1.0`, no new pack key). Textures are the repo's first non-UI PNGs outside `assets/`: `assets/water/*.png` with `.import` files committed (the `.glb.import` files already are). `assets/README.md` gets a five-row Studio-set entry and a new one-line "Water textures" note under Rules, recording that they are generated by `tools/make_water_textures.gd` and are project-owned.

**Licences:** nothing new is licensed. $0 spent.

## 5. Risks + effort

**Failure mode 1 — the transparency stack misbehaves on GL Compatibility.** Five translucent water surfaces within 13 mm of each other, an orthographic camera and per-object sorting: the foam flickers through the body, the rings drop behind the puddle, or the sheet vanishes into the cabinet face. *Mitigations, in order:* the sheen is a **second surface of the body mesh** (not a node), so it can never sort against the body; the foam sits 4 mm below the body and relies on depth order, not priority; the rings are 9 mm above the body. If it still flickers, the fallback is to merge foam+body into one ArrayMesh as two surfaces and keep a `Waterline` node as an invisible AABB carrier — but that needs the test's intent re-read, so I would rather ship the ladder and check it on the device.

**Failure mode 2 — self-lighting breaks the darkness pillar.** An unshaded puddle stays bright blue when the room's light goes out, which is exactly what "darkness as gameplay" forbids and would be caught in `m4_dark`. *Mitigation:* `dark_scale` 0.30 driven off the existing `bulb_energy()`, so the water dims and flickers with the bulb; the acceptance set must include a dark frame **with the tap running**. If it still reads as a lamp, the fallback is a shaded body at a red-suppressed albedo (≈`[0.15,0.35,1.0]`) — darker and muddier than the mockup, which is the honest cost of keeping the pillar.

**Effort: 6.5–8.5 agent-days.** Breakdown: texture tool + 5 PNGs 0.5–1.0 · 5 Blender scripts 2.0–2.5 · renderer (UVs 0.5, water material path + `dark_scale` 0.75, authored sheet/sheen in `_build_pour` 0.75, particle mesh/texture/billboard + caches 0.5, ladder + ring centre 0.5) 2.5–3.0 · data + two-renderer calibration captures 1.0–1.5 · tests + `assets/README.md`/`docs/06` 0.25. **Money: $0.**

## 6. What it does NOT solve

- **Nothing animates.** The foam does not advance, the rings do not expand, the sheet does not flow, the droplets are not wind-driven. Every feature in the brief is a *shape*, and the mockup is a still, so this is enough for acceptance — but "living water" is the shader/particle lane, not mine, and the reconciler should not expect it here.
- **The puddle's silhouette is the sim's, not the mockup's.** The acceptance image's puddle is wider and more lobed than the grid-derived region at 61.1 s. Matching that exactly needs a zone/spread change in `content/` or `sim/` — determinism, solver re-verify, out of my lane.
- **No refraction, no reflection, no distortion of the floor under the water.** No screen-texture read anywhere; the register does not need it.
- **The rings and the cascade still vanish the moment the tap is switched off** (`_sync_stream` frees the whole `PourStream`). The mockup has the tap running so it is consistent, but "rings that fade out after the spill" is a state change, not an art change.
- **The rim does not brighten toward the source.** The mockup's foam is loudest on the sink side; that needs the source cell plumbed into `_build_water_region` (per-vertex alpha via `ARRAY_COLOR`). [uncertain] — excluded from the estimate.
- **The exact hue is a computed prediction, not a measurement.** The grade arithmetic in §0 assumes linear-space adjustments; one capture on each renderer settles it, and if the ceiling bites, the only remaining lever is raising `post.saturation` globally — which would move the frozen room, and I am not proposing that.
