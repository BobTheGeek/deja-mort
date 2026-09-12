extends GdUnitTestSuite

## The harness for "which way is that person pointing".
##
## Bob, twice: the characters do not face the way they move. The first pass
## fixed the sim — `facing` now describes the leg being walked — and they were
## still wrong on screen, because the sim being right is only half of it. The
## other half is the yaw the renderer turns the figure to, and nothing checked
## that end at all.
##
## This does not trust a constant. It measures which way the rig actually faces
## by looking at the mesh — a standing figure's toes reach further forward than
## its heels — and then checks that the rendered figure's own forward vector
## points where the actor is going. If someone changes the rig, the pack, the
## grid's handedness, or `actor.mesh_yaw`, one of these fails and says which.

const F := preload("res://tests/support/sim_fixture.gd")

## Every way you can leave a square, including the diagonals his pathfinder uses.
const HEADINGS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


# --- which way the rig is built to face --------------------------------------

## Measured, not declared: toes reach forward, heels do not.
func test_the_rig_faces_the_way_the_visual_table_says_it_does() -> void:
	var v := GameVisuals.load_table()
	for role in ["player", "attacker"]:
		var mesh_name := str(v.get_value("actor.%s.mesh" % role, ""))
		if mesh_name.is_empty():
			continue
		var measured := _rig_forward(mesh_name)
		var declared := _declared_forward(v)
		assert_float(measured.dot(declared)).override_failure_message(
			("%s is built facing %s, but actor.mesh_yaw = %.0f says its forward is %s. "
			+ "A figure that walks backwards is exactly this number being 180 degrees out.") % [
				mesh_name, measured, v.number("actor.mesh_yaw", 0.0), declared]).is_greater(0.9)


# --- what the renderer actually does with it ---------------------------------

func test_a_figure_points_where_it_is_pointed() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var wrong := PackedStringArray()
	for heading in HEADINGS:
		for actor in world.actors():
			actor.facing = heading
		renderer.sync(world, 1.0, 0.0)
		for actor in world.actors():
			var node: Node3D = renderer.actor_node(actor.id)
			if node == null:
				continue
			var facing := _node_forward(node, renderer)
			var wanted := Vector3(float(heading.x), 0.0, float(heading.y)).normalized()
			if facing.dot(wanted) < 0.95:
				wrong.append("%s told to face %s points %s (off by %.0f degrees)" % [
					actor.id, heading, facing, rad_to_deg(facing.angle_to(wanted))])
	assert_array(Array(wrong)).override_failure_message(
		"figures pointing the wrong way:\n  %s" % "\n  ".join(wrong)).is_empty()


## The whole chain, end to end: walk a real route with corners and check the
## drawn figure against the leg it is drawn walking.
func test_a_walking_figure_points_along_the_leg_it_is_walking() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(world.walk_to(Vector2i(2, 7))).is_true()
	var wrong := PackedStringArray()
	while world.player.action != null and world.time_s() < 40.0:
		world.step()
		renderer.sync(world, 1.0, 0.0)
		if world.player.path.is_empty():
			continue
		var leg: Vector2i = world.player.path[0] - world.player.pos
		var wanted := Vector3(float(leg.x), 0.0, float(leg.y)).normalized()
		var facing := _node_forward(renderer.actor_node(world.player.id), renderer)
		if facing.dot(wanted) < 0.95:
			wrong.append("at %s walking to %s but drawn pointing %s" % [
				world.player.pos, world.player.path[0], facing])
	assert_array(Array(wrong)).override_failure_message(
		"drawn facing does not follow the walk:\n  %s" % "\n  ".join(wrong)).is_empty()


func test_he_is_drawn_facing_the_player_when_he_arrives() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	while world.player.alive and world.time_s() < 120.0:
		world.step()
		renderer.sync(world, 1.0, 0.0)
	var him := world.attacker
	if him == null or not him.inside:
		return
	var to_victim := Vector3(
		float(world.player.pos.x - him.pos.x), 0.0, float(world.player.pos.y - him.pos.y))
	if to_victim.length() < 0.01:
		return
	var facing := _node_forward(renderer.actor_node(him.id), renderer)
	assert_float(facing.dot(to_victim.normalized())).override_failure_message(
		"he killed the player at %s from %s while drawn pointing %s" % [
			world.player.pos, him.pos, facing]).is_greater(0.7)


## Turning is eased, so it must still get there. A figure that never finishes
## its turn reads as walking sideways just as badly as a wrong yaw.
func test_the_turn_finishes_rather_than_creeping() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for actor in world.actors():
		actor.facing = Vector2i(0, 1)
	renderer.sync(world, 1.0, 0.0)
	for actor in world.actors():
		actor.facing = Vector2i(0, -1)
	var turn_rate := GameVisuals.load_table().number("actor.turn_per_s", 14.0)
	for _frame in 30:
		renderer.sync(world, 1.0 / turn_rate, 0.0)
	var facing := _node_forward(renderer.actor_node(world.player.id), renderer)
	assert_float(facing.dot(Vector3(0.0, 0.0, -1.0))).override_failure_message(
		"half a second after a half turn the figure still points %s" % [facing]).is_greater(0.95)


# --- helpers -----------------------------------------------------------------

func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	renderer.sync(world, 1.0, 0.0)
	return renderer


## The forward the visual table claims, as a world vector: the direction the
## rig's own forward ends up pointing when the renderer's yaw is zero.
func _declared_forward(v: GameVisuals) -> Vector3:
	var yaw := deg_to_rad(v.number("actor.mesh_yaw", 0.0))
	# A heading of (0, 1) — due south — is what yaw zero must resolve to once the
	# table's offset is applied. Same arithmetic the renderer does, inverted.
	return Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, -yaw)


## Which way the figure is actually drawn looking, taken from the node the
## renderer turns rather than from any number it was given.
func _node_forward(node: Node3D, renderer: RoomRenderer) -> Vector3:
	var local := _rig_forward(str(renderer.visuals.get_value("actor.player.mesh", "")))
	return (node.transform.basis * local).normalized()


## Reads the mesh. A standing figure's toes reach further along its forward axis
## than the back of its head does, so the sign of (feet - head) on Z is which way
## it faces. No constant to get wrong.
func _rig_forward(mesh_name: String) -> Vector3:
	if _forward_cache.has(mesh_name):
		return _forward_cache[mesh_name]
	var path := RoomRenderer.model_path(mesh_name)
	var inst := (load(path) as PackedScene).instantiate()
	var verts := PackedVector3Array()
	_collect(inst, verts)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v in verts:
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	var height := hi.y - lo.y
	var foot_z := 0.0
	var foot_n := 0
	var head_z := 0.0
	var head_n := 0
	for v in verts:
		if v.y <= lo.y + height * 0.06:
			foot_z += v.z
			foot_n += 1
		elif v.y >= lo.y + height * 0.88:
			head_z += v.z
			head_n += 1
	inst.free()
	var toes := foot_z / maxi(foot_n, 1) - head_z / maxi(head_n, 1)
	var out := Vector3(0.0, 0.0, signf(toes))
	_forward_cache[mesh_name] = out
	return out


var _forward_cache: Dictionary = {}


func _collect(node: Node, out: PackedVector3Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			out.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	for child in node.get_children():
		_collect(child, out)
