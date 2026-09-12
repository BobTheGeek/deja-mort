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
var _bulb: OmniLight3D = null
var _environment: WorldEnvironment = null

var _object_nodes: Dictionary = {}   # object id -> Node3D (a model root, or a greybox mesh)
var _model_nodes: Dictionary = {}    # object ids drawn from a .glb rather than a box
var _actor_nodes: Dictionary = {}    # actor id -> Node3D
var _hazard_nodes: Dictionary = {}   # "layer@x,y" -> MeshInstance3D
var _lit_state: bool = true
var _lit_energy: float = 1.0


func build(world: SimWorld, table: GameVisuals) -> void:
	visuals = table
	for child in get_children():
		child.queue_free()
	_object_nodes.clear()
	_model_nodes.clear()
	_actor_nodes.clear()
	_hazard_nodes.clear()

	_floor_root = _add_root("Floor")
	_object_root = _add_root("Objects")
	_hazard_root = _add_root("Hazards")
	_actor_root = _add_root("Actors")

	_build_environment()
	_build_base(world)
	_build_bulb(world)
	_build_grid(world)
	_build_objects(world)
	_build_actors(world)
	_lit_energy = _bulb.light_energy
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
	# The asset packs are cheerful. docs/06 wants desaturated greys and cold blues
	# with one warm accent, so the mood is pulled globally rather than by
	# repainting every model and losing its flat shading.
	env.adjustment_enabled = true
	env.adjustment_saturation = visuals.number("post.saturation", 1.0)
	env.adjustment_contrast = visuals.number("post.contrast", 1.0)
	env.adjustment_brightness = visuals.number("post.brightness", 1.0)
	_environment.environment = env
	add_child(_environment)


## One light. docs/06: "the mood is a lighting rig, not an art skill". Where it
## hangs is the room's business, so it comes from the room's `lighting` block.
func _build_bulb(world: SimWorld) -> void:
	var bulb: Dictionary = (world.room.get("lighting", {}) as Dictionary).get("bulb", {})
	var cell: Array = bulb.get("cell", [world.grid.width / 2, world.grid.height / 2])
	_bulb = OmniLight3D.new()
	_bulb.name = "Bulb"
	_bulb.position = IsoCamera.cell_to_world(
		Vector2i(int(cell[0]), int(cell[1])), float(bulb.get("height", 2.3)))
	_bulb.light_color = visuals.colour("light.color")
	_bulb.light_energy = float(bulb.get("energy", visuals.number("light.energy", 5.0)))
	_bulb.omni_range = float(bulb.get("range", visuals.number("light.range", 16.0)))
	_bulb.omni_attenuation = visuals.number("light.attenuation", 1.4)
	_bulb.shadow_enabled = visuals.flag("light.shadow", true)
	_bulb.shadow_bias = visuals.number("light.shadow_bias", 0.04)
	add_child(_bulb)


## The plinth the specimen case sits on. Without it the room has no edge and
## stops reading as a diorama.
func _build_base(world: SimWorld) -> void:
	var margin := visuals.number("base.margin", 0.9)
	var height := visuals.number("base.height", 0.45)
	var drop := visuals.number("base.drop", 0.1)
	var mesh := MeshInstance3D.new()
	mesh.name = "Base"
	var box := BoxMesh.new()
	box.size = Vector3(
		float(world.grid.width) + margin * 2.0,
		height,
		float(world.grid.height) + margin * 2.0,
	)
	mesh.mesh = box
	mesh.material_override = _material(visuals.colour("base.color"))
	mesh.position = Vector3(
		float(world.grid.width) * 0.5,
		-drop - height * 0.5,
		float(world.grid.height) * 0.5,
	)
	add_child(mesh)


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
		var node := _add_model(obj, look)
		if node == null:
			var height := float(look.get("height", 0.5))
			node = _add_box(
				_object_root, obj.cells[0], _extent(obj), height,
				visuals.to_colour(look.get("color", null)), height * 0.5,
				float(look.get("inset", 0.08)),
			)
		else:
			_model_nodes[obj.id] = true
		node.name = obj.id
		_object_nodes[obj.id] = node


