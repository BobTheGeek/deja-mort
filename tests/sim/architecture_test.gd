extends GdUnitTestSuite

## Guards the two rules that make the sim testable: no Nodes, and no randomness
## or engine clock outside the injected Rng. Cheap to run, expensive to lose.

const SIM_DIR := "res://sim"
const ALLOWED_BASES := ["RefCounted", "SimActor"]
const FORBIDDEN := [
	"get_tree(", "Input.", "randf(", "randi(", "randomize(",
	"Time.get_", "OS.get_ticks", "Engine.get_",
]


func _sim_scripts() -> PackedStringArray:
	return _gd_files(SIM_DIR)


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
	out.sort()
	return out


func test_the_sim_folder_is_not_empty() -> void:
	assert_int(_sim_scripts().size()).is_greater(10)


func test_no_sim_class_extends_a_node() -> void:
	var offenders := PackedStringArray()
	for path in _sim_scripts():
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.begins_with("extends "):
				continue
			var base := line.substr(8).strip_edges()
			if not ALLOWED_BASES.has(base):
				offenders.append("%s extends %s" % [path, base])
	assert_array(Array(offenders)).override_failure_message(
		"sim/ must be RefCounted only: %s" % [offenders]).is_empty()


func test_no_sim_script_reaches_for_the_engine() -> void:
	var offenders := PackedStringArray()
	for path in _sim_scripts():
		# rng.gd is the one place a generator is allowed to exist at all; every
		# other file must go through it.
		if path.ends_with("/rng.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for needle in FORBIDDEN:
			if text.contains(needle):
				offenders.append("%s uses %s" % [path, needle])
	assert_array(Array(offenders)).override_failure_message(
		"sim/ must stay headless and deterministic: %s" % [offenders]).is_empty()


func test_randomness_only_ever_comes_from_the_injected_rng() -> void:
	var w := preload("res://tests/support/sim_fixture.gd").world("room_01_studio", 42)
	assert_int(w.rng.seed_value()).is_equal(42)
	assert_object(w.rng).is_instanceof(SimRng)
