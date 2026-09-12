extends Node

## Brand tokens, from docs/brand/BRAND.md (Claude Design final set, 12 Sept 2026).
## Registered as the `Brand` autoload in project.godot, so anything can read
## `Brand.BG_DARK`. Never inline a hex value in a scene or a script — if a colour
## is not here, it is not a brand colour.
##
## No `class_name`: a global class called `Brand` would shadow the autoload
## singleton of the same name, and the autoload is what BRAND.md asks callers to
## use.
##
## Nothing consumes these yet. Wiring them into the HUD, notebook and win screen
## is M3 presentation work and is deliberately not in this change.

const BG_DARK := Color("#0B0C0F")          ## dark backgrounds, the diorama void
const FG_DARK := Color("#D7DAE0")          ## type and mark on dark
const BG_LIGHT := Color("#ECEDEF")         ## light backgrounds
const FG_LIGHT := Color("#151619")         ## type and mark on light
const ACCENT := Color("#D9A05B")           ## bulb light, timer final-10s tint, minute hand
const ACCENT_ON_LIGHT := Color("#C2853E")  ## the warm accent on light backgrounds

## Wordmark ONLY, never in UI. Prefer the delivered SVG lockups in
## assets/brand/ over setting live text in Archivo.
const FONT_WORDMARK := "res://assets/fonts/archivo/Archivo-Medium.ttf"

## Tagline, HUD, notebook, menus — everything that is not the wordmark.
const FONT_UI := "res://assets/fonts/inter/Inter-Regular.ttf"
const FONT_UI_BOLD := "res://assets/fonts/inter/Inter-Bold.ttf"

## The 1024 master. Export presets and the project icon all point at this file.
const APP_ICON := "res://assets/brand/app-icon-1024.png"
