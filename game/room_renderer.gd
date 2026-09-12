class_name RoomRenderer
extends Node3D

## Builds the diorama from the room JSON and keeps it in step with sim state.
## Every look decision comes from content/visuals.json via GameVisuals: there is
## no branch in here on an object id, and there must never be one.

const CELL := 1.0

var visuals: GameVisuals = null

var _floor_root: Node3D = null
var _object_root: Node3D = null
var _hazard_root: Node3D = null
var _actor_root: Node3D = null
var _light: DirectionalLight3D = null
var _environment: WorldEnvironment = null

var _object_nodes: Dictionary = {}   # object id -> MeshInstance3D
var _actor_nodes: Dictionary = {}    # actor id -> Node3D
var _hazard_nodes: Dictionary = {}   # "layer@x,y" -> MeshInstance3D
var _lit_state: bool = true


func build(world: SimWorld, table: GameVisuals) -> void:
	visuals = table
	for child in get_children():
		child.queue_free()
	_object_nodes.clear()
	_actor_nodes.clear()
	_hazard_nodes.clear()

	_floor_root = _add_root("Floor")
	_object_root = _add_root("Objects")
	_hazard_root = _add_root("Hazards")
	_actor_root = _add_root("Actors")

	_build_environment()
	_build_grid(world)
	_build_objects(world)
	_build_actors(world)
	_lit_state = bool(world.room_state.get("lit", true))
	_apply_lighting(_lit_state)


