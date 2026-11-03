extends GdUnitTestSuite

## Bob asked for three recolours that keep the object readable, not a flat coat:
## the knife block walnut but its knives left alone, the frying pan carbon, the
## toaster silver. They come from `models.recolor` in visuals.json, keyed by
## model, matched by node or material name — no object is named in code.
##
## The trap these guard: the food props share one `colormap` material, so a
## careless recolour paints every one of them. The fix paints a per-object
## surface override; these prove it lands on the right parts and nowhere else.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var r: RoomRenderer = auto_free(RoomRenderer.new())
	r.build(world, GameVisuals.load_table())
	r.sync(world, 1.0, 0.0)
	return r


func _surface_albedo(node: Node3D, want_node: String) -> Variant:
	for child in _descendants(node):
		if not (child is MeshInstance3D) or child.name != want_node:
			continue
		var mi := child as MeshInstance3D
		var mat := mi.get_surface_override_material(0)
		return (mat as StandardMaterial3D).albedo_color if mat is StandardMaterial3D else null
	return null


func _descendants(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_descendants(c))
	return out


func test_the_block_is_walnut_and_the_knives_are_left_alone() -> void:
	var renderer := _rendered(F.world())
	var knife := renderer.object_node("kitchen_knife")
	var block: Variant = _surface_albedo(knife, "knife-block")
	assert_object(block).override_failure_message("the block was not recoloured").is_not_null()
	assert_bool((block as Color).r > (block as Color).b and (block as Color).r < 0.5) \
		.override_failure_message("the block is not a dark brown: %s" % [block]).is_true()
	for edge in ["cooking-knife", "cooking-knife2", "cooking-knife3"]:
		assert_object(_surface_albedo(knife, edge)).override_failure_message(
			"a knife was repainted; Bob asked to leave them alone").is_null()


func test_the_pan_is_near_black() -> void:
	var albedo: Variant = _surface_albedo(_rendered(F.world()).object_node("frying_pan"), "frying-pan")
	assert_object(albedo).is_not_null()
	assert_bool((albedo as Color).v < 0.2).override_failure_message(
		"the pan is not carbon dark: %s" % [albedo]).is_true()


func test_the_toaster_reads_as_silver_with_a_darker_side() -> void:
	var renderer := _rendered(F.world())
	var mi: MeshInstance3D = null
	for child in _descendants(renderer.object_node("toaster")):
		if child is MeshInstance3D:
			mi = child as MeshInstance3D
	assert_object(mi).is_not_null()
	var shades: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_surface_override_material(i)
		assert_object(mat).override_failure_message("a toaster surface was not recoloured").is_not_null()
		shades.append((mat as StandardMaterial3D).albedo_color.v)
	shades.sort()
	assert_bool(shades[shades.size() - 1] > 0.7).override_failure_message(
		"nothing on the toaster is bright silver: %s" % [shades]).is_true()
	assert_bool(shades[0] < shades[shades.size() - 1]).override_failure_message(
		"the toaster is one flat silver, so it has lost its shape").is_true()


## The proof it did not repaint the shared material: the oil bottle uses the same
## `colormap` material as the knives and carries no recolour, so it keeps its
## original look.
func test_an_unlisted_prop_keeps_its_own_look() -> void:
	var renderer := _rendered(F.world())
	assert_object(_surface_albedo(renderer.object_node("cooking_oil"), "bottle-oil")) \
		.override_failure_message("the oil was tinted by a recolour meant for other props") \
		.is_null()


## Every rule must land on something. A rule keyed to a material that no longer
## exists paints nothing and looks like a design choice.
func test_every_recolour_rule_lands_on_a_rendered_surface() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var table: Dictionary = GameVisuals.load_table().get_value("models.recolor", {})
	for mesh_name in table:
		var id := ""
		for obj in world.objects.all():
			if str(obj.prop("mesh", "")) == mesh_name:
				id = obj.id
				break
		assert_str(id).override_failure_message(
			"%s is recoloured but no room object uses it" % mesh_name).is_not_empty()
		var painted := false
		for child in _descendants(renderer.object_node(id)):
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					if mi.get_surface_override_material(i) != null:
						painted = true
		assert_bool(painted).override_failure_message(
			"%s recolour matched no surface" % mesh_name).is_true()


func test_the_bed_cover_is_wool() -> void:
	var bed := _rendered(F.world()).object_node("bed")
	var cover: Variant = _surface_albedo(bed, "cover")
	assert_bool(cover is Color and (cover as Color).b > (cover as Color).r) \
		.override_failure_message("the cover is not cool wool: %s" % [cover]).is_true()


## The bed frame node carries several materials, so the walnut proof lives on
## the coffee table — one node, one `wood` material, no ambiguity.
func test_the_coffee_table_is_walnut() -> void:
	var table := _rendered(F.world()).object_node("coffee_table")
	var wood: Variant = _surface_albedo(table, "tableCoffee(Clone)")
	assert_bool(wood is Color and (wood as Color).r > (wood as Color).b) \
		.override_failure_message("the table is not warm walnut: %s" % [wood]).is_true()
