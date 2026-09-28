class_name Fuzzy
extends RefCounted

## Nearest-token suggestion for the content linter. When an authored JSON
## reference names a tag, id or mesh that does not exist, this turns the bare
## "unknown 'hides-payer'" into "did you mean 'hides-player'?" — because the whole
## project is authored by hand-typing these strings, and a typo is the most
## common way a rule silently stops matching.
##
## Pure functions, no state, so tools/lint_room.gd and the tests share them.


## Levenshtein edit distance: the fewest single-character insertions, deletions
## or substitutions that turn `a` into `b`. Two-row DP, O(n·m) time, O(m) space.
static func distance(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	if n == 0:
		return m
	if m == 0:
		return n
	var prev := PackedInt32Array()
	var curr := PackedInt32Array()
	prev.resize(m + 1)
	curr.resize(m + 1)
	for j in range(m + 1):
		prev[j] = j
	for i in range(1, n + 1):
		curr[0] = i
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			curr[j] = mini(mini(prev[j] + 1, curr[j - 1] + 1), prev[j - 1] + cost)
		for j in range(m + 1):
			prev[j] = curr[j]
	return prev[m]


## The candidate closest to `name`, or "" when the nearest is further than
## `max_distance` away — a guess that is barely related is worse than none.
static func suggest(name: String, candidates: Array, max_distance: int = 2) -> String:
	var best := ""
	var best_distance := max_distance + 1
	for candidate in candidates:
		var text := str(candidate)
		var d := distance(name, text)
		if d < best_distance:
			best_distance = d
			best = text
	return best if best_distance <= max_distance else ""


## The suffix the linter appends to an error, or "" when there is nothing close.
static func hint(name: String, candidates: Array, max_distance: int = 2) -> String:
	var pick := suggest(name, candidates, max_distance)
	return "" if pick.is_empty() else " — did you mean '%s'?" % pick
