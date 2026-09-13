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


## Returns an object id, or null when there is nothing on the square to act on.
func choose(world: SimWorld, cell: Vector2i, picked: String) -> Variant:
	var here := world.objects.at_cell(cell)
	if here.is_empty():
		return null
	var key := "%d,%d" % [cell.x, cell.y]
	var index := 0
	var repeat := _last == key
	if not picked.is_empty() and not repeat:
		# First tap on this square with something plainly under the cursor.
		for i in here.size():
			if here[i].id == picked:
				index = i
				break
	else:
		index = (int(_cycle.get(key, -1)) + 1) % here.size()
	_cycle[key] = index
	_last = key
	return here[index].id


## Which of the things on this square is being offered, and how many there are —
## the wheel's caption says so out loud.
func position_on(world: SimWorld, cell: Vector2i) -> Array:
	var here := world.objects.at_cell(cell)
	return [int(_cycle.get("%d,%d" % [cell.x, cell.y], 0)) + 1, here.size()]
