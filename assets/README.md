# Assets

Every asset in this repo or referenced by it is listed here with its source and license. No exceptions — this is what lets us ship.

## Rules
- `assets/paid/` is gitignored. Paid packs are documented below and installed locally from the purchase.
- CC0 assets may be committed. Attribution is not required but is recorded anyway.
- Agent-built assets (Blender scripts → .glb) are committed with the generating script.
- No asset from an unknown source. No asset scraped from a game, film, or store page.
- **Fonts keep their license file beside them.** The two families carry different copyright lines, so they live in their own folders with their own `OFL.txt`. `tests/game/brand_test.gd` fails the build if a license goes missing.

## Fonts

`assets/fonts/` — copied from `docs/brand/fonts/`, which is the delivery source of truth. Both families are **SIL Open Font License 1.1**, which permits commercial use and embedding in the game and in store art. Do not sell the fonts themselves.

| Font | File | Source | License | Used for |
|---|---|---|---|---|
| Archivo Medium | `assets/fonts/archivo/Archivo-Medium.ttf` | [Omnibus-Type/Archivo](https://github.com/Omnibus-Type/Archivo) | OFL 1.1 — `archivo/OFL.txt` | **Wordmark only**, tracking −1.5%. Never in UI. |
| Archivo Regular | `assets/fonts/archivo/Archivo-Regular.ttf` | same | OFL 1.1 — `archivo/OFL.txt` | Delivered with the family. Not currently used. |
| Inter Regular | `assets/fonts/inter/Inter-Regular.ttf` | [rsms/inter](https://github.com/rsms/inter) | OFL 1.1 — `inter/OFL.txt` | Tagline, HUD, notebook, menus |
| Inter Bold | `assets/fonts/inter/Inter-Bold.ttf` | same | OFL 1.1 — `inter/OFL.txt` | UI emphasis |
| Inter Light | `assets/fonts/inter/Inter-Light.ttf` | same | OFL 1.1 — `inter/OFL.txt` | Delivered with the family. Not currently used. |

Copyright lines: Archivo © 2020 The Archivo Project Authors · Inter © 2016 The Inter Project Authors.

## Brand art

`assets/brand/` — Claude Design final set, approved 12 Sept 2026. Owned by the project; not licensed from a third party. Source and delivery notes live in `docs/brand/`, and `docs/brand/BRAND.md` is the authority on how these may be used.

| Group | Files | Source | Notes |
|---|---|---|---|
| App icon | `app-icon-{16..1024}.png` | `docs/brand/png/` | Dark tile. `app-icon-1024.png` is the master used by the project icon and every export preset. |
| Mark | `mark-{16..1024}.png`, `mark-mono-{16..1024}.png` | `docs/brand/png/` | The clock face reading 1:30. Transparent background. |
| Lockup rasters | `lockups/` (19 files) | `docs/brand/png/lockups/` | Captured from the approved asset sheet; authoritative for accent placement. |
| Vector, outlined | 24 × `*.svg` | `docs/brand/svg/outlined/` | Text converted to paths using the real Archivo and Inter glyphs, so they render identically without the fonts installed. **Use these, not `svg/live/`.** |

Naming: `lockup-*` is the primary lockup (mark + wordmark, ± tagline) · `stacked-*` / `inline-*` are wordmark-only · `mark-*` is the clock alone.

**Do not**, per `docs/brand/BRAND.md`: drop or swap the accents · straighten the grave · move the hands (it is 1:30) · add numerals or a second hand · fill the circle · put the tagline with the mark alone · use red · rotate, stretch, outline or add effects · recolor the accent.

Two placement quirks the files cannot fix: the inline lockups are cropped tight (the grave's cap is ~1 px from the top edge) and the stacked-with-tagline artboard runs to ~705 px of 710. Always apply the clear-space rule when placing; never crop to the artboard.

**Not copied on purpose:** `docs/brand/svg/live/` (live `<text>`, renders in a default serif unless the fonts are installed — editable source, not for builds) and `docs/brand/svg/outline_svg.py` (the converter).

**Missing from the delivery:** `docs/brand/BRAND.md` refers to `reference/logo-asset-sheet.jpeg` (the approved treatment it calls its source of truth), `reference/approved-door-mark.png` and `reference/door-treatment/`. No `docs/brand/reference/` folder arrived. Nothing in this change depends on those files, but the title-screen door beat described in BRAND.md §"Godot theme constants" has no artwork behind it until they turn up.

### Android adaptive icon — needs a decision

`app-icon-1024.png` is wired into all three Android icon fields, as asked. The legacy launcher icon (`main_192x192`) is correct and verified in the built APK. The two **adaptive** fields are not:

Android 8+ composites `adaptive_background` + `adaptive_foreground` and scales the foreground to roughly 72% of the canvas before masking. Feeding it the finished rounded tile renders a tile inside a tile, with the inner corners visible. The delivered kit already has the right asset for this — `mark-1024.png` is the transparent mark on no background.

One-line fix, when someone decides: point `launcher_icons/adaptive_foreground_432x432` at `res://assets/brand/mark-1024.png` and `adaptive_background_432x432` at a flat `#0B0C0F` tile. Left alone for now because the brief named one file for every preset.

## Tokens

Colours live in one place: the `Brand` autoload at `game/theme/brand.gd`. Never inline a hex value in a scene or script.

| Token | Value |
|---|---|
| `Brand.BG_DARK` | `#0B0C0F` |
| `Brand.FG_DARK` | `#D7DAE0` |
| `Brand.BG_LIGHT` | `#ECEDEF` |
| `Brand.FG_LIGHT` | `#151619` |
| `Brand.ACCENT` | `#D9A05B` |
| `Brand.ACCENT_ON_LIGHT` | `#C2853E` |

## Packs

| Pack | Source | License | Used for | Location |
|---|---|---|---|---|
| Kenney Furniture Kit | kenney.nl | CC0 | household props | assets/models/kenney/ |
| | | | | |

Nothing imported yet — the game is greybox until M4.

## Audio

| Cue / file | Source | License | Notes |
|---|---|---|---|
| all greybox cues | generated in `game/audio_director.gd` | project-owned | Synthesised at load from `content/audio_map.json`. No audio file ships before M4. |
