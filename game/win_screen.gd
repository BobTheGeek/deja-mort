class_name WinScreen
extends Control

## Stars, the ending you got, the run in one line, the endings row, the numbers,
## completion, and the one sentence the notebook wrote about it.
##
## The endings row is the pitch: four discs, the ones you have found lit and
## named, the ones you have not as unnamed silhouettes. It says "there are three
## other ways out of this room" without a word of copy.
##
## Drawn rather than assembled, like the rest of the UI. Every number is `win` in
## visuals.json (Claude Design turn 1; docs/ui/SPEC.md is the drawing).

signal replay_pressed()

const BRAND := preload("res://game/theme/brand.gd")

const ENDINGS: PackedStringArray = [
	SimOutcome.ENDING_EVADE, SimOutcome.ENDING_DISABLE,
	SimOutcome.ENDING_KILL, SimOutcome.ENDING_ESCAPE,
]

const REQUIRED_KEYS: PackedStringArray = [
	"room_dim_color", "room_dim_alpha", "panel_width", "panel_top", "panel_padding",
	"panel_gap", "panel_fill", "panel_fill_alpha", "panel_border", "panel_border_alpha",
	"panel_border_width", "panel_radius", "open_in_s", "open_delay_s", "open_scale_from",
	"star_size", "star_gap", "star_earned_fill", "star_unearned_stroke", "star_unearned_alpha",
	"star_unearned_stroke_width", "ending_size", "ending_tracking_em", "ending_color",
	"run_line_size", "run_line_alpha", "run_line_separator", "endings_row_gap",
	"endings_row_padding_y", "endings_row_rule_alpha", "ending_disc_size", "ending_icon_size",
	"ending_found_fill", "ending_found_icon", "ending_found_label_size",
	"ending_found_label_tracking_em", "ending_unfound_alpha", "ending_unfound_border_width",
	"ending_unfound_label_rule_width", "ending_unfound_label_rule_height", "stats_columns",
	"stats_gap", "stat_label_size", "stat_label_tracking_em", "stat_label_alpha",
	"stat_value_size", "stat_total_alpha", "collectible_mark_size",
	"collectible_not_found_alpha", "collectible_text_size", "completion_label_size",
	"completion_bar_height", "completion_track_alpha", "completion_fill",
	"notebook_line_size", "notebook_line_height", "notebook_line_alpha", "button_min_width",
	"button_height", "button_gap", "button_radius", "button_size", "button_tracking_em",
	"button_primary_fill", "button_primary_text", "button_disabled_border_alpha",
	"button_disabled_text_alpha", "button_disabled_sub_size", "ending_icon_path",
]

var visuals: GameVisuals = null

var _report: Dictionary = {}
var _entry: Dictionary = {}
var _loop_index: int = 1
var _elapsed: float = 0.0
var _hover: String = ""
var _font: Font = null
var _font_bold: Font = null
var _font_light: Font = null
var _icons: Dictionary = {}


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = _load_font("FONT_UI")
	_font_bold = _load_font("FONT_UI_BOLD")
	_font_light = _font
	var path := str(visuals.get_value("win.ending_icon_path", ""))
	for ending in ENDINGS:
		_icons[ending] = load(path % ending) as Texture2D
	_fit_viewport()


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


# --- showing -----------------------------------------------------------------

func show_result(report: Dictionary, entry: Dictionary, loop_index: int) -> void:
	_report = report
	_entry = entry
	_loop_index = loop_index
	_elapsed = 0.0
	_hover = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_viewport()


func hide_screen() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_open() -> bool:
	return visible


