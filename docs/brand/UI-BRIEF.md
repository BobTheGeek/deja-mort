# DÉJÀ MORT — UI design brief for Claude Design

Hand this whole file over as the prompt. It is written to be pasted as-is.

---

## 0. What I need from you, in one line

Design the game's five UI surfaces — **action wheel, HUD, notebook, win/loss screen, title screen** — and deliver them as **outlined SVG + PNG @1×/2×/3×, plus one `ui-tokens.json` of every number you chose**. No live text in any delivered file. No Godot scenes; the engine builds the widgets in code and reads your numbers from JSON.

Read §6 (output formats) before you draw anything. The engine constraints there change what is drawable.

---

## 1. The game

**DÉJÀ MORT** — *You've died here before.* A die-and-retry room-survival puzzle game. Godot 4, Mobile renderer, shipping to desktop and phone.

You are alone in a room. In 75 seconds a man comes in to kill you. You cannot fight him and you cannot outrun him. You can only use the room: pour the cooking oil where he will step, put the toaster in the full sink, tip the bookshelf into the doorway, hide under the bed and let him leave. You will die many times. Each death teaches you one fact about the room or about him, and the notebook writes that fact down for you. Then the loop resets and you try the next idea.

**The tone is deadpan, not horror.** No blood, no gore, no jump scares, no screaming. A death is a slump, a fall, the light flickering, and the loop counter going up by one. The game is never frightening; it is *patient and a little cruel*. The humour, where there is any, is dry.

**The look** is a low-poly 3D room seen from a fixed isometric camera, lit by one bare bulb, floating in a black void like a specimen in a case. Desaturated greys and cold blues, one warm amber accent from the light. Reference feel: Hitman GO, Monument Valley, Lara Croft GO.

Screenshots of the current build are in `docs/screenshots/`:

| file | what it shows |
|---|---|
| `m4_lit.png` | the room as it normally reads |
| `m4_inspect.png` | the inspect line at the bottom (current placeholder HUD) |
| `m4_death.png` | mid-death: he is swinging, the body is down |
| `wheel_fridge.png` | the action wheel open on an object — **this is the thing that most needs you** |
| `m4_tipped.png`, `m4_fire.png`, `m4_flood.png`, `m4_dark.png` | hazard and state reads |
| `win_screen.png` | the current placeholder win screen |

**Everything you design sits on top of that 3D room.** The room must stay partly visible behind every panel; it is the thing the player is reasoning about. Panels are dim glass over a diorama, never opaque pages that replace it.

---

## 2. Brand — fixed, not up for redesign

The brand kit is approved and shipped. Read `docs/brand/BRAND.md` and obey it exactly. Summary of what binds you:

| Token | Value | Use |
|---|---|---|
| `BG_DARK` | `#0B0C0F` | the void, panel bases |
| `FG_DARK` | `#D7DAE0` | type and marks on dark |
| `BG_LIGHT` | `#ECEDEF` | light backgrounds |
| `FG_LIGHT` | `#151619` | type on light |
| `ACCENT` | `#D9A05B` | the warm amber. The bulb, the timer's last ten seconds, the minute hand |
| `ACCENT_ON_LIGHT` | `#C2853E` | the accent on light backgrounds |

- **Type, UI:** Inter Regular / Bold / Light. Already in the repo at `assets/fonts/inter/`.
- **Type, wordmark:** Archivo Medium — **wordmark only, never in UI**. Use the delivered SVG lockups rather than setting the wordmark yourself.
- **Never use red.** Not for danger, not for the timer, not for a loss. This game has no red. Urgency is the amber accent; failure is the absence of light.
- The mark is a clock face reading 1:30. Do not move the hands, add numerals, fill the circle, or recolour the accent.

**If a surface genuinely needs a colour these six cannot express** — for example a "found / not found" state that must not read as either foreground or accent — propose it explicitly as a named addition to the token set, with the hex, the reason, and where it is used. Do not quietly introduce it. Every colour in your delivery must resolve to a token name.

