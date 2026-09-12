class_name Notebook
extends Control

## Auto-written, never typed. Three tabs: what is in the room, what he did, and
## how you died. It is the hint system and it is the only voice the game has.
##
## A case file, not a paper notebook — no ruled lines, no handwriting, nothing
## cosy. Something cold that records what happened to you, repeatedly, without
## comment. Drawn rather than assembled, like the rest of the UI, and every
## number is `notebook` in visuals.json (Claude Design turn 1; docs/ui/SPEC.md
## is the drawing).
##
## Their design has a fourth tab, Achievements. This game has no achievements,
## so it is in docs/BACKLOG.md rather than invented here.

const BRAND := preload("res://game/theme/brand.gd")

const TAB_ROOM := "Room"
const TAB_ATTACKER := "Attacker"
const TAB_DEATHS := "Deaths"
const TABS: PackedStringArray = [TAB_ROOM, TAB_ATTACKER, TAB_DEATHS]

const REQUIRED_KEYS: PackedStringArray = [
	"panel_width", "panel_height", "panel_top", "panel_fill", "panel_fill_alpha",
	"panel_border", "panel_border_alpha", "panel_border_width", "panel_radius",
	"room_dim_color", "room_dim_alpha", "open_in_s", "open_scale_from", "header_padding",
	"header_size", "header_tracking_em", "header_alpha", "close_size", "close_glyph_size",
	"close_alpha", "close_hover_fill", "close_hover_fill_alpha", "tab_row_padding_x",
	"tab_gap", "tab_padding", "tab_size", "tab_tracking_em", "tab_count_size",
	"tab_count_alpha", "tab_selected_color", "tab_selected_line", "tab_selected_line_width",
	"tab_unselected_alpha", "tab_row_rule_alpha", "body_padding", "entry_padding_y",
	"entry_gap", "entry_rule_alpha", "entry_name_size", "entry_line_size",
	"entry_line_height", "entry_line_alpha", "entry_tags_size", "entry_tags_tracking_em",
	"entry_tags_alpha", "entry_tags_separator", "attacker_bullet_size",
	"attacker_bullet_alpha", "attacker_size", "death_number_col", "death_size", "empty_size",
	"empty_alpha", "empty_padding_y", "scroll_fade_height", "scroll_more_size",
	"scroll_more_tracking_em", "scroll_more_alpha", "scrollbar_width", "scrollbar_inset",
	"scrollbar_track_alpha", "scrollbar_thumb_alpha", "scrollbar_min_thumb", "icon_path",
]

var visuals: GameVisuals = null

var _world: SimWorld = null
var _entry: Dictionary = {}
var _active := TAB_ROOM
var _scroll: float = 0.0
var _open_t: float = 0.0
var _hover_close: bool = false
var _font: Font = null
var _font_bold: Font = null
var _close_icon: Texture2D = null


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = _load_font("FONT_UI")
	_font_bold = _load_font("FONT_UI_BOLD")
	_close_icon = load(str(visuals.get_value("notebook.icon_path", "")) % "close") as Texture2D
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


# --- opening and closing -----------------------------------------------------

func show_for(world: SimWorld, entry: Dictionary) -> void:
	_world = world
	_entry = entry
	_active = TAB_ROOM
	_scroll = 0.0
	_open_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_viewport()


func hide_book() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_open() -> bool:
	return visible


func toggle(world: SimWorld, entry: Dictionary) -> void:
	if visible:
		hide_book()
	else:
		show_for(world, entry)


func advance(delta: float) -> void:
	if not visible or _open_t >= 1.0:
		return
	_open_t = clampf(_open_t + delta / maxf(visuals.number("notebook.open_in_s", 0.15), 0.001), 0.0, 1.0)
	queue_redraw()


# --- geometry ----------------------------------------------------------------

func panel_rect() -> Rect2:
	var width := visuals.number("notebook.panel_width", 800.0)
	var height := visuals.number("notebook.panel_height", 720.0)
	var box := frame()
	var top := visuals.number("notebook.panel_top", 200.0) + visuals.inset("top")
	var room := box.y - visuals.inset("bottom") - top
	if height > room:
		height = maxf(room, 200.0)
	var left := visuals.inset("left") + (box.x - visuals.inset("left") - visuals.inset("right") - width) * 0.5
	return Rect2(Vector2(left, top), Vector2(width, height))