func advance(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


## Nothing until the ending has been named; then it arrives.
func reveal() -> float:
	var delay := visuals.number("win.open_delay_s", 0.6)
	var span := maxf(visuals.number("win.open_in_s", 0.35), 0.001)
	return clampf((_elapsed - delay) / span, 0.0, 1.0)


# --- the headline ------------------------------------------------------------

func headline() -> String:
	return str(_report.get("ending", "")).to_upper()


func stars() -> Array:
	var earned := int(_report.get("stars", 0))
	var box := visuals.number("win.star_size", 36.0)
	var gap := visuals.number("win.star_gap", 10.0)
	var total := box * 3.0 + gap * 2.0
	var left := _panel_centre_x() - total * 0.5
	var top := _panel_top() + _padding().x
	var out: Array = []
	for i in 3:
		out.append({
			"earned": i < earned,
			"rect": Rect2(Vector2(left + float(i) * (box + gap), top), Vector2(box, box)),
		})
	return out


func run_line() -> String:
	var separator := str(visuals.get_value("win.run_line_separator", " · "))
	return separator.join(PackedStringArray([
		"Deaths %d" % maxi(_loop_index - 1, 0),
		"Time survived %.1fs" % float(_report.get("time_s", 0.0)),
	]))


# --- the endings row ---------------------------------------------------------

## All four, always, in a fixed order. An unfound ending is never named: the
## silhouette is the invitation and the name would be the answer.
func ending_cells() -> Array:
	var found: Array = _entry.get("endings_found", [])
	var disc := visuals.number("win.ending_disc_size", 96.0)
	var gap := visuals.number("win.endings_row_gap", 16.0)
	var total := disc * float(ENDINGS.size()) + gap * float(ENDINGS.size() - 1)
	var left := _panel_centre_x() - total * 0.5
	var top := _endings_top()
	var out: Array = []
	for i in ENDINGS.size():
		var ending := str(ENDINGS[i])
		var is_found := found.has(ending)
		out.append({
			"ending": ending,
			"found": is_found,
			"label": ending.to_upper() if is_found else "",
			"rect": Rect2(Vector2(left + float(i) * (disc + gap), top), Vector2(disc, disc)),
		})
	return out


func _endings_top() -> float:
	return _panel_top() + _padding().x + visuals.number("win.star_size", 36.0) \
		+ visuals.number("win.ending_size", 64.0) * 1.3 \
		+ visuals.number("win.run_line_size", 22.0) * 2.2 \
		+ visuals.number("win.endings_row_padding_y", 24.0)


# --- the numbers -------------------------------------------------------------

func stats() -> Array:
	var completion: Dictionary = _report.get("completion", {})
	var possible_disc: Array = completion.get("discoveries_possible", [])
	var found: Array = _entry.get("collectible", [])
	return [
		{"label": "INTERACTIONS", "value": "%d / %d" % [
			(_entry.get("interactions_done", []) as Array).size(),
			int(completion.get("interactions_possible", 0))]},
		{"label": "DISCOVERIES", "value": "%d / %d" % [
			(_entry.get("discoveries", []) as Array).size(), possible_disc.size()]},
		{"label": "WAYS TO DIE", "value": "%d" % (_entry.get("deaths", []) as Array).size()},
		{"label": "COLLECTIBLE", "value": "Found" if not found.is_empty() else "Not found"},
	]


func completion_percent() -> float:
	var completion: Dictionary = _report.get("completion", {})
	var possible := float(int(completion.get("interactions_possible", 0))
		+ (completion.get("discoveries_possible", []) as Array).size())
	if possible <= 0.0:
		return 0.0
	var done := float((_entry.get("interactions_done", []) as Array).size()
		+ (_entry.get("discoveries", []) as Array).size())
	return clampf(done / possible * 100.0, 0.0, 100.0)


func completion_track_rect() -> Rect2:
	var padding := _padding()
	var width := visuals.number("win.panel_width", 880.0)
	return Rect2(Vector2(_panel_left() + padding.y, _completion_top()),
		Vector2(width - padding.y * 2.0, visuals.number("win.completion_bar_height", 3.0)))


func completion_bar_rect() -> Rect2:
	var track := completion_track_rect()
	return Rect2(track.position, Vector2(track.size.x * completion_percent() / 100.0, track.size.y))


func _completion_top() -> float:
	return _stats_top() + visuals.number("win.stat_label_size", 13.0) * 1.8 \
		+ visuals.number("win.stat_value_size", 28.0) * 1.6 \
		+ visuals.number("win.panel_gap", 32.0)


func _stats_top() -> float:
	return _endings_top() + visuals.number("win.ending_disc_size", 96.0) \
		+ visuals.number("win.ending_found_label_size", 14.0) * 2.4 \
		+ visuals.number("win.endings_row_padding_y", 24.0)


# --- the buttons -------------------------------------------------------------

func button_rect(id: String) -> Rect2:
	var width := visuals.number("win.button_min_width", 220.0)
	var height := visuals.number("win.button_height", 56.0)
	var gap := visuals.number("win.button_gap", 16.0)
	var left := _panel_centre_x() - (width * 2.0 + gap) * 0.5
	return Rect2(Vector2(left + (width + gap if id == "next" else 0.0), _buttons_top()),
		Vector2(width, height))


## Rooms 2-4 are M5. The button is drawn so the player knows they exist.
func button_enabled(id: String) -> bool:
	return id == "replay"


func press_at(point: Vector2) -> bool:
	if not visible:
		return false
	if button_rect("replay").has_point(point):
		hide_screen()
		replay_pressed.emit()
		return true
	return panel_rect().has_point(point)


func hover_at(point: Vector2) -> void:
	var was := _hover
	_hover = "replay" if button_rect("replay").has_point(point) else ""
	if was != _hover:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		hover_at((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	press_at(click.position)


# --- the panel ---------------------------------------------------------------

func _padding() -> Vector3:
	var raw: Array = visuals.get_value("win.panel_padding", [40, 56, 44])
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


## The vertical stack is measured from these two, never from panel_rect(): the
## panel hugs its content, so its height depends on the stack rather than the
## other way round.
func _panel_top() -> float:
	return visuals.number("win.panel_top", 96.0) + visuals.inset("top")


func _panel_left() -> float:
	var width := visuals.number("win.panel_width", 880.0)
	return visuals.inset("left") \
		+ (frame().x - visuals.inset("left") - visuals.inset("right") - width) * 0.5


func _panel_centre_x() -> float:
	return _panel_left() + visuals.number("win.panel_width", 880.0) * 0.5


## Hugs its content. Filling the frame left a hand's width of nothing between
## the notebook line and the buttons.
func panel_rect() -> Rect2:
	var width := visuals.number("win.panel_width", 880.0)
	var top := _panel_top()
	var height := minf(_buttons_top() + visuals.number("win.button_height", 56.0) + _padding().z - top,
		frame().y - visuals.inset("bottom") - top - 24.0)
	return Rect2(Vector2(_panel_left(), top), Vector2(width, height))


## Where the last line of type ends, so the panel knows where to stop.
func _notebook_bottom() -> float:
	var size := visuals.number("win.notebook_line_size", 22.0)
	var width := visuals.number("win.panel_width", 880.0) - _padding().y * 2.0
	var lines := maxi(_wrapped(str(_report.get("notebook", "")), width, int(size)).size(), 1)
	return completion_track_rect().end.y + visuals.number("win.panel_gap", 32.0) \
		+ size * visuals.number("win.notebook_line_height", 1.4) * float(lines)


func _buttons_top() -> float:
	return _notebook_bottom() + visuals.number("win.panel_gap", 32.0)


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if not visible or visuals == null or _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, frame()),
		visuals.colour_with_alpha("win.room_dim_color", "win.room_dim_alpha"), true)
	var t := reveal()
	if t <= 0.0:
		return
	var panel := panel_rect()
	draw_style_box(_panel_style(t), panel)
	_draw_stars(t)
	_draw_headline(t)
	_draw_endings(t)
	_draw_stats(t)
	_draw_completion(t)
	_draw_notebook_line(t)
	_draw_buttons(t)


func _panel_style(t: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _fade(visuals.colour_with_alpha("win.panel_fill", "win.panel_fill_alpha"), t)
	style.border_color = _fade(
		visuals.colour_with_alpha("win.panel_border", "win.panel_border_alpha"), t)
	style.set_border_width_all(int(visuals.number("win.panel_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("win.panel_radius", 4)))
	return style


func _draw_stars(t: float) -> void:
	var stagger := visuals.number("win.star_reveal_stagger_s", 0.15)
	var index := 0
	for star in stars():
		var box: Rect2 = star["rect"]
		var due := visuals.number("win.open_delay_s", 0.6) + float(index) * stagger
		if _elapsed < due:
			index += 1
			continue
		var points := _star_points(box)
		if bool(star["earned"]):
			draw_colored_polygon(points, _fade(visuals.colour("win.star_earned_fill"), t))
		else:
			var outline := _fade(visuals.colour_with_alpha(
				"win.star_unearned_stroke", "win.star_unearned_alpha"), t)
			draw_polyline(points + PackedVector2Array([points[0]]), outline,
				visuals.number("win.star_unearned_stroke_width", 1.5), true)
		index += 1


func _star_points(box: Rect2) -> PackedVector2Array:
	var centre := box.get_center()
	var outer := box.size.x * 0.5
	var inner := outer * 0.42
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var radius := outer if i % 2 == 0 else inner
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_headline(t: float) -> void:
	var size := int(visuals.number("win.ending_size", 64.0))
	var top := _panel_top() + _padding().x + visuals.number("win.star_size", 36.0) + float(size)
	_tracked(_font_bold, headline(), Vector2(_panel_centre_x(), top), size,
		visuals.number("win.ending_tracking_em", 0.22),
		_fade(visuals.colour("win.ending_color"), t), true)
	var run_size := int(visuals.number("win.run_line_size", 22.0))
	var run := run_line()
	var width := _font.get_string_size(run, HORIZONTAL_ALIGNMENT_LEFT, -1, run_size).x
	draw_string(_font, Vector2(_panel_centre_x() - width * 0.5, top + float(run_size) * 1.9),
		run, HORIZONTAL_ALIGNMENT_LEFT, -1, run_size,
		_fade(visuals.colour_with_alpha("hud.timer_color", "win.run_line_alpha"), t))


func _draw_endings(t: float) -> void:
	var panel := panel_rect()
	var rule := _endings_top() - visuals.number("win.endings_row_padding_y", 24.0) * 0.5
	draw_rect(Rect2(Vector2(panel.position.x + _padding().y, rule),
		Vector2(panel.size.x - _padding().y * 2.0, 1.0)),
		_fade(visuals.colour_with_alpha("hud.timer_color", "win.endings_row_rule_alpha"), t), true)
	var stagger := visuals.number("win.ending_reveal_stagger_s", 0.1)
	var index := 0
	for cell in ending_cells():
		var due := visuals.number("win.open_delay_s", 0.6) + float(index) * stagger
		index += 1
		if _elapsed < due:
			continue
		_draw_ending_cell(cell as Dictionary, t)


func _draw_ending_cell(cell: Dictionary, t: float) -> void:
	var box: Rect2 = cell["rect"]
	var found := bool(cell["found"])
	var centre := box.get_center()
	var radius := box.size.x * 0.5
	var icon_size := visuals.number("win.ending_icon_size", 44.0)
	var icon: Texture2D = _icons.get(str(cell["ending"]), null)
	var alpha := 1.0 if found else visuals.number("win.ending_unfound_alpha", 0.3)
	if found:
		draw_circle(centre, radius, _fade(visuals.colour("win.ending_found_fill"), t))
	else:
		_dashed_circle(centre, radius,
			_fade(_alpha(visuals.colour("hud.timer_color"), alpha), t),
			visuals.number("win.ending_unfound_border_width", 1.5))
	if icon != null:
		draw_texture_rect(icon, Rect2(centre - Vector2(icon_size, icon_size) * 0.5,
			Vector2(icon_size, icon_size)), false,
			_fade(_alpha(visuals.colour("win.ending_found_icon" if found else "hud.timer_color"),
				alpha), t))
	var label_size := int(visuals.number("win.ending_found_label_size", 14.0))
	var label_y := box.end.y + float(label_size) * 1.8
	if found:
		_tracked(_font_bold, str(cell["label"]), Vector2(centre.x, label_y), label_size,
			visuals.number("win.ending_found_label_tracking_em", 0.16),
			_fade(visuals.colour("hud.timer_color"), t), true)
		return
	# A rule where the name would be: something is missing, and it has a shape.
	var width := visuals.number("win.ending_unfound_label_rule_width", 48.0)
	draw_rect(Rect2(Vector2(centre.x - width * 0.5, label_y - float(label_size) * 0.4),
		Vector2(width, visuals.number("win.ending_unfound_label_rule_height", 2.0))),
		_fade(_alpha(visuals.colour("hud.timer_color"), alpha), t), true)


func _draw_stats(t: float) -> void:
	var panel := panel_rect()
	var padding := _padding()
	var columns := maxi(int(visuals.number("win.stats_columns", 4)), 1)
	var gap := visuals.number("win.stats_gap", 24.0)
	var width := (panel.size.x - padding.y * 2.0 - gap * float(columns - 1)) / float(columns)
	var label_size := int(visuals.number("win.stat_label_size", 13.0))
	var value_size := int(visuals.number("win.stat_value_size", 28.0))
	var top := _stats_top()
	var index := 0
	for stat in stats():
		var x := panel.position.x + padding.y + float(index) * (width + gap)
		_tracked(_font, str((stat as Dictionary)["label"]), Vector2(x, top + float(label_size)),
			label_size, visuals.number("win.stat_label_tracking_em", 0.16),
			_fade(visuals.colour_with_alpha("hud.timer_color", "win.stat_label_alpha"), t))
		draw_string(_font_bold, Vector2(x, top + float(label_size) * 1.8 + float(value_size)),
			str((stat as Dictionary)["value"]), HORIZONTAL_ALIGNMENT_LEFT, -1, value_size,
			_fade(visuals.colour("hud.timer_color"), t))
		index += 1


func _draw_completion(t: float) -> void:
	var track := completion_track_rect()
	var label_size := int(visuals.number("win.completion_label_size", 13.0))
	_tracked(_font, "ROOM COMPLETION", Vector2(track.position.x, track.position.y - float(label_size)),
		label_size, visuals.number("win.stat_label_tracking_em", 0.16),
		_fade(visuals.colour_with_alpha("hud.timer_color", "win.stat_label_alpha"), t))
	var percent := "%.0f%%" % completion_percent()
	var width := _font_bold.get_string_size(percent, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size + 4).x
	draw_string(_font_bold, Vector2(track.end.x - width, track.position.y - float(label_size)),
		percent, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size + 4, _fade(visuals.colour("hud.timer_color"), t))
	draw_rect(track, _fade(visuals.colour_with_alpha("hud.timer_color", "win.completion_track_alpha"), t), true)
	var fill := completion_bar_rect()
	fill.size.x *= clampf(_elapsed - visuals.number("win.open_delay_s", 0.6), 0.0,
		visuals.number("win.completion_fill_s", 0.6)) / maxf(visuals.number("win.completion_fill_s", 0.6), 0.001)
	if fill.size.x > 0.0:
		draw_rect(fill, _fade(visuals.colour("win.completion_fill"), t), true)


func _draw_notebook_line(t: float) -> void:
	var panel := panel_rect()
	var padding := _padding()
	var size := int(visuals.number("win.notebook_line_size", 22.0))
	var line_height := float(size) * visuals.number("win.notebook_line_height", 1.4)
	var y := completion_track_rect().end.y + visuals.number("win.panel_gap", 32.0) + float(size)
	var colour := _fade(visuals.colour_with_alpha("hud.timer_color", "win.notebook_line_alpha"), t)
	for line in _wrapped(str(_report.get("notebook", "")), panel.size.x - padding.y * 2.0, size):
		draw_string(_font_light, Vector2(panel.position.x + padding.y, y), str(line),
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		y += line_height


func _draw_buttons(t: float) -> void:
	_draw_button("replay", "REPLAY", t)
	_draw_button("next", "NEXT ROOM", t)


func _draw_button(id: String, label: String, t: float) -> void:
	var box := button_rect(id)
	var size := int(visuals.number("win.button_size", 18.0))
	var tracking := visuals.number("win.button_tracking_em", 0.08)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(visuals.number("win.button_radius", 4)))
	if button_enabled(id):
		var fill := visuals.colour("win.button_primary_fill")
		if _hover == id:
			fill = fill.lightened(visuals.number("win.button_primary_hover_lighten", 0.08))
		style.bg_color = _fade(fill, t)
		draw_style_box(style, box)
		_tracked(_font_bold, label, Vector2(box.get_center().x, box.get_center().y + float(size) * 0.36),
			size, tracking, _fade(visuals.colour("win.button_primary_text"), t), true)
		return
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = _fade(visuals.colour_with_alpha(
		"hud.timer_color", "win.button_disabled_border_alpha"), t)
	style.set_border_width_all(int(visuals.number("win.panel_border_width", 1.5)))
	draw_style_box(style, box)
	var faded := _fade(visuals.colour_with_alpha("hud.timer_color", "win.button_disabled_text_alpha"), t)
	_tracked(_font_bold, label, Vector2(box.get_center().x, box.get_center().y), size, tracking,
		faded, true)
	var sub := int(visuals.number("win.button_disabled_sub_size", 11.0))
	_tracked(_font, "NOT YET", Vector2(box.get_center().x, box.get_center().y + float(sub) * 1.8),
		sub, visuals.number("win.button_disabled_sub_tracking_em", 0.14), faded, true)


# --- helpers -----------------------------------------------------------------

func _dashed_circle(centre: Vector2, radius: float, colour: Color, width: float) -> void:
	var dash: Array = visuals.get_value("win.ending_unfound_border_dash", [6, 6])
	var on := float(dash[0]) / maxf(radius, 1.0)
	var step := (float(dash[0]) + float(dash[1])) / maxf(radius, 1.0)
	var angle := 0.0
	while angle < TAU:
		draw_arc(centre, radius, angle, angle + on, 6, colour, width, true)
		angle += step


func _wrapped(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	if text.strip_edges().is_empty():
		return out
	var line := ""
	for word in text.split(" "):
		var candidate := str(word) if line.is_empty() else line + " " + str(word)
		if _font != null and not line.is_empty() \
				and _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = str(word)
		else:
			line = candidate
	if not line.is_empty():
		out.append(line)
	return out


## Letter spacing, which draw_string does not do.
func _tracked(font: Font, text: String, anchor: Vector2, size: int, tracking_em: float,
		colour: Color, centred := false) -> void:
	if font == null or text.is_empty():
		return
	var extra := tracking_em * float(size)
	var total := -extra
	for i in text.length():
		total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + extra
	var x := anchor.x - (total * 0.5 if centred else 0.0)
	for i in text.length():
		draw_string(font, Vector2(x, anchor.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + extra


func _alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * alpha)


func _fade(colour: Color, t: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * t)


func _load_font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null
