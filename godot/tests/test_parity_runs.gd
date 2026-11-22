extends TestCase

const RunRules = preload("res://godot/core/run.gd")
const FIXTURE: String = "res://godot/tests/fixtures/runs.json"


func test_typescript_run_parity() -> void:
	var fixtures: Variant = load_json(FIXTURE)
	if not fixtures is Array or fixtures.is_empty():
		assert_true(false, "판 기준 자료를 읽을 수 없음: " + FIXTURE)
		return
	var data: Dictionary = GameData.load_all()
	var checked_steps: int = 0
	for fixture: Dictionary in fixtures:
		var failures_before: int = failures.size()
		if _check_run(data, fixture):
			checked_steps += fixture["steps"].size()
		elif failures.size() == failures_before:
			assert_true(false, "시드 %d 검사 중단" % int(fixture["seed"]))
	if failures.is_empty():
		print("판 일치 검사 %d판, 명령 %d개 통과" % [fixtures.size(), checked_steps])


func _check_run(data: Dictionary, fixture: Dictionary) -> bool:
	var seed: int = int(fixture["seed"])
	var result: Dictionary = RunRules.create_run(data, seed)
	var diff: String = _result_difference(result, fixture["startEvents"], fixture["start"])
	if not diff.is_empty():
		assert_true(false, "시드 %d, 시작, %s" % [seed, diff])
		return false
	var steps: Array = fixture["steps"]
	for i: int in range(steps.size()):
		var step: Dictionary = steps[i]
		result = RunRules.apply_command(data, result["state"], step["cmd"])
		diff = _result_difference(result, step["events"], step["state"])
		if not diff.is_empty():
			assert_true(false, "시드 %d, 단계 %d (%s), %s" % [seed, i + 1, JSON.stringify(step["cmd"]), diff])
			return false
	return true


func _result_difference(result: Dictionary, expected_events: Array, expected_state: Dictionary) -> String:
	var diff: String = _first_difference(result["events"], expected_events, "events")
	if not diff.is_empty():
		return diff
	var state: Dictionary = result["state"].duplicate()
	state.erase("log")
	return _first_difference(state, expected_state, "state")


func _first_difference(actual: Variant, expected: Variant, path: String) -> String:
	if expected is Dictionary and actual is Dictionary:
		for key: String in expected:
			var child: String = path + "." + key
			if not actual.has(key):
				return child + " 키 누락"
			var diff: String = _first_difference(actual[key], expected[key], child)
			if not diff.is_empty():
				return diff
		for key: String in actual:
			if not expected.has(key):
				return path + "." + key + " 예상에 없는 키"
		return ""
	if expected is Array and actual is Array:
		for i: int in range(mini(actual.size(), expected.size())):
			var diff: String = _first_difference(actual[i], expected[i], "%s[%d]" % [path, i])
			if not diff.is_empty():
				return diff
		if actual.size() != expected.size():
			return "%s.length 기대값 %d, 실제 %d" % [path, expected.size(), actual.size()]
		return ""
	if _same(actual, expected):
		return ""
	return "%s 기대값 %s, 실제 %s" % [path, JSON.stringify(expected), JSON.stringify(actual)]
