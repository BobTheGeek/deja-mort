class_name SimPredicate
extends RefCounted

## Tiny expression evaluator for the star rubric. Dotted paths, comparisons,
## && || ! and parentheses. Nothing else — a rubric is data, not a program.

static func evaluate(source: String, context: Dictionary) -> bool:
	var parser := SimPredicate.new()
	parser._tokens = parser._tokenize(source)
	parser._context = context
	var value: Variant = parser._parse_or()
	if parser._failed:
		push_error("SimPredicate: cannot parse '%s'" % source)
		return false
	return _truthy(value)


var _tokens: PackedStringArray = []
var _at: int = 0
var _context: Dictionary = {}
var _failed: bool = false


func _tokenize(source: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < source.length():
		var c := source[i]
		if c == " " or c == "\t" or c == "\n":
			i += 1
		elif source.substr(i, 2) in ["&&", "||", "==", "!=", ">=", "<="]:
			out.append(source.substr(i, 2))
			i += 2
		elif c in ["(", ")", "!", "<", ">"]:
			out.append(c)
			i += 1
		elif c == "'" or c == "\"":
			var end := source.find(c, i + 1)
			if end < 0:
				_failed = true
				break
			out.append("'" + source.substr(i + 1, end - i - 1))
			i = end + 1
		else:
			var start := i
			while i < source.length() and not (source[i] in [" ", "\t", "(", ")", "!", "<", ">", "=", "&", "|"]):
				i += 1
			if i == start:
				_failed = true
				break
			out.append(source.substr(start, i - start))
	return out


func _peek() -> String:
	return _tokens[_at] if _at < _tokens.size() else ""


func _take() -> String:
	var t := _peek()
	_at += 1
	return t


func _parse_or() -> Variant:
	var left: Variant = _parse_and()
	while _peek() == "||":
		_take()
		var right: Variant = _parse_and()
		left = _truthy(left) or _truthy(right)
	return left


func _parse_and() -> Variant:
	var left: Variant = _parse_unary()
	while _peek() == "&&":
		_take()
		var right: Variant = _parse_unary()
		left = _truthy(left) and _truthy(right)
	return left


func _parse_unary() -> Variant:
	if _peek() == "!":
		_take()
		return not _truthy(_parse_unary())
	return _parse_comparison()


func _parse_comparison() -> Variant:
	var left: Variant = _parse_primary()
	var op := _peek()
	if not (op in ["==", "!=", ">=", "<=", "<", ">"]):
		return left
	_take()
	var right: Variant = _parse_primary()
	match op:
		"==": return _equal(left, right)
		"!=": return not _equal(left, right)
		">=": return _number(left) >= _number(right)
		"<=": return _number(left) <= _number(right)
		">": return _number(left) > _number(right)
		"<": return _number(left) < _number(right)
	return false


func _parse_primary() -> Variant:
	var token := _take()
	if token == "(":
		var inner: Variant = _parse_or()
		if _peek() == ")":
			_take()
		else:
			_failed = true
		return inner
	if token.begins_with("'"):
		return token.substr(1)
	if token == "true":
		return true
	if token == "false":
		return false
	if token.is_valid_float():
		return float(token)
	if token.is_empty():
		_failed = true
		return false
	return _context.get(token, null)


## A path that resolves to nothing is false, not a crash. A rubric referring to
## a variable this room does not have should simply not award the star.
static func _truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	if value is String:
		return not (value as String).is_empty()
	return true


static func _equal(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == b
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)


static func _number(v: Variant) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v == null:
		return 0.0
	return float(v)
