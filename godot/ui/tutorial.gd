extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const PAPER: Color = Color("#fff3bf")
const BORDER: Color = Color("#5f3dc4")
const STEPS: Array[Dictionary] = [
	{"copy": "① 이 버튼을 눌러 룬 석판을 돌려요.", "at": Vector2(800, 538), "point": Vector2(1095, 648)},
	{"copy": "② 보라 띠의 알 3개가 오른쪽 카드로 나와요.\n하나를 고르세요. 노란 테두리가 추천이에요.", "at": Vector2(760, 270), "point": Vector2(1095, 422)},
	{"copy": "③ 대기칸의 드래곤을 위의 둥지 칸으로 끌어 놓아요.\n같은 드래곤끼리 겹치면 합체해요!", "at": Vector2(24, 246), "point": Vector2(80, 590)},
	{"copy": "④ 준비되면 전투 시작! 전투는 자동이에요.", "at": Vector2(200, 245), "point": Vector2(525, 470)},
	{"copy": "⑤ 위쪽에 다음 보스 예보가 있어요. 눌러서 대응법을 보세요.\n이제 혼자 해 볼까요? 행운을 빌어요!", "at": Vector2(420, 60), "point": Vector2(600, 44)},
]

var _store: Store
var _step: int = -1
var _balloon: Control
var _ending: Tween


func setup(store: Store) -> void:
	_store = store
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
		_show_step(STEPS[next])
	show()
	if next == STEPS.size() - 1 and _ending == null:
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
	var bounds: Vector2 = Vector2(474, 108)
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
