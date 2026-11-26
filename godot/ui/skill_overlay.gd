extends Control
## 스킬 별자리: 드래곤 카드를 누르면 열린다. 세 별자리(발톱 · 비늘 · 무리)를 아래 뿌리별에서 위 으뜸별까지 이어 간다.

const GameTheme = preload("res://godot/ui/theme.gd")
const Controller = preload("res://godot/ui/controller.gd")
const FusionRules = preload("res://godot/core/fusion.gd")
const RunRules = preload("res://godot/core/run.gd")
const Icons = preload("res://godot/ui/icons.gd")
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
## 전환의 룬으로 원소를 고르는 화면이 열려 있는지.
var _transmuting: bool = false
## 단련 화면이 열려 있는지, 그리고 방금 한 단련의 결과(한 줄).
var _tempering: bool = false
var _temper_note: String = ""
var _temper_won: bool = false
## 장비 화면이 열려 있는지.
var _gearing: bool = false


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


func _on_change(events: Array, _state: Dictionary) -> void:
	for event: Dictionary in events:
		if event["t"] == "transmuted":
			_transmuting = false
		if event["t"] == "tempered":
			_temper_won = event["ok"]
			if event["ok"]:
				_temper_note = "단련 성공! +%d이 됐어요." % int(event["to"])
			elif int(event["to"]) == int(event["from"]):
				_temper_note = "단련 실패… +%d에서 버텼어요." % int(event["to"])
			else:
				_temper_note = "단련 실패… +%d으로 내려갔어요." % int(event["to"])
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
	var runes: int = int(_ctl.state.get("items", {}).get("transmute", 0))
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
	GameTheme.heading(_body, Rect2(112, 8, 520, 34), "%s  Lv.%d" % [spec["nameKo"], level], 26)
	## 전투와 같은 값을 보여 준다: 유물은 늘, 시너지는 둥지에 놓인 드래곤일 때.
	var bonus: Dictionary = RunRules.relic_bonus(_ctl.data, _ctl.state).duplicate()
	if _ref["zone"] == "nest":
		var synergy: Dictionary = Battle.team_bonus(_ctl.data, Battle.fielded(_ctl.state["nest"], _ctl.state["nestOpen"]))
		for kind: String in synergy:
			bonus[kind] = int(bonus.get(kind, 0)) + int(synergy[kind])
	var unit: Dictionary = Battle.to_unit(_ctl.data, inst, bonus)
	var escorts: int = Battle.escort_count(_ctl.data["battle"], unit)
	var role: String = spec.get("role", "")
	var stats_line: Label = GameTheme.label(_body, Rect2(112, 42, 380, 22), "%s · 체력 %d · 공격력 %d · 호위 %d마리" % [GameTheme.ROLE_KO.get(role, ""), unit["hp"], unit["atk"], escorts], 15, GameTheme.TEXT)
	stats_line.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_line.tooltip_text = "%s: %s" % [GameTheme.ROLE_KO.get(role, ""), GameTheme.ROLE_NOTE.get(role, "")]
	var ability: String = GameTheme.ability_text(_ctl.data, inst["speciesId"])
	var ability_label: Label = GameTheme.label(_body, Rect2(112, 62, 380, 20), "능력 " + ability if not ability.is_empty() else "형태 능력 없음", 13, tint.lightened(0.45) if not ability.is_empty() else GameTheme.DIM)
	ability_label.clip_text = true
	ability_label.mouse_filter = Control.MOUSE_FILTER_STOP
	ability_label.tooltip_text = ability
	GameTheme.label(_body, Rect2(112, 80, 380, 20), growth + " · 싸우거나 다른 드래곤을 흡수하면 올라요", 13, GameTheme.DIM)
	var point_color: Color = GameTheme.RECOMMEND if points > 0 else GameTheme.DIM
	GameTheme.label(_body, Rect2(PANEL_SIZE.x - 330, 14, 250, 18), "스킬 점수", 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	GameTheme.heading(_body, Rect2(PANEL_SIZE.x - 330, 30, 250, 46), str(points), 38, point_color, HORIZONTAL_ALIGNMENT_RIGHT, 800)
	GameTheme.button(_body, Rect2(PANEL_SIZE.x - 64, 16, 44, 40), "✕", _close, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
	GameTheme.divider(_body, Rect2(24, 100, PANEL_SIZE.x - 48, 8), GameTheme.GOLD_DIM)
	if runes > 0:
		var rune_copy: String = "별자리로 돌아가기" if _transmuting else "전환의 룬 ×%d" % runes
		var rune_button: Button = GameTheme.cta(_body, Rect2(500, 10, 168, 38), rune_copy, _toggle_transmute, "mystic", 16)
		rune_button.tooltip_text = "이 드래곤을 다른 원소의 같은 드래곤으로 바꿔요"
	var temper_copy: String = "돌아가기" if _tempering else "단련 +%d" % Battle.temper_step(_ctl.data, inst)
	var temper_button: Button = GameTheme.cta(_body, Rect2(500, 54, 82, 38), temper_copy, _toggle_temper, "ember", 15)
	temper_button.tooltip_text = "마력을 내고 이 드래곤을 한 단계씩 단련해요"
	var gear_button: Button = GameTheme.cta(_body, Rect2(586, 54, 82, 38), "돌아가기" if _gearing else "장비", _toggle_gear, "gold", 15)
	gear_button.tooltip_text = "가진 장비를 이 드래곤에게 채우거나 벗겨요"
	if _transmuting and runes > 0:
		_draw_transmute(inst, spec)
		return
	if _tempering:
		_draw_temper(inst)
		return
	if _gearing:
		_draw_gear(inst)
		return
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


func _toggle_transmute() -> void:
	_transmuting = not _transmuting
	_tempering = false
	_gearing = false
	_draw_map()


func _toggle_gear() -> void:
	_gearing = not _gearing
	_transmuting = false
	_tempering = false
	_draw_map()


## 장비: 가진 장비를 늘어놓고 이 드래곤에게 채우거나 벗긴다. 제련은 상점에서 한다.
func _draw_gear(inst: Dictionary) -> void:
	var wide: float = PANEL_SIZE.x - 48
	var owned: Array = RunRules.gear_owned(_ctl.state)
	GameTheme.heading(_body, Rect2(24, 118, wide, 38), "장비", 28, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.label(_body, Rect2(24, 158, wide, 22), "드래곤 한 마리는 장비 하나를 차요. 장비는 보스 뒤 상점에서 얻고, 상점에서 제련해요.", 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if owned.is_empty():
		GameTheme.heading(_body, Rect2(24, 320, wide, 40), "아직 장비가 없어요", 24, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var gap: float = 12.0
	var card_w: float = minf(200.0, (wide - gap * (owned.size() - 1)) / owned.size())
	var left: float = (PANEL_SIZE.x - (card_w * owned.size() + gap * (owned.size() - 1))) / 2.0
	for i: int in range(owned.size()):
		var gear: Dictionary = owned[i]
		var spec: Dictionary = Battle.gear_spec(_ctl.data, str(gear["id"]))
		var mine: bool = inst.get("gear") is Dictionary and inst["gear"].get("id") == gear["id"]
		## 누가 차고 있는지.
		var wearer: String = "가방에 있어요"
		for other: Variant in _ctl.state["nest"] + _ctl.state["bench"]:
			if other != null and other.get("gear") is Dictionary and other["gear"].get("id") == gear["id"]:
				wearer = "이 드래곤이 찼어요" if mine else "%s이(가) 찼어요" % _ctl.data["dragons"][other["speciesId"]]["nameKo"]
		var origin: Vector2 = Vector2(left + i * (card_w + gap), 200)
		var card: Panel = GameTheme.frame(_body, Rect2(origin, Vector2(card_w, 330)), GameTheme.PANEL, GameTheme.GOLD_HI if mine else GameTheme.GOLD_DIM, 12)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameTheme.place(_body, Icons.new(str(spec.get("icon", "")), GameTheme.GOLD), Rect2(origin.x + (card_w - 84) / 2.0, origin.y + 16, 84, 84))
		var name_label: Label = GameTheme.heading(_body, Rect2(origin.x + 6, origin.y + 108, card_w - 12, 26), "%s +%d" % [spec.get("nameKo", ""), int(gear.get("level", 0))], 17, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.clip_text = true
		var body: Label = GameTheme.label(_body, Rect2(origin.x + 12, origin.y + 142, card_w - 24, 84), GameTheme.gear_text(_ctl.data, gear), 13, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.wrap(body)
		var where: Label = GameTheme.label(_body, Rect2(origin.x + 6, origin.y + 234, card_w - 12, 20), wearer, 12, GameTheme.RECOMMEND if mine else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		where.clip_text = true
		if mine:
			GameTheme.cta(_body, Rect2(origin.x + 14, origin.y + 268, card_w - 28, 46), "벗기기", _equip.bind(gear["id"], false), "ember", 17)
		else:
			GameTheme.cta(_body, Rect2(origin.x + 14, origin.y + 268, card_w - 28, 46), "채우기", _equip.bind(gear["id"], true), "gold", 17)
	GameTheme.label(_body, Rect2(24, 560, wide, 22), "다른 드래곤이 찬 장비를 채우면 그 드래곤은 벗어요. 차고 있던 장비는 가방으로 돌아가요.", 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)


func _equip(id: String, on: bool) -> void:
	_ctl.dispatch({"type": "equip", "gear": id, "at": _ref if on else null})


func _toggle_temper() -> void:
	_tempering = not _tempering
	_transmuting = false
	_gearing = false
	_temper_note = ""
	_draw_map()


## 단련: 지금 단계, 다음 단계가 주는 것, 성공 확률과 마력, 실패하면 어디로 내려가는지.
func _draw_temper(inst: Dictionary) -> void:
	var cfg: Dictionary = _ctl.data["battle"].get("temper", {})
	var top: int = Battle.temper_max(_ctl.data)
	var step: int = Battle.temper_step(_ctl.data, inst)
	## 형태 능력의 바탕 수치. 0이면 능력이 없는 드래곤이라 능력 강화 문구를 보여 주지 않는다.
	var ability_id: String = Battle.ability_of(_ctl.data, inst["speciesId"])
	var base_pct: int = int(_ctl.data["battle"].get("abilities", {}).get(ability_id, {}).get("pct", 0))
	var offer: Dictionary = RunRules.temper_offer(_ctl.data, inst)
	var safe: Array = cfg.get("safe", [])
	var boosts: Dictionary = cfg.get("abilityPct", {})
	var wide: float = PANEL_SIZE.x - 48
	GameTheme.heading(_body, Rect2(24, 118, wide, 38), "드래곤 단련  +%d" % step, 28, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.label(_body, Rect2(24, 158, wide, 22), "마력을 내고 한 단계씩 올려요. 단계가 오를수록 성공하기 어려워요. 실패해도 드래곤 · 레벨 · 스킬은 그대로예요.", 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	## 단계 띠: 지나온 단계는 금빛, 안전 단계는 굵은 테두리, 능력이 세지는 단계에는 표시.
	var cell: float = 78.0
	var gap: float = 10.0
	var left: float = (PANEL_SIZE.x - (cell * top + gap * (top - 1))) / 2.0
	for i: int in range(1, top + 1):
		var origin: Vector2 = Vector2(left + (i - 1) * (cell + gap), 200)
		var reached: bool = i <= step
		var is_safe: bool = safe.any(func(value: Variant) -> bool: return int(value) == i)
		var line: Color = GameTheme.GOLD_HI if reached else (GameTheme.GOLD_DIM if is_safe else GameTheme.PANEL_LINE)
		var box: Panel = GameTheme.panel(_body, Rect2(origin, Vector2(cell, 74)), Color(GameTheme.GOLD, 0.28) if reached else GameTheme.WELL, line, 3 if is_safe else 1, 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameTheme.heading(_body, Rect2(origin.x, origin.y + 6, cell, 30), "+%d" % i, 22, GameTheme.GOLD_HI if reached else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var mark: String = "안전" if is_safe else ""
		if boosts.has(str(i)) and _boost_shows(base_pct, int(boosts[str(i)])):
			mark = (mark + " · " if not mark.is_empty() else "") + "능력"
		GameTheme.label(_body, Rect2(origin.x, origin.y + 44, cell, 18), mark, 12, GameTheme.RECOMMEND if reached else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var stat_pct: int = int(cfg.get("statPct", 0))
	var boost: int = Battle.temper_boost(_ctl.data, inst)
	var now: String = "지금: 체력 · 공격력 +%d%%" % (stat_pct * step)
	if _boost_shows(base_pct, boost):
		now += " · 형태 능력 +%d%%" % boost
	GameTheme.label(_body, Rect2(24, 292, wide, 24), now if step > 0 else "아직 단련하지 않았어요.", 16, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	if not _temper_note.is_empty():
		GameTheme.heading(_body, Rect2(24, 326, wide, 32), _temper_note, 22, GameTheme.RECOMMEND if _temper_won else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if offer.is_empty():
		GameTheme.heading(_body, Rect2(24, 400, wide, 40), "끝까지 단련했어요", 26, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var gain: String = "+%d이 되면: 체력 · 공격력 +%d%%" % [offer["next"], stat_pct * int(offer["next"])]
	if boosts.has(str(offer["next"])) and _boost_shows(base_pct, int(boosts[str(offer["next"])])):
		gain += " · 형태 능력이 +%d%% 세져요" % int(boosts[str(offer["next"])])
	GameTheme.label(_body, Rect2(24, 372, wide, 24), gain, 16, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	var sure: bool = int(offer["chance"]) >= 100
	GameTheme.heading(_body, Rect2(24, 408, wide, 44), "성공 확률 %d%%" % int(offer["chance"]), 32, GameTheme.RECOMMEND if sure else GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 800)
	var fail: String = "이번 단계는 반드시 성공해요."
	if not sure:
		fail = "실패하면 +%d에 그대로 있어요." % step if int(offer["fall"]) == step else "실패하면 +%d으로 내려가요." % int(offer["fall"])
		fail += " 연달아 실패하면 다음 확률이 %d%%씩 올라요." % int(cfg.get("failAddPct", 0))
	GameTheme.label(_body, Rect2(24, 456, wide, 22), fail, 14, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var mana: int = int(_ctl.state["mana"])
	var enough: bool = mana >= int(offer["cost"])
	var go: Button = GameTheme.cta(_body, Rect2((PANEL_SIZE.x - 300) / 2.0, 496, 300, 56), "단련하기 · 마력 %d" % int(offer["cost"]), _temper, "ember", 22)
	go.disabled = not enough
	GameTheme.label(_body, Rect2(24, 560, wide, 22), "가진 마력 %d" % mana if enough else "마력이 모자라요 (가진 마력 %d)" % mana, 14, GameTheme.TEXT if enough else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)


## 그 강화가 실제로 능력 수치를 바꾸는가(정수로 잘려 그대로면 보여 주지 않는다).
func _boost_shows(base_pct: int, boost: int) -> bool:
	return boost > 0 and Rng.fdiv(base_pct * (100 + boost), 100) > base_pct


func _temper() -> void:
	_ctl.dispatch({"type": "temper", "at": _ref})


## 전환의 룬: 원소마다 어떤 드래곤이 되는지 보여 주고 고르게 한다.
func _draw_transmute(inst: Dictionary, spec: Dictionary) -> void:
	var chance: int = RunRules.transmute_chance(_ctl.data, _ctl.state)
	var sure: bool = chance >= 100
	GameTheme.heading(_body, Rect2(24, 118, PANEL_SIZE.x - 48, 34), "어느 원소로 바꿀까요?", 24, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	var rule: String = "레벨 · 스킬 · 계승 특성은 그대로 가져가요. 등급과 역할, 능력치도 같아요."
	GameTheme.label(_body, Rect2(24, 152, PANEL_SIZE.x - 48, 22), rule, 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var own: String = spec["elements"][0] if not spec["elements"].is_empty() else ""
	var targets: Array = []
	for element: String in GameData.active_elements(_ctl.data):
		var twin: String = RunRules.transmute_target(_ctl.data, inst["speciesId"], element)
		if element != own and not twin.is_empty():
			targets.append([element, twin])
	if targets.is_empty():
		GameTheme.heading(_body, Rect2(24, 300, PANEL_SIZE.x - 48, 40), "이 드래곤은 원소를 바꿀 수 없어요", 22, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.label(_body, Rect2(24, 344, PANEL_SIZE.x - 48, 24), "두 원소를 가진 드래곤과 비밀 드래곤은 전환의 룬이 듣지 않아요.", 15, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var gap: float = 14.0
	var card_w: float = minf(184.0, (PANEL_SIZE.x - 48.0 - gap * (targets.size() - 1)) / targets.size())
	var left: float = (PANEL_SIZE.x - (card_w * targets.size() + gap * (targets.size() - 1))) / 2.0
	for i: int in range(targets.size()):
		var element: String = targets[i][0]
		var twin_spec: Dictionary = _ctl.data["dragons"][targets[i][1]]
		var tint: Color = GameTheme.COLOR[element]
		var origin: Vector2 = Vector2(left + i * (card_w + gap), 190)
		var card: Panel = GameTheme.frame(_body, Rect2(origin, Vector2(card_w, 318)), GameTheme.PANEL, tint, 12)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameTheme.heading(_body, Rect2(origin.x, origin.y + 12, card_w, 26), GameTheme.ELEMENT_KO.get(element, element), 20, tint.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.glow(_body, origin + Vector2(card_w / 2.0, 118), 78.0, Color(tint, 0.5))
		GameTheme.dragon(_body, Rect2(origin.x + (card_w - 132) / 2.0, origin.y + 50, 132, 132), twin_spec["id"])
		var name_label: Label = GameTheme.heading(_body, Rect2(origin.x + 6, origin.y + 190, card_w - 12, 24), twin_spec["nameKo"], 16, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 600)
		name_label.clip_text = true
		## 같은 종을 이미 가지고 있으면 바꾼 뒤 바로 합칠 수 있다.
		var owned: bool = false
		for other: Variant in _ctl.state["nest"] + _ctl.state["bench"]:
			owned = owned or (other != null and other["speciesId"] == twin_spec["id"])
		GameTheme.label(_body, Rect2(origin.x + 6, origin.y + 216, card_w - 12, 20), "같은 드래곤이 있어 합칠 수 있어요" if owned else "", 12, GameTheme.RECOMMEND, HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.cta(_body, Rect2(origin.x + 14, origin.y + 256, card_w - 28, 46), "%s으로" % GameTheme.ELEMENT_KO.get(element, element) if element in ["ice", "poison", "abyss"] else "%s로" % GameTheme.ELEMENT_KO.get(element, element), _transmute.bind(element), "mystic", 18)
	var odds_color: Color = GameTheme.RECOMMEND if sure else GameTheme.GOLD_HI
	GameTheme.heading(_body, Rect2(24, 526, PANEL_SIZE.x - 48, 36), "성공 확률 %d%%" % chance, 26, odds_color, HORIZONTAL_ALIGNMENT_CENTER, 800)
	var fail: String = "지난번에 실패해서 이번에는 반드시 성공해요." if sure else "실패하면 룬만 부서지고 드래곤은 그대로예요. 그다음 전환은 반드시 성공해요."
	GameTheme.label(_body, Rect2(24, 562, PANEL_SIZE.x - 48, 22), fail, 14, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)


func _transmute(element: String) -> void:
	_ctl.dispatch({"type": "transmute", "at": _ref, "element": element})


func _learn(node: String) -> void:
	_ctl.dispatch({"type": "skill", "at": _ref, "node": node})


func _close() -> void:
	if _ctl.changed.is_connected(_on_change):
		_ctl.changed.disconnect(_on_change)
	closed.emit()
	queue_free()
