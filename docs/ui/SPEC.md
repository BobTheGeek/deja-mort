# DÉJÀ MORT — UI spec, turn 1 (wheel + HUD)

All px at 1920×1080. Every number here is also in `ui-tokens.json`. Colours are brand tokens; alpha is stated separately so tokens stay live.

## Wheel — common rules

**Anchor.** Wheel centre = tap point, clamped so the full wheel plus caption stays ≥ `edge_margin` (24) from every screen edge (bottom reserve = wheel extent + 80 for the caption). When clamped, a 2px `FG_DARK` @0.5 leader runs from the tap point (10px dot) to the wheel centre so the player still knows what they hit.

**Pause read.** No full-screen dim. A radial vignette centred on the wheel: `BG_DARK` @0.6 flat to r=210, fading to 0 at r=540. Baked as `wheel-vignette@1x.png` (1080×1080, transparent edges). The rest of the room stays at full brightness — the pause reads from the wheel itself appearing, plus the timer freezing.

**Slot content.** Icon only (monochrome, tinted by state). Time cost when available. Verb word never lives in the slot: on hover/focus it appears as the third line of the caption ("Grab · 1.0s"). Inspect (centre) is free and shows no cost — assumption, see bottom.

**Cost treatment — chosen: rim arc + number (B).** Variant A kept below for the record.
- A · number: `1.0s`, Inter Bold 15px, tabular, under a 30px icon.
- B · rim arc: 4px stroke along the slot edge, length = cost / 3.0s of the circumference (dir A) or a 4px bar at the wedge's outer edge, length = cost/3.0 × 120px (dir B); plus a 12px Bold number. Arc must ship as 12 frames (0.25s steps) or be drawn by the engine as an arc polygon.

**States** (`wheel_common.states`): available / unavailable / hover / pressed / refused. Unavailable is not just faded: dashed border, fill @0.5, icon @0.3, no cost. Hover/pressed invert (fill `FG_DARK`, icon `BG_DARK`) and scale 1.06 / 0.94. Refused: `ACCENT` 2px border + accent icon, caption third line in `ACCENT` ("Grab — can't do that from here"), wheel stays open `refused_hold_s` 1.6, slot shakes ±4px over 0.18s. Hover→pressed tween 0.08s.

**Caption.** 380px wide, `BG_DARK` @0.86, radius 4, padding 12/18, 16px below the wheel, horizontally centred on the wheel and clamped to the frame. Lines: object name (Bold 24), optional stack line (Regular 18 @0.7: "2 of 5 here — tap again to cycle"), optional verb line (Regular 20 @0.85; `ACCENT` when refused).

**Open/close.** Scale 0.9→1.0, alpha 0→1, 0.12s ease-out-cubic. Close 0.08s.

### Direction A · tiles on a ring — CHOSEN
Ring radius 128. Eight 88px circles, centre 104px. Icon 36 (30 when a cost number sits below it), centre icon 44. Touch target = the 88px circle; nearest-neighbour gap at radius 128 is ≈ 10px. Flat fills + uniform borders: engine-drawn, no texture.

```
                 [grab]
        [drop]           [push]
   [use-held]  (inspect)   [open]
        [throw]          [toggle]
                 [hide]
   slot ⌀88 · ring r128 · centre ⌀104
```

### Direction B · dial with wedges — not chosen, reference only
Annulus outer r184 / inner r76, eight wedges of 42° with a 3° gap, centre disc r62. Icon at r122, cost text at r160, cost bar at r178. Wedge = touch target (min chord ≈ 108×108 at inner edge). Wedge available `BG_DARK` @0.86; unavailable @0.55 with dashed `FG_DARK` @0.2 stroke; hover/pressed fill `FG_DARK`, scale 1.03 / 0.95 about the wheel centre; refused stroke `ACCENT` 2px. Deliver as one nine-slice-free polygon set (engine `Polygon2D` per wedge from the angles) — no texture needed.

## HUD

| element | position | type | colour |
|---|---|---|---|
| timer | top 36, centred | Inter Bold 84, tabular, tracking -0.02em | `FG_DARK` |
| timer, urgent (<10s) | same | same size/weight, colour only | `ACCENT` |
| urgent bar | 6px under timer, 3px tall, width = remaining/10 × 200 | — | `ACCENT` |
| loop tally | left 48, top 48 | 3×26px strokes, gap 6, ±2° jitter, 5th stroke diagonal per group | `FG_DARK` @0.85 |
| loop label | 14px right of tally | Inter Regular 20 | `FG_DARK` @0.75 |
| holding label | right 48, top 44, right-aligned | Inter Regular 13, caps, tracking 0.14em | `FG_DARK` @0.55 |
| holding value | under label | Inter Bold 22 | `FG_DARK` |
| hidden chip | 14px under holding | Regular 18 + 22px hide icon, 1.5px dashed border @0.5, fill `BG_DARK` @0.6, radius 4 | `FG_DARK` |
| inspect line | bottom 56, centred, max-width 980 | Regular 26 / 1.4, object name Bold in `ACCENT`; 1.5px `FG_DARK` @0.4 border | `FG_DARK` on `BG_DARK` @0.92 |
| banner | dead centre | Inter Bold 128, tracking 0.28em | `FG_DARK`, room dimmed `BG_DARK` @0.45 |

