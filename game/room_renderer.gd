class_name RoomRenderer
extends Node3D

## Builds the diorama from the room JSON and keeps it in step with sim state.
## Every look decision comes from content/visuals.json via GameVisuals: there is
## no branch in here on an object id, and there must never be one.

const CELL := 1.0

## The child a state marker is drawn as, so it can be found and removed again.
const STATE_MARKER := "StateMarker"

## The ring under whatever the pointer is over.
const HOVER_OUTLINE := "HoverOutline"

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
var _highlight_id: String = ""
var _outline: Node3D = null
var _shut_away: Dictionary = {}  # ids inside a closed container, this frame
var _spread: Array = []          # objects stacked onto furniture this frame
var _once: Dictionary = {}           # actor id -> {clip, left} one-shot animation
var _room: Dictionary = {}           # the room block, for the room's own death beat
var _flicker_left: float = 0.0
var _flicker_t: float = 0.0
var _lit_state: bool = true
var _lit_energy: float = 1.0


func build(world: SimWorld, table: GameVisuals) -> void:
	visuals = table
	_room = world.room
	_once.clear()
	for child in get_children():
		child.queue_free()
	_object_nodes.clear()
	_outline = null
	_highlight_id = ""
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
					# A doorway stands in for the wall it sits in. Drawing both
					# means the wall swallows the door, which is why Room 1 never
					# showed the way he comes in.
					if _has_opening(world, cell):
						continue
					var height := _wall_height(world, cell)
					if height <= 0.0:
						continue
					_add_box(_floor_root, cell, Vector2i.ONE, height,
						_wall_colour(world, cell, wall_colour), height * 0.5)


## The two standing walls take different values. A corner is only legible when
## its two planes are different, which is the first thing the style reference
## does and the first thing a single flat grey loses.
## True when something on this cell is a way through rather than a barrier.
func _has_opening(world: SimWorld, cell: Vector2i) -> bool:
	for obj in world.objects.at_cell(cell):
		if not str(obj.prop("passable_state", "")).is_empty():
			return true
	return false


func _wall_colour(world: SimWorld, cell: Vector2i, fallback: Color) -> Color:
	var yaw := deg_to_rad(visuals.number("camera.yaw_deg", 45.0))
	var far_x: int = 0 if sin(yaw) > 0.0 else world.grid.width - 1
	var far_z: int = 0 if cos(yaw) > 0.0 else world.grid.height - 1
	if cell.x == far_x:
		return visuals.colour("wall.color_far_x", fallback)
	if cell.y == far_z:
		return visuals.colour("wall.color_far_z", fallback)
	return fallback


## Only the two outer walls facing away from the camera stand full height. The
## walls between you and the room are cut down so the diorama stays open, which
## is the whole reason a fixed camera is worth having. Which edges are "near"
## comes from the authored camera yaw, so changing the angle re-solves it.
func _wall_height(world: SimWorld, cell: Vector2i) -> float:
	# An interior wall divides one space from another — Room 1 loses its bathroom
	# without them — so it stands at its own height rather than being cut away.
	var on_boundary := cell.x == 0 or cell.y == 0 \
		or cell.x == world.grid.width - 1 or cell.y == world.grid.height - 1
	if not on_boundary:
		return visuals.number("wall.interior_height", 1.25)
	# The two outer walls between the camera and the room are absent, not short.
	var yaw := deg_to_rad(visuals.number("camera.yaw_deg", 45.0))
	var near_x: int = world.grid.width - 1 if sin(yaw) > 0.0 else 0
	var near_y: int = world.grid.height - 1 if cos(yaw) > 0.0 else 0
	if cell.x == near_x or cell.y == near_y:
		return visuals.number("wall.near_height", 0.0)
	return visuals.number("wall.height", 2.4)


func _build_objects(world: SimWorld) -> void:
	for obj in world.objects.all():
		if obj.cells.is_empty():
			continue
		var look := visuals.object_look(obj.tags)
		var node := _add_model(obj, look)
		if node == null and str(look.get("shape", "")) == "panels":
			node = _add_panels(obj, look)
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


