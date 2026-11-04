# Painted Flood — unshaded, shader-driven water

*Senior TA proposal, lane: shaders / materials / particles. Read-only; nothing implemented.*
*Expert session: `ses_e58d2207dffeA62qsWncU9Y26L` · 4 November 2026 · the shared brief is `docs/reference/water-target-spec.md`.*

## 1. Approach

**Painted Flood.** The current water is *glass*: a semi-transparent `StandardMaterial3D` sheet that is lit by the amber bulb, blended 45% over a warm brown floor, and then crushed by the global `post.saturation` 0.55 grade — which is exactly why the "vivid" data pass (commit `b122158`) landed pale (`water-late-full.png`). The target is *paint*: an opaque-ish, self-lit saturated blue mass with a hand-drawn white contour, white marks on it, and a white cascade — i.e. everything in the target that carries the look is **unaffected by the saturation grade, because it is white**. So the approach is to stop drawing water with lit materials and give the four water elements their own small family of **unshaded `ShaderMaterial`s** (body, foam line, waterfall, droplets), driven by new blocks in `content/visuals.json`, with the vertex data they need (edge distance, wash proximity, along-the-edge UV) written into the existing `ArrayMesh` builders. Every shader is opt-in behind a data key, so the pass can be reverted key by key — the repo's own culture for a visual pass. No new library, no paid asset, $0.

## 2. Exact mechanism

**New shader files** (new `game/shaders/` directory; there are no `.gdshader` files in the repo today):

| File | Used by | Key mechanism |
|---|---|---|
| `game/shaders/water_body.gdshader` | puddle body (`_polygon_mesh`) | `unshaded`, `cull_disabled`; reads `ARRAY_COLOR`: `.r` = metres to the loop boundary, `.g` = wash proximity to a running `wet-source`. Outputs `mix(deep_color, color, smoothstep(0, edge_fade, COLOR.r))` + `wash_color` where `COLOR.g` is high; a low-frequency `sin` luminance breathe; multiplied by `light_level`. |
| `game/shaders/water_foam.gdshader` | edge band (`_edge_band`) **and** ripple rings (`_ring_band`), one shader, `mode` uniform | reads new UVs (`u` = arc length in metres, `v` = across-band 0→1). `alpha = (1 - v)^p`-style core + wide soft halo; domain-warped 2-octave value noise on `u + TIME*drift` gives the hand-painted scallop; colour `mix(foam_color, water_color, v)`. Ring mode adds a travelling outward brightness pulse via `phase`. |
| `game/shaders/water_fall.gdshader` | cascade sheet, rills, lip, foot, basin fill, faucet jet | `unshaded`; vertical scrolling noise streaks (`UV.y*3 - TIME*speed`) rendered as `foam_color` over `water_color`; `smoothstep` side fades so the flat boxes stop reading as rectangles; brighter at the lip and the foot. |
| `game/shaders/water_drop.gdshader` *(fallback path only — see §4)* | droplet particles | manual billboard in `vertex()` via the documented `MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3])` recipe + a procedural circular mask `1.0 - smoothstep(0.55, 1.0, length(UV-0.5)*2.0)`; `ALBEDO = COLOR.rgb`. |

**Changed in `game/room_renderer.gd`** (all additive, all behind data keys):
- `_polygon_mesh(points, offset, colour, alpha, emission)` gains a `spec` argument: when `spec.body.shader` is set it builds a `ShaderMaterial` and writes `ARRAY_COLOR` (loop-boundary distance + wash); otherwise it keeps today's `StandardMaterial3D` path verbatim.
- `_edge_band(...)` and `_ring_band(...)` write `ARRAY_UV` and take the foam shader; both gain a `render_priority` (`Material.render_priority`, engine-level, both renderers) — body 0, rings 1, foam line 2 — because these layers are near-coplanar under a fixed iso camera and transparent sort order is otherwise a coin flip.
- `_wobble(loop, amplitude)` is rewritten as arc-length-driven, two-octave displacement (`amp_long·sin(2πs/λ_long) + amp_detail·sin(2πs/λ_detail)`, deterministic, no RNG). Today's `sin(i*2.7)` is index-based — near-Nyquist, so raising `wobble` (currently 0.02, invisible) would produce a *furry* edge, not the target's large lobes.
- `_build_pour` swaps `_pour_material(...)` for `water_fall.gdshader` materials on `OverflowRun/Upper/Lower/Lip/RillTop/RillLow/Foot`, `BasinFill`, and `FaucetStream` (per-part uniforms, built once — no per-frame cost).
- `_build_water_region` looks up wash origins by **tag** (`obj.tags.has("wet-source") and obj.state.on`) — no id, consistent with house rule 1 — and `_sync_outline_layer` appends each wet-source's on/off to the region `signature` so the wash refreshes when the tap toggles.
- `_apply_lighting` + `_sync_flicker` set `light_level` on registered water materials from the bulb's *current* energy fraction — the water dims with the room (pillar: darkness as gameplay) and inherits the death-beat flicker for free.
- `_make_particles` gains `mesh` (`"sphere"` default / `"dot"`), `color_ramp` (a `Gradient` → `CPUParticles3D.color_ramp`, currently unused), and `damping`. Cache keys extend to `(kind, unshaded, alpha)`; the sphere path and its sharing tests are untouched.

