class_name TitleScreen
extends Control

## The opening beat, from BRAND.md: the clock mark ticks once, the wordmark
## appears, the tagline fades in, then the door opens into Room 1.
##
## The delivered lockup is placed, never re-set. The wordmark is Archivo with
## custom-drawn accents, and setting it live would be a different wordmark — so
## the beat draws the mark alone first and then cross-fades into the lockup
## files, which is the same picture arriving in pieces.
##
## The door appears here and nowhere else. It is the first treatment, kept as
## this one beat; it is not the logo.
##
## Every number is `title` in visuals.json. Drawn, like the rest of the UI.

signal start_requested(fresh: bool)

const BRAND := preload("res://game/theme/brand.gd")
const ROOM_DIR := "res://content/rooms"

const REQUIRED_KEYS: PackedStringArray = [
	"bg", "mark_file", "lockup_file", "lockup_tagline_file", "lockup_width", "lockup_height",
	"lockup_left", "lockup_top", "mark_solo_size", "mark_solo_center", "mark_in_lockup_center",
	"mark_in_lockup_diameter", "mark_in_s", "tick_at_s", "tick_scale_min", "tick_duration_s",
	"wordmark_at_s", "mark_travel_s", "wordmark_fade_s", "tagline_at_s", "tagline_fade_s",
	"menu_at_s", "menu_fade_s", "menu_rise_px", "skippable", "menu_gap",
	"menu_item_height", "menu_size", "menu_tracking_em", "menu_color", "menu_alpha",
	"menu_hover_alpha", "menu_focus_color", "menu_focus_marker_size", "menu_focus_marker_gap",
	"menu_sub_size", "menu_sub_tracking_em", "menu_sub_alpha", "menu_labels", "menu_sub",
	"new_confirm_label", "settings_note", "strip_bottom", "strip_gap", "room_slots",
	"room_label", "room_cell_width", "room_cell_height", "room_cell_padding_x",
	"room_cell_radius", "room_cell_border_width", "room_cell_border_alpha",
	"room_cell_locked_border_alpha", "room_cell_locked_alpha", "room_label_size",
	"room_label_tracking_em", "room_star_size", "room_star_gap", "room_star_fill",
	"room_star_unearned_stroke_alpha", "room_endings_label_size", "room_endings_dot_size",
	"room_endings_dot_gap", "room_endings_found_fill", "room_endings_unfound_border_alpha",
	"door_frame_file", "door_leaf_file", "door_edge_file", "door_size", "door_frame_stroke",
	"door_leaf_fill", "door_edge_fill", "exit_menu_fade_s", "door_in_s", "door_open_at_s",
	"door_open_s", "door_leaf_scale_x_to", "door_room_alpha_to", "door_through_at_s",
	"door_through_s", "door_through_scale_to", "door_fade_out_s",
]

const ITEMS: PackedStringArray = ["continue", "new", "settings"]
const ENDINGS: PackedStringArray = [
	SimOutcome.ENDING_EVADE, SimOutcome.ENDING_DISABLE,
	SimOutcome.ENDING_KILL, SimOutcome.ENDING_ESCAPE,
]

var visuals: GameVisuals = null

var _save: SaveData = null
var _t := 0.0
var _exit_t := -1.0
var _hover := ""
var _confirming := false
var _font: Font = null
var _font_bold: Font = null
var _mark: Texture2D = null
var _lockup: Texture2D = null
var _lockup_tagline: Texture2D = null
var _door: Dictionary = {}


func setup(table: GameVisuals, save: SaveData) -> void:
	visuals = table
	_save = save
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = _load_font("FONT_UI")
	_font_bold = _load_font("FONT_UI_BOLD")
	_mark = load(str(visuals.get_value("title.mark_file", ""))) as Texture2D
	_lockup = load(str(visuals.get_value("title.lockup_file", ""))) as Texture2D
	_lockup_tagline = load(str(visuals.get_value("title.lockup_tagline_file", ""))) as Texture2D
	for part in ["frame", "leaf", "edge"]:
		_door[part] = load(str(visuals.get_value("title.door_%s_file" % part, ""))) as Texture2D
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


func advance(delta: float) -> void:
	_t += delta
	if _exit_t >= 0.0:
		_exit_t += delta
	queue_redraw()


func is_idle() -> bool:
	return _t >= _menu_done() and _exit_t < 0.0


## Nobody watches an opening twice.
func skip() -> void:
	if not visuals.flag("title.skippable", true) or _exit_t >= 0.0:
		return
	_t = maxf(_t, _menu_done())
	queue_redraw()


