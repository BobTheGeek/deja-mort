extends GdUnitTestSuite

## First Light §3: frame_margin -0.5 takes the resolved orthographic size from
## 12.0 to 11.0 (game/iso_camera.gd:11-12); the true-iso angles never move.

func test_the_camera_resolves_to_the_approved_size() -> void:
	var v := GameVisuals.load_table()
	var cam: IsoCamera = auto_free(IsoCamera.new())
	cam.setup(v, 12, 10)
	assert_float(cam.size).is_equal_approx(11.0, 0.01)
	assert_float(cam.rotation_degrees.x).is_equal_approx(v.number("camera.pitch_deg"), 0.01)
	assert_float(cam.rotation_degrees.y).is_equal_approx(v.number("camera.yaw_deg"), 0.01)
