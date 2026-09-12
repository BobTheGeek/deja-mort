extends GdUnitTestSuite

## Guards the brand kit: the tokens match docs/brand/BRAND.md, every path the
## autoload names actually exists, every font family keeps its own licence, and
## the icon is wired everywhere a build can carry one.

const BRAND_DOC := "res://docs/brand/BRAND.md"
const PRESETS := "res://export_presets.cfg"
const ICON := "res://assets/brand/app-icon-1024.png"
const FOREGROUND := "res://assets/brand/icon-adaptive-foreground-1024.png"
const BACKGROUND := "res://assets/brand/icon-adaptive-background-1024.png"


# --- tokens ------------------------------------------------------------------

func test_the_tokens_are_the_approved_values() -> void:
	assert_str(Brand.BG_DARK.to_html(false)).is_equal("0b0c0f")
	assert_str(Brand.FG_DARK.to_html(false)).is_equal("d7dae0")
	assert_str(Brand.BG_LIGHT.to_html(false)).is_equal("ecedef")
	assert_str(Brand.FG_LIGHT.to_html(false)).is_equal("151619")
	assert_str(Brand.ACCENT.to_html(false)).is_equal("d9a05b")
	assert_str(Brand.ACCENT_ON_LIGHT.to_html(false)).is_equal("c2853e")


## The tokens and the brand document must not drift apart.
func test_every_token_appears_in_the_brand_document() -> void:
	var doc := FileAccess.get_file_as_string(BRAND_DOC).to_lower()
	for colour in [Brand.BG_DARK, Brand.FG_DARK, Brand.BG_LIGHT, Brand.FG_LIGHT,
			Brand.ACCENT, Brand.ACCENT_ON_LIGHT]:
		var hex: String = "#" + colour.to_html(false)
		assert_bool(doc.contains(hex)) \
			.override_failure_message("%s is not in BRAND.md" % hex).is_true()


func test_the_autoload_is_registered() -> void:
	assert_bool(ProjectSettings.has_setting("autoload/Brand")).is_true()
	assert_str(str(ProjectSettings.get_setting("autoload/Brand"))) \
		.contains("res://game/theme/brand.gd")


# --- files -------------------------------------------------------------------

func test_every_path_the_brand_names_exists() -> void:
	for path in [Brand.FONT_WORDMARK, Brand.FONT_UI, Brand.FONT_UI_BOLD, Brand.APP_ICON]:
		assert_bool(FileAccess.file_exists(path)) \
			.override_failure_message("Brand names a file that is not there: %s" % path).is_true()


## OFL 1.1 requires the licence to travel with the fonts, and the two families
## carry different copyright lines, so one shared file would not do.
func test_each_font_family_keeps_its_own_licence() -> void:
	var families := {}
	for path in [Brand.FONT_WORDMARK, Brand.FONT_UI, Brand.FONT_UI_BOLD]:
		families[path.get_base_dir()] = true
	assert_int(families.size()).is_greater(1)
	for directory in families:
		var licence: String = str(directory) + "/OFL.txt"
		assert_bool(FileAccess.file_exists(licence)) \
			.override_failure_message("no licence beside the fonts in %s" % [directory]).is_true()
		assert_str(FileAccess.get_file_as_string(licence)).contains("SIL OPEN FONT LICENSE")


func test_the_delivered_art_came_across_intact() -> void:
	for pair in [["res://docs/brand/svg/outlined", ".svg"], ["res://docs/brand/png", ".png"],
			["res://docs/brand/png/lockups", ".png"]]:
		var into: String = "res://assets/brand/lockups" if str(pair[0]).ends_with("lockups") else "res://assets/brand"
		for name in _names(str(pair[0]), str(pair[1])):
			assert_bool(FileAccess.file_exists("%s/%s" % [into, name])) \
				.override_failure_message("delivered file did not come across: %s" % name).is_true()


# --- icon wiring -------------------------------------------------------------

func test_the_project_icon_is_the_brand_icon() -> void:
	assert_str(str(ProjectSettings.get_setting("application/config/icon"))).is_equal(ICON)


## Every preset whose platform can carry an icon points at the right source.
## The two adaptive layers are not the finished tile — see the safe-zone test
## below. Linux has no icon option in Godot's export settings; it takes the
## project icon at runtime, so it is deliberately not listed here.
func test_every_export_preset_that_can_carry_an_icon_uses_it() -> void:
	var text := FileAccess.get_file_as_string(PRESETS)
	var wiring := {
		"application/icon": ICON,
		"launcher_icons/main_192x192": ICON,
		"launcher_icons/adaptive_foreground_432x432": FOREGROUND,
		"launcher_icons/adaptive_background_432x432": BACKGROUND,
	}
	for key in wiring:
		assert_bool(text.contains('%s="%s"' % [key, wiring[key]])) \
			.override_failure_message("preset key %s is not wired to %s" % [key, wiring[key]]).is_true()


## An adaptive layer is 108dp with only the centre 72dp guaranteed visible. A
## foreground that spills past that gets clipped by the launcher mask, which is
## exactly the bug this pair of files exists to avoid.
func test_the_adaptive_foreground_stays_inside_the_safe_zone() -> void:
	var foreground := Image.load_from_file(ProjectSettings.globalize_path(FOREGROUND))
	assert_object(foreground).is_not_null()
	var used := foreground.get_used_rect()
	var safe := float(foreground.get_width()) * 72.0 / 108.0
	assert_float(float(maxi(used.size.x, used.size.y))) \
		.override_failure_message("foreground content is %s on a %d canvas — the mask will clip it"
			% [used.size, foreground.get_width()]).is_less_equal(safe)


func test_the_adaptive_background_is_the_brand_ink() -> void:
	var background := Image.load_from_file(ProjectSettings.globalize_path(BACKGROUND))
	assert_object(background).is_not_null()
	for point in [Vector2i(0, 0), Vector2i(511, 511), Vector2i(1023, 1023)]:
		assert_str(background.get_pixelv(point).to_html(false)).is_equal(Brand.BG_DARK.to_html(false))


# --- scope -------------------------------------------------------------------

## The brand landed; nothing renders it yet. This fails the day someone wires it
## in without updating the plan, which is M3 presentation work.
func test_nothing_uses_the_brand_yet() -> void:
	var users := PackedStringArray()
	for path in _gd_files("res://game"):
		if path.ends_with("/brand.gd"):
			continue
		if FileAccess.get_file_as_string(path).contains("Brand."):
			users.append(path)
	assert_array(Array(users)).override_failure_message(
		"brand is wired into %s — update this test when that is intended" % [users]).is_empty()


func _names(dir_path: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(suffix):
			out.append(f)
	out.sort()
	return out


func _gd_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	for d in dir.get_directories():
		out.append_array(_gd_files("%s/%s" % [dir_path, d]))
	return out