func close_rect() -> Rect2:
	var box := visuals.number("notebook.close_size", 44.0)
	var padding: Array = visuals.get_value("notebook.header_padding", [20, 20, 0, 32])
	var panel := panel_rect()
	return Rect2(Vector2(panel.end.x - float(padding[1]) - box, panel.position.y + float(padding[0]) * 0.5),
		Vector2(box, box))


func tabs() -> PackedStringArray:
	return TABS


func active_tab() -> String:
	return _active


func tab_rect(tab: String) -> Rect2:
	var padding: Array = visuals.get_value("notebook.tab_padding", [14, 2, 12])
	var height := visuals.number("notebook.tab_size", 18.0) + float(padding[0]) * 2.0
	var panel := panel_rect()
	var x := panel.position.x + visuals.number("notebook.tab_row_padding_x", 32.0)
	var top := panel.position.y + _header_height()
	for name in TABS:
		var width := _tab_width(str(name))
		if str(name) == tab:
			return Rect2(Vector2(x, top), Vector2(width, height))
		x += width + visuals.number("notebook.tab_gap", 32.0)
	return Rect2()


func _tab_width(tab: String) -> float:
	if _font_bold == null:
		return 120.0
	var size := int(visuals.number("notebook.tab_size", 18.0))
	var label := tab.to_upper()
	var extra := visuals.number("notebook.tab_tracking_em", 0.1) * float(size)
	var run := _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ extra * float(label.length())
	var count := " %d" % tab_count(tab)
	return run + _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(visuals.number("notebook.tab_count_size", 13.0))).x + 8.0


func _header_height() -> float:
	var padding: Array = visuals.get_value("notebook.header_padding", [20, 20, 0, 32])
	return float(padding[0]) + visuals.number("notebook.close_size", 44.0)


func body_rect() -> Rect2:
	var padding: Array = visuals.get_value("notebook.body_padding", [0, 48, 0, 32])
	var panel := panel_rect()
	var top := tab_rect(TAB_ROOM).end.y + float(padding[0]) + 12.0
	return Rect2(Vector2(panel.position.x + float(padding[3]), top),
		Vector2(panel.size.x - float(padding[1]) - float(padding[3]), panel.end.y - top - 24.0))


# --- what is on the page -----------------------------------------------------

func tab_count(tab: String) -> int:
	match tab:
		TAB_ATTACKER:
			return (_entry.get("attacker_notes", []) as Array).size()
		TAB_DEATHS:
			return (_entry.get("notebook", []) as Array).size()
		_:
			return entries_for(TAB_ROOM).size()


func tab_colour(tab: String) -> Color:
	if tab == _active:
		return visuals.colour("notebook.tab_selected_color")
	return visuals.colour_with_alpha("hud.timer_color", "notebook.tab_unselected_alpha")


## Objects you have looked at, with the tag hints Inspect revealed. Grabbing
## something is not looking at it.
func entries_for(tab: String) -> Array:
	if tab != TAB_ROOM or _world == null:
		return []
	var out: Array = []
	var separator := str(visuals.get_value("notebook.entry_tags_separator", " · "))
	for done in _entry.get("interactions_done", []):
		var parts := str(done).split("|")
		if parts.size() != 2 or parts[0] != "inspect":
			continue
		var obj := _world.objects.by_id(parts[1])
		if obj == null:
			continue
		out.append({
			"name": obj.name,
			"line": obj.inspect,
			"tags": separator.join(Array(obj.tags)).to_upper(),
		})
	return out


func entries() -> Array:
	return entries_for(_active)


## The attacker and death pages are one line each, already written.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	match _active:
		TAB_ATTACKER:
			for note in _entry.get("attacker_notes", []):
				out.append(str(note))
		TAB_DEATHS:
			var index := 1
			for record in _entry.get("notebook", []):
				out.append("Death %d.  %s" % [index, str((record as Dictionary).get("line", ""))])
				index += 1
	return out


func empty_line() -> String:
	if not entries().is_empty() or not lines().is_empty():
		return ""
	match _active:
		TAB_ATTACKER:
			return "Nothing observed yet."
		TAB_DEATHS:
			return "No deaths yet. Give it time."
		_:
			return "Nothing inspected yet."


# --- scrolling ---------------------------------------------------------------