func _menu_done() -> float:
	return visuals.number("title.menu_at_s", 2.3) + visuals.number("title.menu_fade_s", 0.3)


# --- the beat ----------------------------------------------------------------

func mark_visible() -> bool:
	return _t > 0.0 and _exit_t < 0.0


## The hands never move: it is 1:30 and it stays 1:30, so the tick is a scale.
func mark_scale() -> float:
	var at := visuals.number("title.tick_at_s", 0.6)
	var span := maxf(visuals.number("title.tick_duration_s", 0.1), 0.001)
	if _t < at or _t > at + span:
		return 1.0
	var low := visuals.number("title.tick_scale_min", 0.97)
	var phase := (_t - at) / span
	return lerpf(1.0, low, 1.0 - absf(phase * 2.0 - 1.0))


func mark_rect() -> Rect2:
	var solo := visuals.number("title.mark_solo_size", 160.0)
	var centre := _vector("title.mark_solo_center", Vector2(960.0, 540.0))
	var target := lockup_mark_rect()
	var travel := clampf((_t - visuals.number("title.wordmark_at_s", 1.0))
		/ maxf(visuals.number("title.mark_travel_s", 0.4), 0.001), 0.0, 1.0)
	var eased := travel * travel * (3.0 - 2.0 * travel)
	var size := lerpf(solo, target.size.x, eased) * mark_scale()
	var middle := centre.lerp(target.get_center(), eased)
	return Rect2(middle - Vector2(size, size) * 0.5, Vector2(size, size))


func lockup_rect() -> Rect2:
	return Rect2(Vector2(visuals.number("title.lockup_left", 746.0),
		visuals.number("title.lockup_top", 100.0)),
		Vector2(visuals.number("title.lockup_width", 427.0),
			visuals.number("title.lockup_height", 560.0)))


## Where the mark sits inside the delivered lockup, measured from the SVG rather
## than guessed, so the travelling mark lands exactly on it.
func lockup_mark_rect() -> Rect2:
	var box := lockup_rect()
	var centre := _vector("title.mark_in_lockup_center", Vector2(0.227, 0.173))
	var diameter := visuals.number("title.mark_in_lockup_diameter", 0.252) * box.size.x
	return Rect2(box.position + Vector2(centre.x * box.size.x, centre.y * box.size.y)
		- Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))


## The lockup arrives once the mark has landed, not while it is still moving.
## The delivered file contains its own mark, so fading it in under a travelling
## one shows two clocks at once — which is exactly what the first cut did. The
## fade is squeezed into whatever is left before the tagline so the beat keeps
## the order the spec gives it: mark, tick, wordmark, tagline.
func lockup_alpha() -> float:
	return _fade(_lockup_at(), _lockup_span()) * _exit_fade()


func _lockup_at() -> float:
	return visuals.number("title.wordmark_at_s", 1.0) + visuals.number("title.mark_travel_s", 0.4)


func _lockup_span() -> float:
	# Three quarters of the gap, so the wordmark has settled before the tagline
	# starts rather than the two overlapping.
	return clampf(visuals.number("title.wordmark_fade_s", 0.4), 0.05,
		maxf((visuals.number("title.tagline_at_s", 1.6) - _lockup_at()) * 0.75, 0.05))


func tagline_alpha() -> float:
	return _fade(visuals.number("title.tagline_at_s", 1.6),
		visuals.number("title.tagline_fade_s", 0.4)) * _exit_fade()


func menu_alpha() -> float:
	return _fade(visuals.number("title.menu_at_s", 2.3),
		visuals.number("title.menu_fade_s", 0.3)) * _exit_fade()


func _fade(at: float, span: float) -> float:
	return clampf((_t - at) / maxf(span, 0.001), 0.0, 1.0)


func _exit_fade() -> float:
	if _exit_t < 0.0:
		return 1.0
	return clampf(1.0 - _exit_t / maxf(visuals.number("title.exit_menu_fade_s", 0.25), 0.001), 0.0, 1.0)


# --- the menu ----------------------------------------------------------------

func menu_items() -> PackedStringArray:
	return ITEMS


