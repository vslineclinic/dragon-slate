extends RefCounted

const PATH: String = "user://wyrmslot.cfg"

var _config: ConfigFile = ConfigFile.new()
var speed: int:
	get:
		var value: int = int(_config.get_value("settings", "speed", 1))
		return value if value in [1, 2, 4] else 1
	set(value):
		if value in [1, 2, 4]:
			_config.set_value("settings", "speed", value)
			_save()


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


func _save() -> void:
	var error: Error = _config.save(PATH)
	if error != OK:
		push_warning("설정을 저장하지 못했어요 (%s)" % error_string(error))