func _add_root(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	add_child(node)
	return node


func _build_environment() -> void:
	_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = visuals.colour("void.color", Color(0.05, 0.05, 0.06))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = visuals.colour("ambient.color", Color(0.4, 0.4, 0.5))
	env.ambient_light_energy = visuals.number("ambient.energy", 0.3)
	_environment.environment = env
	add_child(_environment)

	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(
		visuals.number("light.pitch_deg", -55.0),
		visuals.number("light.yaw_deg", -40.0),
		0.0,
	)
	_light.light_energy = visuals.number("light.energy", 1.15)
	_light.shadow_enabled = visuals.flag("light.shadow", true)
	add_child(_light)


func _build_grid(world: SimWorld) -> void:
	var floor_height := visuals.number("floor.height", 0.08)
	var floor_colour := visuals.colour("floor.color")
	var wall_colour := visuals.colour("wall.color")
	for y in world.grid.height:
		for x in world.grid.width:
			var cell := Vector2i(x, y)
			match world.grid.cell_type(cell):
				SimGrid.FLOOR:
					_add_box(_floor_root, cell, Vector2i.ONE, floor_height, floor_colour, -floor_height * 0.5)
				SimGrid.WALL:
					var height := _wall_height(world, cell)
					_add_box(_floor_root, cell, Vector2i.ONE, height, wall_colour, height * 0.5)


## Only the two outer walls facing away from the camera stand full height. The
## walls between you and the room are cut down so the diorama stays open, which
## is the whole reason a fixed camera is worth having. Which edges are "near"
## comes from the authored camera yaw, so changing the angle re-solves it.
func _wall_height(world: SimWorld, cell: Vector2i) -> float:
	var on_boundary := cell.x == 0 or cell.y == 0 \
		or cell.x == world.grid.width - 1 or cell.y == world.grid.height - 1
	if not on_boundary:
		return visuals.number("wall.near_height", 0.5)
	var yaw := deg_to_rad(visuals.number("camera.yaw_deg", 45.0))
	var near_x: int = world.grid.width - 1 if sin(yaw) > 0.0 else 0
	var near_y: int = world.grid.height - 1 if cos(yaw) > 0.0 else 0
	if cell.x == near_x or cell.y == near_y:
		return visuals.number("wall.near_height", 0.5)
	return visuals.number("wall.height", 2.4)


func _build_objects(world: SimWorld) -> void:
	for obj in world.objects.all():
		if obj.cells.is_empty():
			continue
		var look := visuals.object_look(obj.tags)
		var height := float(look.get("height", 0.5))
		var mesh := _add_box(
			_object_root, obj.cells[0], _extent(obj), height,
			GameVisuals.to_colour(look.get("color", null)), height * 0.5,
			float(look.get("inset", 0.08)),
		)
		mesh.name = obj.id
		_object_nodes[obj.id] = mesh


func _build_actors(world: SimWorld) -> void:
	for actor in world.actors():
		_actor_nodes[actor.id] = _add_actor(actor)


func _add_actor(actor: SimActor) -> Node3D:
	var key := "actor.%s" % actor.role
	var radius := visuals.number(key + ".radius", 0.3)
	var height := visuals.number(key + ".height", 1.7)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh.mesh = capsule
	mesh.material_override = _material(visuals.colour(key + ".color"))
	mesh.position = IsoCamera.cell_to_world(actor.pos, height * 0.5)
	mesh.name = actor.id
	_actor_root.add_child(mesh)
	return mesh


## Footprint extent in cells, so a two-cell object renders as one long box.
func _extent(obj: SimObject) -> Vector2i:
	var lo := obj.cells[0]
	var hi := obj.cells[0]
	for c in obj.cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi - lo + Vector2i.ONE


func _add_box(parent: Node3D, cell: Vector2i, extent: Vector2i, height: float,
		colour: Color, y_offset: float, inset: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(
		float(extent.x) * CELL - inset * 2.0,
		height,
		float(extent.y) * CELL - inset * 2.0,
	)
	mesh.mesh = box
	mesh.material_override = _material(colour)
	mesh.position = Vector3(
		float(cell.x) + float(extent.x) * 0.5,
		y_offset,
		float(cell.y) + float(extent.y) * 0.5,
	)
	parent.add_child(mesh)
	return mesh


func _material(colour: Color, emission: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	return material


# --- per-frame sync ----------------------------------------------------------

func sync(world: SimWorld, delta: float) -> void:
	_sync_lighting(world)
	_sync_objects(world)
	_sync_hazards(world)
	_sync_actors(world, delta)


func _sync_lighting(world: SimWorld) -> void:
	var lit := bool(world.room_state.get("lit", true))
	if lit == _lit_state:
		return
	_lit_state = lit
	_apply_lighting(lit)


func _apply_lighting(lit: bool) -> void:
	if _light == null or _environment == null:
		return
	_light.light_energy = visuals.number("light.energy", 1.15) if lit \
		else visuals.number("dark.light_energy", 0.16)
	_environment.environment.ambient_light_energy = visuals.number("ambient.energy", 0.3) if lit \
		else visuals.number("dark.ambient_energy", 0.06)


func _sync_objects(world: SimWorld) -> void:
	for obj in world.objects.all():
		var node: MeshInstance3D = _object_nodes.get(obj.id, null)
		if node == null:
			continue
		if obj.cells.is_empty():
			node.visible = false
			continue
		node.visible = true
		var look := visuals.apply_state(visuals.object_look(obj.tags), obj.state)
		var height := float(look.get("height", 0.5)) * float(look.get("scale_y", 1.0))
		node.position = Vector3(
			float(obj.cells[0].x) + float(_extent(obj).x) * 0.5,
			height * 0.5,
			float(obj.cells[0].y) + float(_extent(obj).y) * 0.5,
		)
		node.rotation_degrees = Vector3(0.0, float(look.get("yaw_deg", 0.0)), float(look.get("roll_deg", 0.0)))
		node.scale = Vector3(1.0, float(look.get("scale_y", 1.0)), 1.0)
		node.material_override = _material(
			GameVisuals.to_colour(look.get("color", null)),
			float(look.get("emission", 0.0)),
		)


func _sync_hazards(world: SimWorld) -> void:
	var layers: Dictionary = visuals.get_value("hazard.layers", {})
	var height := visuals.number("hazard.height", 0.02)
	var live := {}
	for layer in layers:
		for cell in world.hazards.cells(str(layer)):
			var key := "%s@%d,%d" % [layer, cell.x, cell.y]
			live[key] = true
			if _hazard_nodes.has(key):
				continue
			var spec: Dictionary = layers[layer]
			var patch := _add_box(
				_hazard_root, cell, Vector2i.ONE, height,
				GameVisuals.to_colour(spec.get("color", null)), height,
			)
			patch.material_override = _material(
				GameVisuals.to_colour(spec.get("color", null)),
				float(spec.get("emission", 0.0)),
				float(spec.get("alpha", 0.5)),
			)
			_hazard_nodes[key] = patch
	for key in _hazard_nodes.keys():
		if live.has(key):
			continue
		(_hazard_nodes[key] as Node).queue_free()
		_hazard_nodes.erase(key)


func _sync_actors(world: SimWorld, delta: float) -> void:
	var rate := visuals.number("loop.walk_lerp_per_s", 12.0)
	var hidden_alpha := visuals.number("actor.hidden_alpha", 0.25)
	for actor in world.actors():
		var node: MeshInstance3D = _actor_nodes.get(actor.id, null)
		if node == null:
			node = _add_actor(actor)
			_actor_nodes[actor.id] = node
		var key := "actor.%s" % actor.role
		var height := visuals.number(key + ".height", 1.7)
		node.visible = actor.alive and _actor_is_present(actor)
		# Interpolation between ticks: the sim jumps a whole cell, the mesh slides.
		var target := IsoCamera.cell_to_world(actor.pos, height * 0.5)
		node.position = node.position.lerp(target, clampf(rate * delta, 0.0, 1.0))
		var alpha := hidden_alpha if actor.is_hidden() else 1.0
		node.material_override = _material(visuals.colour(key + ".color"), 0.0, alpha)


## The attacker exists from tick zero but is standing outside. Drawing him in
## the doorway for seventy-five seconds would give the whole thing away.
func _actor_is_present(actor: SimActor) -> bool:
	if actor.role != "attacker":
		return true
	var attacker := actor as SimAttacker
	return attacker != null and attacker.inside and not attacker.left


func object_node(id: String) -> Node3D:
	return _object_nodes.get(id, null)
