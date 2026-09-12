extends GdUnitTestSuite

## M4 tranche 3: the capsules become figures. docs/06 — "simple faceless figures,
## capsule-and-limbs, silhouette-readable. The room is the star."
##
## Which model an actor uses is keyed on its role, never its id, so a new
## attacker profile needs no code and no new art.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")



func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	return renderer


# --- the mechanism ------------------------------------------------------------

## Keyed on role, never on id, so a new attacker profile needs no code and no
## new art. Packs ship as .glb or .gltf; the resolver takes either.
func test_both_roles_name_a_model_that_exists() -> void:
	var v := _visuals()
	for role in ["player", "attacker"]:
		var mesh := str(v.get_value("actor.%s.mesh" % role, ""))
		assert_str(mesh).override_failure_message("role %s names no mesh" % role).is_not_empty()
		assert_str(RoomRenderer.model_path(mesh)) \
			.override_failure_message("%s names a missing model: %s" % [role, mesh]).is_not_empty()


func test_the_two_roles_are_never_the_same_figure() -> void:
	var v := _visuals()
	assert_str(str(v.get_value("actor.player.mesh", ""))) \
		.override_failure_message("you and he must not look alike") \
		.is_not_equal(str(v.get_value("actor.attacker.mesh", "")))


func test_the_character_pack_ships_with_its_licence() -> void:
	var licence := "res://assets/models/quaternius/LICENSE.txt"
	assert_bool(FileAccess.file_exists(licence)).is_true()
	assert_str(FileAccess.get_file_as_string(licence)).contains("CC0")


# --- it moves ----------------------------------------------------------------

## The pack is rigged with 24 clips. docs/06 asks for pose swaps and a stylised
## death; this is where those come from.
func test_a_figure_carries_its_animations() -> void:
	var world := F.world()
	var node: Node3D = _rendered(world).actor_node(world.player.id)
	var player := _animation_player(node)
	assert_object(player).override_failure_message("figure has no AnimationPlayer").is_not_null()
	for clip in ["Idle", "Walk", "Death"]:
		assert_bool(player.has_animation(clip)) \
			.override_failure_message("no %s clip" % clip).is_true()


func test_a_standing_figure_idles() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	assert_str(_animation_player(node).current_animation) \
		.is_equal(str(_visuals().get_value("actor.clips.idle", "Idle")))


func test_a_walking_figure_walks() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	world.walk_to(Vector2i(3, 5))
	world.step()
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	assert_str(_animation_player(node).current_animation) \
		.is_equal(str(_visuals().get_value("actor.clips.walk", "Walk")))


func test_a_dead_figure_plays_its_death() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	world.kill_actor(world.player, "test", "test")
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	assert_str(_animation_player(node).current_animation) \
		.is_equal(str(_visuals().get_value("actor.clips.death", "Death")))


func _animation_player(node: Node) -> AnimationPlayer:
	for child in _all(node):
		if child is AnimationPlayer:
			return child
	return null


# --- the renderer ------------------------------------------------------------

func test_every_actor_gets_a_body() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for actor in world.actors():
		var node: Node3D = renderer.actor_node(actor.id)
		assert_object(node).override_failure_message("%s has no body" % actor.id).is_not_null()
		assert_int(_mesh_instances(node)).override_failure_message(
			"%s rendered nothing" % actor.id).is_greater(0)


## Whatever the body is, it is the height the data says.
func test_a_figure_is_scaled_to_the_authored_height() -> void:
	var world := F.world()
	var node: Node3D = _rendered(world).actor_node(world.player.id)
	var span := _bounds(node)
	var wanted := _visuals().number("actor.player.height", 1.7)
	assert_float(span.size.y).override_failure_message(
		"figure is %.2f tall, wanted %.2f" % [span.size.y, wanted]).is_equal_approx(wanted, 0.08)


func test_a_figure_stands_on_the_floor() -> void:
	var world := F.world()
	var figure: Node3D = _rendered(world).actor_node(world.player.id)
	var span := _bounds(figure)
	assert_float(span.position.y).override_failure_message(
		"figure floats or sinks: min.y = %.3f" % span.position.y).is_between(-0.06, 0.06)


## Being knocked down is a pose now, not a rotation — see effects_test.gd.
func test_a_standing_actor_stays_upright() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var upright: Node3D = renderer.actor_node(world.player.id)
	assert_float(upright.rotation_degrees.z).is_equal_approx(0.0, 0.01)


func test_hiding_still_fades_the_figure() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	F.act(world, "hide", "closet")
	renderer.sync(world, 0.1)
	assert_bool(world.player.is_hidden()).is_true()
	var hidden: Node3D = renderer.actor_node(world.player.id)
	assert_float(_alpha(hidden)).override_failure_message(
		"a hidden figure should be faded").is_less(1.0)


# --- helpers ----------------------------------------------------------------

func _mesh_instances(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _mesh_instances(child)
	return total


func _has_capsule(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is CapsuleMesh:
		return true
	for child in node.get_children():
		if _has_capsule(child):
			return true
	return false


func _alpha(node: Node) -> float:
	for child in _all(node):
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				return mat.albedo_color.a
	return 1.0


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in _all(node):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			var box: AABB = _chain(mi, node) * mi.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func _chain(node: Node3D, root: Node3D) -> Transform3D:
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
