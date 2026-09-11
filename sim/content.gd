class_name SimContent
extends RefCounted

## The loaded JSON bundle. Every tuning number the sim reads comes from here,
## never from a literal in GDScript.

var tags: Dictionary = {}       # tag name -> group name
var rules: Array = []           # raw rule dictionaries, declaration order preserved
var verbs: Array = []           # raw verb dictionaries, wheel order
var systems: Dictionary = {}    # global tuning defaults
var notebook_templates: Dictionary = {}

var errors: PackedStringArray = []


static func load_from(dir_path: String = "res://content") -> SimContent:
	var c := SimContent.new()
	c.tags = c._flatten_tags(c._read_json(dir_path + "/tags.json", {}))
	c.rules = c._read_json(dir_path + "/rules.json", [])
	c.verbs = c._read_json(dir_path + "/verbs.json", [])
	c.systems = c._read_json(dir_path + "/systems.json", {})
	return c


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Dotted lookup into the systems block: system("wet.rate_tiles_per_s").
## Missing keys are a loud failure, not a silent default — a missing tuning
## number must never be papered over with a literal.
func system(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = systems
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			if fallback == null:
				push_error("SimContent: missing systems key '%s'" % path)
			return fallback
	return node


## Room `systems` blocks override globals one level deep.
func merged_systems(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = systems.duplicate(true)
	for key in overrides:
		if out.has(key) and out[key] is Dictionary and overrides[key] is Dictionary:
			var merged: Dictionary = (out[key] as Dictionary).duplicate(true)
			merged.merge(overrides[key] as Dictionary, true)
			out[key] = merged
		else:
			out[key] = overrides[key]
	return out


func _flatten_tags(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Array:
		for t in raw:
			out[str(t)] = ""
	elif raw is Dictionary:
		for group in raw:
			var entry: Variant = raw[group]
			if entry is Array:
				for t in entry:
					out[str(t)] = str(group)
			else:
				out[str(group)] = ""
	return out


func _read_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing %s" % path)
		return fallback
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return fallback
	return json.data
