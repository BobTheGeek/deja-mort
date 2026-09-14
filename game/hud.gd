class_name GameHud
extends Control

## The timer, how many times you have died, what is in your hands, whether you
## are hidden, what the room just told you, and how the loop ended. Reads sim
## state; decides nothing.
##
## Drawn rather than assembled, like the wheel: the tally is scratched strokes
## and the chips are flat fills with dashed borders, which is a handful of draw
## calls and no textures. Every number is `hud` in visuals.json, which is Claude
## Design's turn-1 table; docs/ui/SPEC.md is the drawing.

signal notebook_pressed()

## What you are holding is not in the room — the renderer hides it, because a
## lamp trailing after you does not look like carrying a lamp. So this chip is
## where you act on it: put it down, switch it on, open it. Bob could not find
## the thing in his own hands any other way.
signal held_pressed()

const BRAND := preload("res://game/theme/brand.gd")

## Read by the HUD, so a test fails the build when the table loses one rather
## than a fallback quietly undoing half the design.
const REQUIRED_KEYS: PackedStringArray = [
	"margin_x", "margin_top", "margin_bottom", "timer_top", "timer_size", "timer_color",
	"timer_letter_spacing_em", "urgent_below_s", "urgent_color", "urgent_bar_width_max",
	"urgent_bar_height", "urgent_bar_gap", "urgent_bar_color", "tally_stroke_width",
	"tally_stroke_height", "tally_gap", "tally_group_gap", "tally_rotation_jitter_deg",
	"tally_alpha", "loop_label_size", "loop_label_alpha", "loop_label_gap",
	"holding_label_size", "holding_label_tracking_em", "holding_label_alpha",
	"holding_value_size", "holding_rule_height", "holding_rule_alpha",
	"holding_rule_hover_alpha", "holding_rule_gap", "hidden_gap_above", "hidden_padding", "hidden_border_width",
	"hidden_border_alpha", "hidden_fill", "hidden_fill_alpha", "hidden_radius",
	"hidden_icon_size", "hidden_text_size", "hidden_breathe_alpha_min",
	"hidden_breathe_period_s", "inspect_size", "inspect_line_height", "inspect_max_width",
	"inspect_padding", "inspect_radius", "inspect_fill", "inspect_fill_alpha",
	"inspect_max_lines", "inspect_hold_s", "inspect_fade_s", "inspect_border_width",
	"inspect_border_color", "inspect_border_alpha", "inspect_name_color", "banner_size",
	"banner_color", "banner_tracking_em", "banner_room_dim_alpha", "notebook_button_size",
	"notebook_button_right", "notebook_button_bottom", "notebook_button_fill",
	"notebook_button_fill_alpha", "notebook_button_border", "notebook_button_border_alpha",
	"notebook_button_border_width", "notebook_button_radius", "notebook_button_icon_size",
	"notebook_button_hover_fill", "notebook_button_hover_icon", "notebook_button_hint_size",
	"notebook_button_hint_tracking_em", "notebook_button_hint_alpha", "paused_timer_alpha",
	"paused_label_size", "paused_label_tracking_em", "paused_label_alpha", "icon_path",
	"hide_icon",
]

## Past this the strokes stop being countable and the numeral is the truth.
const TALLY_CAP := 25

var visuals: GameVisuals = null

var _font: Font = null
var _font_bold: Font = null
var _notebook_icon: Texture2D = null
var _hide_icon: Texture2D = null

var _remaining: float = 0.0
var _deaths: int = 0
var _holding: String = ""
var _holding_hover := false
var _hidden_in: String = ""
var _paused: bool = false
var _ending: String = ""
var _banner: String = ""
var _inspect_name: String = ""
var _inspect_body: String = ""
var _inspect_left: float = 0.0
var _inspect_alpha: float = 1.0
var _elapsed: float = 0.0
var _notebook_hover: bool = false
var _prompt: String = ""
var _hover: String = ""
var _hover_at: Vector2 = Vector2.ZERO


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = _load_font("FONT_UI")
	_font_bold = _load_font("FONT_UI_BOLD")
	_notebook_icon = load(str(visuals.get_value("hud.icon_path", "")) % "notebook") as Texture2D
	_hide_icon = load(str(visuals.get_value("hud.hide_icon", ""))) as Texture2D
	_fit_viewport()