## Hanging cloth: two tall thin panels with a gap between them, rather than a
## box filling the square. Nothing in the furniture kit is a curtain, and a
## brown cube is what the greybox made of one.
##
## Keyed off the `cloth` tag, like every other look — no object is named.
func _add_panels(obj: SimObject, look: Dictionary) -> Node3D:
	var root := Node3D.new()
	_object_root.add_child(root)
	var extent := _extent(obj)
	var height := float(look.get("height", 2.35))
	var depth := float(look.get("panel_depth", 0.1))
	var gap := float(look.get("panel_gap", 0.22))
	var span := float(extent.x) - float(look.get("inset", 0.08)) * 2.0
	var width := maxf((span - gap) * 0.5, 0.05)
	var colour := visuals.to_colour(look.get("color", null))
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, depth)
		panel.mesh = mesh
		panel.position = Vector3(side * (gap + width) * 0.5, height * 0.5,
			-float(extent.y) * 0.5 + depth)
		panel.material_override = _material(colour)
		root.add_child(panel)
	_model_nodes[obj.id] = true
	return root


## Instantiates the object's model at the size the thing really is. A pack is
## authored at one consistent scale — Kenney's furniture kit is 1 unit = 2 m —
## so the conversion is one number per pack in visuals.json.
##
## It used to shrink every model until it fitted inside its cells, which is why
## the bed came out a metre wide next to a 1.7 m figure. The footprint is what
## the sim walks around, not a picture frame: real furniture overhangs.
## Returns null when the object names no mesh, and the caller falls back to a
## greybox box.
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
	var yaw := float(obj.prop("mesh_yaw", 0.0))
	var scale_factor := _pack_scale(mesh_name, bounds, extent, yaw, look)
	model.scale = Vector3.ONE * scale_factor
	model.rotation_degrees = Vector3(0.0, yaw, 0.0)
	# Origin at the footprint centre with the model's own floor at y = 0.
	var centred := -(bounds.position + bounds.size * 0.5) * scale_factor
	model.position = Vector3(centred.x, -bounds.position.y * scale_factor, centred.z) \
		.rotated(Vector3.UP, deg_to_rad(yaw))
	root.position = _footprint_centre(obj, extent)
	return root


## Metres per pack unit, from data. A pack with no declared scale falls back to
## the old behaviour — fitted into its cells — so an undeclared pack looks wrong
## in the one obvious way rather than filling the room.
func _pack_scale(mesh_name: String, bounds: AABB, extent: Vector2i, yaw: float,
		look: Dictionary) -> float:
	var pack := mesh_name.get_slice("/", 0)
	var per_unit := visuals.number("models.%s.metres_per_unit" % pack, 0.0)
	if per_unit > 0.0:
		return per_unit
	push_warning("RoomRenderer: pack '%s' declares no metres_per_unit" % pack)
	var inset := float(look.get("inset", 0.08))
	var available := Vector2(
		float(extent.x) * CELL - inset * 2.0,
		float(extent.y) * CELL - inset * 2.0,
	)
	# A quarter turn swaps which way the model's length runs.
	if int(round(absf(yaw) / 90.0)) % 2 == 1:
		available = Vector2(available.y, available.x)
	return minf(available.x / bounds.size.x, available.y / bounds.size.z)


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

## `tick_alpha` is how far through the current sim tick we are, 0 to 1. The sim
## runs at 10 Hz and the screen at whatever it likes, so without it a figure can
## only ever be in one of ten places a second.
## What the pointer is over. Thirty-nine objects in a twelve-by-ten room, seen
## from across it: the room is not going to get less crowded, so it says which
## one you are about to act on.
##
## An outline, not a frame. The first cut drew a box round the footprint, and a
## box round a counter unit is a box round its neighbours too — Bob: "it is too
## big and thick and still does not accurately tell me what I am going to
## interact with." This traces the object's own silhouette: a copy of its meshes,
## grown a hair along their normals, drawn inside out so only the sliver that
## pokes past the real thing is visible. A hairline, exactly on the shape.
##
## It is the accent, not red. `docs/brand/BRAND.md` forbids red outright, and
## this is the same amber that marks a locked door and a refused action.
func highlight(id: String) -> void:
	if id == _highlight_id:
		return
	_highlight_id = id
	_rebuild_outline()


func highlight_node() -> Node3D:
	return _outline


func highlight_visible() -> bool:
	return _outline != null and _outline.visible


## What the outline covers, on the floor plane — the object's own footprint on
## screen rather than a rectangle drawn around it.
func highlight_rect() -> Rect2:
	if not highlight_visible():
		return Rect2()
	var box := object_bounds(_highlight_id)
	return Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))


