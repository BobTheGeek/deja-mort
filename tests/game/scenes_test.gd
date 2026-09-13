extends GdUnitTestSuite

## The suite tests the sim and the pieces of the UI; until now nothing checked
## that the game itself still parses.
##
## It did not. `main.gd` was merged calling a function that was never added, and
## 422 tests stayed green because every one of them builds its widget directly
## and none of them loads the scene. The game would not have started.

const SCENES: PackedStringArray = ["res://game/main.tscn", "res://game/title.tscn"]
const DIRS: PackedStringArray = ["res://game", "res://sim", "res://tools"]


func test_the_scenes_the_game_boots_actually_load() -> void:
	for path in SCENES:
		var packed := load(str(path)) as PackedScene
		assert_object(packed).override_failure_message(
			"%s does not load" % path).is_not_null()
		assert_bool(packed.can_instantiate()).override_failure_message(
			"%s loads but cannot be instantiated" % path).is_true()


func test_the_scene_the_project_boots_into_is_one_of_them() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_bool(SCENES.has(main_scene)).override_failure_message(
		"the project boots into '%s', which nothing here checks" % main_scene).is_true()


## Every script, not only the ones a test happens to instantiate.
func test_every_script_in_the_project_parses() -> void:
	var broken := PackedStringArray()
	for dir in DIRS:
		for path in _scripts(str(dir)):
			if load(path) == null:
				broken.append(path)
	assert_array(Array(broken)).override_failure_message(
		"scripts that do not parse: %s" % [broken]).is_empty()


func _scripts(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name in dir.get_files():
		if str(name).ends_with(".gd"):
			out.append("%s/%s" % [root, name])
	for name in dir.get_directories():
		out.append_array(_scripts("%s/%s" % [root, name]))
	return out
