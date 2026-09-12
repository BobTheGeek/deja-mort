class_name GameHud
extends Control

## Timer, loop counter, what is in your hands, whether you are hidden, and what
## the room just told you. Reads sim state; decides nothing.
##
## Sizes and positions are Claude Design's, in px at the 1920x1080 canvas the
## project stretches to (docs/ui/SPEC.md). The tally strokes, the urgent bar and
## the hidden chip are the HUD rebuild and are not here yet.

const BRAND := preload("res://game/theme/brand.gd")

var visuals: GameVisuals = null

var _timer: Label = null
var _lines: VBoxContainer = null
var _loop: Label = null
var _held: Label = null
var _hidden: Label = null
var _banner: Label = null
var _inspect: Panel = null
var _inspect_text: RichTextLabel = null
var _inspect_left: float = 0.0


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_viewport()

	var big := int(visuals.number("hud.timer_size", 84))
	var small := int(visuals.number("hud.loop_label_size", 20))

	# The timer is the loudest thing on screen and it owns the top centre.
	_timer = _make_label(big, HORIZONTAL_ALIGNMENT_CENTER, true)
	_timer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer.offset_top = visuals.number("hud.timer_top", 36.0)
	_timer.offset_bottom = _timer.offset_top + float(big) * 1.3
	add_child(_timer)

	_lines = VBoxContainer.new()
	_lines.position = Vector2(visuals.number("hud.margin_x", 48.0), visuals.number("hud.margin_top", 44.0))
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

	_loop = _make_label(small)
	_loop.modulate.a = visuals.number("hud.loop_label_alpha", 0.75)
	_held = _make_label(int(visuals.number("hud.holding_value_size", 22)))
	_hidden = _make_label(int(visuals.number("hud.hidden_text_size", 18)))
	for label in [_loop, _held, _hidden]:
		_lines.add_child(label)

	_banner = _make_label(int(visuals.number("hud.banner_size", 128)), HORIZONTAL_ALIGNMENT_CENTER, true)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -700.0
	_banner.offset_right = 700.0
	_banner.offset_top = -visuals.number("hud.banner_size", 128.0)
	_banner.offset_bottom = visuals.number("hud.banner_size", 128.0)
	_banner.visible = false
	add_child(_banner)

	_build_inspect()
	_fit_viewport()


## Inspect is the one verb whose whole product is words, and white text straight
## onto a lit wall is the contrast case the brief calls out. So it gets a panel.
func _build_inspect() -> void:
	# A Panel with hand-placed children rather than a PanelContainer: the HUD is
	# built off the scene tree in tests, where no layout pass ever runs and a
	# container's idea of its own size is whatever it was last told.
	_inspect = Panel.new()
	_inspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect.add_theme_stylebox_override("panel", _inspect_style())
	_inspect.visible = false
	add_child(_inspect)

	_inspect_text = RichTextLabel.new()
	_inspect_text.bbcode_enabled = true
	_inspect_text.fit_content = false
	_inspect_text.scroll_active = false
	_inspect_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_text.add_theme_font_size_override("normal_font_size",
		int(visuals.number("hud.inspect_size", 26)))
	_inspect_text.add_theme_font_size_override("bold_font_size",
		int(visuals.number("hud.inspect_size", 26)))
	_inspect_text.add_theme_font_override("normal_font", _font("FONT_UI"))
	_inspect_text.add_theme_font_override("bold_font", _font("FONT_UI_BOLD"))
	_inspect_text.add_theme_color_override("default_color", visuals.colour("hud.timer_color"))
	_inspect.add_child(_inspect_text)
	_place_inspect()


