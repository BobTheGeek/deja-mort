class_name ClickTarget
extends RefCounted

## Which object a tap means.
##
## A tap now arrives with two facts: the square under the floor plane, and — if
## the ray met something solid — the object that was actually under the cursor.
## The object wins, because it is the thing the player was looking at. Tapping
## the same square again cycles through everything on it, which is how you reach
## the four things stacked behind the toaster.

## Offsets to look at when a tap lands on nothing — a finger is wider than a
## pixel, and Room 1's smallest object is about 26 canvas px across.
static func ring(radius: float, count: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for step in [0.5, 1.0]:
		for i in count:
			var angle := float(i) / float(count) * TAU
			out.append(Vector2(cos(angle), sin(angle)) * radius * step)
	return out


var _cycle: Dictionary = {}   # "x,y" -> which of the objects on that square is next
var _last := ""


func reset() -> void:
	_cycle.clear()
	_last = ""


## An object id, the cell itself, or null when there is nothing here to act on.
##
## The floor is a target when a cell-targeted rule could apply to it: dropping
## what you hold, pouring oil on the boards. Carrying something, that is the
## square you stand on and the four you can reach, because those are the squares
## you could put it on — Bob stood beside the doorway, tapped the floor in front
## of it, and walked there instead, four times over. Empty handed it is your own
## square only, and it comes last, behind whatever is actually on it.
##
## The cost is that carrying something you cannot step one square by tapping it.
## Tapping two squares away still walks.
## Everything on a square, in the order the wheel offers it. The wheel needs the
## whole list so its arrows can walk through it without tapping the room again.
static func options_for(world: SimWorld, cell: Vector2i) -> Array:
	var options: Array = []
	var standing_here := world.player.pos == cell
	var holding := not world.player.holding.is_empty()
	var beside: bool = _is_beside(world.player.pos, cell) and bool(world.walkable(cell))
	# Somewhere to put a thing down or throw it: your own square and the ones
	# beside it, and — while holding — any hazard square, wherever it is. The
	# water you throw the toaster into is across the room, so a ranged throw needs
	# the wet square itself to be clickable; without it you could only aim from
	# inside the water, which electrocutes you too.
	if holding and (standing_here or beside or _has_hazard(world, cell)):
		options.append(cell)
	for id in in_the_room(world, cell):
		options.append(id)
	if standing_here and not holding:
		options.append(cell)
	return options


static func _has_hazard(world: SimWorld, cell: Vector2i) -> bool:
	for present in world.hazards.at(cell).values():
		if bool(present):
			return true
	return false


## The objects on a square that are actually in the room: not inside a shut
## cupboard, not in somebody's hands. Same list the renderer draws.
static func in_the_room(world: SimWorld, cell: Vector2i) -> PackedStringArray:
	var hidden := world.out_of_sight()
	var out := PackedStringArray()
	for obj in world.objects.at_cell(cell):
		if not hidden.has(obj.id):
			out.append(obj.id)
	return out


func choose(world: SimWorld, cell: Vector2i, picked: String) -> Variant:
	var options := options_for(world, cell)
	if options.is_empty():
		return null
	return _cycle_through(options, cell, picked)


static func _is_beside(from: Vector2i, cell: Vector2i) -> bool:
	return absi(from.x - cell.x) + absi(from.y - cell.y) == 1


## What is under the cursor is what you get — every tap, not just the first.
## Tapping the same square used to cycle, which is how you reached what you could
## not see; the wheel's arrows do that now, and cycling had started handing Bob
## the toaster when he clicked the drawer.
##
## A tap the ray missed has nothing to prefer, so it still cycles: that is the
## only way a blind tap reaches more than one of the things on a square.
func _cycle_through(options: Array, cell: Vector2i, picked: String) -> Variant:
	var key := "%d,%d" % [cell.x, cell.y]
	var index := -1
	if not picked.is_empty():
		for i in options.size():
			if str(options[i]) == picked:
				index = i
				break
	if index < 0:
		index = (int(_cycle.get(key, -1)) + 1) % options.size()
	_cycle[key] = index
	_last = key
	return options[index]


## Which of the things on this square is being offered, and how many there are —
## the wheel's caption says so out loud.
func position_on(world: SimWorld, cell: Vector2i) -> Array:
	var count := options_for(world, cell).size()
	return [mini(int(_cycle.get("%d,%d" % [cell.x, cell.y], 0)) + 1, maxi(count, 1)), count]