Portrait (1080×1920, safe 44/34): timer top 68; tally left 40 top 80; holding right 40 top 76; inspect line inset 40, bottom 66, Regular 28; banner Bold 104 tracking 0.22em.

## Notebook button (HUD)
56×56 at right 48 / bottom 56 (portrait 64×64, right 40 / bottom 210, clear of a 2-line inspect panel). Fill `BG_DARK` @0.78, 1.5px `FG_DARK` @0.35 border, radius 4, 28px notebook glyph (128px master `icons/ui/notebook`). Hover/focus inverts (fill `FG_DARK`, glyph `BG_DARK`). Desktop only: "TAB" hint, Regular 12, tracking 0.16em, @0.5, 6px below. Tab key and this button are the same action.

## Notebook — case file
Opening pauses the sim: room dims `BG_DARK` @0.45, the timer drops to @0.45 with a "PAUSED" label (Regular 13, tracking 0.24em) under it; all other HUD hides. Panel 800×720 centred horizontally at top 200; scale 0.98→1, alpha 0→1, 0.15s. Flat panel — no texture: fill `BG_DARK` @0.92, 1.5px `FG_DARK` @0.35 border, radius 4.

```
┌ Room 1 · Death 3 ─────────────────────── ✕ ┐  header 13 caps, close 44×44
│ ROOM 12   ATTACKER 2   DEATHS 6            │  tabs Bold 18 caps, ACCENT text + 3px underline on selected
│ ───────────────────────────────────────────│
│ Rug                                      ▌ │  entry: name Bold 22
│ A rug that hides whatever is under it.   ▌ │          line Regular 20 @0.85
│ MOVABLE · LIGHT · HIDES-OBJECT             │          tags 14 caps tracked @0.5
│ ─────────────────────────────────────────  │  1px rule @0.1 between entries
│ …                                          │
│            ░░░ 7 MORE BELOW ░░░            │  96px fade + 13 caps label + 4px scrollbar
└────────────────────────────────────────────┘
```

| element | type | colour |
|---|---|---|
| header | Regular 13, caps, tracking 0.2em | `FG_DARK` @0.55 |
| tab, selected | Bold 18, caps, tracking 0.1em, 3px underline | `ACCENT` text and underline |
| tab, unselected | same | `FG_DARK` @0.6 |
| tab count | Regular 13, tabular | inherits @0.6 |
| entry name | Bold 22 | `FG_DARK` |
| entry inspect line | Regular 20 / 1.4 | `FG_DARK` @0.85 |
| entry tags | Regular 14, caps, tracking 0.12em, " · " separated | `FG_DARK` @0.5 |
| attacker fact | Regular 20 / 1.4, 8px square bullet @0.6 | `FG_DARK` |
| death line | "Death N." Bold 20 in a 110px column, text Regular 20 | `FG_DARK` |
| achievement, earned | 12px filled square mark; name Bold 22; description Regular 18 @0.75; right column "Death N" 13 caps tracked @0.55 | `FG_DARK` |
| achievement, locked | same row at @0.4 overall; hollow square mark; right column reads "LOCKED" | `FG_DARK` @0.4 |
| empty state | Regular 20, 56px top padding | `FG_DARK` @0.5 |
| "N more below" | Regular 13, caps, tracking 0.16em, sits in the fade | `FG_DARK` @0.55 |

Tabs are 44px tall touch targets (padding 14/12 around 18px type). ACCENT on the selected tab is only visible while paused, so it never competes with the timer. Tab switch: body alpha 1→0→1 over 0.08s, scroll resets to top. Scroll body: fade (baked 1×96 gradient texture, `BG_DARK` 0→0.96) + 4px scrollbar (track @0.1, thumb @0.45, min thumb 40px). The fade and label disappear when the list fits or the player reaches the end. Counts in the tab labels update live; Deaths count = loop counter; Achievements count reads "earned / total". The Achievements tab has no empty state: every achievement is always listed, locked ones as @0.4 silhouettes (same logic as the endings row on the win screen — the list is the pitch).