## Instantiates the object's model and normalises it into the footprint the sim
## already knows about. Kenney's kit is not authored at 1 unit = 1 m, so the scale
## is derived from the model's own bounds rather than trusted. Returns null when
## the object names no mesh, and the caller falls back to a greybox box.
func _add_model(obj: SimObject, look: Dictionary) -> Node3D:
	var mesh_name := str(obj.prop("mesh", ""))
	if mesh_name.is_empty():
		return null
	var path := model_path(mesh_name)
	if path.is_empty():
		push_warning("RoomRenderer: %s names a missing model %s" % [obj.id, mesh_name])
		return null

	var root := Node3D.new()
	_object_root.add_child(root)
	var model: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(model)

	var bounds := _local_bounds(model)
	if bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		return root
	var extent := _extent(obj)
	var inset := float(look.get("inset", 0.08))
	var available := Vector2(
		float(extent.x) * CELL - inset * 2.0,
		float(extent.y) * CELL - inset * 2.0,
	)
	# The model is fitted as it will finally sit, not as it was authored. A quarter
	# turn swaps which way its length runs, and without this a two-cell bed turned
	# across its own footprint and shrank to fit the short side.
	var yaw := float(obj.prop("mesh_yaw", 0.0))
	if int(round(absf(yaw) / 90.0)) % 2 == 1:
		available = Vector2(available.y, available.x)
	# Uniform, so nothing is stretched: fit whichever span runs out first.
	var scale_factor := minf(available.x / bounds.size.x, available.y / bounds.size.z)
	model.scale = Vector3.ONE * scale_factor
	model.rotation_degrees = Vector3(0.0, float(obj.prop("mesh_yaw", 0.0)), 0.0)
	# Origin at the footprint centre with the model's own floor at y = 0.
	var centred := -(bounds.position + bounds.size * 0.5) * scale_factor
	model.position = Vector3(centred.x, -bounds.position.y * scale_factor, centred.z) \
		.rotated(Vector3.UP, deg_to_rad(float(obj.prop("mesh_yaw", 0.0))))
	root.position = _footprint_centre(obj, extent)
	return root


func _footprint_centre(obj: SimObject, extent: Vector2i) -> Vector3:
	return Vector3(
		float(obj.cells[0].x) + float(extent.x) * 0.5,
		0.0,
		float(obj.cells[0].y) + float(extent.y) * 0.5,
	)


func _local_bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in _descendants(node):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			var box: AABB = mi.transform * mi.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func _descendants(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_descendants(child))
	return out


func _build_actors(world: SimWorld) -> void:
	for actor in world.actors():
		_actor_nodes[actor.id] = _add_actor(actor)


## A figure if the role names one, a capsule if it does not. Keyed on role, never
## on id, so a new attacker profile needs no code and no new art.
func _add_actor(actor: SimActor) -> Node3D:
	var key := "actor.%s" % actor.role
	var height := visuals.number(key + ".height", 1.7)
	var root := Node3D.new()
	root.name = actor.id
	_actor_root.add_child(root)

	var mesh_name := str(visuals.get_value(key + ".mesh", ""))
	var path := model_path(mesh_name)
	if not path.is_empty():
		var model: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var bounds := _local_bounds(model)
		if bounds.size.y > 0.0:
			# Height only. A rigged figure stands in a T-pose until its idle clip
			# starts, so its bind-pose width is arms-out and means nothing.
			var scale_factor := height / bounds.size.y
			model.scale = Vector3.ONE * scale_factor
			model.position = Vector3(
				-(bounds.position.x + bounds.size.x * 0.5) * scale_factor,
				-bounds.position.y * scale_factor,
				-(bounds.position.z + bounds.size.z * 0.5) * scale_factor,
			)
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = visuals.number(key + ".radius", 0.3)
		capsule.height = height
		var mesh := MeshInstance3D.new()
		mesh.mesh = capsule
		mesh.position = Vector3(0.0, height * 0.5, 0.0)
		mesh.material_override = _material(visuals.colour(key + ".color"))
		root.add_child(mesh)

	root.position = IsoCamera.cell_to_world(actor.pos, 0.0)
	return root


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