**New data keys** — `content/visuals.json`, exactly in the two places the brief names:

`hazard.layers.wet`: `wobble` 0.02 → **0.055** + new `wobble_long` 0.85 m / `wobble_detail` 0.22 m; new `body{ shader, color, deep_color, alpha (0.45→0.85), edge_fade, wash_color, wash_radius, wash_strength, breathe, ripple_speed, ripple_strength, light_scale }`; new `rim{ shader, width (0.05→0.085), color, alpha (0.55→0.95), core, halo_alpha, scallop, scallop_scale, drift }`; `particles` → `mesh:"dot"`, `amount` 10→22, `scale` 0.06→0.085, `unshaded` false→true, `color` [0.45,0.62,0.8]→[0.88,0.95,1.0], `color_ramp`, `alpha` 0.9.

`object.by_tag["wet-source"].stream`: new `overflow.water{ shader, color, foam_color, alpha, speed, streak_scale, foam_amount }` (and the same block for `basin` and the jet); `rings` → `radii` [0.30,0.47,0.66] → **[0.34,0.52,0.72,0.95]**, `width` 0.025 → **0.055**, `alpha` 0.45 → **0.8**, `color` → [0.95,0.99,1.0], + `wave_speed`, `scallop`, `scallop_scale`, `expand_span` (0 = static, the default); `splash` → `amount` 20, `scale` 0.09, `unshaded` true, `color` [0.92,0.97,1.0]; new `mist` block (`amount` 10, `lifetime` 0.9, `scale` 0.16, `alpha` 0.35, `mesh:"dot"`, `softness` 1.0) at the cascade foot.

