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
