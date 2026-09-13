class_name UiScale
extends RefCounted

## How big the UI has to be, and where it is allowed to sit.
##
## The canvas is a fixed 1920x1080 that the project stretches to fit any screen,
## which handles every aspect ratio from an iPad's 4:3 to an ultrawide's 21:9 —
## a room floating in black does not care how wide the black is. What a fixed
## canvas does not handle is a screen that is physically small: the wheel's 88
## unit slot lands at about 32 points on a phone, against Apple's 44 and
## Google's 48.
##
## So the scale comes from the screen's own DPI and a minimum in millimetres,
## not from a magic number per device. It applies on a handheld only: a Steam
## Deck runs a desktop OS and is driven by sticks, trackpads and a mouse, and a
## pointer needs no thumb allowance.
##
## Pure functions, so the arithmetic can be checked against real devices in a
## test rather than on a shelf full of phones.

const MM_PER_INCH := 25.4


## How many canvas units fit in a screen pixel, before any UI scaling: the
## stretch the project already does.
static func canvas_scale(screen_px: Vector2i, visuals: GameVisuals) -> float:
	var base := Vector2(visuals.number("ui.design_width", 1920.0),
		visuals.number("ui.design_height", 1080.0))
	if base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	return minf(float(screen_px.x) / base.x, float(screen_px.y) / base.y)


static func millimetres(pixels: float, dpi: int) -> float:
	return pixels / maxf(float(dpi), 1.0) * MM_PER_INCH


## The multiplier to hand to Window.content_scale_factor. Never below 1 — the
## design is the design — and bounded above so a wrong DPI cannot swallow the
## screen. Canvas items only: the room behind them does not move.
static func factor(screen_px: Vector2i, dpi: int, handheld: bool, visuals: GameVisuals) -> float:
	if not handheld:
		return 1.0
	var slot := visuals.number("wheel.slot_size", 88.0) * canvas_scale(screen_px, visuals)
	if slot <= 0.0:
		return 1.0
	var wanted := visuals.number("ui.min_touch_mm", 7.6) / MM_PER_INCH * float(dpi)
	return clampf(wanted / slot, 1.0, visuals.number("ui.max_touch_scale", 1.8))


## The screen's safe area, in the canvas units the UI is laid out in. A notch or
## a home bar is reported in screen pixels; everything drawing the HUD thinks in
## canvas units.
static func insets(safe: Rect2i, window_px: Vector2i, canvas: Vector2) -> Dictionary:
	if window_px.x <= 0 or window_px.y <= 0:
		return _none()
	var per_x := canvas.x / float(window_px.x)
	var per_y := canvas.y / float(window_px.y)
	return {
		"left": maxf(float(safe.position.x), 0.0) * per_x,
		"top": maxf(float(safe.position.y), 0.0) * per_y,
		"right": maxf(float(window_px.x - safe.end.x), 0.0) * per_x,
		"bottom": maxf(float(window_px.y - safe.end.y), 0.0) * per_y,
	}


static func _none() -> Dictionary:
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}


## How big to open. The UI is drawn against a fixed canvas that stretches to the
## window, so a small window renders every number at a fraction of itself — a
## 1152-wide window is 60%, at which a tally of 3px scratches stops reading as
## scratches. As much of the screen as the fraction allows, in the canvas's own
## shape, and never larger than the canvas: past that it is only upscaling.
static func window_size(usable: Vector2i, visuals: GameVisuals) -> Vector2i:
	var base := Vector2(visuals.number("ui.design_width", 1920.0),
		visuals.number("ui.design_height", 1080.0))
	var fraction := visuals.number("ui.window_screen_fraction", 0.85)
	var room := Vector2(float(usable.x), float(usable.y)) * fraction
	var scale := minf(minf(room.x / base.x, room.y / base.y), 1.0)
	return Vector2i(int(round(base.x * scale)), int(round(base.y * scale)))


## Reads the real device and applies both. Called once, from the game; the parts
## it depends on are the two functions above, which are tested without a device.
static func apply(window: Window, visuals: GameVisuals) -> void:
	if window == null:
		return
	var screen := DisplayServer.window_get_size(window.get_window_id())
	var dpi := DisplayServer.screen_get_dpi(DisplayServer.window_get_current_screen(window.get_window_id()))
	var handheld := OS.has_feature("mobile")
	window.content_scale_factor = factor(screen, dpi, handheld, visuals)
	# Only a handheld has a notch. On a desktop the display's "safe area" is the
	# screen minus the menu bar, which has nothing to do with a window inside it —
	# taking it pushed the whole title menu 70px down into the room strip.
	visuals.safe = insets(DisplayServer.get_display_safe_area(), screen,
		window.get_visible_rect().size) if handheld else _none()
