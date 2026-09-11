class_name SimHazardField
extends RefCounted

## Per-cell hazard layers and their spread. Layer names and every rate come from
## content/systems.json; nothing here is object-specific.

const LAYERS: PackedStringArray = [
	"wet", "slippery", "burning", "gas", "shock", "trip", "hot", "concealed",
]

const FOREVER := -1

var _layers: Dictionary = {}      # layer -> { Vector2i: until_tick }
var _spreads: Array = []          # active spread jobs
var _zone_gas: Dictionary = {}    # zone name -> accumulated fraction 0..1


func _init() -> void:
	for layer in LAYERS:
		_layers[layer] = {}


func has(layer: String, cell: Vector2i) -> bool:
	return (_layers.get(layer, {}) as Dictionary).has(cell)


func at(cell: Vector2i) -> Dictionary:
	var out := {}
	for layer in LAYERS:
		out[layer] = has(layer, cell)
	return out


## Deterministic order: row-major.
func cells(layer: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in (_layers.get(layer, {}) as Dictionary).keys():
		out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


func count(layer: String) -> int:
	return (_layers.get(layer, {}) as Dictionary).size()


func spawn(layer: String, cell: Vector2i, until_tick: int = FOREVER) -> bool:
	if not _layers.has(layer):
		_layers[layer] = {}
	var existing: Dictionary = _layers[layer]
	if existing.has(cell) and (int(existing[cell]) == FOREVER or int(existing[cell]) >= until_tick):
		return false
	existing[cell] = until_tick
	return true


func clear(layer: String, cell: Vector2i) -> void:
	(_layers.get(layer, {}) as Dictionary).erase(cell)


func clear_layer(layer: String) -> void:
	_layers[layer] = {}


## 4-connected flood fill over one layer, used by `connected_wet` effects.
func connected(layer: String, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not has(layer, start):
		return out
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		out.append(c)
		for offset in SimGrid.NEIGHBOURS_4:
			var n: Vector2i = c + offset
			if not seen.has(n) and has(layer, n):
				seen[n] = true
				queue.append(n)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


## Start a spreading layer from the cells next to a source, bounded to a zone.
func start_spread(layer: String, source_cells: Array[Vector2i], zone_cells: Array[Vector2i], rate_tiles_per_s: float) -> void:
	for job in _spreads:
		if job["layer"] == layer:
			job["active"] = true
			return
	_spreads.append({
		"layer": layer,
		"sources": source_cells.duplicate(),
		"zone": zone_cells.duplicate(),
		"rate": rate_tiles_per_s,
		"progress": 0.0,
		"active": true,
	})


func stop_spread(layer: String) -> void:
	for job in _spreads:
		if job["layer"] == layer:
			job["active"] = false


func spread_active(layer: String) -> bool:
	for job in _spreads:
		if job["layer"] == layer and bool(job["active"]):
			return true
	return false


func add_gas(zone: String, fraction: float) -> void:
	_zone_gas[zone] = minf(1.0, float(_zone_gas.get(zone, 0.0)) + fraction)


func gas_level(zone: String) -> float:
	return float(_zone_gas.get(zone, 0.0))


## One tick. `walkable(cell)` decides which cells a spread may enter.
## Returns the newly created cells as { layer: Array[Vector2i] }.
func step(tick: int, dt: float, walkable: Callable) -> Dictionary:
	var created := {}
	for layer in LAYERS:
		var live: Dictionary = _layers[layer]
		for cell in live.keys():
			var until: int = int(live[cell])
			if until != FOREVER and tick >= until:
				live.erase(cell)

	for job in _spreads:
		if not bool(job["active"]):
			continue
		var layer: String = job["layer"]
		job["progress"] = float(job["progress"]) + float(job["rate"]) * dt
		var want: int = int(floor(float(job["progress"])))
		while count(layer) < want:
			var next_cell: Variant = _next_spread_cell(job, walkable)
			if next_cell == null:
				break
			spawn(layer, next_cell as Vector2i, FOREVER)
			if not created.has(layer):
				created[layer] = [] as Array[Vector2i]
			(created[layer] as Array).append(next_cell)
	return created


## Nearest un-covered cell reachable from the sources, inside the zone.
## Ties break on distance, then row, then column — no RNG involved.
func _next_spread_cell(job: Dictionary, walkable: Callable) -> Variant:
	var layer: String = job["layer"]
	var allowed := {}
	for c in job["zone"]:
		allowed[c] = true
	var seen := {}
	var frontier: Array[Vector2i] = []
	for s in job["sources"]:
		if allowed.has(s) and (not walkable.is_valid() or bool(walkable.call(s))):
			frontier.append(s)
			seen[s] = true
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		var wave: Array[Vector2i] = frontier.duplicate()
		frontier.clear()
		for c in wave:
			if not has(layer, c):
				return c
		for c in wave:
			for offset in SimGrid.NEIGHBOURS_4:
				var n: Vector2i = c + offset
				if seen.has(n) or not allowed.has(n):
					continue
				if walkable.is_valid() and not bool(walkable.call(n)):
					continue
				seen[n] = true
				frontier.append(n)
	return null
