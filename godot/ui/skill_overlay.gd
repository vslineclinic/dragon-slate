extends Control
## 스킬 맵: 드래곤 카드를 누르면 열린다. 분류(발톱 · 비늘 · 무리)별로 스킬을 찍는다.

const GameTheme = preload("res://godot/ui/theme.gd")
const Controller = preload("res://godot/ui/controller.gd")
const FusionRules = preload("res://godot/core/fusion.gd")
const BRANCHES: Array = [
	{"id": "attack", "nameKo": "발톱 · 공격", "color": Color("#ff8787")},
	{"id": "defense", "nameKo": "비늘 · 방어", "color": Color("#74c0fc")},
	{"id": "pack", "nameKo": "무리 · 호위", "color": Color("#8ce99a")},
]
const PANEL_SIZE: Vector2 = Vector2(780, 440)

signal closed

var _ctl: Controller
var _ref: Dictionary
var _body: Control


func setup(ctl: Controller, ref: Dictionary, screen: Vector2) -> void:
	_ctl = ctl
	_ref = ref
	z_index = 80
	size = screen
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_dim_input)
	GameTheme.place(self, dim, Rect2(Vector2.ZERO, screen))
	_body = Control.new()
	GameTheme.place(self, _body, Rect2((screen - PANEL_SIZE) / 2.0, PANEL_SIZE))
	_ctl.changed.connect(_on_change)
	_draw_map()


func _dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _on_change(_events: Array, _state: Dictionary) -> void:
	if _inst() == null:
		_close()
	else:
		_draw_map()


func _inst() -> Variant:
	return _ctl.state[_ref["zone"]][_ref["index"]]


func _draw_map() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var inst: Variant = _inst()
	if inst == null:
		return
	var spec: Dictionary = _ctl.data["dragons"][inst["speciesId"]]
	var points: int = int(inst.get("skillPoints", 0))
	var learned: Dictionary = inst.get("skills", {})
	var back: Panel = GameTheme.panel(_body, Rect2(Vector2.ZERO, PANEL_SIZE), Color("#1b2030"), Color("#5f3dc4"), 2, 14)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	GameTheme.dragon(_body, Rect2(20, 14, 72, 72), inst["speciesId"])
	var level: int = FusionRules.level_of(inst)
	var need: int = FusionRules.xp_needed(_ctl.data, level)
	var growth: String = "최고 레벨" if need == 0 else "경험치 %d / %d" % [int(inst.get("xp", 0)), need]
	GameTheme.label(_body, Rect2(104, 16, 400, 30), "%s  Lv.%d" % [spec["nameKo"], level], 24, Color("#fff3bf"))
	GameTheme.label(_body, Rect2(104, 72, 520, 20), growth + " · 싸우거나 다른 드래곤을 흡수하면 올라요", 13, GameTheme.DIM)
	var unit: Dictionary = Battle.to_unit(_ctl.data, inst)
	var escorts: int = int(_ctl.data["battle"]["escort"]["count"].get(spec["tier"], 0)) + int(unit["escortBonus"])
	GameTheme.label(_body, Rect2(104, 50, 520, 22), "체력 %d · 공격력 %d · 호위 %d마리" % [unit["hp"], unit["atk"], escorts], 15, GameTheme.DIM)
	var point_color: Color = Color("#ffe066") if points > 0 else GameTheme.DIM
	GameTheme.label(_body, Rect2(PANEL_SIZE.x - 300, 16, 220, 30), "스킬 점수 %d" % points, 22, point_color, HORIZONTAL_ALIGNMENT_RIGHT)
	GameTheme.button(_body, Rect2(PANEL_SIZE.x - 64, 12, 48, 40), "✕", _close)
	var hint: String = "레벨이 오를 때마다 스킬 점수를 1점 받아요." if points == 0 else "찍을 스킬을 눌러요."
	GameTheme.label(_body, Rect2(20, PANEL_SIZE.y - 36, PANEL_SIZE.x - 40, 22), hint, 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)

	var column_w: float = (PANEL_SIZE.x - 40 - 24) / 3.0
	for b: int in range(BRANCHES.size()):
		var branch: Dictionary = BRANCHES[b]
		var x: float = 20 + b * (column_w + 12)
		GameTheme.panel(_body, Rect2(x, 100, column_w, 296), Color("#232838"), GameTheme.PANEL_LINE, 1, 10)
		GameTheme.label(_body, Rect2(x, 106, column_w, 26), branch["nameKo"], 17, branch["color"], HORIZONTAL_ALIGNMENT_CENTER)
		var row: int = 0
		for skill: Dictionary in _ctl.data["skills"].values():
			if skill["branch"] != branch["id"]:
				continue
			_draw_node(Rect2(x + 10, 140 + row * 126, column_w - 20, 114), skill, inst, learned, branch["color"])
			if row == 0:
				GameTheme.label(_body, Rect2(x, 252, column_w, 16), "▼", 12, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
			row += 1


func _draw_node(rect: Rect2, skill: Dictionary, inst: Dictionary, learned: Dictionary, tint: Color) -> void:
	var level: int = int(learned.get(skill["id"], 0))
	var maxed: bool = level >= int(skill["max"])
	var reason: String = FusionRules.skill_rejection(_ctl.data, inst, skill["id"])
	var can: bool = reason.is_empty()
	var locked: bool = reason == "skillLocked"
	var border: Color = GameTheme.RECOMMEND if can else (tint if level > 0 else GameTheme.PANEL_LINE)
	var node: Button = GameTheme.button(_body, rect, "", _learn.bind(skill["id"]), Color("#2b3045") if not locked else Color("#1a1d27"), border, 3 if can else 1)
	node.disabled = not can
	GameTheme.label(node, Rect2(10, 8, rect.size.x - 20, 22), skill["nameKo"], 16, GameTheme.TEXT if not locked else GameTheme.DIM)
	GameTheme.label(node, Rect2(10, 32, rect.size.x - 20, 20), skill["descKo"] + " (단계마다)", 13, GameTheme.DIM)
	var pips: String = "●".repeat(level) + "○".repeat(int(skill["max"]) - level)
	GameTheme.label(node, Rect2(10, 56, rect.size.x - 20, 20), pips, 15, tint)
	var status: String = "누르면 +1" if can else ("끝까지 찍었어요" if maxed else "")
	if locked:
		var needs: PackedStringArray = PackedStringArray()
		for need: String in skill["requires"]:
			needs.append("%s %d단계" % [_ctl.data["skills"][need]["nameKo"], skill["requires"][need]])
		status = "필요: " + ", ".join(needs)
	GameTheme.label(node, Rect2(10, 82, rect.size.x - 20, 20), status, 12, Color("#ffe066") if can else GameTheme.DIM)


func _learn(node: String) -> void:
	_ctl.dispatch({"type": "skill", "at": _ref, "node": node})


func _close() -> void:
	if _ctl.changed.is_connected(_on_change):
		_ctl.changed.disconnect(_on_change)
	closed.emit()
	queue_free()