Portrait: panel inset 40, top 220 (below the paused timer), bottom 74 (34 safe + 40); tabs 19, body type 24/26, death column 120.

Note on italics: Inter Light/Regular/Bold ships no italic, and Godot will not synthesize one. Tags are therefore set as tracked capitals at @0.5 instead of italics — same job (secondary, machine-like), no new font. If you add Inter Italic to the repo, swap tags to Regular Italic 18 @0.6 and drop the caps.

## Win screen
Room dims `BG_DARK` @0.55 (the room is still the trophy behind it). Panel 880 wide, top 96, padding 40/56/44, flat fill `BG_DARK` @0.92 with the standard 1.5px border. Reveals 0.6s after the ending banner, scale 0.98→1 + alpha over 0.35s.

```
┌──────────────────────────────────────────┐
│               ★ ★ ☆                      │ stars 36 ACCENT (unearned: ACCENT stroke @0.4), gap 10, staggered 0.15s
│             D I S A B L E                │ Bold 64, tracking 0.22em
│      Deaths 7 · Time survived 77.6s      │ Regular 22 @0.7
│ ─────────────────────────────────────── │
│   (○)     (●)      (○)      (○)          │ endings row: 96px discs, 44px glyphs
│    ──   DISABLE     ──       ──          │ found: filled disc + Bold 14 caps label
│ ─────────────────────────────────────── │ unfound: whole cell @0.3, dashed disc, 48px rule for label
│ INTERACTIONS DISCOVERIES WAYS TO DIE COLLECTIBLE │ label 13 caps @0.55
│ 14 / 38      3 / 9       6         ☐ Not found   │ value Bold 28, total Regular @0.5
│ ROOM 1 COMPLETION ─────────────── 48%    │ 3px bar, fills over 0.6s
│   The toaster had been waiting for this. │ Light 22 @0.8 (no italic in the font set)
│   [ REPLAY ]      [ NEXT ROOM · not yet ]│ 220×56, primary ACCENT fill + BG_DARK text (hover +8% lightness) / disabled dashed @0.3
└──────────────────────────────────────────┘
```

Endings row order is fixed: EVADE, DISABLE, KILL, ESCAPE (left→right, matching `icons/endings/`). Unfound endings never show a name — only the silhouette glyph and a 48px rule where the name would be. Cells reveal left to right, 0.1s apart. Collectible: found = filled 16px square + "Found" at full; not found = dashed square + text @0.5. Next Room disabled: dashed `FG_DARK` @0.3 border, text @0.4, second line "NOT YET" Regular 11 tracked. Portrait: panel inset 40, top 120; stats become 2 columns; buttons stack full-width at 64 tall.

## The loss beat (2.0s, no input)
| t | what happens |
|---|---|
| 0.00 | Swing lands. Sim stops. Timer freezes on its last value. |
| 0.00–0.30 | Slump. Room alpha 1→0.7; inspect line, holding, hidden chip fade out (0.3s). Timer dims to @0.6. |
| 0.80 | Flicker. Bulb alpha frames 0 → 0.4 → 0, one per 0.083s. Room to 0.25. Timer disappears (cut, no fade). |
| 1.05 | DEAD banner: alpha 0→1 in 0.2s, scale 1.04→1. Hold 0.5s. |
| 1.55 | Banner fades out (0.25s). Loop counter returns with one new stroke: alpha 0→1, x -6→0, 0.15s. "Death 3" → "Death 4". |
| 2.00 | Reset. Bulb snaps on (no fade), room to 1.0, timer at 75.0 starts. |

Nothing in this sequence is red, nothing shakes, nothing has a button. The only new information is one tally stroke.

## Title screen
Void `BG_DARK`, nothing else behind it. The stacked lockup with tagline (`svg/outlined/lockup-stacked-dark-tagline.svg`, 710×931) is placed unmodified at 427×560, left 746 / top 100 — clear space is one cap height on all sides, which the layout respects. Menu at top 720: three 44px-tall rows, Inter Regular 24 caps, tracking 0.2em, `FG_DARK` @0.7; hover @1.0; focused row is Bold `ACCENT` with an 8px accent square 14px to its left, and Continue shows a 14px sub-line "Room 1 · Death 7" @0.5. Room strip at bottom 56: four 300×96 cells, gap 16. Unlocked cell: 1.5px `FG_DARK` @0.35 border, "ROOM 1" Bold 14 caps, three 14px stars (`ACCENT`; unearned = accent stroke @0.4), then "ENDINGS" 11 caps + four 10px dots (found filled `FG_DARK`, unfound 1.5px @0.35 ring), fixed order EVADE DISABLE KILL ESCAPE. Locked cell: dashed @0.2 border, whole cell @0.5, dashed rings where stars and dots would be — the same skeleton, empty.

