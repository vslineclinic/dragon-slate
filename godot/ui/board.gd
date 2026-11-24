extends Control
## 전장 위 둥지 발판 6칸 + 왼쪽 패널의 대기칸 4칸 · 놓아주기 칸 · 전투 시작 버튼.
## 화면 전체를 덮지만 빈 곳은 입력을 통과시킨다(카드만 입력을 받음).

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Controller = preload("res://godot/ui/controller.gd")
const HintRules = preload("res://godot/core/hints.gd")
const FusionRules = preload("res://godot/core/fusion.gd")
const CARD_SIZE: Vector2 = Vector2(120, 88)

var _ctl: Controller
var _areas: Dictionary
var _layer: Control
var _battle: Button
var _preview: Panel
var _preview_text: Label
var _refs: Array[Dictionary] = []
var _drag: Control
var _from: Dictionary
var _drag_origin: Vector2
var _drag_offset: Vector2
var _fighting: bool = false
var _press_point: Vector2

signal inspect(ref: Dictionary)
## 합치면 진화하는데 갈래가 둘이다: 어느 쪽으로 갈지 물어야 한다.
signal lineage(command: Dictionary)
var _last_state: Dictionary = {}
var _team_bonus: Dictionary = {}


func setup(ctl: Controller, areas: Dictionary) -> void:
	_ctl = ctl
	_areas = areas
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 대기칸 띠: 전장 맨 아래. 왼쪽에 세로 이름표, 카드 4칸, 오른쪽에 놓아주기 칸.
	var bench: Rect2 = areas["bench"]
	var release: Rect2 = areas["release"]
	var strip: Panel = GameTheme.panel(self, Rect2(bench.position.x - 40, bench.position.y - 8, release.end.x - bench.position.x + 48, bench.size.y + 16),
		Color("#0b0b10c7"), Color(GameTheme.GOLD_DIM, 0.7), 1, 12, "flat")
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.heading(self, Rect2(bench.position.x - 34, bench.position.y + 6, 22, bench.size.y - 12), "대\n기\n칸", 14, GameTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var zone: Panel = GameTheme.panel(self, release, Color("#2a1416d9"), Color("#ff878766"), 1, 8, "flat")
	var zone_text: Label = GameTheme.label(zone, Rect2(Vector2(6, 0), release.size - Vector2(12, 0)), "여기에 놓으면\n놓아주고 마력을 받아요", 12, Color("#ffc9c9"), HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.wrap(zone_text)
	zone.name = "Release"
	_battle = GameTheme.cta(self, areas["spin"], "전투 시작", _start_battle, "ember", 23)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	move_child(_layer, 0)
	_preview = GameTheme.panel(self, Rect2(), Color("#000000cc"), GameTheme.PANEL_LINE, 0, 4)
	_preview.z_index = 42
	_preview_text = GameTheme.label(_preview, Rect2(6, 3, 0, 0), "", 17, Color("#fff3bf"))
	_preview.hide()
	for kind: String in ["nest", "bench"]:
		for i: int in range(6 if kind == "nest" else 4):
			_refs.append({"zone": kind, "index": i})


## 전투 재생 동안 둥지 카드를 숨긴다(전장에는 유닛이 대신 보임).
func set_fighting(active: bool) -> void:
	_fighting = active
	if not _last_state.is_empty():
		render(_last_state)


func render(state: Dictionary) -> void:
	_last_state = state
	## 전투력은 지금 전장의 시너지와 유물을 넣어 계산한다.
	_team_bonus = Battle.team_bonus(_ctl.data, Battle.fielded(state["nest"], state["nestOpen"]))
	var relics: Dictionary = Run.relic_bonus(_ctl.data, state)
	for kind: String in relics:
		_team_bonus[kind] = int(_team_bonus.get(kind, 0)) + int(relics[kind])
	_cancel_drag()
	for child: Node in _layer.get_children():
		_layer.remove_child(child)
		child.queue_free()
	var recommend: Dictionary = {}
	for pair: Dictionary in HintRules.evolvable_pairs(_ctl.data, state):
		recommend[_key(pair["a"])] = true
		recommend[_key(pair["b"])] = true
	var phase: String = state["phase"]
	var can_drag: bool = phase in ["manage", "pick", "spin"] and not _fighting
	var ready: bool = false
	var manage: bool = phase == "manage" and not _fighting
	for ref: Dictionary in _refs:
		var on_field: bool = ref["zone"] == "nest"
		if on_field and _fighting:
			continue
		var rect: Rect2 = _slot_rect(ref)
		var locked: bool = _locked(state, ref)
		if on_field:
			var pad_fill: Color = Color(0.04, 0.04, 0.07, 0.46 if not locked else 0.3)
			var pad_line: Color = Color(GameTheme.GOLD_HI, 0.95) if manage and not locked else Color(GameTheme.GOLD, 0.28)
			GameTheme.panel(_layer, rect, pad_fill, pad_line, 2, 12)
			GameTheme.panel(_layer, rect.grow(-5), Color.TRANSPARENT, Color(pad_line, pad_line.a * 0.35), 1, 8)
			if ref["index"] % 3 == 0:
				var header: Label = GameTheme.label(_layer, Rect2(rect.position.x, rect.position.y - 22, rect.size.x, 18),
					"전열" if ref["index"] < 3 else "후열", 13, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
				header.add_theme_constant_override("outline_size", 4)
				header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		else:
			GameTheme.well(_layer, rect, 8)
		if locked:
			GameTheme.label(_layer, rect, "잠김", 14, Color(GameTheme.TEXT, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		var inst: Variant = _at(state, ref)
		if inst != null:
			_draw_card(rect, inst, ref, can_drag and not locked, recommend.has(_key(ref)))
			if on_field and not locked:
				ready = true
	_battle.visible = manage
	_battle.disabled = not ready
	_draw_synergies(state)
	get_node("Release").visible = not _fighting


## 전장 위쪽에 원소 시너지를 보여 준다. 발동한 것은 밝게, 모으는 중인 것은 흐리게.
func _draw_synergies(state: Dictionary) -> void:
	## 대기칸 띠 바로 위 한 줄. 넘치면 위로 쌓인다.
	var field: Rect2 = _areas["field"]
	var x: float = field.position.x + 12
	var y: float = _areas["bench"].position.y - 44
	for row: Dictionary in Battle.synergies(_ctl.data, Battle.fielded(state["nest"], state["nestOpen"])):
		var active: bool = row["level"] > 0
		var goal: int = int(row["nextCount"]) if not active else int(row["count"])
		var text: String = "%s %d/%d" % [row["nameKo"], row["count"], goal]
		if active:
			text = "%s %d마리 · %s" % [row["nameKo"], row["count"], str(row["descKo"]) % int(row["value"])]
		var width: float = 42 + text.length() * 11.0
		if x + width > field.end.x - 12:
			x = field.position.x + 12
			y -= 32
		var tint: Color = GameTheme.COLOR[row["element"]]
		var chip: Panel = GameTheme.panel(_layer, Rect2(x, y, width, 28),
			Color(0.05, 0.06, 0.1, 0.85 if active else 0.55), tint if active else Color(1, 1, 1, 0.25), 2 if active else 1, 14)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark: Control = Marks.new(row["element"])
		GameTheme.place(chip, mark, Rect2(6, 4, 20, 20))
		mark.modulate.a = 1.0 if active else 0.5
		GameTheme.label(chip, Rect2(30, 3, width - 36, 22), text, 14, Color("#fff3bf") if active else GameTheme.DIM)
		x += width + 8
	## 유물: 가진 것을 금색 칩으로.
	for relic: Dictionary in _ctl.data.get("relics", []):
		if relic["id"] not in state.get("relics", []):
			continue
		var name: String = relic["nameKo"]
		var chip_w: float = 24 + name.length() * 12.0
		if x + chip_w > field.end.x - 12:
			x = field.position.x + 12
			y -= 32
		var relic_chip: Panel = GameTheme.panel(_layer, Rect2(x, y, chip_w, 28), Color(0.16, 0.12, 0.02, 0.9), Color("#d4af37"), 2, 14)
		relic_chip.tooltip_text = relic["descKo"]
		GameTheme.label(relic_chip, Rect2(0, 3, chip_w, 22), name, 13, Color("#ffe066"), HORIZONTAL_ALIGNMENT_CENTER)
		x += chip_w + 8


func _draw_card(rect: Rect2, inst: Dictionary, ref: Dictionary, draggable: bool, recommended: bool) -> void:
	var id: String = inst["speciesId"]
	var spec: Dictionary = _ctl.data["dragons"][id]
	var elements: Array = spec["elements"]
	var card: Panel = GameTheme.panel(_layer, rect, Color("#15141cf2"), GameTheme.COLOR[elements[0]], 2, 10)
	var stripe_width: float = 100.0 / elements.size()
	for i: int in range(elements.size()):
		GameTheme.panel(card, Rect2(10 + i * stripe_width, 0, stripe_width, 4), GameTheme.COLOR[elements[i]])
	GameTheme.glow(card, Vector2(60, 38), 46.0, Color(GameTheme.COLOR[elements[0]], 0.34))
	GameTheme.panel(card, Rect2(2, 66, rect.size.x - 4, 17), Color(0, 0, 0, 0.42))
	var image: TextureRect = GameTheme.dragon(card, Rect2(25, 4, 66, 66), id)
	for i: int in range(elements.size()):
		GameTheme.place(card, Marks.new(elements[i]), Rect2(92 - i * 22, 16, 20, 20))
	if recommended:
		var outline: Panel = GameTheme.panel(card, Rect2(-3, -3, 126, 94), Color.TRANSPARENT, GameTheme.RECOMMEND, 3, 10)
		outline.create_tween().set_loops().tween_property(outline, "modulate:a", 0.35, 0.5).from(1.0)
		GameTheme.label(card, Rect2(88, 37, 26, 28), "합체\n가능", 10, Color("#ffe066"), HORIZONTAL_ALIGNMENT_RIGHT)
	var tier: String = spec["tier"]
	var tier_color: Color = GameTheme.DIM if tier == "base" else Color("#ffd8a8")
	var dots: String = "●".repeat(inst["traits"].size()) + "○".repeat(maxi(0, _ctl.data["battle"]["maxTraits"] - inst["traits"].size()))
	var level: int = FusionRules.level_of(inst)
	var need: int = FusionRules.xp_needed(_ctl.data, level)
	GameTheme.panel(card, Rect2(8, rect.size.y - 5, rect.size.x - 16, 3), Color(0, 0, 0, 0.5))
	var filled: float = 1.0 if need == 0 else clampf(float(inst.get("xp", 0)) / need, 0.0, 1.0)
	GameTheme.panel(card, Rect2(8, rect.size.y - 5, (rect.size.x - 16) * filled, 3), Color("#ffd43b"))
	if image != null:
		GameTheme.label(card, Rect2(6, 4, 50, 18), "Lv.%d" % level, 12, Color("#fff3bf"))
		GameTheme.label(card, Rect2(6, 20, 50, 16), GameTheme.TIER_KO[tier], 10, GameTheme.TIER_RING[tier] if tier != "base" else tier_color)
		GameTheme.label(card, Rect2(0, 68, 120, 18), spec["nameKo"], 12, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var skill_total: int = 0
		for learned: Variant in inst.get("skills", {}).values():
			skill_total += int(learned)
		var bonus: String = " 스킬 %d" % skill_total if skill_total > 0 else ""
		GameTheme.label(card, Rect2(6, 52, 75, 16), dots + bonus, 10, GameTheme.DIM)
		var power: Label = GameTheme.label(card, Rect2(4, 35, 60, 17), "⚔%d" % Waves.unit_power(Battle.to_unit(_ctl.data, inst, _team_bonus)), 12, Color("#ffd8a8"))
		power.add_theme_constant_override("outline_size", 4)
		power.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		power.tooltip_text = "전투력"
	else:
		var title: Label = GameTheme.label(card, Rect2(8, 10, 80 if elements.size() == 1 else 60, 36), spec["nameKo"], 14)
		GameTheme.wrap(title)
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.label(card, Rect2(8, 46, 75, 20), "Lv.%d · %s" % [level, GameTheme.TIER_KO[tier]], 12, tier_color)
	var points: int = int(inst.get("skillPoints", 0))
	if points > 0:
		var badge: Panel = GameTheme.panel(card, Rect2(34, -12, 86, 20), Color("#5c4a00"), GameTheme.RECOMMEND, 2, 8)
		GameTheme.label(badge, Rect2(0, 0, 86, 20), "스킬 +%d · 눌러요" % points, 11, Color("#ffe066"), HORIZONTAL_ALIGNMENT_CENTER)
		badge.create_tween().set_loops().tween_property(badge, "modulate:a", 0.5, 0.5).from(1.0)
	if draggable:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		card.gui_input.connect(_grab.bind(card, ref))


func _grab(event: InputEvent, card: Control, ref: Dictionary) -> void:
	if _ctl.busy or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_drag = card
	_from = ref
	_drag_offset = event.position
	_press_point = card.position + event.position
	_drag_origin = card.position
	card.z_index = 40
	card.modulate.a = 0.85
	card.accept_event()


func _input(event: InputEvent) -> void:
	if _drag == null:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_drag.position = point - _drag_offset
		_show_preview(point)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var tapped: bool = point.distance_to(_press_point) < 12.0
		var command: Dictionary = {} if tapped else _drop_command(point)
		var from: Dictionary = _from
		_cancel_drag()
		get_viewport().set_input_as_handled()
		if tapped:
			inspect.emit(from)
		elif not command.is_empty():
			if command["type"] == "merge" and _branches(command).size() > 1:
				lineage.emit(command)
			else:
				_ctl.dispatch(command)


## 그 합치기가 진화라면 고를 수 있는 종(계보 선택). 흡수면 빈 배열.
func _branches(command: Dictionary) -> Array:
	var main: Variant = _at(_ctl.state, command["main"])
	var material: Variant = _at(_ctl.state, command["material"])
	if main == null or material == null or _ctl.busy:
		return []
	var preview: Dictionary = FusionRules.merge_preview(_ctl.data, main, material)
	return preview["options"] if preview["kind"] == "evolve" else []


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _drag != null:
		_cancel_drag()


func _cancel_drag() -> void:
	if _drag != null:
		_drag.position = _drag_origin
		_drag.z_index = 0
		_drag.modulate.a = 1.0
		_drag = null
	_preview.hide()


func _show_preview(point: Vector2) -> void:
	var command: Dictionary = _drop_command(point)
	var message: String = ""
	var state: Dictionary = _ctl.state
	var inst: Dictionary = _at(state, _from)
	var tier: String = _ctl.data["dragons"][inst["speciesId"]]["tier"]
	match command.get("type", ""):
		"release":
			message = "놓아주기: 마력 +%d" % _ctl.data["waves"]["releaseMana"].get(tier, 0)
		"move":
			if _locked(state, command["to"]):
				message = "잠긴 칸"
			elif command["to"]["zone"] == "nest":
				message = "전열에 배치 (먼저 맞아요)" if command["to"]["index"] < 3 else "후열에 배치 (오래 버텨요)"
			else:
				message = "대기칸으로"
		"merge":
			var preview: Dictionary = FusionRules.merge_preview(_ctl.data, _at(state, command["main"]), inst)
			if preview["kind"] == "evolve":
				var names: PackedStringArray = PackedStringArray()
				for option: String in preview["options"]:
					names.append(_ctl.data["dragons"][option]["nameKo"])
				message = "진화 → " + " 또는 ".join(names) + ("\n(놓으면 갈래를 골라요)" if names.size() > 1 else "")
			else:
				message = "흡수: 경험치 +%d" % int(preview["xp"])
				var trait_id: Variant = preview["trait"]
				if trait_id != null:
					message += ", 특성 「%s」" % _ctl.data["traits"][trait_id]["nameKo"]
				var blocked: Variant = preview["blocked"]
				if blocked != null:
					message += "\n(레벨 %d가 되면 %s(으)로 진화할 수 있어요)" % [blocked["needLevel"], _ctl.data["dragons"][blocked["result"]]["nameKo"]]
	_preview.visible = not message.is_empty()
	if _preview.visible:
		_preview_text.text = message
		_preview_text.reset_size()
		_preview.size = _preview_text.size + Vector2(12, 6)
		_preview.position = point + Vector2(16, -40)


func _drop_command(point: Vector2) -> Dictionary:
	if _areas["release"].has_point(point):
		return {"type": "release", "from": _from}
	for ref: Dictionary in _refs:
		if ref == _from or not _slot_rect(ref).has_point(point):
			continue
		if _at(_ctl.state, ref) != null:
			return {"type": "merge", "main": ref, "material": _from}
		return {"type": "move", "from": _from, "to": ref}
	return {}


func _slot_rect(ref: Dictionary) -> Rect2:
	var i: int = ref["index"]
	if ref["zone"] == "bench":
		var bench: Rect2 = _areas["bench"]
		return Rect2(bench.position + Vector2(i * (CARD_SIZE.x + 8), 0), CARD_SIZE)
	return GameTheme.pad_rect(_areas["width"], _ctl.data["battle"]["field"], i)


func _at(state: Dictionary, ref: Dictionary) -> Variant:
	return state[ref["zone"]][ref["index"]]


func _locked(state: Dictionary, ref: Dictionary) -> bool:
	return ref["zone"] == "nest" and ref["index"] >= state["nestOpen"]


func _key(ref: Dictionary) -> String:
	return "%s%d" % [ref["zone"], ref["index"]]


func _start_battle() -> void:
	_ctl.dispatch({"type": "startBattle"})