func menu_rect(item: String) -> Rect2:
	var height := visuals.number("title.menu_item_height", 44.0)
	var gap := visuals.number("title.menu_gap", 22.0)
	var index := ITEMS.find(item)
	if index < 0:
		return Rect2()
	var y := _menu_top() + float(index) * (height + gap)
	# The tap target is as wide as the wider of the label and its sub, and at
	# least a square, centred on the same axis as the logo above.
	var width := maxf(_item_width(item), height)
	var centre := _menu_centre_x()
	return Rect2(Vector2(centre - width * 0.5, y), Vector2(width, height))


## The axis the logo and tagline sit on, so the menu lines up under them.
func _menu_centre_x() -> float:
	return lockup_rect().get_center().x


## The menu block sits midway between the bottom of the titles and the top of the
## room strip, so the space above it equals the space below. Both edges are
## measured, not fixed: the tagline reaches the bottom of the lockup box, and the
## strip is placed up from the bottom of the screen.
func _menu_top() -> float:
	var above := lockup_rect().end.y
	var below := _strip_top()
	return above + ((below - above) - _menu_block_height()) * 0.5


func _strip_top() -> float:
	return frame().y - visuals.inset("bottom") \
		- visuals.number("title.strip_bottom", 56.0) - visuals.number("title.room_cell_height", 96.0)


## First row's top to the last row's sub line — the block the player sees.
func _menu_block_height() -> float:
	var height := visuals.number("title.menu_item_height", 44.0)
	var gap := visuals.number("title.menu_gap", 22.0)
	var last_top := float(ITEMS.size() - 1) * (height + gap)
	return last_top + visuals.number("title.menu_size", 24.0) \
		+ visuals.number("title.menu_sub_size", 14.0) * 1.6


## The wider of an item's label and its sub, tracking included.
func _item_width(item: String) -> float:
	var size := int(visuals.number("title.menu_size", 24.0))
	var width := _tracked_width(_font_bold, menu_label(item), size,
		visuals.number("title.menu_tracking_em", 0.2))
	var sub := _sub_for(item)
	if not sub.is_empty():
		var sub_size := int(visuals.number("title.menu_sub_size", 14.0))
		width = maxf(width, _tracked_width(_font, sub, sub_size,
			visuals.number("title.menu_sub_tracking_em", 0.14)))
	return width


## The sub line under an item, or "" — the same for the hit box and the draw.
func _sub_for(item: String) -> String:
	if item == "settings":
		return str(visuals.get_value("title.settings_note", "NOT YET"))
	return menu_sub(item)


func menu_label(item: String) -> String:
	if item == "new" and _confirming:
		return str(visuals.get_value("title.new_confirm_label", "ARE YOU SURE?"))
	var labels: Dictionary = visuals.get_value("title.menu_labels", {})
	return str(labels.get(item, item.to_upper()))


## Continue says where you were. With nothing played there is nothing to say and
## nothing to press.
func menu_sub(item: String) -> String:
	if item != "continue" or not menu_enabled("continue"):
		return ""
	var entry := _entry()
	return str(visuals.get_value("title.menu_sub", "Room %d · Death %d")) % [
		1, maxi(int(entry.get("loops_total", 0)) - 1, 0)]


func menu_enabled(item: String) -> bool:
	match item:
		"continue":
			return _has_progress()
		"new":
			return true
		_:
			return false


## Anything at all worth coming back to. `loops_total` is the count, but a run
## that was abandoned mid-loop still left a notebook behind.
func _has_progress() -> bool:
	var entry := _entry()
	if int(entry.get("loops_total", 0)) > 0:
		return true
	for key in ["notebook", "interactions_done", "deaths", "endings_found"]:
		if not (entry.get(key, []) as Array).is_empty():
			return true
	return false


func _entry() -> Dictionary:
	if _save == null:
		return {}
	var rooms: Dictionary = _save.data.get("rooms", {})
	for id in rooms:
		return rooms[id]
	return {}


# --- the room strip ----------------------------------------------------------

## The rooms that exist, then the slots that do not: the same skeleton, empty.
## The shape of what is coming is the point.
func room_cells() -> Array:
	var slots := int(visuals.number("title.room_slots", 4))
	var rooms := _rooms_on_disk()
	var width := visuals.number("title.room_cell_width", 300.0)
	var height := visuals.number("title.room_cell_height", 96.0)
	var gap := visuals.number("title.strip_gap", 16.0)
	var total := width * float(slots) + gap * float(slots - 1)
	var left := (frame().x - total) * 0.5
	var top := frame().y - visuals.inset("bottom") - visuals.number("title.strip_bottom", 56.0) - height
	var out: Array = []
	for i in slots:
		var unlocked := i < rooms.size()
		var entry: Dictionary = {}
		if unlocked and _save != null:
			entry = (_save.data.get("rooms", {}) as Dictionary).get(str(rooms[i]), {})
		out.append({
			"room_id": str(rooms[i]) if unlocked else "",
			"label": str(visuals.get_value("title.room_label", "ROOM %d")) % (i + 1),
			"unlocked": unlocked,
			"stars": int(entry.get("stars", 0)),
			"endings_found": entry.get("endings_found", []),
			"rect": Rect2(Vector2(left + float(i) * (width + gap), top), Vector2(width, height)),
		})
	return out


