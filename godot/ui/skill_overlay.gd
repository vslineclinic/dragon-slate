extends Control
## 스킬 별자리: 드래곤 카드를 누르면 열린다. 세 별자리(발톱 · 비늘 · 무리)를 아래 뿌리별에서 위 으뜸별까지 이어 간다.

const GameTheme = preload("res://godot/ui/theme.gd")
const Controller = preload("res://godot/ui/controller.gd")
const FusionRules = preload("res://godot/core/fusion.gd")
const BRANCHES: Array = [
	{"id": "attack", "nameKo": "니드호그 자리", "noteKo": "발톱 · 공격", "color": Color("#ff8f7a")},
	{"id": "defense", "nameKo": "현무 자리", "noteKo": "비늘 · 방어", "color": Color("#7cc4ff")},
	{"id": "pack", "nameKo": "티아마트 자리", "noteKo": "무리 · 호위", "color": Color("#9be08a")},
]
const PANEL_SIZE: Vector2 = Vector2(1000, 640)
const COLUMN_W: float = 316.0
## 별 자리(칸 안 좌표). 아래에서 위로 올라가며 좌우로 엇갈린다.
const SPOTS: Array[Vector2] = [Vector2(84, 452), Vector2(232, 346), Vector2(84, 240), Vector2(232, 132)]

signal closed


## 별 하나. state: locked(잠김) · open(찍을 수 있음) · lit(배움) · full(끝까지)
class Star extends Control:
	var tint: Color = Color.WHITE
	var state: String = "locked"
	var crown: bool = false
	var learned: bool = false

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = size.x / 2.0 - 6.0
		var lit: bool = learned
		var line: Color = tint if state == "lit" else (GameTheme.RECOMMEND if state == "open" else Color(tint, 0.35))
		if state == "full":
			line = GameTheme.GOLD_HI
		draw_circle(center + Vector2(0, 2), radius + 2.0, Color(0, 0, 0, 0.5), true, -1.0, true)
		draw_circle(center, radius, Color("#0f0e16"), true, -1.0, true)
		draw_circle(center, radius - 1.0, Color(tint, 0.34 if lit else 0.08), true, -1.0, true)
		draw_arc(center, radius, 0, TAU, 48, line.darkened(0.5), 5.0, true)
		draw_arc(center, radius, 0, TAU, 48, line, 2.5, true)
		if crown:
			for i: int in range(8):
				var out: Vector2 = Vector2.from_angle(TAU * i / 8.0 - PI / 2.0)
				draw_line(center + out * (radius + 4.0), center + out * (radius + (11.0 if i % 2 == 0 else 7.0)), Color(line, 0.85), 2.0, true)
		## 가운데 네 갈래 별빛.
		var reach: float = radius * (0.72 if lit else 0.5)
		var waist: float = reach * 0.22
		var glint: PackedVector2Array = PackedVector2Array()
		for i: int in range(8):
			var angle: float = TAU * i / 8.0 - PI / 2.0
			glint.append(center + Vector2.from_angle(angle) * (reach if i % 2 == 0 else waist))
		draw_colored_polygon(glint, Color.WHITE if lit else Color(line, 0.55))
		if lit:
			draw_circle(center, waist * 1.5, Color.WHITE, true, -1.0, true)


class Links extends Control:
	var lines: Array = []

	func _draw() -> void:
		for line: Dictionary in lines:
			var from: Vector2 = line["from"]
			var to: Vector2 = line["to"]
			var color: Color = line["color"]
			if line["lit"]:
				draw_line(from, to, Color(color, 0.25), 9.0, true)
				draw_line(from, to, color, 3.0, true)
			else:
				draw_dashed_line(from, to, Color(color, 0.4), 2.0, 8.0, true, true)


var _ctl: Controller
var _ref: Dictionary
var _body: Control


