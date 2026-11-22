extends SceneTree
## 화면 없이 테스트 실행:
## godot --headless --path . --script res://godot/tests/run_tests.gd
## godot/tests/test_*.gd 의 test_ 함수를 모두 돌리고, 실패가 있으면 종료 코드 1.


func _init() -> void:
	var dir := DirAccess.open("res://godot/tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var total := 0
	var failed: Array[String] = []
	for f in files:
		var script: GDScript = load("res://godot/tests/" + f)
		var inst: TestCase = script.new()
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			inst.current = f + "::" + name
			var before := inst.failures.size()
			inst.call(name)
			if inst.failures.size() > before:
				failed.append(inst.current)
		for msg in inst.failures:
			print("  ✗ " + msg)
	print("테스트 %d개 중 실패 %d개" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
