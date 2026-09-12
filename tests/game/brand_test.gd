extends GdUnitTestSuite

## Guards the brand kit as it ships. The inventory is asserted against
## assets/brand/ — what goes in the build — rather than by re-comparing with
## docs/, which only ever proved a copy that already happened.
##
## The token check still reads docs/brand/BRAND.md on purpose: it exists to catch
## drift between the code and the brand document, and duplicating that document
## into assets/ would just recreate the stale second copy we deleted.

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


## The shipped inventory, stated outright. If a file goes missing this fails
## whether or not docs/ still has it.
func test_the_shipped_brand_inventory_is_complete() -> void:
	for size in [16, 32, 48, 64, 128, 256, 512, 1024]:
		for stem in ["app-icon", "mark", "mark-mono"]:
			var path := "res://assets/brand/%s-%d.png" % [stem, size]
			assert_bool(FileAccess.file_exists(path)) \
				.override_failure_message("missing %s" % path).is_true()
	for generated in ["icon-adaptive-foreground-1024.png", "icon-adaptive-background-1024.png"]:
		assert_bool(FileAccess.file_exists("res://assets/brand/" + generated)) \
			.override_failure_message("missing generated layer %s" % generated).is_true()
	assert_int(_names("res://assets/brand", ".png").size()).is_equal(26)
	assert_int(_names("res://assets/brand", ".svg").size()).is_equal(24)
	assert_int(_names("res://assets/brand/lockups", ".png").size()).is_equal(19)


## Both lockup families and the mark, in outlined vector form — the ones that
## render the same without Archivo and Inter installed.
func test_the_outlined_vectors_cover_every_lockup_family() -> void:
	var svgs := Array(_names("res://assets/brand", ".svg"))
	for stem in ["lockup-inline-dark", "lockup-stacked-dark", "inline-dark",
			"stacked-dark", "mark-dark", "mark-mono"]:
		assert_array(svgs).override_failure_message("no outlined %s.svg" % stem) \
			.contains(["%s.svg" % stem])


## docs/ is documentation, not game content. Without this Godot imports every
## font, png and svg in there and litters the repo with .import files.
func test_docs_are_not_imported_as_game_content() -> void:
	assert_bool(FileAccess.file_exists("res://docs/.gdignore")) \
		.override_failure_message("docs/.gdignore is missing — Godot will import docs/ as assets").is_true()


func test_no_import_files_are_left_under_docs() -> void:
	var strays := _import_files("res://docs")
	assert_int(strays.size()).override_failure_message(
		"%d .import files under docs/ — first few: %s" % [strays.size(), strays.slice(0, 5)]).is_equal(0)


func _import_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".import"):
			out.append("%s/%s" % [dir_path, f])
	for d in dir.get_directories():
		out.append_array(_import_files("%s/%s" % [dir_path, d]))
	return out


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