## Flat shading, no textures — docs/06. One material per mesh, fully rough so
## nothing reads as plastic under a single bulb.
func _material(colour: Color, emission: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	material.roughness = visuals.number("material.roughness", 1.0)
	material.metallic = visuals.number("material.metallic", 0.0)
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
	if _bulb == null or _environment == null:
		return
	_bulb.light_energy = _lit_energy if lit else visuals.number("dark.light_energy", 0.5)
	_environment.environment.ambient_light_energy = visuals.number("ambient.energy", 0.1) if lit \
		else visuals.number("dark.ambient_energy", 0.035)


func _sync_objects(world: SimWorld) -> void:
	for obj in world.objects.all():
		var node: Node3D = _object_nodes.get(obj.id, null)
		if node == null:
			continue
		if obj.cells.is_empty():
			node.visible = false
			continue
		node.visible = true
		var look := visuals.apply_state(visuals.object_look(obj.tags), obj.state)
		var height := float(look.get("height", 0.5)) * float(look.get("scale_y", 1.0))
		var extent := _extent(obj)
		if _model_nodes.has(obj.id):
			# A model carries its own flat materials. Only state that genuinely
			# changes the look — burning, broken — overrides them.
			node.position = _footprint_centre(obj, extent)
			node.rotation_degrees = Vector3(
				0.0, float(look.get("yaw_deg", 0.0)), float(look.get("roll_deg", 0.0)))
			var emission := float(look.get("emission", 0.0))
			_override_model(node, look, emission)
			_sync_object_light(node, look)
			continue
		node.position = Vector3(
			float(obj.cells[0].x) + float(extent.x) * 0.5,
			height * 0.5,
			float(obj.cells[0].y) + float(extent.y) * 0.5,
		)
		node.rotation_degrees = Vector3(0.0, float(look.get("yaw_deg", 0.0)), float(look.get("roll_deg", 0.0)))
		node.scale = Vector3(1.0, float(look.get("scale_y", 1.0)), 1.0)
		(node as MeshInstance3D).material_override = _material(
			visuals.to_colour(look.get("color", null)),
			float(look.get("emission", 0.0)),
		)
		_sync_object_light(node, look)


## An object whose state says it glows carries its own light, and loses it the
## moment the state ends.
func _sync_object_light(node: Node3D, look: Dictionary) -> void:
	var existing: OmniLight3D = node.get_node_or_null("StateLight") as OmniLight3D
	if not look.has("light"):
		if existing != null:
			existing.free()
		return
	if existing != null:
		return
	var light := _make_light(look["light"])
	light.name = "StateLight"
	node.add_child(light)


## Burning and broken repaint a model; everything else leaves its own materials.
func _override_model(node: Node3D, look: Dictionary, emission: float) -> void:
	var repaint := emission > 0.0
	for child in _descendants(node):
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _material(
				visuals.to_colour(look.get("color", null)), emission) if repaint else null


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
				visuals.to_colour(spec.get("color", null)), height,
			)
			patch.name = "hazard:%s" % key
			patch.material_override = _material(
				visuals.to_colour(spec.get("color", null)),
				float(spec.get("emission", 0.0)),
				float(spec.get("alpha", 0.5)),
			)
			if spec.has("particles"):
				patch.add_child(_make_particles(spec["particles"]))
			if spec.has("light"):
				patch.add_child(_make_light(spec["light"]))
			_hazard_nodes[key] = patch
	for key in _hazard_nodes.keys():
		if live.has(key):
			continue
		# Freed outright rather than queued: queue_free only takes effect at the
		# end of the frame, and a hazard that has gone out must leave the scene
		# the moment the sim says so. free() takes the particles and light with it.
		(_hazard_nodes[key] as Node).free()
		_hazard_nodes.erase(key)


## CPU particles on purpose: the project falls back to GL Compatibility on mobile,
## where GPU particles are not dependable.
func _make_particles(spec: Dictionary) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = int(spec.get("amount", 8))
	particles.lifetime = float(spec.get("lifetime", 1.0))
	particles.direction = Vector3.UP
	particles.spread = float(spec.get("spread", 15.0))
	particles.initial_velocity_min = float(spec.get("velocity", 1.0)) * 0.6
	particles.initial_velocity_max = float(spec.get("velocity", 1.0))
	particles.gravity = Vector3(0.0, float(spec.get("gravity", 0.0)), 0.0)
	particles.scale_amount_min = float(spec.get("scale", 0.1)) * 0.6
	particles.scale_amount_max = float(spec.get("scale", 0.1))
	particles.color = visuals.to_colour(spec.get("color", null))
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(CELL * 0.45, 0.02, CELL * 0.45)
	particles.local_coords = false
	particles.emitting = true
	return particles


