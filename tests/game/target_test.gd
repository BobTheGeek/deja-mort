extends GdUnitTestSuite

## From Bob's playtest: "if I choose to interact with something I am not next to,
## my character does not move."
##
## Walking works. What does not work is knowing what you clicked. Five objects
## share cell (2,1) — the drawer, the charger, the oil, the toaster and the
## token — and the wheel never said which one it meant. Choosing Grab on the
## charger inside a shut drawer is refused, and a refusal that closes the wheel
## and says nothing looks exactly like a character that will not move.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func test_the_room_really_does_stack_objects_on_one_cell() -> void:
	var world := F.world()
	assert_int(world.objects.at_cell(Vector2i(3, 1)).size()).override_failure_message(
		"this test is about stacked objects; the room no longer stacks any").is_greater(2)


func test_the_wheel_says_what_it_is_aimed_at() -> void:
	var world := F.world()
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	wheel.open_at(world, "toaster", Vector2.ZERO)
	assert_str(wheel.target_label()).override_failure_message(
		"the wheel does not name its target").contains(world.objects.by_id("toaster").name)


func test_it_says_how_many_others_are_under_the_cursor() -> void:
	var world := F.world()
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	wheel.open_at(world, "toaster", Vector2.ZERO, 3, 5)
	var label := wheel.target_label()
	assert_str(label).override_failure_message(
		"with five objects stacked the wheel should say which one this is: '%s'" % label) \
		.contains("5")


func test_one_object_on_a_cell_needs_no_counter() -> void:
	var world := F.world()
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	wheel.open_at(world, "couch", Vector2.ZERO, 1, 1)
	assert_str(wheel.target_label()).override_failure_message(
		"a lone object should not be labelled 1 of 1").not_contains("1 of 1")


## A refused action that silently closes the wheel is indistinguishable from a
## character who will not move.
func test_a_refused_action_is_not_silent() -> void:
	var world := F.world()
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	wheel.open_at(world, "glass_jar", Vector2.ZERO)
	assert_bool(world.verb_on("grab", "glass_jar")).override_failure_message(
		"grabbing through a shut cabinet should be refused").is_false()
	wheel.report_refused("grab")
	assert_str(wheel.target_label()).override_failure_message(
		"a refusal should say something").is_not_empty()
	assert_bool(wheel.is_open()).override_failure_message(
		"the wheel should stay open so you can pick something that works").is_true()


# --- what you can page to is what you can see ---------------------------------

## Bob, ninth playtest: "I opened the countertop drawer and scrolled through the
## contents (phone charger, jar of oil), but I could not pick either of them up."
##
## The drawer was shut. His log has no `open` on it at all. What he scrolled
## through was the list of everything the sim keeps on that square, which
## includes what is inside the shut drawer — invisible on screen, because the
## renderer hides it, and dead in the wheel, because Grab needs the drawer open.
## So he paged onto two things that were not in the room and got nothing.
##
## One list. If it is not drawn, you cannot page to it.
func test_a_shut_drawer_does_not_offer_what_is_inside_it() -> void:
	var world := F.world()
	var options := ClickTarget.options_for(world, Vector2i(3, 1))
	assert_array(options).override_failure_message(
		"a shut drawer is offering its contents: %s" % [options]).not_contains(
		["charger", "cooking_oil"])
	assert_array(options).contains(["counter_drawer"])


func test_opening_it_puts_them_on_the_list() -> void:
	var world := F.world()
	assert_bool(F.act(world, "open", "counter_drawer")).is_true()
	var options := ClickTarget.options_for(world, Vector2i(3, 1))
	assert_array(options).override_failure_message(
		"the drawer is open and its contents are still not offered: %s" % [options]).contains(
		["charger", "cooking_oil"])


## And everything on the list has something you can do to it. A slot you can page
## to and cannot use is the whole complaint.
func test_everything_you_can_page_to_can_be_acted_on() -> void:
	var world := F.world()
	assert_bool(F.act(world, "open", "counter_drawer")).is_true()
	var dead := PackedStringArray()
	for option in ClickTarget.options_for(world, Vector2i(3, 1)):
		if not (option is String):
			continue
		var live := 0
		for verb in SimVerbs.verb_ids(world):
			if verb != "inspect" and SimVerbs.is_available(world, world.player, verb, option):
				live += 1
		if live == 0:
			dead.append(str(option))
	assert_array(Array(dead)).override_failure_message(
		"you can page to these and do nothing but look at them: %s" % [dead]).is_empty()


## What you are carrying is in your hands, not on the floor under your feet. The
## sim parks it at your square so dropping and throwing have somewhere to start;
## the HUD is what says you are holding it.
func test_what_you_are_holding_is_not_a_thing_on_the_floor() -> void:
	var world := F.world()
	F.give(world, "glass_jar")
	var options := ClickTarget.options_for(world, world.player.pos)
	assert_array(options).override_failure_message(
		"the jar in your hands is being offered as scenery: %s" % [options]).not_contains(
		["glass_jar"])


## The renderer and the click both have to mean the same thing by "in the room",
## or one of them is lying. Stated once, over every square in the room, in the
## three states that change the answer: hands empty, hands full, cupboards open.
func test_the_list_you_page_through_is_the_list_that_is_drawn() -> void:
	for world: SimWorld in [F.world(), _holding(), _all_open()]:
		var hidden: Dictionary = world.out_of_sight()
		for y in world.grid.height:
			for x in world.grid.width:
				var cell := Vector2i(x, y)
				var offered := PackedStringArray()
				for option in ClickTarget.options_for(world, cell):
					if option is String:
						offered.append(str(option))
				var drawn := PackedStringArray()
				for obj in world.objects.at_cell(cell):
					if not hidden.has(obj.id):
						drawn.append(obj.id)
				assert_array(Array(offered)).override_failure_message(
					"at %s you can page through %s but the room draws %s"
					% [cell, offered, drawn]).is_equal(Array(drawn))


func _holding() -> SimWorld:
	var world := F.world()
	F.give(world, "glass_jar")
	return world


func _all_open() -> SimWorld:
	var world := F.world()
	for obj in world.objects.all():
		if obj.get_state("open", null) != null:
			obj.state["open"] = true
	return world
