extends SceneTree

## Fails the build if any rule id in content/rules.json has no test, or if the
## test that covers it did not pass in the most recent gdUnit4 report.
##
##   godot --headless -s tools/rule_coverage.gd
##
## Convention: a rule with id `foo` is covered by a test named `test_rule_foo`.

const RULES := "res://content/rules.json"
const TESTS_DIR := "res://tests"
const REPORTS_DIR := "res://reports"
const PREFIX := "test_rule_"


func _initialize() -> void:
	var ids := _rule_ids()
	var declared := _declared_tests()
	var results := _latest_results()

	var missing := PackedStringArray()
	var failing := PackedStringArray()
	var unproven := PackedStringArray()

	print("rule coverage: %d rules in %s" % [ids.size(), RULES])
	for id in ids:
		var test_name := PREFIX + id
		if not declared.has(test_name):
			missing.append(id)
			print("  %-28s MISSING TEST" % id)
			continue
		if results.is_empty():
			unproven.append(id)
			print("  %-28s %s (no report)" % [id, test_name])
		elif not results.has(test_name):
			unproven.append(id)
			print("  %-28s %s (not in report)" % [id, test_name])
		elif bool(results[test_name]):
			print("  %-28s %s PASS" % [id, test_name])
		else:
			failing.append(id)
			print("  %-28s %s FAIL" % [id, test_name])

	if not missing.is_empty():
		printerr("rule coverage: FAIL — no test for: %s" % [missing])
		quit(1)
		return
	if not failing.is_empty():
		printerr("rule coverage: FAIL — failing tests for: %s" % [failing])
		quit(1)
		return
	if not unproven.is_empty():
		printerr("rule coverage: FAIL — no passing result recorded for: %s" % [unproven])
		quit(1)
		return
	print("rule coverage: OK — all %d rule ids have a passing test." % ids.size())
	quit(0)


func _rule_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(RULES)) != OK:
		printerr("rule coverage: cannot parse %s" % RULES)
		return out
	for raw in json.data:
		out.append(str((raw as Dictionary).get("id", "")))
	return out


func _declared_tests() -> Dictionary:
	var found := {}
	for path in _gd_files(TESTS_DIR):
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			var trimmed := line.strip_edges()
			if not trimmed.begins_with("func " + PREFIX):
				continue
			var name := trimmed.substr(5, trimmed.find("(") - 5)
			found[name] = path
	return found


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


## Reads the newest gdUnit4 JUnit XML: { test name: passed }.
func _latest_results() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(REPORTS_DIR)
	if dir == null:
		return out
	var runs := PackedStringArray(dir.get_directories())
	if runs.is_empty():
		return out
	var newest := ""
	var newest_n := -1
	for r in runs:
		var n := int(r.get_slice("_", r.get_slice_count("_") - 1))
		if n > newest_n:
			newest_n = n
			newest = r
	var xml_path := "%s/%s/results.xml" % [REPORTS_DIR, newest]
	if not FileAccess.file_exists(xml_path):
		return out
	print("rule coverage: reading %s" % xml_path)
	var parser := XMLParser.new()
	if parser.open(xml_path) != OK:
		return out
	var current := ""
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var tag := parser.get_node_name()
			if tag == "testcase":
				current = parser.get_named_attribute_value_safe("name")
				out[current] = true
			elif (tag == "failure" or tag == "error") and not current.is_empty():
				out[current] = false
	return out