## A thing in the room glowing. The room still has exactly one bulb.
func _make_light(spec: Dictionary) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = visuals.to_colour(spec.get("color", null))
	light.light_energy = float(spec.get("energy", 1.0))
	light.omni_range = float(spec.get("range", 4.0))
	light.position = Vector3(0.0, 0.6, 0.0)
	light.shadow_enabled = false
	return light


func _sync_actors(world: SimWorld, delta: float) -> void:
	var rate := visuals.number("loop.walk_lerp_per_s", 12.0)
	var hidden_alpha := visuals.number("actor.hidden_alpha", 0.25)
	var down_statuses: Array = visuals.get_value("actor.down_statuses", [])
	for actor in world.actors():
		var node: Node3D = _actor_nodes.get(actor.id, null)
		if node == null:
			node = _add_actor(actor)
			_actor_nodes[actor.id] = node
		var key := "actor.%s" % actor.role
		node.visible = actor.alive and _actor_is_present(actor)
		# Interpolation between ticks: the sim jumps a whole cell, the figure slides.
		var target := IsoCamera.cell_to_world(actor.pos, 0.0)
		node.position = node.position.lerp(target, clampf(rate * delta, 0.0, 1.0))
		# No rig in the pack, so being knocked down is the figure laid flat. From an
		# isometric camera that is the whole of the read.
		var down := false
		for status in down_statuses:
			if actor.has_status(str(status)):
				down = true
		_drive_animation(node, actor, down)
		_fade_actor(node, key, hidden_alpha if actor.is_hidden() else 1.0)


## Idle, walk, death. The rig has twenty-four clips; these are the three the sim
## can already tell the difference between.
func _drive_animation(node: Node3D, actor: SimActor, down: bool = false) -> void:
	var player := _animation_player(node)
	if player == null:
		return
	var clip := str(visuals.get_value("actor.clips.idle", "Idle"))
	if not actor.alive:
		clip = str(visuals.get_value("actor.clips.death", "Death"))
	elif down:
		clip = str(visuals.get_value("actor.clips.down", "HitRecieve"))
	elif not actor.path.is_empty():
		clip = str(visuals.get_value("actor.clips.walk", "Walk"))
	if not player.has_animation(clip) or player.current_animation == clip:
		return
	player.play(clip, visuals.number("actor.clips.blend_s", 0.15))


func _animation_player(node: Node) -> AnimationPlayer:
	for child in _descendants(node):
		if child is AnimationPlayer:
			return child
	return null


## Figures keep their own materials at full opacity; hiding fades them.
func _fade_actor(node: Node3D, key: String, alpha: float) -> void:
	for child in _descendants(node):
		if not (child is MeshInstance3D):
			continue
		var mesh := child as MeshInstance3D
		if is_equal_approx(alpha, 1.0) and not (mesh.mesh is CapsuleMesh):
			mesh.material_override = null
			continue
		mesh.material_override = _material(visuals.colour(key + ".color"), 0.0, alpha)


## The attacker exists from tick zero but is standing outside. Drawing him in
## the doorway for seventy-five seconds would give the whole thing away.
func _actor_is_present(actor: SimActor) -> bool:
	if actor.role != "attacker":
		return true
	var attacker := actor as SimAttacker
	return attacker != null and attacker.inside and not attacker.left


## Packs ship as .glb or .gltf. Returns the path that exists, or "".
static func model_path(mesh_name: String) -> String:
	if mesh_name.is_empty():
		return ""
	for extension in [".glb", ".gltf"]:
		var path := "res://assets/models/%s%s" % [mesh_name, extension]
		if ResourceLoader.exists(path):
			return path
	return ""


func object_node(id: String) -> Node3D:
	return _object_nodes.get(id, null)


func actor_node(id: String) -> Node3D:
	return _actor_nodes.get(id, null)
