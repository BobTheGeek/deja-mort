extends SceneTree

## Generates the two water brush textures, so the painted look can never drift
## from its generator:
##
##   godot --headless -s tools/make_water_textures.gd
##
## foam_strip: the puddle's foam edge and ripple rings — a strip that tiles
## along its length: a bright core that wanders and changes thickness, a soft
## halo either side, and the core broken into dashes, so the waterline reads as
## a brush stroke rather than a vector offset.
## drop_mark: the flat white mark the spray's droplets are drawn as.
##
## Both are project-owned. The RGB under transparent pixels is the halo colour,
## so mipmaps and alpha never fringe dark.

const OUT_DIR := "res://assets/water"
const FOAM_STRIP := "res://assets/water/foam_strip.png"
const DROP_MARK := "res://assets/water/drop_mark.png"

## The mockup's own halo tint (#CEDEF7) and a near-white core.
const HALO := Color(0.808, 0.871, 0.969)
const CORE := Color(0.98, 0.99, 1.0)

const FOAM_W := 1024
const FOAM_H := 128
const MARK := 64


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write_foam_strip()
	_write_drop_mark()
	print("make_water_textures: done")
	quit(0)


func _write_foam_strip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var image := Image.create_empty(FOAM_W, FOAM_H, false, Image.FORMAT_RGBA8)
	var dash_left := 0
	var in_gap := false
	for x in FOAM_W:
		if dash_left <= 0:
			in_gap = not in_gap
			dash_left = (20 + rng.randi() % 40) if in_gap else (90 + rng.randi() % 90)
		dash_left -= 1
		# Integer cycles over the strip, so the tile is seamless in u.
		var centre := 0.45 + sin(float(x) * TAU / 512.0) * 0.035 \
			+ sin(float(x) * TAU / 341.333) * 0.02
		var thickness := 0.11 + sin(float(x) * TAU / 512.0 + 1.7) * 0.05
		for y in FOAM_H:
			var v := (float(y) + 0.5) / float(FOAM_H)
			var dist := absf(v - centre)
			var core := clampf((thickness * 0.5 - dist) / 0.05, 0.0, 1.0)
			var halo := pow(clampf(1.0 - dist / 0.5, 0.0, 1.0), 1.6) * 0.55
			var alpha := maxf(core, halo)
			if in_gap:
				alpha *= 0.18 if core > halo else 0.45
			var colour := HALO.lerp(CORE, clampf(core, 0.0, 1.0))
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))
	# A few bubbles riding the core, so the stroke is not a perfect band.
	for i in 6:
		var bx := rng.randi() % FOAM_W
		var by := int(FOAM_H * (0.45 + (rng.randf() - 0.5) * 0.2))
		var r := 2.0 + rng.randf() * 3.0
		for oy in range(-8, 9):
			for ox in range(-8, 9):
				var px := bx + ox
				var py := by + oy
				if px < 0 or px >= FOAM_W or py < 0 or py >= FOAM_H:
					continue
				var d := sqrt(float(ox * ox + oy * oy))
				var ring := clampf(1.0 - absf(d - r) / 1.2, 0.0, 1.0)
				if ring <= 0.0:
					continue
				var under := image.get_pixel(px, py)
				image.set_pixel(px, py, Color(CORE.r, CORE.g, CORE.b, maxf(under.a, ring * 0.9)))
	_save(image, FOAM_STRIP)


func _write_drop_mark() -> void:
	var image := Image.create_empty(MARK, MARK, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var centre := Vector2(32.0, 37.0)
	var radius := 19.0
	var taper := 40.0
	for y in MARK:
		for x in MARK:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			# A teardrop: a round belly with a point pulled upward and one flat
			# side, so the mark reads as a splash on the floor, not a bead.
			if p.y - centre.y > radius * 0.55:
				continue
			var up := clampf((centre.y - p.y) / taper, 0.0, 1.0)
			var width := 1.0 - up * 0.62
			var q := Vector2((p.x - centre.x) / width,
				minf(p.y - centre.y, radius * 0.55))
			var edge := clampf(1.0 - q.length() / radius, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, smoothstep(0.0, 0.45, edge)))
	_save(image, DROP_MARK)


func _save(image: Image, path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		printerr("make_water_textures: cannot write %s (%d)" % [path, error])
		return
	print("wrote %s  %dx%d" % [path, image.get_width(), image.get_height()])