Beat (skippable by any input, which jumps to idle):
| t | what happens |
|---|---|
| 0.00 | Mark alone, 160px, centred. Alpha 0→1, 0.3s. |
| 0.60 | The tick. Hands never move: the whole mark scales 1→0.97→1 in 0.1s, with the click. |
| 1.00 | Mark travels up to its lockup position (0.4s ease-in-out); wordmark fades in beneath (0.4s). Use the delivered lockup files; do not re-set the wordmark. |
| 1.60 | Tagline fades in (0.4s). |
| 2.30 | Menu and strip fade in with an 8px rise (0.3s). Idle. |

On Continue / New:
| t | what happens |
|---|---|
| +0.00 | Lockup and menu fade out (0.25s). Door fades in centred, 480×630 (0.3s). |
| +0.50 | Leaf scales toward its hinge, scaleX 1→0.08 (0.5s ease-in-out); Room 1 fades in behind to @0.6. |
| +1.10 | Frame scales 1→8 about the opening (origin 75%/50%), 0.6s ease-in, fading out over 0.4s; room to 1.0; HUD fades in (0.3s); timer starts at 75.0. |

The door is drawn from the approved-door-mark geometry (frame polyline, leaf quad, edge strip; points in `ui-tokens.json`) in brand tokens: frame `FG_DARK`, leaf `BG_LIGHT`, edge `ACCENT`. No ember, no red. It appears in this sequence and nowhere else — it is not the logo. Deliver as three monochrome PNG layers (`title/door-frame`, `title/door-leaf`, `title/door-edge`) so the engine tints and animates them separately.

## Animation

| element | property | from → to | duration | easing |
|---|---|---|---|---|
| wheel | scale, alpha | 0.9→1, 0→1 | 0.12s | ease-out-cubic |
| wheel close | alpha | 1→0 | 0.08s | linear |
| slot hover | scale | 1→1.06 | 0.08s | ease-out |
| slot pressed | scale | 1.06→0.94 | 0.08s | ease-out |
| slot refused | x | ±4px, 3 cycles | 0.18s | linear |
| timer → urgent | colour | FG_DARK → ACCENT | 0.25s | ease-out |
| timer urgent tick | scale | 1→1.08→1 on each whole second | 0.2s | ease-out |
| urgent bar | width | 200→0 over final 10s | 10s | linear |
| hidden chip | alpha | 1→0.6→1 loop | 2.4s | sine |
| inspect line | alpha | 0→1, hold 5.0, 1→0 | 0.15s / 0.8s | ease-out / linear |
| banner | alpha, scale | 0→1, 1.04→1 | 0.2s | ease-out |
| notebook open | scale, alpha | 0.98→1, 0→1 | 0.15s | ease-out |
| notebook close | alpha | 1→0 | 0.1s | linear |
| notebook tab switch | body alpha | 1→0→1 | 0.08s | linear |
| win panel | scale, alpha | 0.98→1, 0→1 | 0.35s (delay 0.6) | ease-out |
| win stars | alpha | 0→1 each, stagger 0.15s | 0.2s | ease-out |
| win endings row | alpha, y | 0→1, +8→0, stagger 0.1s | 0.25s | ease-out |
| win completion bar | width | 0→48% | 0.6s | ease-in-out |
| death: room | alpha | 1→0.7 (t0) → 0.25 (t0.8) → 1 (t2.0 snap) | 0.3s / cut / cut | ease-out |
| death: bulb flicker | alpha | 0, 0.4, 0 frames | 0.083s each | step |
| death: DEAD | alpha, scale | 0→1, 1.04→1; then 1→0 | 0.2s / 0.25s | ease-out |
| death: new tally stroke | alpha, x | 0→1, -6→0 | 0.15s | ease-out |
| title mark | alpha | 0→1 | 0.3s | ease-out |
| title tick | scale | 1→0.97→1 | 0.1s | ease-in-out |
| title mark travel | y | centre→lockup slot | 0.4s | ease-in-out |
| title wordmark / tagline | alpha | 0→1 | 0.4s | ease-out |
| title menu + strip | alpha, y | 0→1, +8→0 | 0.3s | ease-out |
| door in | alpha | 0→1 | 0.3s | ease-out |
| door leaf | scaleX (hinge origin) | 1→0.08 | 0.5s | ease-in-out |
| door through | scale, alpha | 1→8, 1→0 | 0.6s / 0.4s | ease-in |
| room behind door | alpha | 0→0.6→1 | 0.5s / 0.6s | linear |
| notebook button hover | fill, glyph | BG@0.78→FG, FG→BG | 0.08s | ease-out |

