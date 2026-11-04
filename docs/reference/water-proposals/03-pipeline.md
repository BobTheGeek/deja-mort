# SECOND LIGHT — the water as the frame's second light source

*(Proposal for the water look in DÉJÀ MORT / Room 1. Read-only; nothing was modified. Every number below is either measured from the reference frames or verified against the Godot 4.7 docs — uncertainties are marked.)*
*Expert session: `ses_e58d2207cffdSEBoY9SmFtbBM8` · 4 November 2026 · the shared brief is `docs/reference/water-target-spec.md`.*

---

## 1 · Approach

**The water is not a material to be lit; it is the room's second light.** Today the puddle is a 45%-alpha blue sheet lying on a warm floor, lit by an amber bulb that contains almost no blue, and then the whole frame is desaturated to 0.55 — so the water renders as the mauve-grey we see. My approach fixes it *upstream of the grade*: the water becomes **emission-dominated** (its value barely moves across the room's light gradient, which is exactly what makes the painted water read as self-lit), it is **colour-pre-compensated** for the 0.55 saturation that Godot applies *after* glow, and the frame-level systems (Environment glow, a cool unshadowed spill light, a wet-sheen halo band on the floor) are tuned so that the water's whites are the only thing in the frame that crosses the bloom threshold. No new renderer, no post-processing pass, no mask, no viewport, no decal (the spec's own ceiling), no new library. Cost: **$0, ~3–3.5 agent-days**, all portable to the phone's GL path.

## 2 · Exact mechanism

### 2.0 The measurements this is derived from (my reverse-engineering evidence)

Sampled from the two images with a pixel scanner (PIL), same screen regions:

| Sample | TARGET mockup (2714×1536) | CURRENT build (`water-late-full.png` / `-closeup`) |
|---|---|---|
| Puddle body, flat interior | **#445164 → #4a5567** (68,81,100 → 74,85,103), chroma b−r = **29** | **#616b74** (97,107,116), chroma b−r = **19** |
| Puddle body near the sink | #586e85 / #667c94 (102,124,148), chroma **46** | same as body, no hotspot |
| Lit floor inside the pool | #7f553f–#825840 (127–130, 85–90, 63) | warm-lit mean (123,89,68) — **identical** |
| Shadowed floor, same room | #4d3d3d–#423839 (77,61,61) | (50,46,49) |
| Foam / ripple core | **#ffffff**, halo #cedef7 → #b3c5dd → #8999a6 | brightest cool pixel ≈ #656f7c; no pure-white cool pixel at all; the frame's brightest non-HUD pixel is the warm lamp (253,253,248) |
| Frame's brightest cool pixel | (235,245,255) at the cascade | (99,113,125) |

Two findings fall out of this table and drive everything:

1. **The water's value is flat while the room's is not.** Target puddle: (68,81,100) on the lit side, (73,82,99) further from the bulb — a **±4%** variation. The floor over the same span goes (128,88,63) → (66,56,57), a **2×** variation. That is the entire "slightly self-lit" read. It is not brightness, it is *constancy*.
2. **The puddle is not more luminous than the lit floor — it is more chromatic.** Luma: puddle 80, lit floor 89, shadowed floor 62. Chroma: puddle b−r = 29, floor b−r = **−65**. The water reads because it is the only cool mass in a warm field at mid value. *Nothing in my proposal raises the water's brightness above the pool's.* (This also means the spec's stated `#3f7fd4` is the intent, not the pixels: the painted pixels are a slate #445164. Aim for the pixels.)

### 2.1 Godot's grade order — the fact the whole design hangs on

`Environment`, class reference, order of operations: **Depth of Field → Auto Exposure → Glow → Tonemap → Adjustments.** So glow is generated *before* `post.saturation` (0.55) and `post.contrast` (1.10) touch the image. Two consequences:

- The water's **source colour must be more saturated than the target's final pixel**, because the grade will pull it back.
- Pre-compensating in the material **replaces** the need for a masked post grade (which is what I would otherwise have had to propose, and which I reject in §6).

Undoing `saturation 0.55` and `contrast 1.10` from the target's final pixel gives the pre-grade pixel the water must render at:

- read in sRGB space: **#415a77**
- read in linear space: **#52627d**  → `[uncertain: the docs say "after tonemapping" but not in which encoding the mix happens; the two readings bracket the answer and both are far bluer than the current output]`

Aim: **#46597a**, i.e. linear `(0.061, 0.100, 0.191)`.

### 2.2 The actual bug: alpha, not colour

Solving the alpha-blend for the water body: `a·W + (1−a)·F = pre_grade`, with `F` the lit floor's linear radiance `(0.216, 0.098, 0.051)`:

| alpha | required water output `W` | verdict |
|---|---|---|
| **0.45** (today) | `(−0.066, 0.048, 0.157)` | **negative red — impossible.** No colour at 0.45 alpha can be this blue; the floor's red always bleeds through and neutralises it |
| 0.85 | `(0.034, 0.100, 0.216)` = **#345880** | achievable, and stable across the lit/shadow zones (#345880 → #445c80) |

So: **`hazard.layers.wet.alpha` 0.45 → 0.85 is the single biggest fix.** The current albedo `#3F80D9` is already nearly the right hue; at 0.45 alpha it can never show it.

### 2.3 Exact data (all of it in `content/visuals.json`)

```jsonc
"post": {
  "saturation": 0.55, "contrast": 1.10, "brightness": 1.0,   // UNCHANGED - the room is frozen
  "tonemap": "linear",                    // NEW key. Keep LINEAR: Filmic/ACES/AgX desaturate
                                          // highlights, which would grey the cascade core and the blue.
                                          // Linear also makes Mobile and Compatibility identical here.
  "glow": {
    "enabled": true,
    "blend_mode": "screen",               // GLOW_BLEND_MODE_SCREEN. Compatibility FORCES Screen and
                                          // ignores the property; 4.7's default is already Screen (changed
                                          // in 4.6), so setting it explicitly locks the pair together.
    "hdr_threshold": 0.95,                // MUST be < 1.0: Compatibility's colour buffer is RGBA8/LDR
                                          // and clips at 1.0, so a threshold of 1.0 glows on desktop
                                          // and does nothing on the phone. Godot's own note for the
                                          // Mobile renderer says "a value of 0.9 works well".
    "hdr_scale": 2.0,                     // default; softens the threshold edge
    "intensity": 1.5,                     // Godot's documented Mobile compensation (default is 0.3)
    "bloom": 0.06,                        // a whisper of uniform lift so the halo has no hard ring
    "strength": 1.5,                      // DESKTOP-ONLY (documented no-op on Compatibility)
    "levels": [0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0]   // DESKTOP-ONLY (levels/no-ops on Compatibility)
  },
  "glow_fallback": { "hdr_threshold": 0.97, "intensity": 1.2 }  // read only when the GL renderer is active
},
"hazard": { "layers": { "wet": {
  "color":          [0.086, 0.137, 0.227],   // was [0.25,0.5,0.85]. Dark + near-neutral on purpose: the
                                             // ALBEDO is what varies with the room's light, so it must be
                                             // small or the water stops being value-flat.
  "emission_color": [0.231, 0.345, 0.502],   // NEW key -> #3b5880, the derived pre-grade pixel
  "emission":       0.90,                    // was 0.04. This carries ~90% of the water's output.
  "alpha":          0.85,                    // was 0.45
  "rim_color":      [1.0, 1.0, 1.0],         // was [0.72,0.86,0.96]
  "rim_alpha":      0.90,                    // was 0.55
  "rim_emission":   1.15,                    // NEW -> crosses the glow threshold = pure white + halo
  "rim_width":      0.075,                   // was 0.05. 0.075 m = 7.4 px at 1080p (camera.size 11 m / 1080)
  "halo_width":     0.30, "halo_color": [0.30,0.50,0.77], "halo_alpha": 0.12,  // NEW, see 2.4
  "light": { "color": [0.45,0.66,1.0], "energy": 2.0, "range": 6.0 },          // NEW, see 2.4
  "particles": { "unshaded": true, "color": [1.0,1.0,1.0], "amount": 22,
                 "lifetime": 3.2, "scale": 0.085, "velocity": 0.10, "spread": 10.0, "gravity": 0.0 }
}}},
// in object.by_tag["wet-source"].stream:
  "emission": 0.90,                                    // the faucet jet (was 0)
  "basin":    { "emission": 0.60, "alpha": 0.85 },     //   was 0.04 / 0.65
  "overflow": { "emission": 0.75, "alpha": 0.85,       //   was 0.04 / 0.62
                "foam_color": [1,1,1], "foam_emission": 1.20,   // NEW; the rills are currently shape.color at 0.63 alpha
                "rings": { "radii": [0.42, 0.66, 0.92, 1.20],   // was [0.3,0.47,0.66] - 4 rings, per the spec
                           "width": 0.06,                       // was 0.025 (2.5 px at 1080p: invisible on a phone)
                           "alpha": 0.90,                       // was 0.45
                           "emission": 1.10,                    // NEW
                           "color": [1.0, 1.0, 1.0],
                           "falloff": 0.85 } },                 // was pow(0.72, i)
  "splash":   { "unshaded": true, "color": [1,1,1], "amount": 24, "velocity": 1.6, "scale": 0.08 }
```

### 2.4 Five micro-capabilities in `game/room_renderer.gd` (all ~5 lines, none architectural)

1. `_material(colour, emission, alpha)` gains an optional **`emission_color`** (falling back to `colour`). Without it, albedo and emission are forced to the same colour and §2.2's split is impossible. *This touches a function every object in the room uses — read the key only when present.*
2. `_edge_band(...)` gains an `emission` parameter (called with `spec.rim_emission`). Today it hardcodes `_material(colour, 0.0, alpha)`.
3. `_ring_band(...)` gains an `emission` parameter (called with `rings.emission`). Same reason.
4. `_edge_band(...)` gains **inner/outer alpha via vertex colours** and its material gets `vertex_color_use_as_albedo = true`: this is the **`WetHalo`** mesh, a second outward band, 0.30 m wide, nested outside the waterline band, blending `BaseMaterial3D.BLEND_MODE_ADD`. Call it in `_build_water_region` beside `Waterline` and `WaterBody`. It is the paint's "the floor around the water is cooler and lifted" — a wet sheen that is *occlusion-correct for free* (it is real geometry on the floor plane) and that never double-blends under the translucent body (it lies outside it, the property the existing comment already protects).
5. `_build_water_region` attaches the layer's `light` block **once per region** at the region's centre (`_make_light` already exists and is already shadow-free), with energy scaled by region area: `energy = base × clampf(cells/12.0, 0.4, 1.0)`. The code already supports `spec.light` for *cell* layers; the `shape: "outline"` path skips it.

Optional, but recommended for the illustrated register: a **committed noise PNG** (`tools/` script → `assets/water/foam-noise-256.png`, tiling value noise, project-owned, $0) used to modulate `rim_width` and the ring alphas so the foam edge wobbles *irregularly* rather than by `_wobble`'s sine. Asset cost: **$0** (generated, not downloaded).

### 2.5 Third-party additions, with exact names, licences and cost

| Addition | Licence | Cost | Verdict |
|---|---|---|---|
| **None required** | — | **$0** | The whole target look lands without a library |
| *Kenney Particle Pack* (kenney.nl/assets/particle-pack), soft radial billboard sprites for droplets/spray | **CC0 1.0** (same source family the project already ships: Furniture Kit, Food Kit) | **$0**, must be added to `assets/README.md` | Optional upgrade for feature 5 only. Our droplets are currently shaded spheres (`_particle_mesh()` is a 6×3 `SphereMesh`); a billboard quad + radial sprite reads far more like painted spray. `[uncertain: billboarding in a StandardMaterial3D under the Compatibility renderer — vertex-shader feature, expected to work, verify on device]` |
| *A post-processing addon / CompositorEffect stack* | — | $0 | **Rejected by the engine**: CompositorEffects are ❌ on Compatibility (renderer table). Do not buy or vendor one. |

Total art spend for this proposal: **$0**, against a budget of "under $100".

## 3 · Feature by feature

**1. Saturated blue body.** Alpha 0.45 → 0.85 (the floor can no longer desaturate it) + a dark albedo with a pre-compensated emissive colour (#3b5880, derived by undoing the 0.55 saturation the frame applies after glow). Renders at the target's measured **#445164–#4a5567**, with a more chromatic core (#586e85) near the sink from the spill light and the basin's own emission. Value-flat by construction (emission dominates), which is the measured signature of the paint.

**2. Foam edge line.** `rim_color` → pure white, `rim_alpha` 0.90, `rim_emission` 1.15, `rim_width` 0.075 m (7.4 px at 1080p; the target's line is 0.07–0.13 m). Emission ≥ 1.0 clips to **#ffffff** on both renderers *and* is the only large cool mass in the frame above the glow threshold, so it arrives with the soft blue-white halo (#cedef7 → #b3c5dd) the paint shows — generated by glow, not painted on.

**3. Ripple rings.** Four rings (radii 0.42/0.66/0.92/1.20 m), width 0.025 → **0.06 m** (2.5 px at 1080p today — they exist in code and vanish on screen; the test only counts `SplashRing` nodes), alpha 0.90, `emission 1.10`, white, falloff 0.72^i → 0.85^i so the outer rings still read. Same glow halo as the foam.

**4. Cascade.** The jet, basin fill and overflow sheet get emission 0.9/0.6/0.75 at alpha 0.85 — self-lit rather than dependent on the amber bulb (measured target: the sheet reads #8999a7 with a **#ffffff** core at the tap, and the current build's equivalent is a pale grey-blue rectangle). The rills become white (new `foam_color`/`foam_emission`) so vertical white streaks carry the overflow; the existing `splash` particle burst at the foot turns unshaded white and gets the glow halo, which is the white spray at its base. This is why the cascade reads visually continuous with the rings and the puddle: **all four are the same emissive white crossing the same threshold.**

**5. Droplets / spray.** `hazard.layers.wet.particles`: `unshaded` false → **true**, colour → **[1,1,1]**, amount 10 → 22, scale 0.06 → 0.085, lifetime 2.4 → 3.2, gravity −0.02 → 0.0. Unshaded white at 1.0 means every droplet crosses the glow threshold, so they read as bright spray with halos instead of the grey specks they are today (today they take the room light: the comment in `effects_test.gd:119` says "unshaded only where something glows" — these now genuinely glow, and that comment should be updated with the change).

**6. Illustrated register.** Delivered by *four frame-level decisions*, not by textures: (a) **linear tonemap retained** — a hard white core with no filmic rolloff, and flat poster colour fields between the white and the blue; (b) **emission-dominated water** — its value ignores the room's gradient, which is what "painted on" means; (c) **a hard-ish glow threshold** (0.95) — bright cores plus a soft blue-white halo, no muddy mid-tones, and the *area* of white (foam + rings + droplets + cascade) is what makes the water's halo louder than the lamp's; (d) **specular 0.0 / roughness 1.0 kept** — the water stays matte like paint, despite `docs/06`'s "wet = darker floor tint + specular". The target's puddle has no specular highlight; do not add one.

## 4 · Renderer notes (the phone's Compatibility path)

**Verified facts that change what I can promise** (all from the 4.7 class reference and the renderer comparison):

- **Glow is supported**, but the Compatibility implementation is "simpler, optimized for low-end devices", and the docs mark these as **no effect** there: `glow_blend_mode` (always Screen), `glow_strength`, `glow_normalized`, `glow_mix`, `glow_levels/1`, `/2`, `/4` (assume the whole levels row, `[uncertain]` for `/3`,`/5`–`/7`). **The halo's radius is therefore not controllable on the phone.** Only `glow_hdr_threshold`, `glow_hdr_scale`, `glow_intensity` and `glow_bloom` are portable.
- **Colour buffer is RGBA8 / low dynamic range** (Mobile: RGB10A2, up to 2.0; RGBA16F only with HDR 2D, which Compatibility does not have). This is *why* the threshold must be 0.95, and it means desktop will show a slightly wider halo ramp than the phone (0.95→2.0 vs 0.95→1.0). §2.3's `glow_fallback` block exists to close that: read it at build time when `RenderingServer.get_rendering_device() == null` (Compatibility) `[verify — the documented alternative is ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility"]`. This per-renderer post block is **the one capability beyond the spec's ceilings list**; it needs no engine feature, only a branch on existing data.
- **Adjustments and tonemapping: supported and identical** on both paths, so the grade my numbers are pre-compensated against is the same on the phone.
- **One extra unshadowed OmniLight3D per region** — inside the 8-omnis-per-mesh budget; the puddle sits in the middle of the floor grid where each affected floor cell has exactly 2 lights (the bulb + this).
- **CPUParticles3D only** — unchanged, and my droplets stay CPU-driven (the only change is `unshaded` + colour).
- **No decals, no depth texture in canvas shaders, no compositor effects** — none needed. The wet halo is geometry, not a decal; the glow is the engine's; there is no post pass.
- **Cost:** glow is fill-rate work on GL. The water's bright area is maybe 3% of the frame, so the glow pyramid adds roughly one small-RT blur chain: expect **< 1 ms** at 1080p on a mid phone `[uncertain — measure]`. It is a single data-driven `post.glow.enabled` switch away from being disabled if frames drop.

## 5 · Risks + effort

**Risk 1 — the bloom does not survive the port.** The halo is the paint's most distinctive element and it is generated by the one effect whose *shape* I cannot control on the phone (strength/levels are no-ops; blend is forced to Screen). Failure mode: on the device the halo is a 2-pixel fringe, the foil for the illustrated register collapses, and the water reads flatter than the desktop review suggests. *Mitigation:* the emissive colours carry 90% of the look without any glow — the water is still saturated, value-flat and white-edged with glow off. Verify with one GL capture before sign-off; the `glow_fallback` block is where you compensate.

**Risk 2 — alpha 0.85 turns the puddle into a blue mat.** At 0.45 the water is a wet floor; at 0.85+ it is a flat mat, and the seams between two adjacent regions become visible (each region is a separate 0.85-alpha sheet, so a join double-blends). Second-order: `_sync_hazards` frees outline regions outright, so the loop reset pops instead of fading (`loop.hazard_fade_s` 0.25 exists in data but is not honoured on this path). *Mitigation:* stay at 0.85, never 1.0; ship the `WetHalo` in the same commit so the edge dissolves into the floor rather than cutting; if the pop shows, wire `hazard_fade_s` into the outline path as an alpha ramp (0.5 day).

**Effort:** glow block + renderer detection 0.5 d · five micro-capabilities 0.5 d · the data pass and the colour calibration 1 d · `WetHalo` 0.5–1 d · device verification on both renderers + acceptance shots 0.5 d = **3–3.5 agent-days, $0.** Plus one proposed test: assert on the built `WaterBody` material that `emission_enabled`, `emission_energy_multiplier ≥ 0.8` and `albedo_color.a ≥ 0.8` — the "self-lit and not floor-coloured" contract, checkable headless, alongside the existing `water_test.gd` node-name contract (`WaterBody`, `Waterline`, `SplashRing`, `PourStream`, `BasinFill`, `Overflow` — all preserved).

## 6 · What it does NOT solve

1. **Hand-painted irregularity.** The foam edge and rings come from Chaikin smoothing plus a sine `_wobble`; that is *regular* irregularity. My noise-PNG option is the honest path and it is a texture on geometry, not a frame effect — without it, a close look still says "procedural".
2. **The rings' dashes and dots.** The target's rings are broken segments with specks on them. Glow can light them; only per-ring authoring can break them.
3. **The cascade's internal streaking.** I make the sheet self-lit and the rills white; the *vertical texture inside* the sheet is geometry/UV work.
4. **The mockup's brighter, warmer mid-room.** Measured: the target's shadowed floor and wall mids sit above the live build's (#4d3d3d vs #2d3241 in places) — the paint lifted the whole room, not just the water. The spec says the room is frozen, so I deliberately spend nothing there; the spill light lifts only the water's neighbourhood. A side-by-side reviewer will still see the mockup's room as a touch brighter.
5. **A true water-only colour grade.** I chose pre-compensation over a masked post pass, and I want that on the record: a 2D (CanvasLayer) post pass **cannot read depth in 4.7** (the canvas_item shader reference has no `DEPTH_TEXTURE` built-in), and a 3D screen-reading pass gets a copy taken **before the transparent pass**, so it cannot even see the water. An occlusion-correct mask needs a second 3D viewport sharing the game's `World3D` with a `cull_mask` for a key layer — a whole extra render pass on the phone, for a refinement the pre-compensation already buys at zero cost. If the reconciler wants that tier, that is what it costs.
6. **The particles.** Droplets stay `CPUParticles3D` spheres (no trails, no attractors on GL) and are nothing like the paint's big arrow-shaped foam chunks; the Kenney sprite option narrows but does not close that gap, and it is *not* the "larger droplets" the spec asks for in kind.
7. **The shape of the wet region** — its spread and outline are the sim's, and this proposal changes none of it.