func content_height() -> float:
	var total := 0.0
	var padding := visuals.number("notebook.entry_padding_y", 18.0)
	var width := body_rect().size.x
	for entry in entries():
		total += _entry_height(entry as Dictionary, width) + padding
	var line_size := int(visuals.number("notebook.attacker_size", 20.0))
	var line_height := float(line_size) * visuals.number("notebook.entry_line_height", 1.4)
	for line in lines():
		total += _wrapped(str(line), width - visuals.number("notebook.death_number_col", 110.0),
			line_size).size() * line_height + padding
	return total


func _entry_height(entry: Dictionary, width: float) -> float:
	var gap := visuals.number("notebook.entry_gap", 4.0)
	var name_size := visuals.number("notebook.entry_name_size", 22.0)
	var line_size := visuals.number("notebook.entry_line_size", 20.0)
	var tags_size := visuals.number("notebook.entry_tags_size", 14.0)
	var wrapped := _wrapped(str(entry["line"]), width, int(line_size)).size()
	return name_size * 1.3 + gap + line_size * visuals.number("notebook.entry_line_height", 1.4) \
		* float(wrapped) + gap + tags_size * 1.4


func scroll_offset() -> float:
	return _scroll


func scroll_by(amount: float) -> void:
	_scroll = clampf(_scroll + amount, 0.0, maxf(content_height() - body_rect().size.y, 0.0))
	queue_redraw()


## What is left below the fold, in entries. Zero when the list fits or you have
## reached the end, which is when the fade and its label disappear.
func more_below() -> int:
	var body := body_rect()
	var hidden := content_height() - _scroll - body.size.y
	if hidden <= 1.0:
		return 0
	var counted := 0
	var y := 0.0
	var padding := visuals.number("notebook.entry_padding_y", 18.0)
	for entry in entries():
		y += _entry_height(entry as Dictionary, body.size.x) + padding
		if y > _scroll + body.size.y:
			counted += 1
	var line_size := int(visuals.number("notebook.attacker_size", 20.0))
	var line_height := float(line_size) * visuals.number("notebook.entry_line_height", 1.4)
	for line in lines():
		y += _wrapped(str(line), body.size.x - visuals.number("notebook.death_number_col", 110.0),
			line_size).size() * line_height + padding
		if y > _scroll + body.size.y:
			counted += 1
	return counted


# --- input -------------------------------------------------------------------

func press_at(point: Vector2) -> bool:
	if not visible:
		return false
	if close_rect().has_point(point):
		hide_book()
		return true
	for tab in TABS:
		if tab_rect(str(tab)).has_point(point):
			if _active != str(tab):
				_active = str(tab)
				_scroll = 0.0
			queue_redraw()
			return true
	if panel_rect().has_point(point):
		return true
	hide_book()
	return true