**Contrast:** body text on any panel must hit at least 4.5:1 against what is behind it *including the room showing through*. Assume the room behind a panel can be anywhere from `#0B0C0F` to a lit wall around `#9a8f84`.

---

## 3. The five surfaces

### 3.1 The action wheel — the priority

**This is the whole control scheme.** The game has one input: a single pointer (mouse click, touch tap, or controller cursor). You tap a thing in the room, the wheel opens on it, you pick a verb. There is no other action UI, no inventory screen, no context menu, no keyboard shortcuts.

**Opening the wheel pauses the sim.** That is the time model: thinking is free, doing costs seconds. The pause must read instantly — right now the room dims 45% behind it, which you may keep, replace, or refine.

**Fixed layout — do not change it.** Nine slots: eight compass positions plus a centre. The position of a verb never changes, so muscle memory is the skill:

| slot | angle | verb id | label |
|---|---|---|---|
| centre | — | `inspect` | Inspect |
| N | 0° | `grab` | Grab |
| NE | 45° | `push` | Push |
| E | 90° | `open` | Open/Close |
| SE | 135° | `toggle` | Toggle |
| S | 180° | `hide` | Hide |
| SW | 225° | `throw` | Throw |
| W | 270° | `use-held-on` | Use held on |
| NW | 315° | `drop` | Drop/Place |

**Every slot is always drawn**, available or not. The unavailable ones are the tutorial: seeing "Throw" greyed out until you are holding something is how the player learns that throwing needs a held object. Current values are 100% / 28% opacity; you can do better than opacity.

Required states per slot: **available**, **unavailable**, **hover/focus**, **pressed**, and the wheel-level state **refused** (see below).

**Each slot must carry, legibly, at a glance:**
1. the verb — an icon, a word, or both; you decide, but a first-time player must be able to guess what it does
2. whether it is available
3. the **time cost in seconds** when available (e.g. "1.5s"). This is currently only in a tooltip, which is useless on a phone. The whole game is a 75-second budget; the cost of an action is the single most important number on the wheel.

**The wheel also has a caption**, added after a playtest, and it must survive your redesign:
- It names the object the wheel is aimed at — *"Toaster"*.
- When several objects share a floor square it says which one — *"Toaster (2 of 5 here — click again to cycle)"*. Five objects sharing one square is real; the kitchen counter in Room 1 has the drawer, the charger, the cooking oil, the toaster and a collectible token all on one cell.
- On a refused action it stays open and says why — *"Grab — can't do that from here"* — in the accent colour. A wheel that closed silently on a refusal was indistinguishable from a character that would not move, and cost a playtester his whole session.

**Bob's verdict on the current wheel: "not legible and needs a serious design pass."** He is right. It is nine default grey Godot buttons in a ring.

**Constraints:**
- The wheel opens **centred on the tapped point**, anywhere on screen, including near an edge. Design for edge collision: it must still be usable when opened 60 px from a corner.
- Minimum touch target **44 × 44 dp** per slot, with enough gap that a thumb cannot hit two.
- It must be readable at the smallest supported window (1152 × 648) and on a phone at arm's length.
- The room behind the wheel stays visible: the player is choosing *where* as much as *what*.

### 3.2 The HUD — always on screen

Small, permanent, never in the way. Current elements:

| element | content | notes |
|---|---|---|
| **the timer** | `75.0` counting down, one decimal | The loudest thing on screen. Currently 64 px, top centre. It is the soundtrack and the antagonist. In the last 10 seconds it turns amber — design that escalation. |
| **loop counter** | `Death 3` | Not a score. A fact. It should feel like a tally scratched on a wall. |
| **holding** | `Holding: lighter` or `Holding: —` | |
| **hidden** | `Hidden in: closet`, shown only while hidden | Being hidden is a fragile state; it should feel like it. |
| **inspect line** | `Fridge — Humming. Heavy. Exactly as wide as the doorway.` | Bottom centre, 5 seconds, then fades. This is the only voice the game has in the room. Some lines run ~90 characters; design for two lines of wrap. |
| **banner** | `DEAD`, `LOSS`, `EVADE`, `DISABLE`, `KILL`, `ESCAPE` | Centre screen, at the *end* of the death beat. |