func setup(ctl: Controller, ref: Dictionary, screen: Vector2) -> void:
	_ctl = ctl
	_ref = ref
	z_index = 80
	size = screen
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
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
	var back: Panel = GameTheme.frame(_body, Rect2(Vector2.ZERO, PANEL_SIZE), GameTheme.INK, GameTheme.GOLD, 14)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	var sky: Control = Control.new()
	sky.clip_contents = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_body, sky, Rect2(4, 4, PANEL_SIZE.x - 8, PANEL_SIZE.y - 8))
	GameTheme.picture(sky, Rect2(0, 0, PANEL_SIZE.x - 8, PANEL_SIZE.y - 8), "res://assets/backgrounds/chart.png")
	var tint: Color = GameTheme.COLOR.get(spec["elements"].front(), GameTheme.GOLD)
	GameTheme.glow(_body, Vector2(60, 56), 80.0, Color(tint, 0.45))
	GameTheme.dragon(_body, Rect2(22, 16, 78, 78), inst["speciesId"])
	var level: int = FusionRules.level_of(inst)
	var need: int = FusionRules.xp_needed(_ctl.data, level)
	var growth: String = "최고 레벨" if need == 0 else "경험치 %d / %d" % [int(inst.get("xp", 0)), need]
	GameTheme.heading(_body, Rect2(112, 14, 520, 34), "%s  Lv.%d" % [spec["nameKo"], level], 26)
	var unit: Dictionary = Battle.to_unit(_ctl.data, inst)
	var escorts: int = int(_ctl.data["battle"]["escort"]["count"].get(spec["tier"], 0)) + int(unit["escortBonus"])
	GameTheme.label(_body, Rect2(112, 50, 560, 22), "체력 %d · 공격력 %d · 호위 %d마리" % [unit["hp"], unit["atk"], escorts], 15, GameTheme.TEXT)
	GameTheme.label(_body, Rect2(112, 72, 560, 20), growth + " · 싸우거나 다른 드래곤을 흡수하면 올라요", 13, GameTheme.DIM)
	var point_color: Color = GameTheme.RECOMMEND if points > 0 else GameTheme.DIM
	GameTheme.label(_body, Rect2(PANEL_SIZE.x - 330, 14, 250, 18), "스킬 점수", 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	GameTheme.heading(_body, Rect2(PANEL_SIZE.x - 330, 30, 250, 46), str(points), 38, point_color, HORIZONTAL_ALIGNMENT_RIGHT, 800)
	GameTheme.button(_body, Rect2(PANEL_SIZE.x - 64, 16, 44, 40), "✕", _close, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
	GameTheme.divider(_body, Rect2(24, 100, PANEL_SIZE.x - 48, 8), GameTheme.GOLD_DIM)
	var hint: String = "레벨이 오를 때마다 스킬 점수를 1점 받아요. 별은 아래에서 위로 이어져요." if points == 0 else "금빛으로 깜빡이는 별을 누르면 한 단계 배워요. 별은 아래에서 위로 이어져요."
	GameTheme.label(_body, Rect2(20, PANEL_SIZE.y - 32, PANEL_SIZE.x - 40, 22), hint, 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)

	var links: Links = Links.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_body, links, Rect2(Vector2.ZERO, PANEL_SIZE))
	for b: int in range(BRANCHES.size()):
		var branch: Dictionary = BRANCHES[b]
		var origin: Vector2 = Vector2(26 + b * COLUMN_W, 104)
		GameTheme.heading(_body, Rect2(origin.x, origin.y + 468, COLUMN_W, 28), branch["nameKo"], 20, branch["color"], HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.label(_body, Rect2(origin.x, origin.y + 448, COLUMN_W, 20), branch["noteKo"], 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var spot_of: Dictionary = {}
		var chain: Array = _ctl.data["skills"].values().filter(func(skill: Dictionary) -> bool: return skill["branch"] == branch["id"])
		for i: int in range(mini(chain.size(), SPOTS.size())):
			spot_of[chain[i]["id"]] = origin + SPOTS[i] - Vector2(0, 62)
		for i: int in range(mini(chain.size(), SPOTS.size())):
			var skill: Dictionary = chain[i]
			for required: String in skill.get("requires", {}):
				if spot_of.has(required):
					var met: bool = int(learned.get(required, 0)) >= int(skill["requires"][required])
					links.lines.append({"from": spot_of[required], "to": spot_of[skill["id"]], "lit": met, "color": branch["color"]})
			_draw_star(spot_of[skill["id"]], skill, inst, learned, branch["color"], i == SPOTS.size() - 1, i % 2 == 0)
	links.queue_redraw()


func _draw_star(center: Vector2, skill: Dictionary, inst: Dictionary, learned: Dictionary, tint: Color, crown: bool, text_right: bool) -> void:
	var level: int = int(learned.get(skill["id"], 0))
	var maxed: bool = level >= int(skill["max"])
	var reason: String = FusionRules.skill_rejection(_ctl.data, inst, skill["id"])
	var can: bool = reason.is_empty()
	var locked: bool = reason == "skillLocked"
	var edge: float = 76.0 if crown else 64.0
	if level > 0:
		GameTheme.glow(_body, center, edge * 0.95, Color(tint, 0.55))
	if can:
		var halo: TextureRect = GameTheme.glow(_body, center, edge * 1.0, Color(GameTheme.RECOMMEND, 0.7))
		halo.create_tween().set_loops().tween_property(halo, "modulate:a", 0.2, 0.7).from(0.7)
	var star: Star = Star.new()
	star.tint = tint
	star.crown = crown
	star.learned = level > 0
	star.state = "full" if maxed else ("open" if can else ("lit" if level > 0 else "locked"))
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_body, star, Rect2(center - Vector2(edge, edge) / 2.0, Vector2(edge, edge)))
	var text_w: float = 158.0
	var text_x: float = center.x + edge / 2.0 + 6.0 if text_right else center.x - edge / 2.0 - 6.0 - text_w
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if text_right else HORIZONTAL_ALIGNMENT_RIGHT
	var name_color: Color = GameTheme.GOLD_HI if maxed else (GameTheme.TEXT if not locked else GameTheme.DIM)
	GameTheme.heading(_body, Rect2(text_x, center.y - 40, text_w, 22), skill["nameKo"], 16, name_color, align, 600)
	var desc: Label = GameTheme.label(_body, Rect2(text_x, center.y - 18, text_w, 18), skill["descKo"], 12, GameTheme.TEXT if not locked else GameTheme.DIM, align)
	desc.clip_text = true
	var pips: String = "◆".repeat(level) + "◇".repeat(int(skill["max"]) - level)
	GameTheme.label(_body, Rect2(text_x, center.y, text_w, 18), pips, 13, tint if level > 0 else Color(tint, 0.6), align)
	var status: String = "누르면 +1" if can else ("끝까지 배웠어요" if maxed else "")
	if locked:
		var needs: PackedStringArray = PackedStringArray()
		for need: String in skill["requires"]:
			needs.append("%s %d단계" % [_ctl.data["skills"][need]["nameKo"], skill["requires"][need]])
		status = "먼저: " + ", ".join(needs)
	var status_label: Label = GameTheme.label(_body, Rect2(text_x, center.y + 18, text_w, 18), status, 11, GameTheme.RECOMMEND if can else GameTheme.DIM, align)
	status_label.clip_text = true
	var left: float = minf(text_x, center.x - edge / 2.0)
	var right: float = maxf(text_x + text_w, center.x + edge / 2.0)
	var tap: Button = GameTheme.ghost(_body, Rect2(left - 4.0, center.y - edge / 2.0 - 2.0, right - left + 8.0, edge + 4.0), _learn.bind(skill["id"]))
	tap.disabled = not can
	tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can else Control.CURSOR_ARROW
	tap.tooltip_text = "%s: %s (단계마다)" % [skill["nameKo"], skill["descKo"]]


func _learn(node: String) -> void:
	_ctl.dispatch({"type": "skill", "at": _ref, "node": node})


func _close() -> void:
	if _ctl.changed.is_connected(_on_change):
		_ctl.changed.disconnect(_on_change)
	closed.emit()
	queue_free()
