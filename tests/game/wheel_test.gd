extends GdUnitTestSuite

## The wheel, rebuilt from Claude Design's turn-1 spec (docs/ui/SPEC.md,
## direction A — tiles on a ring). Bob's verdict on the old one was "not legible
## and needs a serious design pass"; it was nine default grey buttons in a ring.
##
## These are the claims the spec makes that code can be wrong about: where the
## slots are, that they stay on screen, that an unavailable slot is legibly
## unavailable rather than merely faint, that the cost of an action is visible
## without a tooltip, and that a refusal says so.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")
const VERB_COUNT := 9


func _wheel(world: SimWorld) -> ActionWheel:
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	return wheel


func _open(world: SimWorld, target: Variant = "fridge", at := Vector2(960, 540),
		index := 1, count := 1) -> ActionWheel:
	var wheel := _wheel(world)
	wheel.open_at(world, target, at, index, count)
	wheel.advance(1.0)          # let the open tween finish
	return wheel


# --- the table ---------------------------------------------------------------

## Every key the wheel reads must be in visuals.json. A silent fallback is how a
## design lands half-applied and nobody notices.
func test_the_table_carries_every_number_the_wheel_reads() -> void:
	var v := GameVisuals.load_table()
	var missing := PackedStringArray()
	for key in ActionWheel.REQUIRED_KEYS:
		if v.get_value("wheel." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing wheel keys: %s" % [missing]).is_empty()


func test_every_verb_has_an_icon_on_disk() -> void:
	var missing := PackedStringArray()
	for entry in F.content().verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var path: String = GameVisuals.load_table().get_value("wheel.icon_path", "") % verb
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_array(Array(missing)).override_failure_message(
		"verbs with no icon: %s" % [missing]).is_empty()


# --- geometry ----------------------------------------------------------------

func test_the_slots_sit_where_the_spec_puts_them() -> void:
	var world := F.world()
	var wheel := _open(world)
	var v := GameVisuals.load_table()
	var radius := v.number("wheel.radius")
	var angles: Dictionary = v.get_value("wheel.slot_angles_deg", {})
	assert_int(wheel.verbs().size()).is_equal(VERB_COUNT)
	for entry in F.content().verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var slot := str((entry as Dictionary).get("slot", ""))
		var centre := wheel.slot_centre(verb)
		if slot == "center":
			assert_vector(centre).override_failure_message(
				"the centre verb is not in the centre").is_equal_approx(wheel.centre_point(), Vector2.ONE)
			continue
		var offset := centre - wheel.centre_point()
		assert_float(offset.length()).override_failure_message(
			"%s sits %.1f from the centre, not %.1f" % [verb, offset.length(), radius]) \
			.is_equal_approx(radius, 1.0)
		# Zero degrees is straight up and they run clockwise.
		var wanted := Vector2(sin(deg_to_rad(float(angles[slot]))), -cos(deg_to_rad(float(angles[slot]))))
		assert_float(offset.normalized().dot(wanted)).override_failure_message(
			"%s (%s) points the wrong way round the ring" % [verb, slot]).is_greater(0.99)


func test_no_two_slots_overlap_and_each_is_big_enough_for_a_thumb() -> void:
	var world := F.world()
	var wheel := _open(world)
	var v := GameVisuals.load_table()
	var size := v.number("wheel.slot_size")
	assert_float(size).override_failure_message(
		"a %.0fpx slot is under the 44dp touch minimum" % size).is_greater_equal(
			v.number("wheel.min_touch_target"))
	var verbs := wheel.verbs()
	for a in verbs:
		for b in verbs:
			if a == b:
				continue
			var gap := wheel.slot_centre(str(a)).distance_to(wheel.slot_centre(str(b)))
			var touching := (wheel.slot_size(str(a)) + wheel.slot_size(str(b))) * 0.5
			assert_float(gap).override_failure_message(
				"%s and %s overlap: %.1f apart, %.1f wide" % [a, b, gap, touching]).is_greater(touching)


func test_a_tap_lands_on_the_slot_you_aimed_at() -> void:
	var world := F.world()
	var wheel := _open(world)
	for verb in wheel.verbs():
		assert_str(wheel.verb_at(wheel.slot_centre(str(verb)))).override_failure_message(
			"tapping the middle of %s hits nothing" % verb).is_equal(str(verb))


func test_tapping_the_gap_outside_the_ring_dismisses_rather_than_guessing() -> void:
	var world := F.world()
	var wheel := _open(world)
	var far := wheel.centre_point() + Vector2(GameVisuals.load_table().number("wheel.radius") * 3.0, 0.0)
	assert_str(wheel.verb_at(far)).override_failure_message(
		"a tap well outside the ring chose a verb").is_empty()


# --- staying on screen -------------------------------------------------------

func test_the_wheel_stays_on_screen_when_you_tap_in_a_corner() -> void:
	var world := F.world()
	var v := GameVisuals.load_table()
	var frame := Vector2(v.number("ui.design_width", 1920.0), v.number("ui.design_height", 1080.0))
	var margin := v.number("wheel.edge_margin")
	for corner in [Vector2(4, 4), Vector2(frame.x - 4, 4), Vector2(4, frame.y - 4), frame - Vector2(4, 4)]:
		var wheel := _wheel(world)
		wheel.open_at(world, "fridge", corner)
		wheel.advance(1.0)
		var box := wheel.occupied_rect()
		assert_bool(box.position.x >= margin - 0.5 and box.position.y >= margin - 0.5
			and box.end.x <= frame.x - margin + 0.5 and box.end.y <= frame.y - margin + 0.5) \
			.override_failure_message("tapped %s and the wheel occupies %s of a %s frame" % [
				corner, box, frame]).is_true()
		assert_bool(wheel.needs_leader()).override_failure_message(
			"the wheel moved off the tap point at %s without drawing the leader that says so" % corner) \
			.is_true()


func test_a_tap_in_open_space_needs_no_leader() -> void:
	var world := F.world()
	assert_bool(_open(world).needs_leader()).override_failure_message(
		"a leader line drawn when the wheel is exactly on the tap point").is_false()


# --- what a slot says --------------------------------------------------------

func test_an_unavailable_slot_is_more_than_just_faint() -> void:
	var world := F.world()
	var wheel := _open(world)
	# Nothing is held, so Throw cannot be available.
	assert_str(wheel.slot_state("throw")).is_equal("unavailable")
	var style := wheel.slot_style("throw")
	assert_str(str(style.get("border_style", ""))).override_failure_message(
		"unavailable reads as a dashed border, not only a lower alpha").is_equal("dashed")
	assert_float(float(style.get("icon_alpha", 1.0))).is_less(0.5)


func test_an_available_slot_shows_what_the_action_costs() -> void:
	var world := F.world()
	var wheel := _open(world)
	assert_str(wheel.slot_state("open")).is_equal("available")
	assert_float(wheel.cost_of("open")).override_failure_message(
		"opening the fridge should cost time and the slot should say so").is_greater(0.0)
	assert_str(wheel.cost_label("open")).override_failure_message(
		"no cost printed on an available slot").is_not_empty()


func test_an_unavailable_slot_prints_no_cost() -> void:
	var world := F.world()
	assert_str(_open(world).cost_label("throw")).override_failure_message(
		"an unavailable slot is advertising a price").is_empty()


func test_inspect_is_free_and_says_nothing_about_time() -> void:
	var world := F.world()
	var wheel := _open(world)
	assert_float(wheel.cost_of("inspect")).is_equal_approx(0.0, 0.001)
	assert_str(wheel.cost_label("inspect")).override_failure_message(
		"thinking is free; the centre slot should not print 0.0s").is_empty()


# --- the caption -------------------------------------------------------------

func test_the_caption_names_the_object() -> void:
	var world := F.world()
	var wheel := _open(world, "toaster")
	assert_str(wheel.caption_lines()[0]).is_equal(world.objects.by_id("toaster").name)


func test_the_caption_counts_a_stacked_cell_and_only_then() -> void:
	var world := F.world()
	var stacked := _open(world, "toaster", Vector2(960, 540), 2, 5).caption_lines()
	assert_int(stacked.size()).is_greater(1)
	assert_str(stacked[1]).contains("2 of 5")
	assert_int(_open(world, "couch").caption_lines().size()).override_failure_message(
		"a lone object should not be told it is 1 of 1").is_equal(1)


func test_hovering_a_slot_names_the_verb_and_its_cost() -> void:
	var world := F.world()
	var wheel := _open(world)
	wheel.hover_at(wheel.slot_centre("open"))
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).override_failure_message(
		"hovering a slot says nothing: %s" % [lines]).contains("Open")