Design these as a set. Include **portrait phone** placement — the timer cannot sit under a notch, and the inspect line cannot sit under a home indicator. Assume a safe-area inset.

### 3.3 The notebook — the hint system

Opened with Tab or a HUD button; **pauses the sim**. It is auto-written, never typed by the player, and it is the only narrator the game has. Three tabs:

| tab | contents | empty state |
|---|---|---|
| **Room** | Everything you have inspected. Per object: name (bold), the inspect line, then the revealed tags in italics — e.g. `Cooking oil` / *"Half a bottle. Slippery when spilled."* / `carryable, pourable, flammable`. Grows to 20+ entries; needs to scroll. | "Nothing inspected yet." |
| **Attacker** | What you have observed about him, one line per fact — how he gets in, what he does first, what he searches, how long the chain holds him. | "Nothing observed yet." |
| **Deaths** | One line per death, numbered: `Death 2. He found you under the bed.` This is the game's dry comic voice. | "No deaths yet. Give it time." |

Bob: *"reads fine, though it needs a design pass."* It is currently a 620 × 460 grey box with three plain tab buttons and a `RichTextLabel`.

**The conceit is a notebook — but it is not a skeuomorphic paper notebook.** No ruled lines, no coffee rings, no handwriting fonts, no leather. It is closer to a case file or an evidence log: something cold that records what happened to you, repeatedly, without comment.

Needs: tab row with clear selected/unselected states, a scrollable body, a visible "this list continues" affordance, and a close control. Body text must be set in Inter at a size that survives a phone.

### 3.4 The win / loss screen

Shown on a win. Currently one panel of text. The empty slots on it are the pitch — they tell the player something better exists without a word of copy.

It must present:

| element | content |
|---|---|
| **stars** | 1–3, earned and unearned both shown (`★★☆`) |
| **ending name** | one of `EVADE`, `DISABLE`, `KILL`, `ESCAPE` |
| **deaths** | `Deaths: 7` |
| **time survived** | `Time survived: 77.6s` |
| **the endings row** | all four endings, found ones lit, unfound ones as silhouettes. **The most important element on the screen** — it is the "there are three other ways to solve this room" message, delivered without text |
| **interactions** | `14 / 38` |
| **discoveries** | `3 / 9` |
| **ways to die** | `6` |
| **collectible** | found / not found — one hidden token per room |
| **completion** | `48%` |
| **the notebook line** | a single italic sentence about the run |
| **buttons** | `Replay`, `Next Room` (disabled until Room 2 exists — design the disabled state) |

**Also design the loss state.** There is currently no loss screen at all: you die, the word LOSS appears, and about two seconds later the room resets. That reset is deliberate and must stay fast — the loop is the game, and a slow death screen kills "one more try". So the loss treatment is **the two-second beat itself**, not a screen with buttons: what the player sees during the slump, the flicker, and the fade to the loop counter. Design that sequence. It has to feel like a shrug, not a punishment.

### 3.5 The title screen

Specified in `docs/brand/BRAND.md` and not yet built: the clock mark ticks once, the wordmark appears, the tagline fades in, then a door (the first-treatment door mark, `docs/reference/approved-door-mark.png`) opens into Room 1.

Design the frames and hand over the timing. Also design: **Continue / New / Settings**, and the room-select strip that will appear once Rooms 2–4 exist (four entries, each showing stars earned and endings found).

---

## 4. How this game is built — what it means for you

- **The UI is built in code**, not in a Godot scene file. Every widget is constructed by a script that reads its numbers from `content/visuals.json`. So your delivery is **a specification plus assets**, never a scene.
- **Every number you choose must be data.** Sizes, radii, paddings, hold durations, fade times, opacities. A literal in the code is a bug in this project by rule. Give them to me as JSON (§6.4) and I will merge them into `content/visuals.json` under the existing `wheel`, `hud`, `panel`, `death` and new `notebook` / `win` blocks.
- **Nothing may key off a specific object.** No design that requires a bespoke icon for the toaster. Objects are tags and state; if a slot needs an icon, it is a *verb* icon (nine of them) or a *tag* icon (a short shared list I can supply), never an object icon.
- **All copy is generated at runtime** — object names, inspect lines, death lines, counters. You control the frame, the rhythm, and the type; you do not control the string. Design for variable length and say what happens at overflow.

