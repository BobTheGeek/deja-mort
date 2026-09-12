class_name GameHud
extends Control

## Timer, loop counter, what is in your hands, and whether you are hidden.
## Reads sim state; decides nothing.

var visuals: GameVisuals = null

var _timer: Label = null
var _lines: VBoxContainer = null
var _loop: Label = null
var _held: Label = null
var _hidden: Label = null
var _banner: Label = null
var _inspect: Label = null
var _inspect_left: float = 0.0


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Control under a CanvasLayer has no parent rect to anchor against, so it
	# is sized to the viewport by hand and kept that way.
	_fit_viewport()

	var big := int(visuals.number("hud.timer_size", 64))
	var small := int(visuals.number("hud.label_size", 18))

	# The timer is the loudest thing on screen and it owns the top centre.
	_timer = _make_label(big, HORIZONTAL_ALIGNMENT_CENTER)
	_timer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer.offset_top = visuals.number("hud.timer_top", 14.0)
	_timer.offset_bottom = _timer.offset_top + float(big) * 1.3
	add_child(_timer)

	_lines = VBoxContainer.new()
	_lines.position = Vector2(visuals.number("hud.label_left", 24.0), visuals.number("hud.label_top", 96.0))
	_lines.add_theme_constant_override("separation", int(visuals.number("hud.label_gap", 26.0)) - small)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

	_loop = _make_label(small)
	_held = _make_label(small)
	_hidden = _make_label(small)
	for label in [_loop, _held, _hidden]:
		_lines.add_child(label)

	_banner = _make_label(big, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400.0
	_banner.offset_right = 400.0
	_banner.offset_top = -float(big)
	_banner.offset_bottom = float(big)
	_banner.visible = false
	add_child(_banner)

	# Inspect is the one verb whose whole product is words. It used to produce
	# them into the notebook and nowhere else, which read as nothing happening.
	_inspect = _make_label(int(visuals.number("hud.inspect_size", 20)), HORIZONTAL_ALIGNMENT_CENTER)
	_inspect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_inspect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect.offset_left = visuals.number("hud.inspect_margin", 140.0)
	_inspect.offset_right = -visuals.number("hud.inspect_margin", 140.0)
	_inspect.offset_top = -visuals.number("hud.inspect_bottom", 118.0)
	_inspect.offset_bottom = -visuals.number("hud.inspect_bottom", 118.0) + float(int(visuals.number("hud.inspect_size", 20))) * 3.4
	_inspect.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_inspect)

	_fit_viewport()


## Built off the scene tree in tests, where there is no viewport to measure.
func _fit_viewport() -> void:
	var view := get_viewport()
	if view == null:
		return
	size = view.get_visible_rect().size
	if not view.size_changed.is_connected(_fit_viewport):
		view.size_changed.connect(_fit_viewport)


func _make_label(font_size: int, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func sync(world: SimWorld, loop_index: int, panel_open: bool = false) -> void:
	var remaining := world.timer_remaining_s()
	_timer.text = "%0.1f" % remaining
	var urgent := remaining <= visuals.number("hud.urgent_below_s", 10.0)
	_timer.add_theme_color_override("font_color",
		visuals.colour("hud.urgent_color") if urgent else visuals.colour("hud.timer_color"))

	_loop.text = "Death %d" % maxi(loop_index - 1, 0)
	_held.text = "Holding: %s" % (world.player.holding if not world.player.holding.is_empty() else "—")
	_hidden.text = "Hidden in: %s" % world.player.hidden_in if world.player.is_hidden() else ""

	if world.ending.is_empty() or panel_open:
		_banner.visible = false
		return
	_banner.visible = true
	_banner.text = world.ending.to_upper()
	_banner.add_theme_color_override("font_color", visuals.colour("hud.timer_color"))


## What you just looked at, for as long as the table says. The name is there
## because the wheel can be aimed at any of five things stacked on a cell.
func show_inspect(object_name: String, text: String) -> void:
	_inspect.text = "%s — %s" % [object_name, text] if not object_name.is_empty() else text
	_inspect.add_theme_color_override("font_color", visuals.colour("hud.inspect_color"))
	_inspect_left = visuals.number("hud.inspect_hold_s", 4.0)


func inspect_text() -> String:
	return _inspect.text


## Fades on real seconds, not sim ticks: the sim is stopped while a panel is open
## and the line should still go away.
func advance(delta: float) -> void:
	if _inspect_left <= 0.0:
		return
	_inspect_left -= delta
	var fade := visuals.number("hud.inspect_fade_s", 0.8)
	_inspect.modulate.a = clampf(_inspect_left / maxf(fade, 0.001), 0.0, 1.0)
	if _inspect_left <= 0.0:
		_inspect.text = ""
		_inspect.modulate.a = 1.0


func flash(text: String) -> void:
	_banner.text = text
	_banner.visible = true