## Measured rather than laid out, so one line of text gets a one-line panel.
func _inspect_metrics() -> Dictionary:
	var padding: Array = visuals.get_value("hud.inspect_padding", [18, 26])
	var size := visuals.number("hud.inspect_size", 26.0)
	var width := visuals.number("hud.inspect_max_width", 980.0)
	var inner := width - float(padding[1]) * 2.0
	var font := _font("FONT_UI")
	var text := _inspect_text.get_parsed_text() if _inspect_text != null else ""
	var run := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x \
		if font != null else 0.0
	var lines := clampi(int(ceil(run / maxf(inner, 1.0))), 1, 3)
	var line_height := size * visuals.number("hud.inspect_line_height", 1.4)
	return {
		"padding": Vector2(float(padding[1]), float(padding[0])),
		"size": Vector2(width, line_height * float(lines) + float(padding[0]) * 2.0),
		"inner": Vector2(inner, line_height * float(lines)),
	}


func _inspect_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = visuals.colour_with_alpha("hud.inspect_fill", "hud.inspect_fill_alpha")
	style.border_color = visuals.colour_with_alpha("hud.inspect_border_color", "hud.inspect_border_alpha")
	var border := int(visuals.number("hud.inspect_border_width", 1.5))
	style.set_border_width_all(border)
	var radius := int(visuals.number("hud.inspect_radius", 4))
	style.set_corner_radius_all(radius)
	return style


func _place_inspect() -> void:
	if _inspect == null:
		return
	var metrics := _inspect_metrics()
	var box: Vector2 = size if size.x > 0.0 else Vector2(
		visuals.number("ui.design_width", 1920.0), visuals.number("ui.design_height", 1080.0))
	_inspect.size = metrics["size"]
	_inspect.position = Vector2((box.x - _inspect.size.x) * 0.5,
		box.y - visuals.number("hud.margin_bottom", 56.0) - _inspect.size.y)
	_inspect_text.position = metrics["padding"]
	_inspect_text.size = metrics["inner"]


func inspect_rect() -> Rect2:
	return Rect2(_inspect.position, _inspect.size) if _inspect != null else Rect2()


## Built off the scene tree in tests, where there is no viewport to measure.
func _fit_viewport() -> void:
	var view := get_viewport()
	if view == null:
		size = Vector2(visuals.number("ui.design_width", 1920.0), visuals.number("ui.design_height", 1080.0))
		return
	size = view.get_visible_rect().size
	_place_inspect()
	if not view.size_changed.is_connected(_fit_viewport):
		view.size_changed.connect(_fit_viewport)


func _font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null


func _make_label(font_size: int, align: int = HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	var font := _font("FONT_UI_BOLD" if bold else "FONT_UI")
	if font != null:
		label.add_theme_font_override("font", font)
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
	_banner.add_theme_color_override("font_color", visuals.colour("hud.banner_color"))


## What you just looked at, for as long as the table says. The name is there
## because the wheel can be aimed at any of five things stacked on a cell.
func show_inspect(object_name: String, text: String) -> void:
	var name_colour := visuals.colour("hud.inspect_name_color")
	_inspect_text.text = "[b][color=#%s]%s[/color][/b]  %s" % [
		name_colour.to_html(false), object_name, text] if not object_name.is_empty() else text
	_inspect.visible = true
	_inspect.modulate.a = 1.0
	_inspect_left = visuals.number("hud.inspect_hold_s", 5.0)
	_place_inspect()


func inspect_text() -> String:
	return _inspect_text.get_parsed_text() if _inspect.visible else ""


## Fades on real seconds, not sim ticks: the sim is stopped while a panel is open
## and the line should still go away.
func advance(delta: float) -> void:
	if _inspect_left <= 0.0:
		return
	_inspect_left -= delta
	var fade := visuals.number("hud.inspect_fade_s", 0.8)
	_inspect.modulate.a = clampf(_inspect_left / maxf(fade, 0.001), 0.0, 1.0)
	if _inspect_left <= 0.0:
		_inspect.visible = false
		_inspect_text.text = ""
		_inspect.modulate.a = 1.0


func flash(text: String) -> void:
	_banner.text = text
	_banner.visible = true