## Overflow
- Inspect line: wrap to 2 lines inside 980px at 26px (~80 chars fits; a 90-char line may take a third line — clip at 2 and bump hold to 6.5s, or drop to 24px once). Beyond 2 lines: clip with no ellipsis and bump the hold to 6.5s. Object name never wraps alone from its dash (use a non-breaking space before the dash).
- Caption name >380px ("Chest of drawers (upper)"): shrink Bold 24 → 20 once, then wrap to 2 lines. Caption grows downward; the wheel clamp already reserves 80px.
- Holding value > 260px: ellipsis at the end, no shrink.
- Tally: groups of 5; past 25 deaths the strokes collapse to a single group plus the numeral (numeral is the truth, strokes are texture).

## Overflow — notebook
- Entry name wider than the column ("Chest of drawers (upper)" fits at 22px in 720px; longer names wrap, never truncate).
- 25+ entries: scroll; the "N more below" count is live. No pagination.
- Death line > 2 lines: wraps; the number column stays fixed at 110px.
- Tags > 1 line: wrap; separator is " · ".
- Achievement "when" column is right-aligned and never wraps in landscape; in portrait it drops under the description.

## Overflow — win screen
- Notebook line > 2 lines at 22px in 768px: drop to 20px once, then clip at 3 lines.
- Stat values > 3 digits keep the 4-column grid; the column widens, labels never wrap.
- Ending names longer than "DISABLE" (all four are ≤ 7 chars) — tracking drops to 0.16em above 8 chars.

## Overflow — title
- Room names are fixed ("ROOM N"); no overflow case.
- Continue sub-line: "Room N · Death NNN" — three-digit deaths fit; never wraps.

## Delivered files
- `icons/verbs|endings|ui/<name>-1x|2x|3x.png` — white monochrome, transparent, at used size (verbs 36, endings 44, ui 28) plus `<name>-master-128.png`. The filesystem here disallows "@" in names; rename `-1x` → `@1x` on import.
- `icons/**/*.svg` — geometry-only sources (128×128). `svg/live/` and `svg/outlined/` are identical because no delivered SVG contains text.
- `wheel/wheel-vignette-1x|2x.png` — 1080² radial, `BG_DARK` @0.6 flat to r210, 0 at r540. Centre on the wheel.
- `notebook/scroll-fade-1x|2x|3x.png` — 4×96 vertical gradient, stretch horizontally.
- `title/door-frame|leaf|edge-1x|2x|3x.png` — 480×630 at @1x, white; tint frame `FG_DARK`, leaf `BG_LIGHT`, edge `ACCENT`.
- No slot, panel or button textures: all are flat fills + uniform borders, engine-drawn from `ui-tokens.json`.
- The wordmark is never re-set: place `brand/svg/outlined/lockup-stacked-dark-tagline.svg` from the brand kit.

## Assumptions
- Room 1 screenshot used in all mocks is `m4_lit.png` with the placeholder HUD painted out (`ui/ref/room-lit.png`); the patch is visible at top-centre where the timer sits and is mock-only.
- Title beat "tick" is interpreted as a scale pulse because the hands must stay at 1:30.
- Ending glyphs: evade = path around a bar, disable = power symbol struck through, kill = X, escape = door ajar (reuses the open verb icon). 128px masters, monochrome, in `icons/endings/`.
- The death beat is identical for every cause of death; the cause goes to the notebook, not the screen.
- Achievements are per-profile (not per room) and the "when" stamp is the death number they were earned on. Six shown; the list scrolls like Room past ~8.
- Inspect costs 0s (thinking is free). If it costs time, it takes the variant-A number like any slot.
- Costs used in the mock: grab 1.0, push 2.0, open 0.5, toggle 0.5, hide 2.5, throw 1.0, use-held-on 1.5, drop 0.5.
- Cost scale saturates at 3.0s (`cost_scale_max_s`); anything longer draws a full arc.
- Room stand-in in the mock is flat geometry; contrast was checked against `#4a4d55` floor and `#9a8f84` wall assumption: slot fill `BG_DARK` @0.88 over `#9a8f84` gives ≈ `#1c1c1d`, `FG_DARK` on it is 13:1.
- Icons are 128px masters with 10px stroke, exported monochrome; `hide` doubles as the hidden-chip icon.
- The 44dp touch minimum is satisfied by both directions at 1152×648 (dir A slot = 53px, dir B wedge chord ≈ 65px).
