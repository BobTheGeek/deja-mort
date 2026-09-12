extends SceneTree

## Generates the two Android adaptive-icon layers from assets that already exist,
## so they can never drift from the approved treatment.
##
##   godot --headless -s tools/make_icon_layers.gd
##
## Why this is needed: an adaptive icon is two 108dp layers, and the launcher
## mask only guarantees the centre 72dp. Handing it the finished app-icon tile
## nests a tile inside a tile; handing it the full-bleed mark clips the circle.
## The foreground here is the mark inset so it lands inside the safe zone at the
## same visual weight it has on the app-icon tile. The background is the brand's
## own ink, read from the Brand autoload rather than typed in again.

const APP_ICON := "res://assets/brand/app-icon-1024.png"
const MARK := "res://assets/brand/mark-1024.png"
const OUT_FOREGROUND := "res://assets/brand/icon-adaptive-foreground-1024.png"
const OUT_BACKGROUND := "res://assets/brand/icon-adaptive-background-1024.png"
const OUT_PREVIEW := "res://docs/screenshots/icon-adaptive-preview.png"

const SIZE := 1024
## Android adaptive icon: 108dp layer, 72dp guaranteed visible.
const SAFE_ZONE := 72.0 / 108.0


func _initialize() -> void:
	var app_icon := Image.load_from_file(ProjectSettings.globalize_path(APP_ICON))
	var mark := Image.load_from_file(ProjectSettings.globalize_path(MARK))
	if app_icon == null or mark == null:
		printerr("make_icon_layers: cannot read the source icons")
		quit(1)
		return

	var tile_fraction := _content_fraction(app_icon, Brand.BG_DARK)
	var layer_fraction := tile_fraction * SAFE_ZONE
	print("mark occupies %.1f%% of the app-icon tile" % (tile_fraction * 100.0))
	print("safe zone is %.1f%% of the layer, so the mark goes to %.1f%% of it"
		% [SAFE_ZONE * 100.0, layer_fraction * 100.0])

	_write_background()
	var foreground := _write_foreground(mark, layer_fraction)
	_write_preview(foreground)
	print("make_icon_layers: done")
	quit(0)


## How much of `image` is content rather than its own background colour.
## Returns the longer side of the content's bounding box as a fraction.
func _content_fraction(image: Image, background: Color) -> float:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			# Anything meaningfully lighter than the ink is the mark.
			if absf(pixel.r - background.r) + absf(pixel.g - background.g) \
					+ absf(pixel.b - background.b) < 0.15:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return 1.0
	var span := float(maxi(max_x - min_x, max_y - min_y) + 1)
	return span / float(image.get_width())


func _write_background() -> void:
	var canvas := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Brand.BG_DARK)
	_save(canvas, OUT_BACKGROUND)


func _write_foreground(mark: Image, layer_fraction: float) -> Image:
	var bounds := mark.get_used_rect()
	if bounds.size.x <= 0:
		bounds = Rect2i(Vector2i.ZERO, mark.get_size())
	var trimmed := mark.get_region(bounds)

	var target := int(round(float(SIZE) * layer_fraction))
	var scaled := trimmed.duplicate() as Image
	var aspect := float(bounds.size.y) / float(bounds.size.x)
	var width := target
	var height := int(round(float(target) * aspect))
	if height > target:
		height = target
		width = int(round(float(target) / aspect))
	scaled.resize(width, height, Image.INTERPOLATE_LANCZOS)

	var canvas := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(
		scaled,
		Rect2i(Vector2i.ZERO, scaled.get_size()),
		Vector2i((SIZE - width) / 2, (SIZE - height) / 2),
	)
	_save(canvas, OUT_FOREGROUND)
	return canvas


## What a launcher actually shows: the two layers stacked, cropped to the 72dp
## safe zone, and masked to a circle. Committed as evidence — an icon is not
## something to check by arithmetic alone.
func _write_preview(foreground: Image) -> void:
	var crop := int(round(float(SIZE) * SAFE_ZONE))
	var offset := (SIZE - crop) / 2
	var preview := Image.create_empty(crop, crop, false, Image.FORMAT_RGBA8)
	var centre := float(crop) * 0.5
	for y in crop:
		for x in crop:
			var inside: bool = Vector2(float(x) - centre, float(y) - centre).length() <= centre - 1.0
			if not inside:
				preview.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var top := foreground.get_pixel(x + offset, y + offset)
			preview.set_pixel(x, y, Brand.BG_DARK.lerp(top, top.a))
	_save(preview, OUT_PREVIEW)


func _save(image: Image, path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		printerr("make_icon_layers: cannot write %s (%d)" % [path, error])
		return
	print("wrote %s  %dx%d" % [path, image.get_width(), image.get_height()])
