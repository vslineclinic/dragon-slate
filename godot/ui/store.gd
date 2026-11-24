extends RefCounted

const PATH: String = "user://wyrmslot.cfg"
## 하던 판의 자동 저장. 규칙이나 자료가 바뀌어 옛 저장을 이어 할 수 없게 되면 RUN_VERSION을 올린다.
const RUN_PATH: String = "user://run.json"
## 데모판은 저장을 따로 둔다(정식판과 같은 폴더를 쓰므로 서로 덮어쓰지 않게).
const DEMO_RUN_PATH: String = "user://run_demo.json"
const RUN_VERSION: int = 2
const RUN_PHASES: Array[String] = ["spin", "pick", "manage", "reward", "relic", "fork", "slab"]

## 화면 캡처 · 메모리 측정 같은 도구가 켠다: 하던 판 저장 파일을 쓰지도 지우지도 않는다(사용자의 저장을 지킨다).
static var autosave_off: bool = false

var _config: ConfigFile = ConfigFile.new()
var speed: int:
	get:
		var value: int = int(_config.get_value("settings", "speed", 1))
		return value if value in [1, 2, 4] else 1
	set(value):
		if value in [1, 2, 4]:
			_config.set_value("settings", "speed", value)
			_save()


## 원정 길이: "standard"(기본 20웨이브) 또는 "long"(긴 원정 40웨이브).
var run_length: String:
	get:
		var value: String = str(_config.get_value("settings", "run_length", "standard"))
		return value if value in ["standard", "long"] else "standard"
	set(value):
		if value in ["standard", "long"]:
			_config.set_value("settings", "run_length", value)
			_save()


## 깬 지역 수(0이면 첫 지역만 열려 있다).
func stages_cleared() -> int:
	return maxi(0, int(_config.get_value("stages", "cleared", 0)))


## 그 지역에서 받은 별(0~3).
func stage_stars(index: int) -> int:
	return clampi(int(_config.get_value("stages", "stars%d" % index, 0)), 0, 3)


## 지역을 깼다: 다음 지역을 열고 별 기록을 올린다.
func record_stage(index: int, stars: int) -> void:
	_config.set_value("stages", "cleared", maxi(stages_cleared(), index + 1))
	_config.set_value("stages", "stars%d" % index, maxi(stage_stars(index), clampi(stars, 0, 3)))
	_save()


## index번째 지역으로 데려갈 용({"speciesId", "traits"}). 없으면 {}.
func carry_for(index: int) -> Dictionary:
	var found: Variant = _config.get_value("stages", "carry%d" % index, {})
	return found if found is Dictionary else {}


func set_carry(index: int, dragon: Dictionary) -> void:
	_config.set_value("stages", "carry%d" % index, {"speciesId": dragon.get("speciesId", ""), "traits": dragon.get("traits", []).duplicate()})
	_save()


## 타이틀에서 마지막으로 고른 지역. 긴 원정은 지역 수와 같은 번호.
var stage_pick: int:
	get:
		return maxi(0, int(_config.get_value("settings", "stage_pick", 0)))
	set(value):
		_config.set_value("settings", "stage_pick", maxi(0, value))
		_save()


## 궁극기를 자동으로 쓸지(끄면 전투 중에 직접 단추를 누른다).
var ult_auto: bool:
	get:
		return bool(_config.get_value("settings", "ult_auto", true))
	set(value):
		_config.set_value("settings", "ult_auto", value)
		_save()


## 판을 마친 성적으로 별 수를 매긴다: 깨면 1, 잃은 생명이 1 이하면 2, 하나도 안 잃으면 3.
static func stars_for(state: Dictionary) -> int:
	if state.get("phase") != "victory":
		return 0
	var lost: int = int(state.get("livesLost", 0))
	return 3 if lost == 0 else (2 if lost <= 1 else 1)