**Starting colour, with the arithmetic that produces it:** the grade preserves luma and pulls every channel 45% toward it, so a source blue must be ~1.8× more saturated than the desired pixel. Author the `: source_color` uniform at `color = [0.05, 0.45, 1.0]`, `deep_color = [0.02, 0.28, 0.85]` → lands at roughly `#4A90D6`–`#5473D1` after the grade (in the target's `#3f7fd4`–`#4a90e2` family). Treat these as **start values, calibrate against a capture** (see §5) — the exact colour space of the adjustment pass is `[uncertain]`.

**New asset:** one 64×64 white-on-transparent radial dot PNG, `assets/ui/water/droplet-dot.png`, generated by a committed `tools/make_water_dot.gd` (the `tools/make_icon_layers.gd` pattern). Project-owned, $0, listed in `assets/README.md`. **New libraries: none. Money: $0.**

## 3. Feature-by-feature

1. **Saturated blue body** — `water_body.gdshader` at `alpha` 0.85 (floor nearly hidden), unshaded so the amber bulb can't tint it, pre-compensated source colour, `deep_color` at the rim and a lighter centre via `edge_fade` — the luminous mass. A `wash_color` bloom of foam near the running sink (from the tag lookup) is the pale area around the sink in the target.
2. **Foam edge line** — the foam shader's core + halo on the existing `_edge_band`; `width` 0.085 m = **8.3 px** at the 1920×1080 canvas (98 px/m), which is 1.4 px after a 320-wide downscale instead of today's 0.8 px sub-pixel ghost. The thickening is an anti-aliasing decision as much as a taste one (Compatibility has no MSAA 2D); the scallop noise + arc-length wobble give the hand-painted break-up; `render_priority` 2 draws it over the body's rim.
3. **Ripple rings** — `_ring_band` × 4 at the radii above, on the foam shader in ring mode: wavy (scallop on the ring's angular `u`), white, thick, drawn at `floor_y + 0.006` above the body, with a slow outward travelling brightness pulse. They are children of the pour, so they appear 2.5 s after the tap opens, exactly as today. (`rings.expand_span > 0` would make them physically expand — offered as data, default 0, because the target reads as fixed concentric rings.)
4. **Cascade** — `water_fall.gdshader` on the existing tongue/rill/lip/foot boxes and basin slab: scrolling white streaks over saturated blue, side fades so the sheet has no rectangular edges, a bright lip at the basin and a white foot, the widened `OverflowRill` bands reading as the foam hugging the cabinet face; brighter and continuous with the rings below it because it shares the same blue and the same foam white.
5. **Droplets/spray** — the wet layer's particles get `mesh:"dot"` (camera-facing round dots, not 6-segment spheres), 22 of them, 42% larger, unshaded, near-white with a `color_ramp` fade-in/out so they don't pop; the cascade keeps its `splash` (bigger, brighter, white) and gains a softer `mist` emitter at the foot.
6. **Illustrated register** — the entire water family is flat, unshaded and self-lit with a baked edge gradient, in a room where everything else is lit by one bulb. That contrast *is* the Monument-Valley read: the water becomes the one painted thing on a photographed floor.

## 4. Renderer notes

Nothing in the proposal needs a GL capability the spec's ceilings list does not already guarantee: no decals, no screen or depth texture reads (deliberately avoided — fewer `[uncertain]`s), no glow (the halo is painted in the shader so the frozen room is never re-graded), no CompositorEffect, no new lights, same `CPUParticles3D`-only particle budget. `TIME`, `COLOR`, vertex UVs/colours, alpha blending and `ShaderMaterial` are engine-level and identical on Mobile and Compatibility.

Two things I would flag:
- **Billboard on Compatibility** — if I take the `water_drop.gdshader` fallback path (manual vertex billboard), that is pure vertex maths and renderer-independent; if instead the implementer uses `StandardMaterial3D.billboard_mode` + the dot texture, that is *not* listed in the ceilings and is `[uncertain]` on GL — one device check, and the fallback is the shader. **Primary = `StandardMaterial3D` billboard + generated dot texture** (conventional, correct particle scaling, no custom vertex math); the shader is the escape hatch if the phone disagrees.
- **`CPUParticles3D` writing per-particle colour into the `COLOR` varying** is what the shader fallback relies on — same mechanism `vertex_color_use_as_albedo` uses today, so it should hold, but it is the one thing to eyeball on the phone.
- Cost on the phone is trivial: the water adds ~6 small transparent meshes and ≤40 particles, and no new lights or passes. The water materials are rebuilt only when the wet region's cell set changes (every ~4 s), never per frame.

## 5. Risks + effort

**Failure mode 1 — the grade still wins.** The global `post.saturation` 0.55 caps the blue channel relative to red: to land `#4a90e2` exactly you would need either a negative-red source or a blue above 1.0, so the achievable result is ~`#4A90D6`–`#5473D1` depending on whether the adjustment runs in linear or sRGB (`[uncertain]`). Mitigation: the pre-compensated source colour, the edge gradient, and leaning the read onto the white foam/droplets/cascade that the grade cannot touch. Detection: `tools/capture.gd` with the existing intent sequence that opens the tap, sampled against the target's hex. If Bob wants the exact blue, the lever is one number — `post.saturation` 0.55 → 0.62 — which re-grades the frozen room and is his call, not this pass's.

**Failure mode 2 — the water reads as a sticker.** A flat unshaded blue on a lit floor can look pasted on, especially where the dilated puddle slices under a plinth and over the character's feet. Mitigation: `edge_fade` gradient, shader halo, `alpha` held at 0.85 (not 1.0), `light_scale` 0.55 so it dims with the room, the wash tying it to the sink, and verification against `water-late-closeup.png` at the same camera. Secondary risk folded in: near-coplanar transparent layers popping — handled by `render_priority` + the y offsets (band 0.024 / body 0.021 / rings 0.026).

**Effort: 4–6 agent-days** (5.25 nominal): body shader + vertex-colour plumbing + `_wobble` rework + wash lookup 1.25; foam shader + UVs + priorities 1.0; fall shader + pour rebuild 1.0; droplets (dot generator, `_make_particles` extensions, splash/mist) 0.75; `light_level` plumbing + visuals.json pass 0.5; capture/calibration on both renderer paths + PR evidence 0.75. **Money: $0.** Tests to add alongside: a `water_test.gd` assertion that the foam width clears 6 px at the design canvas, that the body material is the shader, and that `light_level` drops when `room_state.lit` is false.

## 6. What it does NOT solve

- **The exact target blue.** Quantified above; under a frozen 0.55 grade the pixel will sit in the right family but not on `#4a90e2`. Only a global grade nudge fixes it precisely.
- **Puddle shape.** Chaikin + a better wobble still yields a rounded blob; the target's outline is close but the *fingers* of a spreading liquid come from the cell set (`sim/hazards.gd`, unchanged) and the kitchen zone's reach — the water will not creep into the living area anywhere the sim does not already go. A materials pass cannot add reach without touching determinism and the solver.
- **No reflections, refraction, depth or shoreline interaction.** Compatibility has no SSR/SSIL and no decals: the water cannot wet the cabinet's base, leave footprint trails, or mirror anything. The target does not ask for these, but nothing here should be read as a step toward a reflective floor.
- **No real bloom.** The halo is painted inside the water's own pixels; it will not bleed onto the floor or furniture the way an engine glow would.
- **Not hand-painted.** The break-up is procedural (deterministic sine + hash noise, no RNG, so a recorded loop repeats). A 512² authored foam mask with edge-distance masking is the honest next step if the procedural reads too regular.
- **The room, the HUD, the death beat and the sim are untouched** — including the fact that `docs/06`'s state table still describes wet cells as "darker floor tint + specular", which this pass supersedes and which the reconciler may want to amend.