---

## 5. Engine constraints — read before drawing

The renderer is **Godot 4 Mobile, falling back to GL Compatibility on phones**. That rules out several things designers normally reach for:

1. **No backdrop blur.** Frosted glass over the room is not affordable. Use opacity, tint, and grain instead.
2. **No real-time drop shadows on UI.** If a shadow is part of the design, bake it into the PNG with transparency.
3. **No gradients that need a shader.** A gradient baked into a texture is fine. A procedural or animated one is not.
4. **No blend modes beyond normal alpha.** No multiply, no screen, no overlay.
5. **Animation is transform + opacity only** — position, rotation, scale, alpha, and swapping between delivered frames. If something should pulse, wipe, or tick, deliver it as frames or as a tween spec (from → to, duration, easing).
6. **One font family for UI: Inter.** Do not introduce another. Weights available: Light, Regular, Bold.
7. The game already applies a **vignette and film grain** over everything (strength 0.55, grain 0.03) and pulls global saturation down to 0.62. Your UI sits *under* that, so anything you design will land slightly darker and slightly less saturated than your artboard. Design against the delivered screenshots, not against white.

---

## 6. Output formats — the part that matters most

### 6.1 Design frame

- Primary: **1920 × 1080** (16:9 landscape). Everything specified in px at this frame; the engine scales proportionally.
- Also deliver: **1080 × 1920** portrait phone layouts for the HUD, wheel, notebook and win screen. Assume a 44 px top safe-area inset and a 34 px bottom inset.
- Must remain legible when the game window is as small as **1152 × 648**.

### 6.2 Vector

