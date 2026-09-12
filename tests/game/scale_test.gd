extends GdUnitTestSuite

## From Bob's playtest: "the size of the furniture does not make sense. For
## example, the bed is incredibly tiny. Same for the couch and coffee table."
##
## He is right, and the cause was the fitting rule: every model was shrunk until
## it fitted inside the cells the sim had given it. One cell is one metre, so a
## double bed with a one-by-two footprint was squeezed to a metre wide, and the
## figures standing next to it are a real 1.7 m tall.
##
## Kenney's kit is internally consistent — it is authored at 1 unit = 2 m — so
## the fix is one number in data per pack, not a size per object. The footprint
## goes back to meaning what the sim uses it for: which cells are occupied.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")

## What each thing measures in the real world, along its longest floor span,
## except where noted. Ranges, not numbers: this is a catalogue, not a caliper.
const REAL_SIZES := {
	"front_door": {"axis": "height", "min": 1.90, "max": 2.20},
	"fridge": {"axis": "height", "min": 1.55, "max": 2.00},
	"floor_lamp": {"axis": "height", "min": 1.40, "max": 2.00},
	"bed": {"axis": "floor", "min": 1.85, "max": 2.40},
	"couch": {"axis": "floor", "min": 1.70, "max": 2.40},
	"coffee_table": {"axis": "floor", "min": 0.90, "max": 1.50},
	"bathtub": {"axis": "floor", "min": 1.50, "max": 2.50},
	"toilet": {"axis": "floor", "min": 0.60, "max": 1.10},
	"toaster": {"axis": "floor", "min": 0.15, "max": 0.60},
	"tv": {"axis": "floor", "min": 0.90, "max": 1.60},
}


func test_the_pack_scale_is_data_not_a_number_in_the_renderer() -> void:
	var per_unit := GameVisuals.load_table().number("models.kenney.metres_per_unit", 0.0)
	assert_float(per_unit).override_failure_message(
		"visuals.json must declare how many metres one Kenney unit is").is_greater(0.0)


func test_the_furniture_is_the_size_furniture_is() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var wrong := PackedStringArray()
	for id in REAL_SIZES:
		var spec: Dictionary = REAL_SIZES[id]
		var span := _world_aabb(renderer.object_node(str(id)))
		var measured := maxf(span.size.x, span.size.z) if str(spec["axis"]) == "floor" else span.size.y
		if measured < float(spec["min"]) or measured > float(spec["max"]):
			wrong.append("%s is %.2f m, should be %.2f–%.2f" % [
				id, measured, spec["min"], spec["max"]])
	assert_array(Array(wrong)).override_failure_message(
		"furniture at the wrong size:\n  %s" % "\n  ".join(wrong)).is_empty()


## The comparison Bob actually made with his eyes.
func test_a_bed_is_bigger_than_a_coffee_table_and_longer_than_a_person() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var bed := _longest(renderer.object_node("bed"))
	var table := _longest(renderer.object_node("coffee_table"))
	assert_float(bed).override_failure_message(
		"the bed (%.2f m) is not longer than the coffee table (%.2f m)" % [bed, table]) \
		.is_greater(table)
	var tall := GameVisuals.load_table().number("actor.player.height", 1.7)
	assert_float(bed).override_failure_message(
		"a %.2f m bed cannot hold a %.2f m person" % [bed, tall]).is_greater(tall)


## Nothing is stretched to reach its size — one uniform scale per model.
func test_nothing_is_squashed_to_fit() -> void:
	var renderer := _rendered(F.world())
	for id in ["bed", "couch", "fridge", "bathtub"]:
		var model := renderer.object_node(str(id)).get_child(0) as Node3D
		var s := model.scale
		assert_float(absf(s.x - s.y) + absf(s.y - s.z)).override_failure_message(
			"%s is scaled unevenly: %s" % [id, s]).is_less(0.001)


## Real size means some things overhang their cells — a coffee table is wider
## than a metre. It may lean over the edge; it may not swallow the next room.
func test_overhang_is_bounded() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var limit := GameVisuals.load_table().number("models.max_overhang_m", 0.6)
	var bad := PackedStringArray()
	for obj in world.objects.all():
		if str(obj.prop("mesh", "")).is_empty():
			continue
		var node := renderer.object_node(obj.id)
		if node == null:
			continue
		var span := _world_aabb(node)
		var footprint := _footprint_span(obj)
		var over := maxf(span.size.x - footprint.x, span.size.z - footprint.y) * 0.5
		if over > limit:
			bad.append("%s hangs %.2f m past its footprint" % [obj.id, over])
	assert_array(Array(bad)).override_failure_message(
		"models spilling across the room:\n  %s" % "\n  ".join(bad)).is_empty()


func test_a_model_still_stands_on_the_floor() -> void:
	var renderer := _rendered(F.world())
	for id in ["bed", "couch", "fridge", "toilet"]:
		var span := _world_aabb(renderer.object_node(str(id)))
		assert_float(span.position.y).override_failure_message(
			"%s floats or sinks: min.y = %.3f" % [id, span.position.y]).is_between(-0.06, 0.06)


# --- helpers -----------------------------------------------------------------

func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	return renderer


func _longest(node: Node3D) -> float:
	var span := _world_aabb(node)
	return maxf(span.size.x, span.size.z)


func _footprint_span(obj: SimObject) -> Vector2:
	var lo := obj.cells[0]
	var hi := obj.cells[0]
	for c in obj.cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector2(float(hi.x - lo.x + 1), float(hi.y - lo.y + 1))


func _world_aabb(node: Node3D) -> AABB:
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
