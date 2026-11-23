extends Node
## 배경음악: 상황에 맞는 곡을 부드럽게 바꿔 튼다. 장면이 바뀌어도 이어지도록 root에 하나만 둔다.
## 곡: title · prepare · battle_calm · battle_rush · boss · final_boss
## 모음: "a"(클로드 합성) · "b"(코덱스 합성) · "off"

const SETTINGS_PATH: String = "user://wyrmslot-music.cfg"
const SETS: Array[String] = ["a", "b", "off"]
const SET_KO: Dictionary = {"a": "♪ A", "b": "♪ B", "off": "♪ 끔"}
const FADE_SECONDS: float = 0.8
const VOLUME_DB: float = -8.0
const SILENT_DB: float = -60.0

static var _instance: Node

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _track: String = ""
var _set: String = "b"


static func get_for(tree: SceneTree) -> Node:
	if not is_instance_valid(_instance):
		_instance = load("res://godot/ui/music.gd").new()
		_instance.name = "Music"
		tree.root.add_child.call_deferred(_instance)
	return _instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: String = str(config.get_value("music", "set", "b"))
		_set = saved if saved in SETS else "b"


## 전투 배속과 상관없이 같은 빠르기로 들리게 한다.
func play(track: String) -> void:
	if track == _track:
		return
	_track = track
	if is_inside_tree():
		_start()


func _ready() -> void:
	if not _track.is_empty():
		_start()


func current_set() -> String:
	return _set


## A → B → 끔 → A 순서로 바꾸고 저장한다.
func cycle_set() -> String:
	_set = SETS[(SETS.find(_set) + 1) % SETS.size()]
	var config: ConfigFile = ConfigFile.new()
	config.set_value("music", "set", _set)
	config.save(SETTINGS_PATH)
	_start()
	return _set


static func track_path(set_name: String, track: String) -> String:
	return "res://assets/music/%s/%s.ogg" % [set_name, track]


func _start() -> void:
	var old: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var next: AudioStreamPlayer = _players[_active]
	if old.playing:
		var out: Tween = old.create_tween()
		out.tween_property(old, "volume_db", SILENT_DB, FADE_SECONDS)
		out.tween_callback(old.stop)
	var path: String = track_path(_set, _track)
	if _set == "off" or _track.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	next.create_tween().tween_property(next, "volume_db", VOLUME_DB, FADE_SECONDS)