## Built off the scene tree in tests, where there is no viewport to measure.
func _fit_viewport() -> void:
	var view := get_viewport()
	if view == null:
		size = frame()
		return
	size = view.get_visible_rect().size
	if not view.size_changed.is_connected(_fit_viewport):
		view.size_changed.connect(_fit_viewport)
	queue_redraw()


func frame() -> Vector2:
	var view := get_viewport()
	if view != null:
		return view.get_visible_rect().size
	return Vector2(visuals.number("ui.design_width", 1920.0), visuals.number("ui.design_height", 1080.0))


func sync(world: SimWorld, loop_index: int, panel_open: bool = false) -> void:
	_remaining = world.timer_remaining_s()
	_deaths = maxi(loop_index - 1, 0)
	_paused = panel_open
	_ending = world.ending
	var held := world.objects.by_id(world.player.holding) if not world.player.holding.is_empty() else null
	_holding = held.name if held != null else ""
	var spot := world.objects.by_id(world.player.hidden_in) if world.player.is_hidden() else null
	_hidden_in = spot.name if spot != null else ""
	# Named while the loop is over, and gone the moment the next one starts. It
	# used to be set and never unset, so LOSS sat across a running room.
	#
	# While a loop is ending the banner is left alone, because the death beat
	# flashes DEAD before the ending gets named and that must survive the frames
	# in between.
	if panel_open:
		_hover = ""
	if _ending.is_empty():
		_banner = ""
		_prompt = ""
	elif not panel_open:
		_banner = _ending.to_upper()
	queue_redraw()


## Real seconds, for the things that move while the sim is stopped.
func advance(delta: float) -> void:
	_elapsed += delta
	if _inspect_left > 0.0:
		_inspect_left -= delta
		_inspect_alpha = clampf(_inspect_left / maxf(visuals.number("hud.inspect_fade_s", 0.8), 0.001),
			0.0, 1.0)
		if _inspect_left <= 0.0:
			_inspect_name = ""
			_inspect_body = ""
	queue_redraw()


# --- the timer ---------------------------------------------------------------

func timer_colour() -> Color:
	return visuals.colour("hud.urgent_color") if _is_urgent() else visuals.colour("hud.timer_color")


func timer_alpha() -> float:
	return visuals.number("hud.paused_timer_alpha", 0.45) if _paused else 1.0


func paused_look() -> bool:
	return _paused


func _is_urgent() -> bool:
	return _remaining <= visuals.number("hud.urgent_below_s", 10.0)


func _timer_rect() -> Rect2:
	var height := visuals.number("hud.timer_size", 84.0)
	var top := visuals.number("hud.timer_top", 36.0) + visuals.inset("top")
	return Rect2(Vector2(0.0, top), Vector2(frame().x, height * 1.2))


## Drains over the last ten seconds. The timer is the antagonist; this is it
## breathing down your neck.
func urgent_bar_rect() -> Rect2:
	if not _is_urgent() or _paused:
		return Rect2()
	var span := visuals.number("hud.urgent_below_s", 10.0)
	var width := visuals.number("hud.urgent_bar_width_max", 200.0) \
		* clampf(_remaining / maxf(span, 0.001), 0.0, 1.0)
	var height := visuals.number("hud.urgent_bar_height", 3.0)
	var top := _timer_rect().position.y + visuals.number("hud.timer_size", 84.0) \
		+ visuals.number("hud.urgent_bar_gap", 6.0)
	return Rect2(Vector2(frame().x * 0.5 - width * 0.5, top), Vector2(width, height))


