extends SceneTree
## 메모리 측정(테스트 아님): 화면을 단계별로 띄우며 Godot 모니터와 프로세스 메모리를 적는다.
## godot --audio-driver Dummy --path . --position -4000,-4000 --script res://godot/tests/memprobe.gd -- <웨이브 수> [창 크기 바꾸기 0|1]
## 사용자 저장(설정 · 진행 기록 · 하던 판)은 Store.autosave_off로 쓰지도 지우지도 않는다(어느 저장 칸이든).

const Bot = preload("res://godot/tools/bot.gd")

var _base_objects: int = 0


func _init() -> void:
	## 사용자가 하던 판의 자동 저장을 건드리지 않는다.
	load("res://godot/ui/store.gd").set("autosave_off", true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var waves: int = int(args[0]) if args.size() > 0 else 10
	var resize: bool = args.size() > 1 and args[1] == "1"
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(30)
	_sample("0 빈 엔진")

	var title: Node = (load("res://godot/scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await _frames(2)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	await _frames(88)
	_sample("1 타이틀")

	title.call("_open_dex")
	await _frames(20)
	var dex: Node = title.get_child(title.get_child_count() - 1)
	for page: String in ["fire", "ice", "lightning", "poison", "steel", "abyss", "mixed"]:
		dex.call("_show_page", page)
		await _frames(15)
	_sample("2 타이틀 도감(7쪽 모두)")
	dex.call("_close")
	await _frames(30)
	_sample("3 도감 닫음")

	if resize:
		for size: Vector2i in [Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(Vector2i(-4000, -4000))
			await _frames(40)
		_sample("4 창 크기 4번 바꿈")

	title.call("_start")
	await _frames(60)
	var game: Node = title.get("_game")
	var tut: Variant = game.get("_tutorial")
	if tut != null:
		tut.call("finish")
	var ctl: Variant = game.get("controller")
	## 시작 묶음 화면을 닫고 기본 묶음으로 둔다.
	game.set("_start_open", false)
	game.call("_clear_reward")
	ctl.busy = false
	game.get("store").speed = 4
	_sample("5 게임 시작")
	_base_objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	var last_wave: int = 0
	var guard: int = 0
	while int(ctl.state["wave"]) <= waves and ctl.state["phase"] not in ["gameOver", "victory"] and guard < 200000:
		guard += 1
		await process_frame
		if ctl.busy:
			continue
		var command: Dictionary = Bot.choose(ctl.data, ctl.state)
		if command.is_empty():
			continue
		ctl.dispatch(command)
		var wave: int = int(ctl.state["wave"])
		if wave != last_wave and wave % 5 == 1 and wave > 1:
			last_wave = wave
			await _frames(30)
			_sample("6 웨이브 %d 시작" % wave)
	_sample("7 끝 (웨이브 %d, %s)" % [ctl.state["wave"], ctl.state["phase"]])

	game.call("_return_to_title")
	await _frames(60)
	_sample("8 타이틀로 돌아옴")
	quit()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame



func _sample(stage: String) -> void:
	_census(stage)
	var out: Array = []
	var command: String = "$p = Get-Process -Id %d; '{0} {1}' -f $p.WorkingSet64, $p.PrivateMemorySize64" % OS.get_process_id()
	OS.execute("powershell", ["-NoProfile", "-Command", command], out)
	var parts: PackedStringArray = str(out[0]).strip_edges().split(" ") if not out.is_empty() else PackedStringArray()
	var mb: Callable = func(v: float) -> String: return "%.0f" % (v / 1048576.0)
	print("MEM | %-26s | 작업집합 %5sMB | 전용 %5sMB | 정적 %4sMB | 텍스처 %4sMB | 버퍼 %4sMB | 비디오 %4sMB | 객체 %6d | 리소스 %5d | 노드 %5d | 고아 %4d" % [
		stage,
		mb.call(float(parts[0])) if parts.size() > 1 else "?",
		mb.call(float(parts[1])) if parts.size() > 1 else "?",
		mb.call(Performance.get_monitor(Performance.MEMORY_STATIC)),
		mb.call(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		mb.call(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		mb.call(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	])


## 노드가 어디에 쌓이는지: 부모 경로(3단계)별 자손 수 상위 6개.
func _census(stage: String) -> void:
	var counts: Dictionary = {}
	_walk(root, "", 0, counts)
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var top: PackedStringArray = PackedStringArray()
	for key: String in keys.slice(0, 8):
		top.append("%s=%d" % [key, counts[key]])
	print("NODES | %s | %s" % [stage, ", ".join(top)])


func _walk(node: Node, path: String, depth: int, counts: Dictionary) -> void:
	for child: Node in node.get_children():
		var label: String = child.name if not child.name.begins_with("@") else child.get_class()
		var script: Script = child.get_script() as Script
		if script != null:
			label += "<" + script.resource_path.get_file().get_basename() + ">"
		label += "#%d" % child.get_index()
		var name: String = path + "/" + label
		if depth == 4:
			counts[name] = int(counts.get(name, 0)) + 1 + _size(child)
		else:
			_walk(child, name, depth + 1, counts)


func _size(node: Node) -> int:
	var total: int = 0
	for child: Node in node.get_children():
		total += 1 + _size(child)
	return total
