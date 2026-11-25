extends Node
## 효과음: 짧은 소리를 여러 개 겹쳐 튼다. 배경음악처럼 root에 하나만 둔다.
## 소리 파일은 tools/music/make_sfx.py가 코드로 만든다(assets/sfx/*.wav).
## 켜고 끄기는 배경음악 설정 파일에 같이 저장한다.

const SETTINGS_PATH: String = "user://wyrmslot-music.cfg"
const VOICES: int = 10
const VOLUME_DB: float = -6.0
## 같은 소리를 너무 자주 틀지 않는다(초). 전투 타격은 한 틱에 여러 번 날 수 있다.
const MIN_GAP: Dictionary = {"hit": 0.06, "hit_strong": 0.07, "crit": 0.08, "death_enemy": 0.05, "land": 0.04, "click": 0.03}
## 소리마다 크기 보정(dB). 자주 나는 소리는 작게.
const GAIN: Dictionary = {"hit": -8.0, "hit_strong": -5.0, "death_enemy": -6.0, "click": -4.0, "land": -3.0, "spin": -4.0}

static var _instance: Node

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _on: bool = true
var _streams: Dictionary = {}
var _last: Dictionary = {}


static func get_for(tree: SceneTree) -> Node:
	if not is_instance_valid(_instance):
		_instance = load("res://godot/ui/sfx.gd").new()
		_instance.name = "Sfx"
		tree.root.add_child.call_deferred(_instance)
	return _instance


## 어디서든 한 줄로: Sfx.play(get_tree(), "line"). 장면 밖(시험 등)에서는 조용히 넘어간다.
static func play(tree: SceneTree, sound: String, pitch: float = 1.0) -> void:
	if tree == null:
		return
	get_for(tree).fire(sound, pitch)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_on = bool(config.get_value("sfx", "on", true))


func is_on() -> bool:
	return _on


func toggle() -> bool:
	_on = not _on
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("sfx", "on", _on)
	config.save(SETTINGS_PATH)
	return _on


static func sound_path(sound: String) -> String:
	return "res://assets/sfx/%s.wav" % sound


func fire(sound: String, pitch: float = 1.0) -> void:
	if not _on or not is_inside_tree():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -10.0)) < float(MIN_GAP.get(sound, 0.0)):
		return
	_last[sound] = now
	if not _streams.has(sound):
		var path: String = sound_path(sound)
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	if _streams[sound] == null:
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = VOLUME_DB + float(GAIN.get(sound, 0.0))
	player.pitch_scale = pitch
	player.play()