# --- the tally ---------------------------------------------------------------

## Where the left-hand column starts, notch included.
func lines_position() -> Vector2:
	return Vector2(visuals.number("hud.margin_x", 48.0) + visuals.inset("left"),
		visuals.number("hud.margin_top", 44.0) + visuals.inset("top"))


## One scratch per death, in groups of five with the fifth struck across the
## other four. "Death 3" is a score; three scratches is a fact about you.
func tally_strokes() -> Array:
	if _paused or _deaths <= 0:
		return []
	var drawn := _deaths if _deaths <= TALLY_CAP else 5
	var width := visuals.number("hud.tally_stroke_width", 3.0)
	var height := visuals.number("hud.tally_stroke_height", 26.0)
	var gap := visuals.number("hud.tally_gap", 6.0)
	var group_gap := visuals.number("hud.tally_group_gap", 14.0)
	var jitter := visuals.number("hud.tally_rotation_jitter_deg", 2.0)
	var origin := lines_position()
	var out: Array = []
	for i in drawn:
		var group := i / 5
		var within := i % 5
		var left := origin.x + float(group) * ((width + gap) * 4.0 + group_gap)
		if within == 4:
			# The fifth lies across the four it closes.
			out.append({
				"from": Vector2(left - gap * 0.5, origin.y + height * 0.9),
				"to": Vector2(left + (width + gap) * 3.5, origin.y + height * 0.1),
				"diagonal": true,
			})
			continue
		var x := left + float(within) * (width + gap)
		# Deterministic wobble: a hand, not a printer, and the same hand twice.
		var lean := sin(float(i) * 2.399) * jitter
		var offset := tan(deg_to_rad(lean)) * height * 0.5
		out.append({
			"from": Vector2(x - offset, origin.y),
			"to": Vector2(x + offset, origin.y + height),
			"diagonal": false,
		})
	return out


func loop_label() -> String:
	return "" if _paused else "Death %d" % _deaths


func _tally_width() -> float:
	var strokes := tally_strokes()
	if strokes.is_empty():
		return 0.0
	var right := 0.0
	for stroke in strokes:
		right = maxf(right, maxf((stroke["from"] as Vector2).x, (stroke["to"] as Vector2).x))
	return right - lines_position().x


# --- hands and hiding --------------------------------------------------------

func holding_value() -> String:
	return "" if _paused else _holding


func holding_rect() -> Rect2:
	var label := visuals.number("hud.holding_label_size", 13.0)
	var value := visuals.number("hud.holding_value_size", 22.0)
	var width := 320.0
	var right := frame().x - visuals.number("hud.margin_x", 48.0) - visuals.inset("right")
	var top := visuals.number("hud.margin_top", 44.0) + visuals.inset("top")
	return Rect2(Vector2(right - width, top), Vector2(width, label * 1.9 + value * 1.4))


func hidden_visible() -> bool:
	return not _paused and not _hidden_in.is_empty()


func hidden_text() -> String:
	return "Hidden in %s" % _hidden_in if hidden_visible() else ""


## A fragile state, so it breathes rather than sitting there.
func hidden_alpha() -> float:
	var low := visuals.number("hud.hidden_breathe_alpha_min", 0.6)
	var period := maxf(visuals.number("hud.hidden_breathe_period_s", 2.4), 0.001)
	return low + (1.0 - low) * (cos(_elapsed / period * TAU) * 0.5 + 0.5)


func hidden_rect() -> Rect2:
	var padding: Array = visuals.get_value("hud.hidden_padding", [8, 14])
	var text_size := visuals.number("hud.hidden_text_size", 18.0)
	var icon := visuals.number("hud.hidden_icon_size", 22.0)
	var run := _font.get_string_size(hidden_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(text_size)).x \
		if _font != null else 160.0
	var width := run + icon + float(padding[1]) * 2.0 + 10.0
	var height := maxf(text_size, icon) + float(padding[0]) * 2.0
	var holding := holding_rect()
	return Rect2(Vector2(holding.end.x - width,
		holding.end.y + visuals.number("hud.hidden_gap_above", 14.0)), Vector2(width, height))


