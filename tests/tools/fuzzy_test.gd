extends GdUnitTestSuite

## Levenshtein + nearest-token suggestion, used by tools/lint_room.gd to turn
## "unknown tag 'hides-payer'" into "did you mean 'hides-player'?".
##
## Written before the implementation.

const Fuzzy := preload("res://tools/fuzzy.gd")


func test_distance_of_a_string_to_itself_is_zero() -> void:
	assert_int(Fuzzy.distance("toaster", "toaster")).is_equal(0)


func test_distance_counts_single_edits() -> void:
	assert_int(Fuzzy.distance("kitten", "sitting")).override_failure_message(
		"the classic Levenshtein example is 3").is_equal(3)
	assert_int(Fuzzy.distance("toster", "toaster")).is_equal(1)   # one insertion
	assert_int(Fuzzy.distance("hides-payer", "hides-player")).is_equal(1)


func test_distance_handles_empty_strings() -> void:
	assert_int(Fuzzy.distance("", "abc")).is_equal(3)
	assert_int(Fuzzy.distance("abc", "")).is_equal(3)
	assert_int(Fuzzy.distance("", "")).is_equal(0)


func test_suggest_picks_the_closest_candidate() -> void:
	var tags := ["hides-player", "carryable", "flammable", "conductive"]
	assert_str(Fuzzy.suggest("hides-payer", tags)).is_equal("hides-player")
	assert_str(Fuzzy.suggest("carryabel", tags)).is_equal("carryable")


func test_suggest_is_silent_when_nothing_is_close() -> void:
	var tags := ["hides-player", "carryable"]
	assert_str(Fuzzy.suggest("toaster", tags)).override_failure_message(
		"a token unlike anything known should get no guess").is_empty()


func test_suggest_respects_the_distance_threshold() -> void:
	assert_str(Fuzzy.suggest("abcd", ["abcdefgh"], 2)).is_empty()   # 4 edits away
	assert_str(Fuzzy.suggest("abcd", ["abcde"], 2)).is_equal("abcde")


func test_suggest_on_no_candidates_is_empty() -> void:
	assert_str(Fuzzy.suggest("anything", [])).is_empty()