## One hairline at the design canvas: the orthographic camera covers `size`
## metres over the canvas height, so a pixel is that many metres.
func outline_thickness() -> float:
	var metres_per_pixel := visuals.number("camera.size", 11.0) \
		/ maxf(visuals.number("ui.design_height", 1080.0), 1.0)
	return metres_per_pixel * visuals.number("object.highlight_pixels", 1.5)


func _outline_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = visuals.colour("object.highlight_color")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = outline_thickness()
	material.disable_receive_shadows = true
	material.no_depth_test = false
	return material


func _rebuild_outline() -> void:
	if _outline != null:
		if _outline.get_parent() != null:
			_outline.get_parent().remove_child(_outline)
		_outline.free()
		_outline = null
	var node: Node3D = _object_nodes.get(_highlight_id, null)
	if _highlight_id.is_empty() or node == null:
		return
	_outline = Node3D.new()
	_outline.name = HOVER_OUTLINE
	var paint := _outline_material()
	for child in _descendants(node):
		if not (child is MeshInstance3D) or (child as MeshInstance3D).mesh == null:
			continue
		var source := child as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.transform = _chain_from(source, node)
		copy.material_override = paint
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_outline.add_child(copy)
	# A sibling of the object, not a child of it: _override_model walks the
	# object's descendants every frame and clears material_override on each, so
	# an outline parented under it lost its paint on the next sync.
	_object_root.add_child(_outline)
	_outline.visible = false


func _sync_highlight(world: SimWorld) -> void:
	if _outline == null:
		return
	var obj := world.objects.by_id(_highlight_id) if not _highlight_id.is_empty() else null
	var node: Node3D = _object_nodes.get(_highlight_id, null)
	_outline.visible = obj != null and not obj.cells.is_empty() and node != null and node.visible
	if _outline.visible:
		# Follows what it outlines: pushed, tipped, opened.
		_outline.transform = node.transform


func sync(world: SimWorld, delta: float, tick_alpha: float = 0.0) -> void:
	_sync_lighting(world)
	_sync_highlight(world)
	_sync_flicker(delta)
	_sync_objects(world)
	_sync_hazards(world)
	_sync_actors(world, delta, tick_alpha)


## docs/06's death beat: "a slump, a fall, the light flickers". Deterministic
## wobble, so a recorded loop looks the same twice.
func flicker(seconds: float) -> void:
	if seconds <= 0.0 or _bulb == null:
		return
	_flicker_left = seconds
	_flicker_t = 0.0


func is_flickering() -> bool:
	return _flicker_left > 0.0


func _sync_flicker(delta: float) -> void:
	if _bulb == null:
		return
	if _flicker_left <= 0.0:
		if not is_zero_approx(_bulb.light_energy - _lit_energy) and _lit_state:
			_bulb.light_energy = _lit_energy
		return
	_flicker_left -= delta
	_flicker_t += delta
	var rate := visuals.number("death.flicker_hz", 11.0)
	var depth := visuals.number("death.flicker_depth", 0.75)
	var wave := absf(sin(_flicker_t * rate)) * absf(cos(_flicker_t * rate * 0.37))
	_bulb.light_energy = _lit_energy * (1.0 - depth + depth * wave)
	if _flicker_left <= 0.0:
		_bulb.light_energy = _lit_energy


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
	_hide_what_is_shut_away(world)
	_place_objects(world)
	_stack_small_objects(world)


## What is inside a shut cupboard is not on screen. It used to be drawn at its
## own square regardless, so a jar inside a closed cabinet was visible, clickable
## and refused — which reads as a broken game rather than a shut cabinet.
##
## Generic: any object that lists `contains` and has an `open` state hides what
## it holds while it is shut. No object is named.
func _hide_what_is_shut_away(world: SimWorld) -> void:
	_shut_away.clear()
	# And what someone is holding. The sim keeps carrying it at their cell —
	# dropping and throwing both need somewhere to start from — but a lamp
	# trailing after you around the room does not look like carrying a lamp.
	# The HUD says what is in your hands instead.
	for actor in world.actors():
		if not actor.holding.is_empty():
			_shut_away[actor.holding] = true
	for obj in world.objects.all():
		if obj.contains.is_empty() or obj.get_state("open", null) == null:
			continue
		if bool(obj.get_state("open", false)):
			continue
		for id in obj.contains:
			var inside := world.objects.by_id(str(id))
			# Once it is out of the cupboard it has its own place in the room.
			if inside != null and inside.on.is_empty():
				_shut_away[str(id)] = true