# --- the way into the notebook -----------------------------------------------

## Tab opens the notebook on a desktop. A phone has no Tab key.
func notebook_button_rect() -> Rect2:
	var box := visuals.number("hud.notebook_button_size", 56.0)
	return Rect2(Vector2(
		frame().x - visuals.number("hud.notebook_button_right", 48.0) - visuals.inset("right") - box,
		frame().y - visuals.number("hud.notebook_button_bottom", 56.0) - visuals.inset("bottom") - box),
		Vector2(box, box))


func press_at(point: Vector2) -> bool:
	if notebook_button_rect().has_point(point):
		notebook_pressed.emit()
		return true
	if not holding_value().is_empty() and holding_rect().has_point(point):
		held_pressed.emit()
		return true
	return false


func hover_at(point: Vector2) -> void:
	var was := [_notebook_hover, _holding_hover]
	_notebook_hover = notebook_button_rect().has_point(point)
	_holding_hover = not holding_value().is_empty() and holding_rect().has_point(point)
	if was != [_notebook_hover, _holding_hover]:
		queue_redraw()


# --- what the room just said -------------------------------------------------

func show_inspect(object_name: String, text: String) -> void:
	_inspect_name = object_name
	_inspect_body = text
	_inspect_left = visuals.number("hud.inspect_hold_s", 5.0)
	_inspect_alpha = 1.0
	queue_redraw()


func inspect_text() -> String:
	if _inspect_body.is_empty():
		return ""
	return "%s  %s" % [_inspect_name, _inspect_body] if not _inspect_name.is_empty() else _inspect_body


func inspect_rect() -> Rect2:
	if _inspect_body.is_empty():
		return Rect2()
	var padding: Array = visuals.get_value("hud.inspect_padding", [18, 26])
	var width := visuals.number("hud.inspect_max_width", 980.0)
	var text_size := visuals.number("hud.inspect_size", 26.0)
	var height := text_size * visuals.number("hud.inspect_line_height", 1.4) \
		* float(_inspect_lines().size()) + float(padding[0]) * 2.0
	var box := frame()
	return Rect2(Vector2((box.x - width) * 0.5,
		box.y - visuals.number("hud.margin_bottom", 56.0) - visuals.inset("bottom") - height),
		Vector2(width, height))


## Wrapped by hand: the panel is measured before it is drawn, and a container
## only knows its own size after a layout pass, which never runs in a test.
func _inspect_lines() -> PackedStringArray:
	var padding: Array = visuals.get_value("hud.inspect_padding", [18, 26])
	var inner := visuals.number("hud.inspect_max_width", 980.0) - float(padding[1]) * 2.0
	var text_size := int(visuals.number("hud.inspect_size", 26.0))
	var cap := int(visuals.number("hud.inspect_max_lines", 2))
	var lines := PackedStringArray()
	var line := ""
	for word in inspect_text().split(" "):
		var candidate := str(word) if line.is_empty() else line + " " + str(word)
		var too_long := _font != null and not line.is_empty() \
			and _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > inner
		if too_long:
			lines.append(line)
			line = str(word)
			if lines.size() >= cap:
				line = ""
				break
		else:
			line = candidate
	if lines.size() < cap and not line.is_empty():
		lines.append(line)
	return lines


func banner_text() -> String:
	return _banner


## What the pointer is over, at the pointer. The room is crowded and the pack's
## pieces are simple; from across the room a drawer and a cupboard look alike.
func show_hover(name: String, at: Vector2) -> void:
	if name == _hover and at.distance_to(_hover_at) < 1.0:
		return
	_hover = name
	_hover_at = at
	queue_redraw()


