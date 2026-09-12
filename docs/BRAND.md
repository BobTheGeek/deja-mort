# DÉJÀ MORT — Brand Tokens and Asset Kit

Source of truth: `reference/logo-asset-sheet.jpeg` (the approved treatment). The SVGs in this folder are a **vector reconstruction** of that sheet — clean geometry, editable, same tokens — not the original designer's file. If the design tool can export its own vector source, replace these with it and keep the tokens.

## Tokens (approved Sept 12, 2026 — Claude Design final set)

| Token | Value | Use |
|---|---|---|
| `ink_dark_bg` | `#0B0C0F` | dark backgrounds, the diorama void |
| `ink_dark_fg` | `#D7DAE0` | type and mark on dark |
| `ink_light_bg` | `#ECEDEF` | light backgrounds |
| `ink_light_fg` | `#151619` | type and mark on light |
| `accent_dark` | `#D9A05B` | the warm accent on dark: grave/minute hand only. Also the in-game bulb light and the timer's final-10s tint |
| `accent_light` | `#C2853E` | the warm accent on light backgrounds |
| Type, wordmark | **Archivo Medium** (SIL OFL), tracking −1.5%, accents custom-drawn (acute default angle; grave at 9° lean; never the font's defaults) | wordmark only — never in UI |
| Type, everything else | **Inter Regular / Bold** (SIL OFL) | tagline, HUD, notebook, menus |
| Tagline | *You've died here before.* — Inter Regular, sentence case, 38% of wordmark cap height, `ink_dark_fg`/`ink_light_fg`, gap above = 1.35× the wordmark's line gap | never with the mark alone; never inside the mark |
| Clear space | wordmark: one cap height all sides · mark: one quarter of its diameter | |
| Minimum sizes | mark 16 px · inline wordmark 18 px cap height · stacked wordmark 40 px total height; below these, mark alone | |

**The mark:** a clock face reading 1:30 — hour hand short and heavy at 1, minute hand thin and long straight down at 6, the minute hand in the accent color. The wordmark's grave on À is the same stroke. Monochrome: all one ink; the grave keeps its stance, so the idea survives without the accent.

**Don'ts (from the sheet):** drop or swap the accents · straighten the grave or change its angle · change the hand positions (it is 1:30) · add numerals, ticks, or a second hand · fill the circle · put the tagline inside the lockup's clear space or with the mark alone · use red · put the mark on a busy photograph · rotate, stretch, outline, or add effects · recolor the accent to anything else.

**Superseded:** the door mark (first treatment) and the ember palette (#111111 / #F0F0F0 / #E65C00). The door survives as the title-screen opening element only — see `reference/approved-door-mark.png`. The SVGs in this folder are reconstructions of the *door* treatment and are superseded by Claude Design's delivered files; replace them on receipt.

## Files (Claude Design final set, Sept 12, 2026)

```
brand/
  svg/live/       Claude Design's originals. Text is live (<text>) and the files ship WITHOUT a
                  <style>/@import, so they render in a default serif unless Archivo and Inter are
                  installed. Keep these as the editable source; do not use them in builds.
  svg/outlined/   Same files with every <text> converted to paths using the real Archivo Medium
                  (tracking −1.5%) and Inter Regular glyphs from brand/fonts/. Render identically
                  anywhere. USE THESE for Godot, store pages, print. (c2pa metadata removed — the
                  signed hash would no longer match after editing.)
  svg/outline_svg.py   the converter; re-run if the live files change.
  png/            Claude Design's rasters: mark-N and mark-mono-N (transparent), app-icon-N (dark
                  tile) at 1024→16; png/lockups/ captures from the asset sheet.
  fonts/          Archivo + Inter .ttf with OFL licenses. See fonts/README.md.
  README-claude-design.md   their delivery notes.

  Naming: lockup-*  = PRIMARY (mark + wordmark, ±tagline; dark / light / mono-transparent)
          stacked-* / inline-* = wordmark-only lockups
          mark-*   = the clock alone
```

**Verified:** outlined SVGs match the sheet captures for glyph shapes and accent placement (accents are drawn geometry positioned for Archivo Medium's metrics, not font accents). Monochrome stacked tagline is one line in the vector files.

**Known quirks to handle at placement, not in the files:**
- The inline lockup SVGs are cropped tight — the grave's round cap reaches within ~1 px of the top edge. Always apply the clear-space rule (one cap height) when placing; never let a layout crop to the artboard.
- The stacked-with-tagline artboard is 710 px wide and the tagline runs to ~705; same rule.
- The SVGs' tagline is ≈29% of the wordmark cap height (the sheet's usage note says 38%). The files match what was approved visually; if it should be larger, it's the `font-size` on the `class="t"` text in `svg/live/`, then re-run the outliner.
- Accent strokes use round line caps in the SVGs; the sheet captures show flat caps. Vector is the source of truth.

**Superseded:** the door treatment lives in `reference/door-treatment/` (my reconstruction) and `reference/approved-door-mark.png` (the first sheet's crop). Title-screen use only.

## Godot theme constants

Put these in `game/theme/brand.gd` (autoload) and reference them everywhere; never inline hex in scenes.

```gdscript
class_name Brand
const BG_DARK    := Color("#0B0C0F")
const FG_DARK    := Color("#D7DAE0")
const BG_LIGHT   := Color("#ECEDEF")
const FG_LIGHT   := Color("#151619")
const ACCENT     := Color("#D9A05B")   # bulb light, timer final-10s tint, minute hand
const ACCENT_ON_LIGHT := Color("#C2853E")
const FONT_WORDMARK := "res://assets/fonts/Archivo-Medium.ttf"  # wordmark ONLY — use the delivered SVG lockups, not live text
const FONT_UI       := "res://assets/fonts/Inter-Regular.ttf"
const FONT_UI_BOLD  := "res://assets/fonts/Inter-Bold.ttf"
```

Where the tokens show up in-game: the diorama void is `BG_DARK`; the room's single light and the timer's last-ten-seconds tint are `ACCENT`; HUD type is `FG_DARK`. Title screen beat: the clock mark ticks once, the wordmark appears, the tagline fades in, then the door (`reference/approved-door-mark.png` geometry) opens into Room 1.

## Export targets

**App icons:** iOS and Android want 1024 master; Godot's export presets take `png/icon-1024.png` and generate the rest. Windows `.ico` and macOS `.icns` from the same master (`tools/make_icons.sh`, to write at M6). Keep the door only — never the wordmark — in icons.

**Steam store art** (verify current sizes in the Steamworks docs before upload; these are the long-standing ones):

| Asset | Size | Use |
|---|---|---|
| Header capsule | 920 × 430 | inline lockup, ember visible |
| Small capsule | 462 × 174 | inline lockup, no tagline |
| Main capsule | 1232 × 706 | stacked lockup over a dark diorama render |
| Vertical capsule | 748 × 896 | stacked lockup |
| Library capsule | 600 × 900 | stacked lockup |
| Library hero | 3840 × 1240 | diorama render, no text |
| Library logo | 1280 × 720 | inline lockup, transparent |
| Page background | 1438 × 810 | diorama render, heavily darkened |

Capsules are built at M6, once Room 1 has real art to sit behind the lockup.