## A toaster on a counter is on the counter. Everything used to be drawn at
## floor level, so the small objects sat inside the furniture they share a square
## with — invisible, and unclickable, which is most of what Bob could not click.
##
## No object is named: an object is stacked when something taller stands on its
## square, which is what "on the counter" means geometrically.
func _stack_small_objects(world: SimWorld) -> void:
	_spread.clear()
	var bounds: Dictionary = {}
	for obj in world.objects.all():
		if _object_nodes.has(obj.id) and not obj.cells.is_empty() and not _shut_away.has(obj.id):
			bounds[obj.id] = object_bounds(obj.id)
	for obj in world.objects.all():
		if not bounds.has(obj.id):
			continue
		var mine: AABB = bounds[obj.id]
		var support := 0.0
		for other in world.objects.all():
			if other.id == obj.id or not bounds.has(other.id):
				continue
			if not _shares_a_cell(obj, other):
				continue
			var theirs: AABB = bounds[other.id]
			if theirs.size.y <= mine.size.y:
				continue
			support = maxf(support, theirs.end.y)
		if support <= 0.0:
			continue
		var node: Node3D = _object_nodes[obj.id]
		node.position.y += support
		_spread.append({"id": obj.id, "cell": obj.cells[0]})
	_spread_across_cell()


## Four things on one counter square used to be drawn in exactly the same spot,
## so three of them were inside the fourth. They are laid out around the square
## instead — by their order in the room file, so it is the same arrangement every
## loop.
func _spread_across_cell() -> void:
	var by_cell: Dictionary = {}
	for item in _spread:
		var key := "%d,%d" % [(item["cell"] as Vector2i).x, (item["cell"] as Vector2i).y]
		if not by_cell.has(key):
			by_cell[key] = []
		(by_cell[key] as Array).append(str(item["id"]))
	var radius := visuals.number("object.stack_spread", 0.22)
	for key in by_cell:
		var ids: Array = by_cell[key]
		if ids.size() < 2:
			continue
		for i in ids.size():
			var node: Node3D = _object_nodes[ids[i]]
			var angle := float(i) / float(ids.size()) * TAU
			node.position += Vector3(cos(angle), 0.0, sin(angle)) * radius
	_spread.clear()


func _shares_a_cell(a: SimObject, b: SimObject) -> bool:
	for cell in a.cells:
		if b.cells.has(cell):
			return true
	return false


func _place_objects(world: SimWorld) -> void:
	for obj in world.objects.all():
		var node: Node3D = _object_nodes.get(obj.id, null)
		if node == null:
			continue
		if obj.cells.is_empty() or _shut_away.has(obj.id):
			node.visible = false
			continue
		node.visible = true
		var look := visuals.apply_state(visuals.object_look(obj.tags), obj.state)
		var height := float(look.get("height", 0.5)) * float(look.get("scale_y", 1.0))
		var extent := _extent(obj)
		if _model_nodes.has(obj.id):
			# A model carries its own flat materials. Only state that genuinely
			# changes the look — burning, broken — overrides them.
			node.position = _footprint_centre(obj, extent) + _mounting(obj)
			node.rotation_degrees = _object_rotation(obj, look)
			var emission := float(look.get("emission", 0.0))
			_override_model(node, look, emission)
			_sync_object_light(node, look)
			_sync_object_marker(node, look)
			continue
		node.position = Vector3(
			float(obj.cells[0].x) + float(extent.x) * 0.5,
			height * 0.5,
			float(obj.cells[0].y) + float(extent.y) * 0.5,
		) + _mounting(obj)
		node.rotation_degrees = _object_rotation(obj, look)
		node.scale = Vector3(1.0, float(look.get("scale_y", 1.0)), 1.0)
		(node as MeshInstance3D).material_override = _material(
			visuals.to_colour(look.get("color", null)),
			float(look.get("emission", 0.0)),
		)
		_sync_object_light(node, look)
		_sync_object_marker(node, look)