func hover_at(point: Vector2) -> void:
	var was := _hover_close
	_hover_close = close_rect().has_point(point)
	if was != _hover_close:
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
	if not click.pressed:
		return
	accept_event()
	match click.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(visuals.number("notebook.entry_padding_y", 18.0) * 3.0)
		MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-visuals.number("notebook.entry_padding_y", 18.0) * 3.0)
		_:
			press_at(click.position)


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if not visible or visuals == null or _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, frame()),
		visuals.colour_with_alpha("notebook.room_dim_color", "notebook.room_dim_alpha"), true)
	var panel := panel_rect()
	draw_style_box(_panel_style(), panel)
	_draw_header(panel)
	_draw_tabs(panel)
	_draw_body()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = visuals.colour_with_alpha("notebook.panel_fill", "notebook.panel_fill_alpha")
	style.border_color = visuals.colour_with_alpha("notebook.panel_border", "notebook.panel_border_alpha")
	style.set_border_width_all(int(visuals.number("notebook.panel_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("notebook.panel_radius", 4)))
	return style


func _draw_header(panel: Rect2) -> void:
	var padding: Array = visuals.get_value("notebook.header_padding", [20, 20, 0, 32])
	var size := int(visuals.number("notebook.header_size", 13.0))
	var deaths := (_entry.get("notebook", []) as Array).size()
	var title := "%s · DEATH %d" % [str(_world.room.get("title", "")).to_upper() if _world != null else "",
		deaths]
	_tracked(_font, title, panel.position + Vector2(float(padding[3]), float(padding[0]) + float(size)),
		size, visuals.number("notebook.header_tracking_em", 0.2),
		visuals.colour_with_alpha("hud.timer_color", "notebook.header_alpha"))

	var close := close_rect()
	if _hover_close:
		var style := StyleBoxFlat.new()
		style.bg_color = visuals.colour_with_alpha("notebook.close_hover_fill", "notebook.close_hover_fill_alpha")
		style.set_corner_radius_all(int(visuals.number("notebook.panel_radius", 4)))
		draw_style_box(style, close)
	if _close_icon != null:
		var glyph := visuals.number("notebook.close_glyph_size", 18.0)
		draw_texture_rect(_close_icon,
			Rect2(close.get_center() - Vector2(glyph, glyph) * 0.5, Vector2(glyph, glyph)), false,
			visuals.colour_with_alpha("hud.timer_color", "notebook.close_alpha"))


func _draw_tabs(panel: Rect2) -> void:
	var size := int(visuals.number("notebook.tab_size", 18.0))
	var count_size := int(visuals.number("notebook.tab_count_size", 13.0))
	var padding: Array = visuals.get_value("notebook.tab_padding", [14, 2, 12])
	for tab in TABS:
		var name := str(tab)
		var box := tab_rect(name)
		var colour := tab_colour(name)
		var baseline := box.position.y + float(padding[0]) + float(size) * 0.85
		var width := _tracked(_font_bold, name.to_upper(), Vector2(box.position.x, baseline), size,
			visuals.number("notebook.tab_tracking_em", 0.1), colour)
		draw_string(_font, Vector2(box.position.x + width + 8.0, baseline), "%d" % tab_count(name),
			HORIZONTAL_ALIGNMENT_LEFT, -1, count_size,
			Color(colour.r, colour.g, colour.b, visuals.number("notebook.tab_count_alpha", 0.6)))
		if name != _active:
			continue
		var line := visuals.number("notebook.tab_selected_line_width", 3.0)
		draw_rect(Rect2(Vector2(box.position.x, box.end.y - line), Vector2(box.size.x, line)),
			visuals.colour("notebook.tab_selected_line"), true)
	var rule := tab_rect(TAB_ROOM).end.y
	draw_rect(Rect2(Vector2(panel.position.x, rule), Vector2(panel.size.x, 1.0)),
		visuals.colour_with_alpha("hud.timer_color", "notebook.tab_row_rule_alpha"), true)


func _draw_body() -> void:
	var body := body_rect()
	var blank := empty_line()
	if not blank.is_empty():
		draw_string(_font, body.position + Vector2(0.0, visuals.number("notebook.empty_padding_y", 56.0)),
			blank, HORIZONTAL_ALIGNMENT_LEFT, -1, int(visuals.number("notebook.empty_size", 20.0)),
			visuals.colour_with_alpha("hud.timer_color", "notebook.empty_alpha"))
		return
	var y := body.position.y - _scroll
	var padding := visuals.number("notebook.entry_padding_y", 18.0)
	for entry in entries():
		y = _draw_entry(entry as Dictionary, body, y) + padding
	for line in lines():
		y = _draw_line(str(line), body, y) + padding
	_draw_scroll_furniture(body)


func _draw_entry(entry: Dictionary, body: Rect2, top: float) -> float:
	var gap := visuals.number("notebook.entry_gap", 4.0)
	var name_size := int(visuals.number("notebook.entry_name_size", 22.0))
	var line_size := int(visuals.number("notebook.entry_line_size", 20.0))
	var tags_size := int(visuals.number("notebook.entry_tags_size", 14.0))
	var y := top + float(name_size)
	if _visible_in(body, y):
		draw_string(_font_bold, Vector2(body.position.x, y), str(entry["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, visuals.colour("hud.timer_color"))
	y += float(name_size) * 0.3 + gap
	var line_height := float(line_size) * visuals.number("notebook.entry_line_height", 1.4)
	for line in _wrapped(str(entry["line"]), body.size.x, line_size):
		y += line_height
		if _visible_in(body, y):
			draw_string(_font, Vector2(body.position.x, y), str(line), HORIZONTAL_ALIGNMENT_LEFT,
				-1, line_size, visuals.colour_with_alpha("hud.timer_color", "notebook.entry_line_alpha"))
	y += gap + float(tags_size)
	if _visible_in(body, y):
		# No italic in the family, so the tag hints are tracked capitals instead.
		_tracked(_font, str(entry["tags"]), Vector2(body.position.x, y), tags_size,
			visuals.number("notebook.entry_tags_tracking_em", 0.12),
			visuals.colour_with_alpha("hud.timer_color", "notebook.entry_tags_alpha"))
	y += float(tags_size) * 0.4
	if _visible_in(body, y):
		draw_rect(Rect2(Vector2(body.position.x, y + 8.0), Vector2(body.size.x, 1.0)),
			visuals.colour_with_alpha("hud.timer_color", "notebook.entry_rule_alpha"), true)
	return y


func _draw_line(text: String, body: Rect2, top: float) -> float:
	var size := int(visuals.number("notebook.attacker_size", 20.0))
	var line_height := float(size) * visuals.number("notebook.entry_line_height", 1.4)
	var column := visuals.number("notebook.death_number_col", 110.0) if _active == TAB_DEATHS else 0.0
	var head := ""
	var body_text := text
	if _active == TAB_DEATHS:
		var split := text.split("  ", true, 1)
		head = str(split[0])
		body_text = str(split[1]) if split.size() > 1 else ""
	var y := top
	var first := true
	for line in _wrapped(body_text, body.size.x - column, size):
		y += line_height
		if not _visible_in(body, y):
			first = false
			continue
		if first and _active == TAB_DEATHS:
			draw_string(_font_bold, Vector2(body.position.x, y), head, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size, visuals.colour("hud.timer_color"))
		elif first and _active == TAB_ATTACKER:
			var bullet := visuals.number("notebook.attacker_bullet_size", 8.0)
			draw_rect(Rect2(Vector2(body.position.x, y - bullet), Vector2(bullet, bullet)),
				visuals.colour_with_alpha("hud.timer_color", "notebook.attacker_bullet_alpha"), true)
		draw_string(_font, Vector2(body.position.x + maxf(column, 20.0), y), str(line),
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, visuals.colour("hud.timer_color"))
		first = false
	return y


## The fade, the count and the bar: all three go away when the list fits or the
## reader has reached the end.
func _draw_scroll_furniture(body: Rect2) -> void:
	var left := more_below()
	var content := content_height()
	if content <= body.size.y:
		return
	var track := visuals.number("notebook.scrollbar_width", 4.0)
	var x := body.end.x + visuals.number("notebook.scrollbar_inset", 16.0) - track
	draw_rect(Rect2(Vector2(x, body.position.y), Vector2(track, body.size.y)),
		visuals.colour_with_alpha("hud.timer_color", "notebook.scrollbar_track_alpha"), true)
	var thumb := maxf(body.size.y * body.size.y / content, visuals.number("notebook.scrollbar_min_thumb", 40.0))
	var travel := body.size.y - thumb
	var at := body.position.y + travel * clampf(_scroll / maxf(content - body.size.y, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(x, at), Vector2(track, thumb)),
		visuals.colour_with_alpha("hud.timer_color", "notebook.scrollbar_thumb_alpha"), true)
	if left <= 0:
		return
	var fade := visuals.number("notebook.scroll_fade_height", 96.0)
	var top := body.end.y - fade
	var colour := visuals.colour("notebook.panel_fill")
	for step in 12:
		var t := float(step) / 11.0
		draw_rect(Rect2(Vector2(body.position.x, top + fade * t), Vector2(body.size.x, fade / 11.0 + 1.0)),
			Color(colour.r, colour.g, colour.b, t * visuals.number("notebook.scroll_fade_to_alpha", 0.96)), true)
	var size := int(visuals.number("notebook.scroll_more_size", 13.0))
	_tracked(_font, "%d MORE BELOW" % left,
		Vector2(body.get_center().x - 60.0, body.end.y - float(size)), size,
		visuals.number("notebook.scroll_more_tracking_em", 0.16),
		visuals.colour_with_alpha("hud.timer_color", "notebook.scroll_more_alpha"))


func _visible_in(body: Rect2, y: float) -> bool:
	return y >= body.position.y - 40.0 and y <= body.end.y + 40.0


## Wrapped by hand: everything here is measured before it is drawn so the panel
## can be laid out without a layout pass.
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


## Letter spacing, which draw_string does not do. Returns the width drawn.
func _tracked(font: Font, text: String, at: Vector2, size: int, tracking_em: float,
		colour: Color) -> float:
	if font == null or text.is_empty():
		return 0.0
	var extra := tracking_em * float(size)
	var x := at.x
	for i in text.length():
		draw_string(font, Vector2(x, at.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + extra
	return x - at.x - extra


func _load_font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null
