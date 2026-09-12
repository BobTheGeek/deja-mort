class_name ActionWheel
extends Control

## Nine fixed slots: eight on a ring plus Inspect in the middle. Slot order comes
## from content/verbs.json, availability from SimVerbs — the same function the
## solver uses — so an unavailable slot is the truth, not a guess.
##
## Opening the wheel pauses the sim. That is the whole time model: thinking is
## free, doing costs seconds, and the cost is printed on the slot rather than
## hidden in a tooltip no phone will ever show.
##
## Drawn rather than assembled: flat fills, uniform borders, dashed borders and
## cost arcs are a handful of draw calls and no textures, which is what
## docs/ui/SPEC.md asks for. Every number comes from `wheel` in visuals.json.

signal chosen(verb: String, target: Variant, rule_id: String)
signal dismissed()

const BRAND := preload("res://game/theme/brand.gd")

## Read by the wheel, so a test can fail the build when the table loses one
## rather than letting a fallback quietly undo half the design.
const REQUIRED_KEYS: PackedStringArray = [
	"radius", "slot_size", "center_size", "slot_icon_size", "slot_icon_size_with_cost",
	"center_icon_size", "slot_angles_deg", "edge_margin", "caption_reserve_below",
	"leader_line_width", "leader_line_color", "leader_line_alpha", "tap_dot_size",
	"tap_dot_color", "backdrop_color", "backdrop_alpha", "backdrop_flat_radius",
	"backdrop_fade_radius", "backdrop_texture", "open_scale_from", "open_alpha_from",
	"open_duration_s", "close_duration_s", "cost_scale_max_s", "cost_arc_width",
	"cost_arc_inset", "cost_number_size", "min_touch_target", "caption_width",
	"caption_padding", "caption_radius", "caption_color", "caption_alpha",
	"caption_gap_above", "caption_name_size", "caption_sub_size", "caption_sub_color",
	"caption_sub_alpha", "caption_verb_size", "caption_verb_color", "caption_verb_alpha",
	"refused_color", "refused_border_width", "refused_hold_s", "refused_shake_px",
	"refused_shake_duration_s", "hover_scale", "pressed_scale", "states", "icon_path",
]

var visuals: GameVisuals = null

var _target: Variant = null
var _world: SimWorld = null
var _slots: Dictionary = {}        # verb -> {slot, label, angle, icon, available, cost, rule_ids}
var _order: PackedStringArray = PackedStringArray()
var _tap := Vector2.ZERO           # where the player actually tapped
var _centre := Vector2.ZERO        # where the wheel ended up, after clamping
var _caption: PackedStringArray = PackedStringArray()
var _stack_line := ""
var _hover := ""
var _pressed := ""
var _refused_verb := ""
var _refused_left := 0.0
var _open_t := 0.0
var _vignette: Texture2D = null
var _font: Font = null
var _font_bold: Font = null


func setup(table: GameVisuals, world: SimWorld) -> void:
	visuals = table
	_world = world
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = _load_font("FONT_UI")
	_font_bold = _load_font("FONT_UI_BOLD")
	_vignette = load(str(visuals.get_value("wheel.backdrop_texture", ""))) as Texture2D

	_slots.clear()
	_order = PackedStringArray()
	var angles: Dictionary = visuals.get_value("wheel.slot_angles_deg", {})
	var icon_path := str(visuals.get_value("wheel.icon_path", ""))
	for entry in world.content.verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var slot := str((entry as Dictionary).get("slot", ""))
		_slots[verb] = {
			"slot": slot,
			"label": str((entry as Dictionary).get("label", verb)),
			"angle": float(angles.get(slot, 0.0)),
			"icon": load(icon_path % verb) as Texture2D,
			"available": false,
			"cost": 0.0,
			"rule_ids": PackedStringArray(),
		}
		_order.append(verb)
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


## The canvas the design was drawn against. The project stretches canvas items to
## it, so every number in the table is literal at any window size.
func frame() -> Vector2:
	var view := get_viewport()
	if view != null:
		return view.get_visible_rect().size
	return Vector2(visuals.number("ui.design_width", 1920.0), visuals.number("ui.design_height", 1080.0))