## Some states are facts the player acts on and cannot otherwise see: a door
## that is locked, a chain that is on, a fridge shoved against the way in. They
## get a small solid mark on the object, described in `state_visual` — size,
## offset, brand colour — so adding one to a new state is a table entry.
##
## Nothing is named here: the mark comes from the state, not from the object.
func _sync_object_marker(node: Node3D, look: Dictionary) -> void:
	var spec: Variant = look.get("marker", null)
	var marker: MeshInstance3D = node.get_node_or_null(NodePath(STATE_MARKER))
	if not (spec is Dictionary):
		if marker != null:
			marker.queue_free()
			node.remove_child(marker)
		return
	var shape: Dictionary = spec
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = STATE_MARKER
		marker.mesh = BoxMesh.new()
		node.add_child(marker)
	var size := visuals.to_vector3(shape.get("size", null), Vector3(0.12, 0.12, 0.12))
	(marker.mesh as BoxMesh).size = size
	marker.position = visuals.to_vector3(shape.get("offset", null), Vector3(0.0, 1.0, 0.0))
	marker.rotation_degrees = Vector3(0.0, 0.0, float(shape.get("roll_deg", 0.0)))
	marker.material_override = _material(visuals.to_colour(shape.get("color", null)),
		visuals.number("object.marker_emission", 0.35))


## A wall cabinet is on the wall and a light switch is at hand height. Drawn on
## the floor they are furniture, and the thing standing in front of them hides
## them — which is what happened to both. `mount_y` is the object's own, in
## metres off the floor.
func _mounting(obj: SimObject) -> Vector3:
	return Vector3(0.0, float(obj.prop("mount_y", 0.0)), 0.0)


## A falling object lies down along the way it fell. The tip direction is already
## in the object's own `tips.dir`, and ignoring it — rolling everything about Z —
## is what sent the bookshelf sideways through the wall.
func _object_rotation(obj: SimObject, look: Dictionary) -> Vector3:
	var yaw := float(look.get("yaw_deg", 0.0)) + float(obj.prop("mesh_yaw", 0.0)) * 0.0
	var angle := float(look.get("roll_deg", 0.0))
	if is_zero_approx(angle):
		return Vector3(0.0, yaw, 0.0)
	var tips: Variant = obj.prop("tips", null)
	var direction := str((tips as Dictionary).get("dir", "E")) if tips is Dictionary else "E"
	match direction:
		"N": return Vector3(-angle, yaw, 0.0)
		"S": return Vector3(angle, yaw, 0.0)
		"W": return Vector3(0.0, yaw, angle)
		_:   return Vector3(0.0, yaw, -angle)


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


func _sync_actors(world: SimWorld, delta: float, tick_alpha: float = 0.0) -> void:
	_expire_once(delta)
	var turn_rate := visuals.number("actor.turn_per_s", 14.0)
	var hidden_alpha := visuals.number("actor.hidden_alpha", 0.25)
	var tick_seconds := 1.0 / maxf(float(world.system("tick_hz", 10.0)), 1.0)
	var down_statuses: Array = visuals.get_value("actor.down_statuses", [])
	for actor in world.actors():
		var node: Node3D = _actor_nodes.get(actor.id, null)
		if node == null:
			node = _add_actor(actor)
			_actor_nodes[actor.id] = node
		var key := "actor.%s" % actor.role
		node.visible = actor.alive and _actor_is_present(actor)
		node.position = _actor_position(actor, tick_seconds, tick_alpha)
		_face_travel(node, actor, turn_rate, delta)
		# No rig in the pack, so being knocked down is the figure laid flat. From an
		# isometric camera that is the whole of the read.
		var down := false
		for status in down_statuses:
			if actor.has_status(str(status)):
				down = true
		_drive_animation(node, actor, down)
		_fade_actor(node, key, hidden_alpha if actor.is_hidden() else 1.0)


## Idle, walk, down, dead — plus whatever a one-shot has asked for, which beats
## all of them for as long as it lasts. How a body falls is the death beat's
## call, and it reads the cause the sim recorded.
func _drive_animation(node: Node3D, actor: SimActor, down: bool = false) -> void:
	var player := _animation_player(node)
	if player == null:
		return
	var clip := str(visuals.get_value("actor.clips.idle", "Idle"))
	if not actor.alive:
		clip = str(DeathBeat.resolve(visuals, _room, actor.death_cause).get("victim_clip", "Death"))
	elif down:
		clip = str(visuals.get_value("actor.clips.down", "HitRecieve"))
	elif not actor.path.is_empty():
		clip = str(visuals.get_value("actor.clips.walk", "Walk"))
	var once: Dictionary = _once.get(actor.id, {})
	if not once.is_empty():
		clip = str(once["clip"])
	if not player.has_animation(clip) or player.current_animation == clip:
		return
	player.play(clip, visuals.number("actor.clips.blend_s", 0.15))