# --- refusal -----------------------------------------------------------------

func test_a_refusal_marks_the_slot_and_keeps_the_wheel_open() -> void:
	var world := F.world()
	var wheel := _open(world, "glass_jar")
	assert_bool(world.verb_on("grab", "glass_jar")).override_failure_message(
		"grabbing through a shut cabinet should be refused").is_false()
	wheel.report_refused("grab")
	assert_str(wheel.slot_state("grab")).is_equal("refused")
	assert_bool(wheel.is_open()).is_true()
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).contains("can't")
	assert_object(wheel.slot_style("grab").get("border")).override_failure_message(
		"a refusal is the accent, and nothing in this game is red") \
		.is_equal(GameVisuals.load_table().colour("wheel.refused_color"))


func test_the_refusal_clears_itself() -> void:
	var world := F.world()
	var wheel := _open(world, "glass_jar")
	wheel.report_refused("grab")
	wheel.advance(GameVisuals.load_table().number("wheel.refused_hold_s") + 0.1)
	assert_str(wheel.slot_state("grab")).override_failure_message(
		"the slot is still shouting about a refusal from a while ago").is_not_equal("refused")


# --- opening and closing -----------------------------------------------------

func test_it_opens_over_time_rather_than_appearing() -> void:
	var world := F.world()
	var wheel := _wheel(world)
	wheel.open_at(world, "fridge", Vector2(960, 540))
	assert_float(wheel.open_progress()).override_failure_message(
		"the wheel is fully open on the frame it was asked to open").is_less(1.0)
	wheel.advance(GameVisuals.load_table().number("wheel.open_duration_s") + 0.01)
	assert_float(wheel.open_progress()).is_equal_approx(1.0, 0.001)


func test_closing_forgets_the_target() -> void:
	var world := F.world()
	var wheel := _open(world)
	wheel.close()
	assert_bool(wheel.is_open()).is_false()
	assert_object(wheel.target()).is_null()
