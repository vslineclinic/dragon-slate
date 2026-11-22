class_name TestCase
extends RefCounted
## 테스트 기본 클래스. test_ 로 시작하는 함수를 run_tests.gd가 차례로 부른다.

var failures: Array[String] = []
var current := ""


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if not _same(actual, expected):
		failures.append("%s: %s 기대값 %s, 실제 %s" % [current, msg, str(expected), str(actual)])


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


## JSON에서 읽은 숫자는 float이라 int와 같은 값이면 같다고 본다
func _same(a: Variant, b: Variant) -> bool:
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return float(a) == float(b)
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return a == b


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("파일을 열 수 없음: " + path)
		return null
	return JSON.parse_string(f.get_as_text())