# --- opening and closing -----------------------------------------------------

func open_at(world: SimWorld, target: Variant, screen_point: Vector2,
		index: int = 1, count: int = 1) -> void:
	_world = world
	_target = target
	_tap = screen_point
	_hover = ""
	_pressed = ""
	_refused_verb = ""
	_refused_left = 0.0
	_open_t = 0.0
	_fit_viewport()
	_centre = _clamped_centre(screen_point)
	_compose_caption(world, target, index, count)
	_refresh(world)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target = null
	_hover = ""
	_refused_verb = ""
	queue_redraw()


func is_open() -> bool:
	return visible


func target() -> Variant:
	return _target


## Drives the open tween and the refusal hold. Real seconds: the sim is stopped
## while the wheel is up, and the wheel still has to move.
func advance(delta: float) -> void:
	if not visible:
		return
	var duration := visuals.number("wheel.open_duration_s", 0.12)
	if _open_t < 1.0:
		_open_t = clampf(_open_t + delta / maxf(duration, 0.001), 0.0, 1.0)
		queue_redraw()
	if _refused_left > 0.0:
		_refused_left -= delta
		if _refused_left <= 0.0:
			_refused_verb = ""
			_compose_caption(_world, _target, 1, 1)
		queue_redraw()


func open_progress() -> float:
	return _open_t


# --- geometry ----------------------------------------------------------------

func verbs() -> PackedStringArray:
	return _order


func centre_point() -> Vector2:
	return _centre


func tap_point() -> Vector2:
	return _tap


## A wheel that walked away from your finger has to say where it went.
func needs_leader() -> bool:
	return _centre.distance_to(_tap) > 1.0


func slot_size(verb: String) -> float:
	return visuals.number("wheel.center_size") if _is_centre(verb) else visuals.number("wheel.slot_size")


func slot_centre(verb: String) -> Vector2:
	if not _slots.has(verb) or _is_centre(verb):
		return _centre
	var angle := deg_to_rad(float(_slots[verb]["angle"]))
	return _centre + Vector2(sin(angle), -cos(angle)) * visuals.number("wheel.radius")


