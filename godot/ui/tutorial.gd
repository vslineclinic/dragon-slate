extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const PAPER: Color = Color("#fff3bf")
const BORDER: Color = Color("#5f3dc4")
const BUBBLE: Vector2 = Vector2(474, 108)

var _store: Store
var _steps: Array[Dictionary] = []
var _step: int = -1
var _balloon: Control
var _ending: Tween


func setup(store: Store, areas: Dictionary = {}) -> void:
	_store = store
	if areas.is_empty():
		areas = GameTheme.areas(1280.0)
	var spin: Rect2 = areas["spin"]
	var right: Rect2 = areas["right"]
	var bubble_x: float = right.position.x + (right.size.x - BUBBLE.x) / 2.0
	var pad: Rect2 = GameTheme.pad_rect(areas["width"], {"frontX": 260, "backX": 140}, 1)
	_steps = [
		{"copy": "① 이 버튼을 눌러 룬 석판을 돌려요.", "at": Vector2(bubble_x, 524), "point": spin.get_center() + Vector2(0, -24)},
		{"copy": "② 보라 띠의 알 3개가 아래 카드로 나와요.\n하나를 고르세요. 노란 테두리가 추천이에요.", "at": Vector2(bubble_x, 366), "point": Vector2(right.get_center().x, right.position.y + 66)},
		{"copy": "③ 대기칸의 드래곤을 전장의 노란 발판으로 끌어 놓아요.\n같은 드래곤끼리 겹치면 합체해요!", "at": Vector2(pad.end.x + 40, pad.position.y - 40), "point": pad.get_center() + Vector2(40, 0)},
		{"copy": "④ 준비되면 전투 시작! 전투는 자동이에요.\n전열은 먼저 맞고, 후열은 오래 버텨요.", "at": Vector2(bubble_x, 524), "point": spin.get_center() + Vector2(0, -24)},
		{"copy": "⑤ 위쪽에 다음 보스 예보가 있어요. 눌러서 대응법을 보세요.\n이제 혼자 해 볼까요? 행운을 빌어요!", "at": Vector2(420, 60), "point": Vector2(600, 44)},
	]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85


func update(state: Dictionary) -> void:
	if _store.tutorial_done():
		return
	var next: int = _matching_step(state)
	if next < _step or next < 0:
		hide()
		return
	if _step != next:
		_step = next
		_show_step(_steps[next])
	show()
	if next == _steps.size() - 1 and _ending == null:
		_ending = create_tween()
		_ending.tween_interval(7.0)
		_ending.tween_callback(finish)


func finish() -> void:
	if _ending != null:
		_ending.kill()
		_ending = null
	_store.finish_tutorial()
	hide()


func _matching_step(state: Dictionary) -> int:
	match state["phase"]:
		"spin":
			if state["wave"] == 1:
				return 0
			if state["wave"] == 2:
				return 4
		"pick":
			return 1
		"manage":
			for dragon: Variant in state["nest"]:
				if dragon != null:
					return 3
			return 2
	return -1


func _show_step(step: Dictionary) -> void:
	if _balloon != null:
		remove_child(_balloon)
		_balloon.queue_free()
	var at: Vector2 = step["at"]
	var tip: Vector2 = step["point"] - at
	var bounds: Vector2 = BUBBLE
	_balloon = Control.new()
	_balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _balloon, Rect2(at, bounds))
	var leader: Line2D = Line2D.new()
	leader.default_color = PAPER
	leader.width = 3.0
	leader.add_point(Vector2(clampf(tip.x, 20.0, bounds.x - 20.0), 0.0 if tip.y < 0.0 else bounds.y))
	leader.add_point(tip)
	_balloon.add_child(leader)
	GameTheme.panel(_balloon, Rect2(tip - Vector2(4, 4), Vector2(8, 8)), PAPER, BORDER, 0, 4)
	var bubble: Panel = GameTheme.panel(_balloon, Rect2(Vector2.ZERO, bounds), PAPER, BORDER, 2, 12)
	var message: Label = GameTheme.label(bubble, Rect2(16, 7, 442, 61), step["copy"], 17, GameTheme.INK)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size.x = 442
	var skip: Button = GameTheme.button(bubble, Rect2(304, 69, 154, 29), "안내 건너뛰기", finish, BORDER, BORDER)
	skip.add_theme_font_size_override("font_size", 14)