func _rooms_on_disk() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(ROOM_DIR)
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()
	for name in names:
		if str(name).ends_with(".json"):
			out.append(str(name).trim_suffix(".json"))
	return out


# --- the way out -------------------------------------------------------------

func begin_exit() -> void:
	if _exit_t < 0.0:
		_exit_t = 0.0


func door_alpha() -> float:
	if _exit_t < 0.0:
		return 0.0
	var fading := clampf((_exit_t - visuals.number("title.door_through_at_s", 1.1))
		/ maxf(visuals.number("title.door_fade_out_s", 0.4), 0.001), 0.0, 1.0)
	return clampf(_exit_t / maxf(visuals.number("title.door_in_s", 0.3), 0.001), 0.0, 1.0) * (1.0 - fading)


## The leaf swings toward its hinge; the room shows through the gap.
func leaf_scale_x() -> float:
	if _exit_t < 0.0:
		return 1.0
	var t := clampf((_exit_t - visuals.number("title.door_open_at_s", 0.5))
		/ maxf(visuals.number("title.door_open_s", 0.5), 0.001), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	return lerpf(1.0, visuals.number("title.door_leaf_scale_x_to", 0.08), eased)


func room_alpha() -> float:
	if _exit_t < 0.0:
		return 0.0
	var opening := clampf((_exit_t - visuals.number("title.door_open_at_s", 0.5))
		/ maxf(visuals.number("title.door_open_s", 0.5), 0.001), 0.0, 1.0)
	var through := clampf((_exit_t - visuals.number("title.door_through_at_s", 1.1))
		/ maxf(visuals.number("title.door_through_s", 0.6), 0.001), 0.0, 1.0)
	return maxf(opening * visuals.number("title.door_room_alpha_to", 0.6), through)


## The frame rushes past the camera, which is the cut into the room.
func frame_scale() -> float:
	if _exit_t < 0.0:
		return 1.0
	var t := clampf((_exit_t - visuals.number("title.door_through_at_s", 1.1))
		/ maxf(visuals.number("title.door_through_s", 0.6), 0.001), 0.0, 1.0)
	return lerpf(1.0, visuals.number("title.door_through_scale_to", 8.0), t * t)


## The room is built when the door starts to open, not before: a room running
## behind a menu is a room whose timer is already going.
func room_wanted() -> bool:
	return _exit_t >= visuals.number("title.door_open_at_s", 0.5)


func exit_finished() -> bool:
	return _exit_t >= visuals.number("title.door_through_at_s", 1.1) \
		+ visuals.number("title.door_through_s", 0.6)


# --- input -------------------------------------------------------------------

func press_at(point: Vector2) -> bool:
	if _exit_t >= 0.0:
		return true
	if not is_idle():
		skip()
		return true
	for item in ITEMS:
		if not menu_rect(str(item)).has_point(point):
			continue
		_choose(str(item))
		return true
	return false


func _choose(item: String) -> void:
	if not menu_enabled(item):
		return
	match item:
		"continue":
			start_requested.emit(false)
		"new":
			# Wiping a notebook is the one destructive thing on this screen.
			if not _confirming and _has_progress():
				_confirming = true
				queue_redraw()
				return
			start_requested.emit(true)


func hover_at(point: Vector2) -> void:
	var was := _hover
	_hover = ""
	for item in ITEMS:
		if menu_rect(str(item)).has_point(point):
			_hover = str(item)
	if was != _hover:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_at((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		press_at((event as InputEventMouseButton).position)
		return
	if event.is_pressed() and not is_idle():
		accept_event()
		skip()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if visuals == null or _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, frame()), visuals.colour("title.bg"), true)
	_draw_lockup()
	if mark_visible():
		_draw_mark()
	_draw_menu()
	_draw_strip()
	if _exit_t >= 0.0:
		_draw_door()


func _draw_mark() -> void:
	if _mark == null:
		return
	# Fades out as the lockup's own mark fades in underneath it.
	var alpha := 1.0 - lockup_alpha()
	if alpha <= 0.0:
		return
	draw_texture_rect(_mark, mark_rect(), false, Color(1.0, 1.0, 1.0, alpha * _exit_fade()))


func _draw_lockup() -> void:
	var box := lockup_rect()
	if _lockup != null and lockup_alpha() > 0.0:
		# Placed, never re-set: the no-tagline file at the same width, so its own
		# mark lands where the travelling one does.
		var height := box.size.x * float(_lockup.get_height()) / float(_lockup.get_width())
		draw_texture_rect(_lockup, Rect2(box.position, Vector2(box.size.x, height)), false,
			Color(1.0, 1.0, 1.0, lockup_alpha()))
	if _lockup_tagline != null and tagline_alpha() > 0.0:
		draw_texture_rect(_lockup_tagline, box, false, Color(1.0, 1.0, 1.0, tagline_alpha()))


func _draw_menu() -> void:
	var alpha := menu_alpha()
	if alpha <= 0.0:
		return
	var rise := visuals.number("title.menu_rise_px", 8.0) * (1.0 - alpha)
	var size := int(visuals.number("title.menu_size", 24.0))
	for item in ITEMS:
		var name := str(item)
		var box := menu_rect(name).position + Vector2(0.0, rise)
		var enabled := menu_enabled(name)
		var focused := _hover == name and enabled
		var colour := visuals.colour("title.menu_focus_color") if focused \
			else visuals.colour("title.menu_color")
		var row_alpha := visuals.number("title.menu_alpha", 0.7)
		if focused:
			row_alpha = visuals.number("title.menu_hover_alpha", 1.0)
		elif not enabled:
			row_alpha *= 0.5
		var baseline := box.y + float(size)
		var centre := _menu_centre_x()
		var label_font := _font_bold if focused else _font
		var tracking := visuals.number("title.menu_tracking_em", 0.2)
		# The label is centred on the axis. A focus marker hangs to its left
		# without shifting it, so the block stays centred whether or not a row is
		# hovered.
		var label_width := _tracked_width(label_font, menu_label(name), size, tracking)
		var left := centre - label_width * 0.5
		if focused:
			var marker := visuals.number("title.menu_focus_marker_size", 8.0)
			draw_rect(Rect2(Vector2(left - marker - visuals.number(
				"title.menu_focus_marker_gap", 14.0), baseline - marker),
				Vector2(marker, marker)), Color(colour.r, colour.g, colour.b, alpha), true)
		_tracked(label_font, menu_label(name), Vector2(left, baseline), size, tracking,
			Color(colour.r, colour.g, colour.b, row_alpha * alpha))
		var sub := _sub_for(name)
		if sub.is_empty():
			continue
		var sub_size := int(visuals.number("title.menu_sub_size", 14.0))
		var sub_tracking := visuals.number("title.menu_sub_tracking_em", 0.14)
		var sub_left := centre - _tracked_width(_font, sub, sub_size, sub_tracking) * 0.5
		_tracked(_font, sub, Vector2(sub_left, baseline + float(sub_size) * 1.6), sub_size,
			sub_tracking, Color(colour.r, colour.g, colour.b,
				visuals.number("title.menu_sub_alpha", 0.5) * alpha))


func _draw_strip() -> void:
	var alpha := menu_alpha()
	if alpha <= 0.0:
		return
	for raw in room_cells():
		_draw_room_cell(raw as Dictionary, alpha)


func _draw_room_cell(cell: Dictionary, alpha: float) -> void:
	var box: Rect2 = cell["rect"]
	var unlocked := bool(cell["unlocked"])
	var dim := 1.0 if unlocked else visuals.number("title.room_cell_locked_alpha", 0.5)
	var ink := visuals.colour("title.menu_color")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(ink.r, ink.g, ink.b, alpha * dim * visuals.number(
		"title.room_cell_border_alpha" if unlocked else "title.room_cell_locked_border_alpha", 0.35))
	style.set_border_width_all(int(visuals.number("title.room_cell_border_width", 1.5)))
	style.set_corner_radius_all(int(visuals.number("title.room_cell_radius", 4)))
	draw_style_box(style, box)

	var padding := visuals.number("title.room_cell_padding_x", 22.0)
	var label_size := int(visuals.number("title.room_label_size", 14.0))
	var left := box.position.x + padding
	_tracked(_font_bold, str(cell["label"]), Vector2(left, box.position.y + padding + float(label_size)),
		label_size, visuals.number("title.room_label_tracking_em", 0.16),
		Color(ink.r, ink.g, ink.b, alpha * dim))

	var star := visuals.number("title.room_star_size", 14.0)
	var gap := visuals.number("title.room_star_gap", 4.0)
	var star_y := box.position.y + padding + float(label_size) * 1.6
	for i in 3:
		var at := Rect2(Vector2(left + float(i) * (star + gap), star_y), Vector2(star, star))
		var earned := i < int(cell["stars"])
		var colour := visuals.colour("title.room_star_fill")
		if earned:
			draw_colored_polygon(_star_points(at), Color(colour.r, colour.g, colour.b, alpha * dim))
		else:
			var faint := Color(colour.r, colour.g, colour.b,
				alpha * dim * visuals.number("title.room_star_unearned_stroke_alpha", 0.4))
			var points := _star_points(at)
			draw_polyline(points + PackedVector2Array([points[0]]), faint, 1.5, true)

	var dot := visuals.number("title.room_endings_dot_size", 10.0)
	var dot_gap := visuals.number("title.room_endings_dot_gap", 10.0)
	var dot_y := box.end.y - padding - dot * 0.5
	var found: Array = cell["endings_found"]
	var label := int(visuals.number("title.room_endings_label_size", 11.0))
	_tracked(_font, "ENDINGS", Vector2(left, dot_y + float(label) * 0.4), label,
		visuals.number("title.room_label_tracking_em", 0.16),
		Color(ink.r, ink.g, ink.b, alpha * dim * 0.55))
	var dots_left := left + 90.0
	for i in ENDINGS.size():
		var centre := Vector2(dots_left + float(i) * (dot + dot_gap), dot_y)
		if found.has(str(ENDINGS[i])):
			draw_circle(centre, dot * 0.5,
				Color(ink.r, ink.g, ink.b, alpha * dim))
		else:
			draw_arc(centre, dot * 0.5, 0.0, TAU, 24, Color(ink.r, ink.g, ink.b,
				alpha * dim * visuals.number("title.room_endings_unfound_border_alpha", 0.35)),
				1.5, true)


func _star_points(box: Rect2) -> PackedVector2Array:
	var centre := box.get_center()
	var outer := box.size.x * 0.5
	var inner := outer * 0.42
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * (outer if i % 2 == 0 else inner))
	return points


