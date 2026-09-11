class_name SimGrid
extends RefCounted

## Pure geometry. Knows cells and zones; knows nothing about objects.
## Object-dependent questions arrive as Callables so pathing stays testable
## without a world.

enum { FLOOR, WALL, VOID }

const NEIGHBOURS_4: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const NEIGHBOURS_8: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var width: int = 0
var height: int = 0

var _cells: Array[int] = []
var _zones: Dictionary = {}   # name -> Rect2i


static func from_room(grid_block: Dictionary, zones_block: Dictionary) -> SimGrid:
	var g := SimGrid.new()
	g.width = int(grid_block.get("width", 0))
	g.height = int(grid_block.get("height", 0))
	g._cells.resize(g.width * g.height)
	g._cells.fill(VOID)
	var rows: Variant = grid_block.get("cells", [])
	for y in range(min(g.height, (rows as Array).size())):
		var row: String = str(rows[y])
		for x in range(min(g.width, row.length())):
			g._cells[y * g.width + x] = g._char_to_cell(row[x])
	for name in zones_block:
		var pair: Array = zones_block[name]
		var a := Vector2i(int(pair[0][0]), int(pair[0][1]))
		var b := Vector2i(int(pair[1][0]), int(pair[1][1]))
		g._zones[str(name)] = Rect2i(a, b - a + Vector2i.ONE)
	return g


func _char_to_cell(c: String) -> int:
	match c:
		"#": return WALL
		".": return FLOOR
		" ": return VOID
		_: return FLOOR


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_type(c: Vector2i) -> int:
	if not in_bounds(c):
		return VOID
	return _cells[c.y * width + c.x]


func is_floor(c: Vector2i) -> bool:
	return cell_type(c) == FLOOR


## Chebyshev. One metric everywhere, so no rule has to choose.
func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func neighbours(c: Vector2i, connectivity: int = 4) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var offsets := NEIGHBOURS_4 if connectivity == 4 else NEIGHBOURS_8
	for o in offsets:
		var n := c + o
		if in_bounds(n):
			out.append(n)
	return out


func is_adjacent(a: Vector2i, b: Vector2i, connectivity: int = 4) -> bool:
	if a == b:
		return true
	var offsets := NEIGHBOURS_4 if connectivity == 4 else NEIGHBOURS_8
	for o in offsets:
		if a + o == b:
			return true
	return false


## Deterministic A*. 4-connected movement, unit step cost plus extra_cost(cell).
## Ties break on f, then g, then NEIGHBOURS_4 declaration order via insertion
## sequence. Returns the path excluding `from` and including `to`; empty on failure.
func path(from: Vector2i, to: Vector2i, blocked: Callable = Callable(), extra_cost: Callable = Callable()) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to:
		return result
	if not in_bounds(from) or not in_bounds(to):
		return result
	if _is_blocked(to, blocked):
		return result

	var came: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var seq: Dictionary = {from: 0}
	var counter: int = 0
	var open: Array[Vector2i] = [from]

	while not open.is_empty():
		var best_i := 0
		var best_f: float = INF
		var best_g: float = INF
		var best_seq: int = 0
		for i in open.size():
			var c: Vector2i = open[i]
			var g: float = g_score[c]
			var f: float = g + float(distance(c, to))
			var s: int = seq[c]
			if f < best_f or (is_equal_approx(f, best_f) and (g < best_g or (is_equal_approx(g, best_g) and s < best_seq))):
				best_i = i
				best_f = f
				best_g = g
				best_seq = s
		var current: Vector2i = open[best_i]
		if current == to:
			var node := to
			while node != from:
				result.insert(0, node)
				node = came[node]
			return result
		open.remove_at(best_i)

		for offset in NEIGHBOURS_4:
			var n: Vector2i = current + offset
			if not in_bounds(n) or _is_blocked(n, blocked):
				continue
			var step: float = 1.0
			if extra_cost.is_valid():
				step += float(extra_cost.call(n))
			var tentative: float = float(g_score[current]) + step
			if not g_score.has(n) or tentative < float(g_score[n]):
				g_score[n] = tentative
				came[n] = current
				counter += 1
				seq[n] = counter
				if not open.has(n):
					open.append(n)
	return result


func _is_blocked(c: Vector2i, blocked: Callable) -> bool:
	if blocked.is_valid():
		return bool(blocked.call(c))
	return cell_type(c) != FLOOR


## Bresenham between cell centres. `blocks_sight(cell)` is asked about every cell
## strictly between the endpoints.
func has_los(from: Vector2i, to: Vector2i, blocks_sight: Callable = Callable()) -> bool:
	for c in line(from, to):
		if c == from or c == to:
			continue
		if blocks_sight.is_valid() and bool(blocks_sight.call(c)):
			return false
		if not blocks_sight.is_valid() and cell_type(c) == WALL:
			return false
	return true


func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx + dy
	var c := from
	while true:
		out.append(c)
		if c == to:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
	return out


func zone_names() -> PackedStringArray:
	var names := PackedStringArray(_zones.keys())
	names.sort()
	return names


func zone_rect(name: String) -> Rect2i:
	return _zones.get(name, Rect2i())


func zone_of(c: Vector2i) -> String:
	for name in zone_names():
		if (_zones[name] as Rect2i).has_point(c):
			return name
	return ""


func zone_cells(name: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _zones.has(name):
		return out
	var r: Rect2i = _zones[name]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func zone_center(name: String) -> Vector2i:
	var r: Rect2i = zone_rect(name)
	return r.position + r.size / 2