## A swing, a flinch — something that plays through and then hands the figure
## back. Presentation only: the sim resolved the attack the moment it landed.
func play_once(actor_id: String, clip: String, seconds: float) -> void:
	if clip.is_empty() or seconds <= 0.0:
		return
	_once[actor_id] = {"clip": clip, "left": seconds}


func current_clip(actor_id: String) -> String:
	var node: Node3D = _actor_nodes.get(actor_id, null)
	if node == null:
		return ""
	var player := _animation_player(node)
	return player.current_animation if player != null else ""


func _expire_once(delta: float) -> void:
	for id in _once.keys():
		var entry: Dictionary = _once[id]
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) <= 0.0:
			_once.erase(id)


func _animation_player(node: Node) -> AnimationPlayer:
	for child in _descendants(node):
		if child is AnimationPlayer:
			return child
	return null


## Where the figure actually is: between the cell it left and the cell it is
## walking into, at the fraction the sim reports, plus however far through the
## current tick the frame happens to be. Constant speed, no easing, no jump.
func _actor_position(actor: SimActor, tick_seconds: float, tick_alpha: float) -> Vector3:
	var here := IsoCamera.cell_to_world(actor.pos, 0.0)
	if actor.path.is_empty():
		return here
	var progress := actor.walk_progress + actor.walk_speed * tick_seconds * clampf(tick_alpha, 0.0, 1.0)
	return here.lerp(IsoCamera.cell_to_world(actor.path[0], 0.0), clampf(progress, 0.0, 1.0))


## Turn to face the way you are walking, and turn at a rate rather than snapping.
func _face_travel(node: Node3D, actor: SimActor, turn_rate: float, delta: float) -> void:
	if actor.facing == Vector2i.ZERO:
		return
	var wanted := rad_to_deg(atan2(float(actor.facing.x), float(actor.facing.y))) \
		+ visuals.number("actor.mesh_yaw", 0.0)
	var current := node.rotation_degrees.y
	var step := wrapf(wanted - current, -180.0, 180.0) * clampf(turn_rate * delta, 0.0, 1.0)
	node.rotation_degrees = Vector3(0.0, current + step, 0.0)


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


## What an object occupies on screen, as drawn — model scale, rotation and all.
func object_bounds(id: String) -> AABB:
	var node: Node3D = _object_nodes.get(id, null)
	if node == null:
		return AABB()
	var out := AABB()
	var first := true
	for child in _descendants(node):
		if not (child is MeshInstance3D) or (child as MeshInstance3D).mesh == null:
			continue
		var mi := child as MeshInstance3D
		var box: AABB = _chain_from(mi, node) * mi.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	if first:
		return AABB()
	# The node itself is placed on the room; the chain above stops at it.
	return AABB(out.position + node.position, out.size)


func _chain_from(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t


## The object under a click. Rays against what is drawn, because clicking the
## floor square under the cursor is wrong for anything tall: from this camera
## the middle of the fridge projects onto the square behind the fridge.
##
## Presentation decides which object the player meant; the sim still decides
## what may be done to it.
func pick(from: Vector3, direction: Vector3) -> String:
	var best := ""
	var nearest := INF
	for id in _object_nodes:
		var node: Node3D = _object_nodes[id]
		if node == null or not node.visible:
			continue
		var box := object_bounds(str(id))
		if box.size == Vector3.ZERO:
			continue
		# A flat thing — a rug, a spill — is unclickable as a box of zero height.
		if box.size.y < 0.02:
			box = AABB(box.position, Vector3(box.size.x, 0.02, box.size.z))
		var hit: Variant = box.intersects_ray(from, direction)
		if hit == null:
			continue
		var distance := (hit as Vector3).distance_to(from)
		if distance < nearest:
			nearest = distance
			best = str(id)
	return best


func actor_node(id: String) -> Node3D:
	return _actor_nodes.get(id, null)
