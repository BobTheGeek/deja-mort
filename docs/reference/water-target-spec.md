# Water target — Bob's desired output

**The acceptance image:** `/Users/bobgibilaro/Downloads/Gemini_Generated_Image_y5tmhey5tmhey5tm.jpeg`
(an AI-painted mockup over a screenshot of this game's Room 1 with the tap running, timer 61.1 — treat it as the exact look Bob wants for the water.)

**The closest real frames today** (the current build, saved 4 Nov 2026 on branch `water-outline`):
`docs/reference/water-fallback-vivid/water-late-full.png`,
`.../water-late-closeup.png`,
`.../water-pour.png`.

## What the target shows, feature by feature

1. **Puddle body** — saturated, luminous mid-blue (roughly `#3f7fd4`–`#4a90e2` under this light), clearly bluer and more saturated than the current build, reading slightly self-lit on the dark floor. One clean mass across the kitchen, spilling toward the living area — roughly the spread the sim already does.
2. **Foam edge** — a bright, near-white, wavy line tracing the whole puddle boundary; thick enough to read at phone size; hand-painted irregular, like stylised game water.
3. **Ripple rings** — 3–4 concentric white/wavy foam rings on the floor around the sink's base, radiating from the spill, drawn over the puddle where they overlap; clearly visible from the fixed camera.
4. **Cascade** — at the sink, a bright blue vertical cascade with white foam streaks hugging the cabinet face from the basin lip to the floor; white spray at its foot; visually continuous with the rings and the puddle.
5. **Droplets/spray** — scattered bright white droplets across the spill zone, larger and brighter than today's.
6. **Register** — clean, high-contrast, illustrated (Monument Valley / stylised console VFX), never photoreal. Everything else in the room is unchanged from the screenshot.

## House constraints every proposal must respect

- **Engine:** Godot 4.7.2-stable (pinned). Desktop uses the **Mobile** renderer; phone builds fall back to the **Compatibility** (GL) renderer (`project.godot`). Every effect must work on both.
- **Compatibility ceilings** (verified against the Godot 4.7 docs): 8 omni lights per mesh (adjustable), **no decals**, no SSR/SSIL/SDFGI, no PCSS, no depth-of-field blur, no debanding (RGBA8); **glow is supported**; Environment adjustments supported; custom fullscreen-quad post-processing supported; shaders may read screen and depth textures; **CompositorEffects are not supported**.
- **Particles:** `CPUParticles3D` only — `tests/game/effects_test.gd` fails the build on GPU particles (the GL fallback cannot be trusted with them).
- **Architecture:** looks are data. `game/room_renderer.gd` reads `content/visuals.json`; objects resolve looks by **tags and state**, never by object id; meshes are referenced from room JSON as `"mesh": "<pack>/<name>"`. The sim (`sim/`) is pure logic (RefCounted, no rendering) and must stay deterministic; presentation is a consumer.
- **Pillars (fixed):** darkness as gameplay (light is information), silhouette readability at phone size, brand palette amber `#D9A05B` on void `#0B0C0F`, diorama-in-the-void framing, and phone-Compatibility performance. The rest of the room's look is approved and frozen — only the water may change.
- **Assets/licences:** CC0 preferred; agent-built pieces (Blender scripts → `.glb`) are committed with their generating script; paid packs live gitignored in `assets/paid/` and are documented in `assets/README.md`. The demo's art budget is **under $100** total (`docs/06`); Bob explicitly allows new libraries/assets for this — list every cost.
- **Where the water lives today:** `game/room_renderer.gd` (`_sync_outline_layer`, `_build_water_region`, `_outline_loops`, `_chaikin`, `_wobble`, `_polygon_mesh`, `_edge_band`, `_ring_band`, `_build_pour`, `_update_pour`, `_sync_stream`, `_make_particles`); `content/visuals.json` (`hazard.layers.wet`, `object.by_tag["wet-source"].stream`); `sim/hazards.gd` (the wet cell field the region is built from); `tests/game/water_test.gd` (the behaviour contract).