func _init() -> void:
	var error: Error = _config.load(PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("설정을 읽지 못했어요 (%s)" % error_string(error))


func discovered() -> PackedStringArray:
	return PackedStringArray(_config.get_value("codex", "discovered", PackedStringArray()))


func mark_discovered(id: String) -> bool:
	var found: PackedStringArray = discovered()
	if found.has(id):
		return false
	found.append(id)
	_config.set_value("codex", "discovered", found)
	_save()
	return true


static func next_unlocked(current: int, phase: String, played_level: int, max_level: int) -> int:
	if phase != "victory":
		return current
	return maxi(current, mini(max_level, played_level + 1))


func unlocked() -> int:
	var value: Variant = _config.get_value("calamity", "unlocked", 0)
	return maxi(0, value) if value is int else 0


func record_run(state: Dictionary, max_level: int) -> void:
	var current: int = unlocked()
	var next: int = next_unlocked(current, state["phase"], state["calamity"], max_level)
	if next > current:
		_config.set_value("calamity", "unlocked", next)
		_save()


func tutorial_done() -> bool:
	return _config.get_value("tutorial", "done", false) == true


func finish_tutorial() -> void:
	if not tutorial_done():
		_config.set_value("tutorial", "done", true)
		_save()


## 하던 판을 글(JSON)로 싼다. 명령 기록은 빼고 저장한다.
static func pack_run(state: Dictionary, length: String, demo: bool) -> String:
	var copy: Dictionary = state.duplicate(true)
	copy["log"] = []
	return JSON.stringify({"version": RUN_VERSION, "demo": demo, "length": length, "state": copy}, "", false)


## 저장한 글을 푼다: {"state": 상태, "length": 원정 길이}. 못 읽거나 지금 판에서 이어 할 수 없으면 {}.
static func unpack_run(text: String, data: Dictionary, demo: bool) -> Dictionary:
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var packed: Dictionary = json.data
	if int(packed.get("version", 0)) != RUN_VERSION or bool(packed.get("demo", false)) != demo or not packed.get("state") is Dictionary:
		return {}
	var state: Dictionary = GameData._normalize_numbers(packed["state"])
	if not _run_is_playable(state, data):
		return {}
	return {"state": state, "length": str(packed.get("length", "standard"))}


## 이어 할 수 있는 상태인가: 진행 중인 차례이고, 필요한 칸이 다 있고, 든 용이 모두 지금 자료에 있는 종인가.
static func _run_is_playable(state: Dictionary, data: Dictionary) -> bool:
	for key: String in ["seed", "rngState", "wave", "phase", "lives", "mana", "nest", "bench", "nestOpen", "relics", "discovered", "calamity"]:
		if not state.has(key):
			return false
	if state["phase"] not in RUN_PHASES or not state["nest"] is Array or not state["bench"] is Array:
		return false
	if int(state["wave"]) < 1 or int(state["wave"]) > int(data["waves"]["maxWave"]):
		return false
	## 고르는 차례라면 고를 것이 있어야 한다(없으면 이어 해도 나아갈 수 없다).
	match state["phase"]:
		"pick":
			if not state.get("grid") is Dictionary:
				return false
		"reward":
			if not state.get("rewardChoices") is Array or state["rewardChoices"].is_empty():
				return false
		"relic":
			if not state.get("relicChoices") is Array or state["relicChoices"].is_empty():
				return false
		"fork":
			if not state.get("forkChoices") is Array or state["forkChoices"].is_empty():
				return false
		"slab":
			if not state.get("runePending") is String or not state.get("slab") is Array:
				return false
	for key: String in ["items", "waveMod"]:
		if state.has(key) and not state[key] is Dictionary:
			return false
	for inst: Variant in state["nest"] + state["bench"]:
		if inst != null and (not inst is Dictionary or not data["dragons"].has(inst.get("speciesId", ""))):
			return false
	return true


## 지금 판(정식 · 데모)의 저장 파일.
static func run_path() -> String:
	return DEMO_RUN_PATH if OS.has_feature("demo") else RUN_PATH


## path를 비우면 지금 판의 저장 파일. 임시 파일에 다 쓴 뒤 바꿔치기해서, 쓰는 도중 꺼져도 직전 저장이 남는다.
func save_run(state: Dictionary, length: String, path: String = "") -> void:
	var real: bool = path.is_empty()
	if real and autosave_off:
		return
	var target: String = run_path() if real else path
	var draft: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(draft, FileAccess.WRITE)
	if file == null:
		push_warning("판을 저장하지 못했어요 (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(pack_run(state, length, OS.has_feature("demo")))
	var failed: bool = file.get_error() != OK
	file.close()
	if failed:
		push_warning("판을 저장하지 못했어요")
		return
	var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(draft), ProjectSettings.globalize_path(target))
	if error != OK:
		push_warning("판을 저장하지 못했어요 (%s)" % error_string(error))


func load_run(data: Dictionary, path: String = "") -> Dictionary:
	var target: String = run_path() if path.is_empty() else path
	if not FileAccess.file_exists(target):
		return {}
	return unpack_run(FileAccess.get_file_as_string(target), data, OS.has_feature("demo"))


func clear_run(path: String = "") -> void:
	var real: bool = path.is_empty()
	if real and autosave_off:
		return
	var target: String = run_path() if real else path
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _save() -> void:
	## 도구(캡처 · 메모리 측정)가 켠 동안에는 사용자의 설정 · 진행 기록도 디스크에 쓰지 않는다.
	if autosave_off:
		return
	var error: Error = _config.save(PATH)
	if error != OK:
		push_warning("설정을 저장하지 못했어요 (%s)" % error_string(error))