func _draw_door() -> void:
	var alpha := door_alpha()
	if alpha <= 0.0:
		return
	var size := _vector("title.door_size", Vector2(480.0, 630.0))
	var centre := frame() * 0.5
	var box := Rect2(centre - size * 0.5, size)
	var scale := frame_scale()
	if scale > 1.0:
		var origin := centre + Vector2(size.x * 0.25, 0.0)
		box = Rect2(origin + (box.position - origin) * scale, size * scale)
	_draw_door_part("leaf", Rect2(box.position, Vector2(box.size.x * leaf_scale_x(), box.size.y)),
		"title.door_leaf_fill", alpha)
	_draw_door_part("edge", Rect2(
		box.position + Vector2(box.size.x * leaf_scale_x(), 0.0), Vector2(6.0, box.size.y)),
		"title.door_edge_fill", alpha)
	_draw_door_part("frame", box, "title.door_frame_stroke", alpha)


func _draw_door_part(part: String, box: Rect2, colour_key: String, alpha: float) -> void:
	var texture: Texture2D = _door.get(part, null)
	if texture == null:
		return
	var colour := visuals.colour(colour_key)
	draw_texture_rect(texture, box, false, Color(colour.r, colour.g, colour.b, alpha))


func _tracked(font: Font, text: String, at: Vector2, size: int, tracking_em: float,
		colour: Color) -> void:
	if font == null or text.is_empty():
		return
	var extra := tracking_em * float(size)
	var x := at.x
	for i in text.length():
		draw_string(font, Vector2(x, at.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + extra


## The width _tracked draws a line at — every glyph plus a tracking gap, less the
## trailing gap after the last one — so a line can be centred on an axis.
func _tracked_width(font: Font, text: String, size: int, tracking_em: float) -> float:
	if font == null or text.is_empty():
		return 0.0
	var extra := tracking_em * float(size)
	var width := 0.0
	for i in text.length():
		width += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + extra
	return width - extra


func _vector(path: String, fallback: Vector2) -> Vector2:
	var raw: Variant = visuals.get_value(path, null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


func _load_font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null
