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
func choose(world: SimWorld, cell: Vector2i, picked: String) -> Variant:
	var options: Array = []
	var standing_here := world.player.pos == cell
	var holding := not world.player.holding.is_empty()
	var beside: bool = _is_beside(world.player.pos, cell) and bool(world.walkable(cell))
	var within_reach: bool = standing_here or (holding and beside)
	if holding and within_reach:
		options.append(cell)
	for obj in world.objects.at_cell(cell):
		options.append(obj.id)
	if standing_here and not holding:
		options.append(cell)
	if options.is_empty():
		return null
	return _cycle_through(options, cell, picked)


static func _is_beside(from: Vector2i, cell: Vector2i) -> bool:
	return absi(from.x - cell.x) + absi(from.y - cell.y) == 1


func _cycle_through(options: Array, cell: Vector2i, picked: String) -> Variant:
	var key := "%d,%d" % [cell.x, cell.y]
	var index := 0
	var repeat := _last == key
	if not picked.is_empty() and not repeat:
		# First tap on this square with something plainly under the cursor.
		for i in options.size():
			if str(options[i]) == picked:
				index = i
				break
	else:
		index = (int(_cycle.get(key, -1)) + 1) % options.size()
	_cycle[key] = index
	_last = key
	return options[index]


## Which of the things on this square is being offered, and how many there are —
## the wheel's caption says so out loud.
func position_on(world: SimWorld, cell: Vector2i) -> Array:
	var count := world.objects.at_cell(cell).size()
	if world.player.pos == cell:
		count += 1
	return [int(_cycle.get("%d,%d" % [cell.x, cell.y], 0)) + 1, count]
