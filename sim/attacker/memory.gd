class_name SimAttackerMemory
extends RefCounted

## none / notice / full. Everything here reads tags and prior-loop records —
## no room and no object is named.

const MODE_NONE := "none"
const MODE_NOTICE := "notice"
const MODE_FULL := "full"

var mode: String = MODE_NONE
var loops: Array = []              # newest last: {player_pos_at_arrival, hidden_in, trap_cells, death_cause}
var search_order: PackedStringArray = []
var avoid_cells: Dictionary = {}   # cell -> extra path cost


func configure(profile: SimAttackerProfile, prior_loops: Array = []) -> void:
	mode = profile.memory
	search_order = profile.search_order.duplicate()
	loops = prior_loops.duplicate()


## Called once when he comes through the door.
func on_arrival(world: SimWorld, att: SimActor) -> void:
	avoid_cells.clear()
	match mode:
		MODE_NOTICE:
			_notice(world)
		MODE_FULL:
			_full(world, att)


## Hiding spots ranked for this loop: categories first, then declaration order.
func ranked_spots(world: SimWorld, searched: Dictionary) -> Array[SimObject]:
	var spots: Array[SimObject] = []
	for category in search_order:
		for obj in world.objects.with_tag("hides-player"):
			if searched.has(obj.id) or spots.has(obj):
				continue
			if str(obj.prop("category", "")) == category:
				spots.append(obj)
	for obj in world.objects.with_tag("hides-player"):
		if not searched.has(obj.id) and not spots.has(obj):
			spots.append(obj)
	return spots


func extra_path_cost(cell: Vector2i) -> float:
	return float(avoid_cells.get(cell, 0.0))


## `notice`: something has been moved, so look near it, and stay out from under
## anything that is leaning.
func _notice(world: SimWorld) -> void:
	var bumped := PackedStringArray()
	for obj in world.objects.all():
		if not obj.is_moved():
			continue
		for spot in world.objects.with_tag("hides-player"):
			if bumped.has(spot.id):
				continue
			if _near(world, obj, spot, int(world.system("attacker.notice_radius"))):
				bumped.append(str(spot.prop("category", "")))
		for cell in _tips_onto(obj):
			avoid_cells[cell] = float(world.system("attacker.avoid_cost"))
	for obj in world.objects.all():
		if bool(obj.get_state("leaning", false)) or bool(obj.get_state("tipped", false)):
			for cell in _tips_onto(obj):
				avoid_cells[cell] = float(world.system("attacker.avoid_cost"))
	_promote(bumped)


## `full`: where you were, what you hid in, and what killed him last time.
func _full(world: SimWorld, att: SimActor) -> void:
	var window := loops.slice(maxi(0, loops.size() - int(world.system("attacker.memory_window"))))
	var first := PackedStringArray()
	for record in window:
		var hidden_in := str(record.get("hidden_in", ""))
		if not hidden_in.is_empty():
			var obj := world.objects.by_id(hidden_in)
			if obj != null:
				first.append(str(obj.prop("category", "")))
		for pair in record.get("trap_cells", []):
			avoid_cells[Vector2i(int(pair[0]), int(pair[1]))] = float(world.system("attacker.avoid_cost"))
		var cause := str(record.get("death_cause", ""))
		if cause.is_empty():
			continue
		# He avoids the layer that killed him, whatever that layer was.
		for cell in world.hazards.cells(cause):
			avoid_cells[cell] = float(world.system("attacker.avoid_cost"))
		if cause == "shock":
			for cell in world.hazards.cells("wet"):
				avoid_cells[cell] = float(world.system("attacker.avoid_cost"))
	_promote(first)


func _promote(categories: PackedStringArray) -> void:
	var promoted := PackedStringArray()
	for c in categories:
		if not c.is_empty() and not promoted.has(c):
			promoted.append(c)
	for c in search_order:
		if not promoted.has(c):
			promoted.append(c)
	search_order = promoted


func _near(world: SimWorld, a: SimObject, b: SimObject, radius: int) -> bool:
	for ca in a.cells:
		for cb in b.cells:
			if world.grid.distance(ca, cb) <= radius:
				return true
	return false


func _tips_onto(obj: SimObject) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tips: Variant = obj.prop("tips", null)
	if tips == null:
		return out
	for pair in (tips as Dictionary).get("onto", []):
		out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out


static func record_loop(world: SimWorld) -> Dictionary:
	var trap_cells: Array = []
	for layer in ["slippery", "shock", "burning", "trip"]:
		for c in world.hazards.cells(layer):
			trap_cells.append([c.x, c.y])
	return {
		"player_pos_at_arrival": [world.player_pos_at_arrival.x, world.player_pos_at_arrival.y],
		"hidden_in": world.player_hidden_at_arrival,
		"trap_cells": trap_cells,
		"death_cause": world.attacker.death_cause if world.attacker != null else "",
	}