## Everything the open wheel covers, caption included. Used to keep it on screen.
func occupied_rect() -> Rect2 :
	var reach := visuals.number("wheel.radius") + visuals.number("wheel.slot_size") * 0.5
	var box := Rect2(_centre - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	return box.merge(_caption_rect())


func verb_at(point: Vector2) -> String:
	for verb in _order:
		var name := str(verb)
		if point.distance_to(slot_centre(name)) <= slot_size(name) * 0.5:
			return name
	return ""


func hover_at(point: Vector2) -> void:
	var was := _hover
	_hover = verb_at(point)
	if _hover != was:
		_compose_caption(_world, _target, 1, 1)
		queue_redraw()


# --- what each slot says -----------------------------------------------------

## available / unavailable / hover / pressed / refused, exactly the five the
## spec names.
func slot_state(verb: String) -> String:
	if verb == _refused_verb:
		return "refused"
	if not _slots.has(verb) or not bool(_slots[verb]["available"]):
		return "unavailable"
	if verb == _pressed:
		return "pressed"
	if verb == _hover:
		return "hover"
	return "available"


## The resolved look for a slot: colours already through the brand tokens, alphas
## already applied, so nothing downstream re-decides a colour.
func slot_style(verb: String) -> Dictionary:
	var state := slot_state(verb)
	var table: Dictionary = (visuals.get_value("wheel.states", {}) as Dictionary).get(state, {})
	return {
		"state": state,
		"fill": _tinted(table, "fill", "fill_alpha"),
		"border": _tinted(table, "border", "border_alpha"),
		"border_width": float(table.get("border_width", 1.5)),
		"border_style": str(table.get("border_style", "solid")),
		"dash": table.get("dash", [6, 6]),
		"icon": _tinted(table, "icon", "icon_alpha"),
		"icon_alpha": float(table.get("icon_alpha", 1.0)),
		"cost": _tinted(table, "cost", "cost_alpha"),
		"shows_cost": table.get("cost", null) != null,
		"scale": float(table.get("scale", 1.0)),
	}


func cost_of(verb: String) -> float:
	return float(_slots[verb]["cost"]) if _slots.has(verb) else 0.0


## Free actions print nothing. A slot that says "0.0s" is noise.
func cost_label(verb: String) -> String:
	if slot_state(verb) == "unavailable" or cost_of(verb) <= 0.0:
		return ""
	return "%.1fs" % cost_of(verb)


func caption_lines() -> PackedStringArray:
	return _caption


func target_label() -> String:
	return " ".join(_caption)


## A refused action that closes the wheel and says nothing reads as a character
## who will not move. It stays open, marks the slot in the accent, and says why.
func report_refused(verb: String) -> void:
	_refused_verb = verb
	_refused_left = visuals.number("wheel.refused_hold_s", 1.6)
	_compose_caption(_world, _target, 1, 1)
	queue_redraw()


# --- input -------------------------------------------------------------------

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
		if not _pressed.is_empty():
			_pressed = ""
			queue_redraw()
		return
	accept_event()
	if click.button_index == MOUSE_BUTTON_RIGHT:
		close()
		dismissed.emit()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var verb := verb_at(click.position)
	if verb.is_empty():
		close()
		dismissed.emit()
		return
	if slot_state(verb) == "unavailable":
		# Not a refusal — there is no rule at all. The caption already explains
		# by naming the verb; saying more would be inventing a reason.
		_hover = verb
		_compose_caption(_world, _target, 1, 1)
		queue_redraw()
		return
	_pressed = verb
	var rule_ids: PackedStringArray = _slots[verb]["rule_ids"]
	chosen.emit(verb, _target, rule_ids[0] if rule_ids.size() == 1 else "")


# --- internals ---------------------------------------------------------------

func _is_centre(verb: String) -> bool:
	return _slots.has(verb) and str(_slots[verb]["slot"]) == "center"


func _tinted(table: Dictionary, key: String, alpha_key: String) -> Variant:
	if table.get(key, null) == null:
		return null
	var base := visuals.to_colour(table[key], Color.MAGENTA)
	return Color(base.r, base.g, base.b, float(table.get(alpha_key, 1.0)))


## The wheel keeps the whole of itself, caption included, inside the frame.
func _clamped_centre(point: Vector2) -> Vector2:
	var margin := visuals.number("wheel.edge_margin", 24.0)
	var reach := visuals.number("wheel.radius") + visuals.number("wheel.slot_size") * 0.5
	var below := reach + visuals.number("wheel.caption_reserve_below", 80.0)
	var box := frame()
	return Vector2(
		clampf(point.x, margin + reach, maxf(box.x - margin - reach, margin + reach)),
		clampf(point.y, margin + reach, maxf(box.y - margin - below, margin + reach)),
	)


## Availability for all nine verbs, available or not. The unavailable slots are
## the tutorial, so they stay on screen.
func _refresh(world: SimWorld) -> void:
	var table := SimVerbs.availability(world, world.player, _target)
	for verb in _order:
		var name := str(verb)
		var entry: Dictionary = table.get(name, {})
		_slots[name]["available"] = bool(entry.get("available", false))
		_slots[name]["cost"] = float(entry.get("duration_s", 0.0))
		_slots[name]["rule_ids"] = entry.get("rule_ids", PackedStringArray())


## Name, then which of the things under the cursor this is, then what the slot
## under the pointer would do.
func _compose_caption(world: SimWorld, target: Variant, index: int, count: int) -> void:
	if world == null:
		return
	if index > 0 and count > 0:
		_stack_line = "%d of %d here — tap again to cycle" % [index, count] if count > 1 else ""
	var lines := PackedStringArray([_describe(world, target)])
	if not _stack_line.is_empty():
		lines.append(_stack_line)
	if not _refused_verb.is_empty():
		lines.append("%s — can't do that from here" % _label_of(_refused_verb))
	elif not _hover.is_empty():
		var cost := cost_label(_hover)
		lines.append("%s · %s" % [_label_of(_hover), cost] if not cost.is_empty() else _label_of(_hover))
	_caption = lines


func _label_of(verb: String) -> String:
	return str(_slots[verb]["label"]) if _slots.has(verb) else verb.capitalize()


func _describe(world: SimWorld, target: Variant) -> String:
	if target is String:
		var obj := world.objects.by_id(str(target))
		if obj != null:
			return obj.name
	elif target is Vector2i:
		return "Floor %s" % [target]
	return str(target)


func _load_font(constant: String) -> Font:
	var script: Script = BRAND
	var path: Variant = script.get_script_constant_map().get(constant, null)
	return load(str(path)) as Font if path != null else null


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if not visible or visuals == null:
		return
	_draw_backdrop()
	if needs_leader():
		var colour := visuals.colour_with_alpha("wheel.leader_line_color", "wheel.leader_line_alpha")
		draw_line(_tap, _centre, colour, visuals.number("wheel.leader_line_width", 2.0))
		draw_circle(_tap, visuals.number("wheel.tap_dot_size", 10.0) * 0.5,
			visuals.colour("wheel.tap_dot_color"))
	for verb in _order:
		_draw_slot(str(verb))
	_draw_caption()


## No full-screen dim: a radial vignette centred on the wheel, so the room the
## player is reasoning about stays lit.
func _draw_backdrop() -> void:
	if _vignette == null:
		return
	var span := visuals.number("wheel.backdrop_fade_radius", 540.0) * 2.0
	var tint := visuals.colour("wheel.backdrop_color")
	tint.a = visuals.number("wheel.backdrop_alpha", 0.6) * _eased()
	draw_texture_rect(_vignette, Rect2(_centre - Vector2(span, span) * 0.5, Vector2(span, span)),
		false, tint)


func _draw_slot(verb: String) -> void:
	var style := slot_style(verb)
	var centre := slot_centre(verb) + _shake(verb)
	var radius := slot_size(verb) * 0.5 * float(style["scale"]) * _grow()
	var fill: Variant = style["fill"]
	if fill != null:
		draw_circle(centre, radius, _faded(fill))
	var border: Variant = style["border"]
	if border != null:
		if str(style["border_style"]) == "dashed":
			_draw_dashed_circle(centre, radius, _faded(border), float(style["border_width"]),
				style["dash"])
		else:
			draw_arc(centre, radius, 0.0, TAU, 64, _faded(border), float(style["border_width"]), true)
	var label := cost_label(verb)
	_draw_icon(verb, centre, radius, style, not label.is_empty())
	if not label.is_empty() and bool(style["shows_cost"]):
		_draw_cost(verb, centre, radius, style, label)


func _draw_icon(verb: String, centre: Vector2, radius: float, style: Dictionary,
		with_cost: bool) -> void:
	var icon: Texture2D = _slots[verb]["icon"]
	if icon == null:
		return
	var key := "wheel.center_icon_size"
	if not _is_centre(verb):
		key = "wheel.slot_icon_size_with_cost" if with_cost else "wheel.slot_icon_size"
	var box := visuals.number(key, 36.0) * (radius / (slot_size(verb) * 0.5))
	var offset := Vector2(0.0, -box * 0.16) if with_cost else Vector2.ZERO
	draw_texture_rect(icon, Rect2(centre + offset - Vector2(box, box) * 0.5, Vector2(box, box)),
		false, _faded(style["icon"]))


## The cost twice over: an arc round the rim you can read without focusing, and
## the number for when you need to know exactly.
func _draw_cost(verb: String, centre: Vector2, radius: float, style: Dictionary,
		label: String) -> void:
	var colour := _faded(style["cost"])
	var span := clampf(cost_of(verb) / maxf(visuals.number("wheel.cost_scale_max_s", 3.0), 0.001), 0.0, 1.0)
	var inset := visuals.number("wheel.cost_arc_inset", 3.0)
	draw_arc(centre, radius - inset, -PI * 0.5, -PI * 0.5 + TAU * span, 48, colour,
		visuals.number("wheel.cost_arc_width", 4.0), true)
	if _font_bold == null:
		return
	var size := int(visuals.number("wheel.cost_number_size", 12.0))
	var width := _font_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font_bold, centre + Vector2(-width * 0.5, radius * 0.52), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _draw_caption() -> void:
	if _caption.is_empty() or _font == null:
		return
	var box := _caption_rect()
	var panel := visuals.colour_with_alpha("wheel.caption_color", "wheel.caption_alpha")
	panel.a *= _eased()
	draw_style_box(_caption_box(panel), box)
	var padding: Array = visuals.get_value("wheel.caption_padding", [12, 18])
	var y := box.position.y + float(padding[0])
	for i in _caption.size():
		var line := str(_caption[i])
		var font := _font_bold if i == 0 else _font
		var size := int(_caption_size(i))
		var colour := _caption_colour(i)
		colour.a *= _eased()
		y += font.get_ascent(size)
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(box.get_center().x - width * 0.5, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		y += font.get_descent(size) + 4.0


func _caption_size(index: int) -> float:
	if index == 0:
		return visuals.number("wheel.caption_name_size", 24.0)
	if index == 1 and not _stack_line.is_empty():
		return visuals.number("wheel.caption_sub_size", 18.0)
	return visuals.number("wheel.caption_verb_size", 20.0)


func _caption_colour(index: int) -> Color:
	if index == 1 and not _stack_line.is_empty():
		return visuals.colour_with_alpha("wheel.caption_sub_color", "wheel.caption_sub_alpha")
	if index > 0 and not _refused_verb.is_empty():
		return visuals.colour("wheel.refused_color")
	if index == 0:
		return visuals.colour("wheel.caption_sub_color")
	return visuals.colour_with_alpha("wheel.caption_verb_color", "wheel.caption_verb_alpha")


func _caption_rect() -> Rect2:
	var padding: Array = visuals.get_value("wheel.caption_padding", [12, 18])
	var width := visuals.number("wheel.caption_width", 380.0)
	var height := float(padding[0]) * 2.0
	for i in maxi(_caption.size(), 1):
		height += _caption_size(i) * 1.35
	var top := _centre.y + visuals.number("wheel.radius") + visuals.number("wheel.slot_size") * 0.5 \
		+ visuals.number("wheel.caption_gap_above", 16.0)
	var left := clampf(_centre.x - width * 0.5, visuals.number("wheel.edge_margin", 24.0),
		maxf(frame().x - width - visuals.number("wheel.edge_margin", 24.0), 0.0))
	return Rect2(Vector2(left, top), Vector2(width, height))


func _caption_box(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	var radius := int(visuals.number("wheel.caption_radius", 4.0))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _draw_dashed_circle(centre: Vector2, radius: float, colour: Color, width: float,
		dash: Variant) -> void:
	var on := float((dash as Array)[0]) if dash is Array else 6.0
	var off := float((dash as Array)[1]) if dash is Array else 6.0
	var step := (on + off) / maxf(radius, 1.0)
	var angle := 0.0
	while angle < TAU:
		draw_arc(centre, radius, angle, angle + on / maxf(radius, 1.0), 6, colour, width, true)
		angle += step


## Scale and alpha on the way in, so the wheel arrives rather than appears.
func _eased() -> float:
	var from := visuals.number("wheel.open_alpha_from", 0.0)
	return from + (1.0 - from) * _open_t


func _grow() -> float:
	var from := visuals.number("wheel.open_scale_from", 0.9)
	var t := 1.0 - pow(1.0 - _open_t, 3.0)
	return from + (1.0 - from) * t


func _faded(colour: Variant) -> Color:
	var out: Color = colour if colour is Color else Color.MAGENTA
	out.a *= _eased()
	return out


## A refused slot shakes once, briefly. Nothing else on screen moves.
func _shake(verb: String) -> Vector2:
	if verb != _refused_verb:
		return Vector2.ZERO
	var duration := visuals.number("wheel.refused_shake_duration_s", 0.18)
	var elapsed := visuals.number("wheel.refused_hold_s", 1.6) - _refused_left
	if elapsed > duration:
		return Vector2.ZERO
	var amount := visuals.number("wheel.refused_shake_px", 4.0)
	return Vector2(sin(elapsed / maxf(duration, 0.001) * TAU * 3.0) * amount, 0.0)
