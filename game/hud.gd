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


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Control under a CanvasLayer has no parent rect to anchor against, so it
	# is sized to the viewport by hand and kept that way.
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)

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


func _fit_viewport() -> void:
	size = get_viewport_rect().size


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


func flash(text: String) -> void:
	_banner.text = text
	_banner.visible = true
