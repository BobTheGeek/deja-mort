class_name IsoCamera
extends Camera3D

## Fixed orthographic isometric rig. Never rotates, never follows — the room is
## a diorama and the frame holds still.


func setup(visuals: GameVisuals, grid_width: int, grid_height: int) -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	var margin := visuals.number("camera.frame_margin", 1.0)
	var span := float(maxi(grid_width, grid_height)) + margin * 2.0
	size = maxf(visuals.number("camera.size", 13.0), span)

	rotation_degrees = Vector3(
		visuals.number("camera.pitch_deg", -35.264),
		visuals.number("camera.yaw_deg", 45.0),
		0.0,
	)
	# basis.z points backwards out of the lens, so stepping along it pulls the
	# camera away from the room centre without changing what it looks at.
	var centre := Vector3(float(grid_width) * 0.5, 0.0, float(grid_height) * 0.5)
	var distance := visuals.number("camera.height", 14.0)
	position = centre + transform.basis.z * distance
	near = 0.05
	far = distance * 4.0


## Grid cell under a screen point, using the floor plane. No physics needed.
func cell_under(screen_point: Vector2) -> Vector2i:
	var origin := project_ray_origin(screen_point)
	var direction := project_ray_normal(screen_point)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return Vector2i(-1, -1)
	var point: Vector3 = hit
	return Vector2i(int(floor(point.x)), int(floor(point.z)))


static func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(float(cell.x) + 0.5, y, float(cell.y) + 0.5)
