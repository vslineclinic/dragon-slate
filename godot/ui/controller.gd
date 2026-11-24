class_name GameController
extends RefCounted

const RunRules = preload("res://godot/core/run.gd")

signal changed(events: Array, state: Dictionary)

var data: Dictionary
var state: Dictionary
var busy: bool = false
## 앞 지역에서 데려온 용({"speciesId", "traits"}). 새 판을 만들 때마다 대기칸에 넣는다.
var carry: Dictionary = {}


func _init(game_data: Dictionary, seed: int) -> void:
	data = game_data
	state = RunRules.create_run(data, seed)["state"]


func dispatch(cmd: Dictionary) -> Array:
	if busy:
		return []
	var result: Dictionary = RunRules.apply_command(data, state, cmd)
	state = result["state"]
	var events: Array = result["events"]
	changed.emit(events, state)
	return events


## start = 시작 묶음의 원소(빈 글이면 기본 묶음).
func restart(seed: int, calamity: int = -1, start: String = "") -> void:
	var level: int = state["calamity"] if calamity == -1 else calamity
	var result: Dictionary = RunRules.create_run(data, seed, level, start, carry)
	state = result["state"]
	busy = false
	changed.emit(result["events"], state)
