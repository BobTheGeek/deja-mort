extends GdUnitTestSuite

## Grid geometry: pathing, line of sight, zones, and the distance metric.

const F := preload("res://tests/support/sim_fixture.gd")


func test_terrain_reads_from_the_room_ascii() -> void:
	var w := F.world()
	assert_int(w.grid.width).is_equal(12)
	assert_int(w.grid.height).is_equal(10)
	assert_int(w.grid.cell_type(Vector2i(0, 0))).is_equal(SimGrid.WALL)
	assert_int(w.grid.cell_type(Vector2i(3, 2))).is_equal(SimGrid.FLOOR)
	assert_int(w.grid.cell_type(Vector2i(99, 99))).is_equal(SimGrid.VOID)


func test_distance_is_chebyshev() -> void:
	var w := F.world()
	assert_int(w.grid.distance(Vector2i(0, 0), Vector2i(3, 1))).is_equal(3)
	assert_int(w.grid.distance(Vector2i(0, 0), Vector2i(3, 4))).is_equal(4)


func test_a_path_avoids_walls_and_objects() -> void:
	var w := F.world()
	var route := w.grid.path(Vector2i(6, 5), Vector2i(1, 2), Callable(w, "blocked"))
	assert_array(route).is_not_empty()
	for c in route:
		assert_bool(w.walkable(c)).override_failure_message("stepped on %s" % c).is_true()
	assert_vector(route[route.size() - 1]).is_equal(Vector2i(1, 2))


func test_a_path_into_a_wall_is_empty() -> void:
	var w := F.world()
	assert_array(w.grid.path(Vector2i(6, 5), Vector2i(0, 0), Callable(w, "blocked"))).is_empty()


func test_pathing_is_deterministic() -> void:
	var w := F.world()
	var a := w.grid.path(Vector2i(6, 5), Vector2i(1, 2), Callable(w, "blocked"))
	var b := w.grid.path(Vector2i(6, 5), Vector2i(1, 2), Callable(w, "blocked"))
	assert_array(a).is_equal(b)


func test_the_fridge_blocks_line_of_sight_from_the_doorway() -> void:
	var w := F.world()
	assert_bool(w.grid.has_los(Vector2i(1, 2), Vector2i(4, 2), Callable(w, "blocks_sight"))).is_false()


## Room 1 assumes the fridge hides the living zone from the doorway. On a strict
## Bresenham line the diagonal (1,2) -> (5,4) misses the fridge cell entirely.
## Recorded, not papered over: the geometry is an M2 decision, see docs/BACKLOG.md.
func test_the_diagonal_from_the_doorway_is_currently_clear() -> void:
	var w := F.world()
	assert_bool(w.grid.has_los(Vector2i(1, 2), Vector2i(5, 4), Callable(w, "blocks_sight"))).is_true()


func test_line_of_sight_is_clear_across_open_floor() -> void:
	var w := F.world()
	assert_bool(w.grid.has_los(Vector2i(3, 4), Vector2i(6, 4), Callable(w, "blocks_sight"))).is_true()


func test_a_line_includes_both_endpoints() -> void:
	var w := F.world()
	var pts := w.grid.line(Vector2i(1, 2), Vector2i(4, 2))
	assert_vector(pts[0]).is_equal(Vector2i(1, 2))
	assert_vector(pts[pts.size() - 1]).is_equal(Vector2i(4, 2))


func test_zones_cover_the_authored_rectangles() -> void:
	var w := F.world()
	assert_array(Array(w.grid.zone_names())).contains(["kitchen", "living", "bath", "bed"])
	assert_array(w.grid.zone_cells("bath")).contains([Vector2i(9, 2)])
	assert_str(w.grid.zone_of(Vector2i(6, 6))).is_equal("living")