- **Outlined SVG only.** Convert every `<text>` element to paths using the real Inter glyphs, exactly as the brand kit's `svg/outlined/` files were made. A live `<text>` renders in a default serif on any machine without the font installed, and Godot will not substitute for you.
- Keep the editable live-text version too, in a separate `svg/live/` folder, as the source you would come back to. I will not ship those.
- No embedded raster images inside an SVG. No filters (`feGaussianBlur` and friends do not survive Godot's SVG rasteriser). No CSS classes that depend on an external sheet.
- One artboard per asset, tight bounds, origin at top-left, integer dimensions.

### 6.3 Raster

Godot rasterises an SVG once at import time at a fixed scale, so a vector scaled up in-game goes soft. For anything that must be crisp, I need PNGs:

- **PNG, 32-bit RGBA, transparent background, no colour profile, no interlacing.**
- Three sizes per asset: `@1x`, `@2x`, `@3x` where `@1x` is the size at the 1920 × 1080 frame.
- Power-of-two dimensions are **not** required.
- **Do not bake text into a PNG** unless the string is fixed forever (a logo, a verb label if you decide labels are art rather than type). Anything containing a number, an object name, or a generated sentence must be engine-rendered type, so what I need from you there is the type spec, not a picture of it.

### 6.4 The token file — required

A single `ui-tokens.json` containing **every number you chose**, so it can go straight into `content/visuals.json`. Shape it like this (these are the current live values, as a format example — replace them with yours):

```json
{
  "wheel": {
    "radius": 104.0,
    "slot_size": 78.0,
    "center_size": 92.0,
    "available_alpha": 1.0,
    "faded_alpha": 0.28,
    "backdrop_color": "$BG_DARK",
    "backdrop_alpha": 0.45,
    "caption_size": 20.0,
    "caption_color": "$FG_DARK",
    "refused_color": "$ACCENT",
    "slot_angles_deg": { "N": 0, "NE": 45, "E": 90, "SE": 135, "S": 180, "SW": 225, "W": 270, "NW": 315 }
  },
  "hud": {
    "timer_size": 64,
    "urgent_below_s": 10.0,
    "urgent_color": "$ACCENT",
    "inspect_size": 20.0,
    "inspect_hold_s": 5.0,
    "inspect_fade_s": 0.8
  },
  "panel": {
    "color": [0.06, 0.06, 0.08],
    "border_color": [0.3, 0.29, 0.27],
    "border_width": 2,
    "corner_radius": 4,
    "padding": 18
  }
}
```

Rules for that file:
- A colour is either the string `"$BG_DARK"` / `"$FG_DARK"` / `"$BG_LIGHT"` / `"$FG_LIGHT"` / `"$ACCENT"` / `"$ACCENT_ON_LIGHT"`, or a literal `[r, g, b]` in 0–1 floats. The `$` form is a live reference to the brand token and is strongly preferred — it means a token change propagates.
- Durations are seconds with an `_s` suffix. Angles are degrees with `_deg`. Distances are px at the 1920 × 1080 frame.
- Every number in your layouts appears here. If I have to measure something off a PNG, it is not specified.

### 6.5 Nine-slice panels

Panels resize with content, so a fixed-size PNG will not do. For every panel, frame, or button background:

- Deliver the texture **plus its four slice margins in px** (`left`, `top`, `right`, `bottom`), so it can become a `StyleBoxTexture`.
- The centre region must tile or stretch cleanly. Corners must not distort.
- State them in `ui-tokens.json` as `"slice": [left, top, right, bottom]`.
- Simple panels — flat fill, uniform border, rounded corners — do not need a texture at all. Give me colour, border width, corner radius and padding and the engine draws it. Prefer this where it does not cost you anything, because it scales perfectly at every resolution.

### 6.6 Icons

- Square artboards, transparent, **monochrome** (a single flat colour), so the engine can tint them to any brand token and fade them for the unavailable state.
- Master at **128 × 128** px, exported at `@1x/@2x/@3x` of their used size.
- Nine verb icons minimum: inspect, grab, push, open, toggle, hide, throw, use-held-on, drop.
- Optional but welcome: a small icon set for the win screen rows (interactions, discoveries, ways to die, collectible) and for the four endings on the endings row.

### 6.7 Naming and folders

```
ui/
  ui-tokens.json
  wheel/        slot-available@2x.png, slot-unavailable@2x.png, …
  hud/
  notebook/
  win/
  title/
  icons/verbs/  inspect@2x.png, grab@2x.png, …
  icons/endings/
  svg/outlined/
  svg/live/
  SPEC.md
```

- Lower-case kebab-case. State suffixes after the name: `slot-available`, `slot-pressed`, `slot-disabled`.
- No spaces, no capitals, no version numbers in filenames.

### 6.8 SPEC.md — required

One markdown file that a developer can build from without opening a design tool:

- A labelled layout diagram per surface, with px measurements at the 1920 × 1080 frame.
- A type table: every text element → font, weight, size px, line height, letter-spacing, colour token.
- A states table: every interactive element → its states and what changes between them.
- An animation table: element → property → from → to → duration → easing.
- Overflow behaviour: what happens to a 90-character inspect line, a 25-entry notebook, an object called "Chest of drawers (upper)".
- Every assumption you made about content I did not give you.

---

## 7. Out of scope

Do not design: the 3D room, the furniture, the characters, the lighting, the app icon, the store capsules, or the logo. Those are done or belong to another pass. If you think one of them is wrong, say so in a note — do not fix it in the delivery.

---

## 8. How I will judge it

1. **Can a first-time player use the wheel without being told anything?** That is the whole test. Everything else is second.
2. **Does the timer feel like an antagonist?**
3. **Does a death feel like a shrug rather than a punishment?**
4. **Does the endings row make you want the other three?**
5. **Does it hold up on a phone, one-handed, at arm's length?**
6. **Is the room still visible behind all of it?**
7. Is every number in `ui-tokens.json`, every colour a token, and every SVG outlined?

If you have to choose between beautiful and legible, choose legible. The room is the star; the UI is a pane of glass over it.
