extends GdUnitTestSuite

## M4 tranche 2: boxes become furniture. docs/06 import conventions —
## assets/models/<pack>/<name>.glb, origin at footprint centre with y=0 at the
## floor, referenced from room JSON as "mesh": "kenney/<name>".
##
## Kenney's kit is not authored at 1 unit = 1 m, so the renderer normalises each
## model into the footprint the sim already knows about. An object with no mesh
## keeps its greybox box, so nothing regresses while the mapping is filled in.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")
const MODELS := "res://assets/models/kenney"


# --- the pack ----------------------------------------------------------------

func test_the_pack_ships_with_its_licence() -> void:
	var licence := MODELS + "/LICENSE.txt"
	assert_bool(FileAccess.file_exists(licence)).is_true()
	assert_str(FileAccess.get_file_as_string(licence)).contains("Creative Commons Zero")


func test_every_mesh_the_room_names_actually_exists() -> void:
	var missing := PackedStringArray()
	for obj in F.world().objects.all():
		var mesh := str(obj.prop("mesh", ""))
		if mesh.is_empty():
			continue
		var path := "res://assets/models/%s.glb" % mesh
		if not ResourceLoader.exists(path):
			missing.append("%s names %s" % [obj.id, path])
	assert_array(Array(missing)).override_failure_message(
		"room names a mesh that is not there: %s" % [missing]).is_empty()


func test_mesh_names_are_namespaced_by_pack() -> void:
	for obj in F.world().objects.all():
		var mesh := str(obj.prop("mesh", ""))
		if mesh.is_empty():
			continue
		assert_bool(mesh.contains("/")) \
			.override_failure_message("%s names '%s' with no pack prefix" % [obj.id, mesh]).is_true()


## Enough of Room 1 should be real furniture for the frame to read as a room.
func test_most_of_the_room_is_meshed() -> void:
	var world := F.world()
	var meshed := 0
	var visible := 0
	for obj in world.objects.all():
		if obj.cells.is_empty() or obj.has_tag("collectible"):
			continue
		visible += 1
		if not str(obj.prop("mesh", "")).is_empty():
			meshed += 1
	assert_int(meshed).override_failure_message(
		"only %d of %d objects have a mesh" % [meshed, visible]).is_greater(visible / 2)


# --- the renderer ------------------------------------------------------------

func test_a_meshed_object_renders_its_model_not_a_box() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var fridge := renderer.object_node("fridge")
	assert_object(fridge).is_not_null()
	assert_int(_mesh_instances(fridge)).override_failure_message(
		"fridge did not instantiate a model").is_greater(0)
	assert_bool(_is_plain_box(fridge)) \
		.override_failure_message("fridge is still a BoxMesh").is_false()


func test_an_unmeshed_object_still_gets_its_greybox() -> void:
	var world := F.world()
	var bare := world.objects.by_id("bubble_token")
	assert_str(str(bare.prop("mesh", ""))).is_empty()
	assert_object(_rendered(world).object_node("bubble_token")).is_not_null()


## A model authored at Kenney's scale must end up the size of its footprint.
func test_a_model_is_normalised_into_its_footprint() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for id in ["fridge", "bed", "couch"]:
		var obj := world.objects.by_id(id)
		var node := renderer.object_node(id)
		assert_object(node).is_not_null()
		var span := _world_aabb(node)
		var footprint := _footprint_size(obj)
		assert_float(maxf(span.size.x, span.size.z)).override_failure_message(
			"%s spans %.2f but its footprint is %.2f" % [id, maxf(span.size.x, span.size.z), footprint]) \
			.is_less_equal(footprint + 0.05)


func test_a_model_stands_on_the_floor() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for id in ["fridge", "bed", "couch"]:
		var span := _world_aabb(renderer.object_node(id))
		assert_float(span.position.y).override_failure_message(
			"%s floats or sinks: min.y = %.3f" % [id, span.position.y]).is_between(-0.06, 0.06)


# --- the grain I promised and did not write ---------------------------------

func test_the_vignette_shader_actually_grains() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_bool(source.contains("grain")) \
		.override_failure_message("visuals.json declares a grain value nothing reads").is_true()


# --- helpers ----------------------------------------------------------------

func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	return renderer


func _footprint_size(obj: SimObject) -> float:
	var lo := obj.cells[0]
	var hi := obj.cells[0]
	for c in obj.cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return float(maxi(hi.x - lo.x, hi.y - lo.y) + 1)


func _mesh_instances(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _mesh_instances(child)
	return total


func _is_plain_box(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		return true
	for child in node.get_children():
		if _is_plain_box(child):
			return true
	return false


func _world_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in _all(node):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			var box: AABB = mi.global_transform * mi.mesh.get_aabb() if mi.is_inside_tree() \
				else _local_chain(mi, node) * mi.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func _local_chain(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root.get_parent():
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
