# 06 — Art and Audio Requirements

## Art

### Direction

**Low-poly 3D, fixed orthographic isometric camera, diorama framing.** The room is a two-wall cutaway box floating in darkness — a specimen case, a bubble. Reference feel: Hitman GO, Monument Valley, Lara Croft GO. Bob has a concept image (low-poly isometric bedroom, `reference/style-target.png`) that shows the *construction* — keep the bones, change the mood.

**The mood is a lighting rig, not an art skill.**

- **One light source** per room (bare bulb, desk lamp, streetlight through blinds) with real shadows. Minimal ambient. Dark corners are gameplay (they affect his sight) and they're the look.
- **Palette:** desaturated — grays, cold blues, muted wood — with one warm accent from the light. The warm accent is the brand amber `#D9A05B` (see `brand/BRAND.md`); the void is `#0B0C0F`. No mint greens, no patterned rugs, no showroom brightness.
- **Flat shading, no textures.** Vertex color or a single material with a color ramp.
- **Post:** vignette and slight grain so it reads as a diorama, not a render. Optional tilt-shift if it's cheap.
- **Sparse dressing.** Every visible object is interactable. Decorative clutter thins out or becomes an object with tags.
- **Characters:** simple faceless figures, capsule-and-limbs, silhouette-readable. The room is the star.
- **Deaths:** stylized. A slump, a fall, the light flickers, fade to the loop counter. No blood, no gore.

### Camera and rendering

- `Camera3D`, orthographic, true isometric rotation (-35.264°, 45°, 0). Size tuned so a 12×10 room fills ~80% of a 16:9 frame; on portrait mobile, rotate the room 90° rather than shrinking it.
- **Renderer: Mobile.** One `DirectionalLight3D` or `OmniLight3D` with shadows enabled; test shadow quality on a phone at Milestone 3.
- Walls: the two back walls render; the two front walls are absent (cutaway). If a room's geometry needs a front wall for a door, render it as a low knee-wall with the door frame visible.

### State → visual mapping (global table, never per-object)

| state | visual |
|---|---|
| `open` | hinged part rotates / drawer slides |
| `broken` | swap to `<mesh>_broken` if present, else shrink + debris particle |
| `tipped/leaning` | rotate on pivot |
| `on` | emissive material + light child |
| `burning` | fire particle + orange point light |
| `wet` (cell) | darker floor tint + specular |
| `slippery` (cell) | glossy tint |
| `concealed` (cell) | none (that's the point) |
| `moved` | none |
| actor `hidden` | actor mesh disabled; object gets a subtle "occupied" tell only for the *player's* benefit? **No** — no tell. Trust the notebook |
| actor `prone/stunned/blinded/pinned` | pose swap; blinded adds a hand-over-eyes gesture |

### Asset sourcing

- **Greybox first.** Milestones 0–2 use boxes and capsules only. No asset work until the loop is proven.
- **Kenney** (CC0): Furniture Kit and related packs cover most household props. Also consider the ~$20 all-in-one bundle on itch.io.
- **Quaternius** (CC0): characters, props.
- **One paid Synty POLYGON pack** if a thematically perfect one exists (check for apartment / horror / office). Sold for Unity/Unreal; ships as FBX; imports into Godot fine. Keep in `assets/paid/` (gitignored) with the source documented in `assets/README.md`.
- **Agent-built** bespoke pieces (the room's signature trap object, the attacker figure) via Blender's Python API, matched to the pack's proportions. Deliver as `.glb`.
- Art budget for the demo: plausibly under $100.

### Import conventions

`assets/models/<pack>/<name>.glb` · scale normalized so 1 unit = 1 m · origin at footprint center, y=0 at floor · one material per model (flat) · objects referenced from room JSON by `"mesh": "kenney/dresser"`.

---

## Audio

### Stance (from the design doc)

1. **Sound is a system in both directions.** The sim emits `noise` events with cell and loudness. The attacker's perception consumes them; so does the `AudioDirector`. The player must be able to *hear him* when they can't see him.
2. **No dialogue. No VO.**
3. **The timer is the soundtrack.** Music only between loops and on the win screen.

### AudioDirector contract (`game/audio_director.gd`)

Subscribes to the event bus. Maps `(event.type, rule_id | object.tags, actor)` → cue via `content/audio_map.json`. Positional: each cue plays from the event's cell (3D audio with the iso camera as listener; stereo width matters more than distance). Attacker sounds are **always audible** regardless of walls (muffled through walls via a low-pass when no LOS), because they carry information.

### Required cues for the demo (what each one *communicates*)

**Attacker (information-bearing — must be distinct and always audible):**
- Footsteps outside the door (he's arriving) · door handle tried (he's at the door) · lock being worked (breach in progress; loops for `breach_costs.locked`) · chain strained/snapped · brace shoved (heavy scrape; loops for brace cost) · door opens · flimsy door kicked · window breaks · footsteps inside, per zone material (kitchen tile vs. living wood vs. bathroom tile — this is how a hidden player tracks him) · search cue: closet door / curtain / under-bed rustle / shower curtain (which spot he's checking) · investigate cue: a pause and a turn (subtle) · attack · leave (footsteps receding, door closes) · pause-tell (Room 4 only)

**Player actions (feedback; can be quiet):**
- Walk (per zone material) · grab / drop · push light / push heavy (scrape) · open/close · toggle (click) · hide (rustle) · throw + impact (per weight; fragile = shatter, loud) · pour · ignite · tap running (sustained) · TV on (sustained lure, diegetic) · phone: charging chime, call connected

**Systems:**
- Water spreading (sustained, low) · fire crackle (sustained) · shock (sharp, short) · shelf tip: creak (leaning), crash (falls) · gas hiss (Room 3)

**Timer and structure:**
- Tick or heartbeat metronome · final-10-seconds swell · zero: silence for one beat, then the door · death sting (short, dry — the deadpan tone; not a horror stinger) · reset whoosh (<1s) · win: a single resolved chord, then the win-screen music · between-loop ambient (room tone, distant traffic, a clock)

**Loudness values in `audio_map.json` are presentation-only.** The sim's `loudness` on noise events (what he hears) is defined in the rule table and is a separate number.

### Sourcing

CC0 libraries cover almost everything for the demo: Freesound (filter CC0), Kenney's audio packs, the Sonniss GDC bundles. Agents wire and mix; they do not compose. The between-loop and win-screen music is a placeholder until a composer or a later experiment. **Do not use the Yorushika track.** The feeling is the reference, not the song.