func hover_text() -> String:
	return _hover


func hover_rect() -> Rect2:
	if _hover.is_empty() or _font == null:
		return Rect2()
	var size := int(visuals.number("hud.hover_size", 20.0))
	var padding: Array = visuals.get_value("hud.hover_padding", [6.0, 10.0])
	var offset: Array = visuals.get_value("hud.hover_offset", [18.0, -14.0])
	var run := _font.get_string_size(_hover, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Vector2(run + float(padding[1]) * 2.0, float(size) * 1.3 + float(padding[0]) * 2.0)
	var at := _hover_at + Vector2(float(offset[0]), float(offset[1]))
	var frame_size := frame()
	at.x = clampf(at.x, 0.0, maxf(frame_size.x - box.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(frame_size.y - box.y, 0.0))
	return Rect2(at, box)


## Shown under the banner while the game waits for a press. Cleared by the next
## loop, like everything else about a finished one.
func show_prompt(text: String) -> void:
	_prompt = text
	queue_redraw()


func prompt_text() -> String:
	return _prompt


func flash(text: String) -> void:
	_banner = text
	queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if visuals == null or _font == null:
		return
	_draw_timer()
	if _paused:
		_draw_tracked(_font, "PAUSED", Vector2(frame().x * 0.5, _timer_rect().end.y + 18.0),
			int(visuals.number("hud.paused_label_size", 13.0)),
			visuals.number("hud.paused_label_tracking_em", 0.24),
			_alpha(visuals.colour("hud.timer_color"), visuals.number("hud.paused_label_alpha", 0.55)),
			true)
		return
	_draw_tally()
	_draw_holding()
	if hidden_visible():
		_draw_hidden()
	_draw_notebook_button()
	if not _hover.is_empty():
		_draw_hover()
	if not _inspect_body.is_empty():
		_draw_inspect()
	if not _banner.is_empty():
		_draw_banner()


func _draw_timer() -> void:
	var text_size := int(visuals.number("hud.timer_size", 84.0))
	_draw_tracked(_font_bold, "%0.1f" % _remaining,
		Vector2(frame().x * 0.5, _timer_rect().position.y + float(text_size)), text_size,
		visuals.number("hud.timer_letter_spacing_em", -0.02),
		_alpha(timer_colour(), timer_alpha()), true)
	var bar := urgent_bar_rect()
	if bar.size.x > 0.0:
		draw_rect(bar, visuals.colour("hud.urgent_bar_color"), true)


func _draw_tally() -> void:
	var colour := _alpha(visuals.colour("hud.timer_color"), visuals.number("hud.tally_alpha", 0.85))
	var width := visuals.number("hud.tally_stroke_width", 3.0)
	for stroke in tally_strokes():
		draw_line(stroke["from"], stroke["to"], colour,
			width * (0.8 if bool(stroke["diagonal"]) else 1.0), true)
	var label := loop_label()
	if label.is_empty():
		return
	var origin := lines_position()
	var left := origin.x
	if _deaths > 0:
		left += _tally_width() + visuals.number("hud.loop_label_gap", 14.0)
	draw_string(_font, Vector2(left, origin.y + visuals.number("hud.tally_stroke_height", 26.0) * 0.85),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(visuals.number("hud.loop_label_size", 20.0)),
		_alpha(visuals.colour("hud.timer_color"), visuals.number("hud.loop_label_alpha", 0.75)))


func _draw_holding() -> void:
	var box := holding_rect()
	var label_size := int(visuals.number("hud.holding_label_size", 13.0))
	_draw_tracked(_font, "HOLDING", Vector2(box.end.x, box.position.y + float(label_size)),
		label_size, visuals.number("hud.holding_label_tracking_em", 0.14),
		_alpha(visuals.colour("hud.timer_color"), visuals.number("hud.holding_label_alpha", 0.55)),
		false, true)
	var value := holding_value()
	if value.is_empty():
		value = "—"
	var value_size := int(visuals.number("hud.holding_value_size", 22.0))
	var run := _font_bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
	var baseline := box.position.y + float(label_size) * 1.9 + float(value_size)
	draw_string(_font_bold, Vector2(box.end.x - run, baseline),
		value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size, visuals.colour("hud.timer_color"))
	if holding_value().is_empty():
		return
	# A rule under the name: this is a thing you can press, which is where you
	# put it down, switch it on, or open it. It brightens under the pointer.
	var rule := visuals.number("hud.holding_rule_height", 1.5)
	draw_rect(Rect2(Vector2(box.end.x - run, baseline + visuals.number("hud.holding_rule_gap", 6.0)),
		Vector2(run, rule)),
		_alpha(visuals.colour("hud.timer_color"), visuals.number(
			"hud.holding_rule_hover_alpha" if _holding_hover else "hud.holding_rule_alpha", 0.28)))


func _draw_hidden() -> void:
	var box := hidden_rect()
	var alpha := hidden_alpha()
	draw_style_box(_chip_style(alpha), box)
	var padding: Array = visuals.get_value("hud.hidden_padding", [8, 14])
	var icon := visuals.number("hud.hidden_icon_size", 22.0)
	var colour := _alpha(visuals.colour("hud.timer_color"), alpha)
	if _hide_icon != null:
		draw_texture_rect(_hide_icon,
			Rect2(box.position + Vector2(float(padding[1]), (box.size.y - icon) * 0.5),
				Vector2(icon, icon)), false, colour)
	var text_size := int(visuals.number("hud.hidden_text_size", 18.0))
	draw_string(_font, box.position + Vector2(float(padding[1]) + icon + 10.0,
		box.size.y * 0.5 + float(text_size) * 0.36), hidden_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, colour)


func _draw_hover() -> void:
	var box := hover_rect()
	var style := StyleBoxFlat.new()
	style.bg_color = visuals.colour_with_alpha("hud.hover_fill", "hud.hover_fill_alpha")
	style.set_corner_radius_all(int(visuals.number("hud.inspect_radius", 4)))
	draw_style_box(style, box)
	var size := int(visuals.number("hud.hover_size", 20.0))
	var padding: Array = visuals.get_value("hud.hover_padding", [6.0, 10.0])
	draw_string(_font, box.position + Vector2(float(padding[1]), float(padding[0]) + float(size)),
		_hover, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		_alpha(visuals.colour("hud.timer_color"), visuals.number("hud.hover_alpha", 0.9)))


func _chip_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _alpha(visuals.colour("hud.hidden_fill"),
		visuals.number("hud.hidden_fill_alpha", 0.6) * alpha)
	style.border_color = _alpha(visuals.colour("hud.timer_color"),
		visuals.number("hud.hidden_border_alpha", 0.5) * alpha)
	style.set_border_width_all(int(visuals.number("hud.hidden_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("hud.hidden_radius", 4)))
	return style


func _draw_notebook_button() -> void:
	var box := notebook_button_rect()
	var style := StyleBoxFlat.new()
	style.bg_color = _alpha(visuals.colour("hud.notebook_button_hover_fill" if _notebook_hover
		else "hud.notebook_button_fill"),
		1.0 if _notebook_hover else visuals.number("hud.notebook_button_fill_alpha", 0.78))
	style.border_color = _alpha(visuals.colour("hud.notebook_button_border"),
		visuals.number("hud.notebook_button_border_alpha", 0.35))
	style.set_border_width_all(int(visuals.number("hud.notebook_button_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("hud.notebook_button_radius", 4)))
	draw_style_box(style, box)
	if _notebook_icon != null:
		var icon := visuals.number("hud.notebook_button_icon_size", 28.0)
		draw_texture_rect(_notebook_icon,
			Rect2(box.get_center() - Vector2(icon, icon) * 0.5, Vector2(icon, icon)), false,
			visuals.colour("hud.notebook_button_hover_icon" if _notebook_hover
				else "hud.notebook_button_border"))
	if OS.has_feature("mobile"):
		return
	_draw_tracked(_font, "TAB", Vector2(box.get_center().x, box.end.y + 18.0),
		int(visuals.number("hud.notebook_button_hint_size", 12.0)),
		visuals.number("hud.notebook_button_hint_tracking_em", 0.16),
		_alpha(visuals.colour("hud.timer_color"), visuals.number("hud.notebook_button_hint_alpha", 0.5)),
		true)


func _draw_inspect() -> void:
	var box := inspect_rect()
	var style := StyleBoxFlat.new()
	style.bg_color = _alpha(visuals.colour("hud.inspect_fill"),
		visuals.number("hud.inspect_fill_alpha", 0.92) * _inspect_alpha)
	style.border_color = _alpha(visuals.colour("hud.inspect_border_color"),
		visuals.number("hud.inspect_border_alpha", 0.4) * _inspect_alpha)
	style.set_border_width_all(int(visuals.number("hud.inspect_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("hud.inspect_radius", 4)))
	draw_style_box(style, box)

	var padding: Array = visuals.get_value("hud.inspect_padding", [18, 26])
	var text_size := int(visuals.number("hud.inspect_size", 26.0))
	var line_height := float(text_size) * visuals.number("hud.inspect_line_height", 1.4)
	var y := box.position.y + float(padding[0]) + float(text_size)
	var name_run := _font_bold.get_string_size(_inspect_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var first := true
	for line in _inspect_lines():
		var x := box.position.x + float(padding[1])
		var text := str(line)
		if first and not _inspect_name.is_empty() and text.begins_with(_inspect_name):
			draw_string(_font_bold, Vector2(x, y), _inspect_name, HORIZONTAL_ALIGNMENT_LEFT, -1,
				text_size, _alpha(visuals.colour("hud.inspect_name_color"), _inspect_alpha))
			x += name_run
			text = text.substr(_inspect_name.length())
		draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			_alpha(visuals.colour("hud.timer_color"), _inspect_alpha))
		y += line_height
		first = false


func _draw_banner() -> void:
	draw_rect(Rect2(Vector2.ZERO, frame()), _alpha(visuals.colour("hud.inspect_fill"),
		visuals.number("hud.banner_room_dim_alpha", 0.45)), true)
	var text_size := int(visuals.number("hud.banner_size", 128.0))
	_draw_tracked(_font_bold, _banner, frame() * 0.5 + Vector2(0.0, float(text_size) * 0.36),
		text_size, visuals.number("hud.banner_tracking_em", 0.28),
		visuals.colour("hud.banner_color"), true)
	if _prompt.is_empty():
		return
	var prompt_size := int(visuals.number("death.retry_prompt_size", 20.0))
	_draw_tracked(_font, _prompt,
		frame() * 0.5 + Vector2(0.0, float(text_size) * 0.95), prompt_size,
		visuals.number("death.retry_prompt_tracking_em", 0.18),
		_alpha(visuals.colour("hud.banner_color"), visuals.number("death.retry_prompt_alpha", 0.6)),
		true)


## Letter spacing, which draw_string does not do. Tracked capitals are most of
## how this HUD reads, so it is worth the loop.
func _draw_tracked(font: Font, text: String, anchor: Vector2, text_size: int, tracking_em: float,
		colour: Color, centred := false, right := false) -> void:
	if font == null or text.is_empty():
		return
	var extra := tracking_em * float(text_size)
	var total := -extra
	for i in text.length():
		total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + extra
	var x := anchor.x
	if centred:
		x -= total * 0.5
	elif right:
		x -= total
	for i in text.length():
		draw_string(font, Vector2(x, anchor.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, colour)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + extra


func _alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * alpha)


func _load_font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null
