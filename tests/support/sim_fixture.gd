class_name SimTestFixture
extends RefCounted

## Shared setup for sim tests. Keeps each rule test to its own three lines.

const ROOM_PATH := "res://content/rooms/%s.json"


static func content() -> SimContent:
	return SimContent.load_from()


static func room_data(room_id: String = "room_01_studio") -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(ROOM_PATH % room_id))
	return json.data


static func world(room_id: String = "room_01_studio", seed_value: int = 1) -> SimWorld:
	return SimWorld.create(room_data(room_id), content(), SimRng.new(seed_value))


## Issue an intent and run the clock until it finishes.
static func act(w: SimWorld, verb: String, target: Variant, rule_id: String = "") -> bool:
	if not w.verb_on(verb, target, rule_id):
		return false
	w.step_until_idle()
	return true


static func goto(w: SimWorld, cell: Vector2i) -> bool:
	if not w.walk_to(cell):
		return false
	w.step_until_idle()
	return w.player.pos == cell


## Put an object straight into the player's hand. Used when the grab path is not
## what the test is about.
static func give(w: SimWorld, object_id: String) -> void:
	w.objects.take_from_container(object_id)
	var obj := w.objects.by_id(object_id)
	obj.on = ""
	w.player.holding = object_id


## A bare actor with no perception and no planner — enough to aim actor-targeted
## rules at. The attacker itself is M2.
static func target_actor(w: SimWorld, cell: Vector2i, id: String = "dummy") -> SimActor:
	var a := SimActor.new()
	a.configure(id, cell, 1.0, 1, w.vulnerable_statuses())
	w.add_actor(a)
	return a


static func fired(w: SimWorld, rule_id: String) -> bool:
	for e in w.events.log_all():
		if e.rule_id == rule_id:
			return true
	return false


static func rule_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for raw in content().rules:
		out.append(str((raw as Dictionary).get("id", "")))
	return out
