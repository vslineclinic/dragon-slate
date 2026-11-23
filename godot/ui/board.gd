extends Control
## 전장 위 둥지 발판 6칸 + 아래 띠 대기칸 4칸 + 놓아주기 칸 + 전투 시작 버튼.
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
var _last_state: Dictionary = {}


func setup(ctl: Controller, areas: Dictionary) -> void:
	_ctl = ctl
	_areas = areas
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bench: Rect2 = areas["bench"]
	GameTheme.label(self, Rect2(bench.position.x, bench.position.y - 24, 200, 22), "대기칸", 15, GameTheme.DIM)
	var release: Rect2 = areas["release"]
	var zone: Panel = GameTheme.panel(self, release, Color("#3b2a2acc"), Color("#ff878780"), 2, 8)
	GameTheme.label(zone, Rect2(Vector2.ZERO, release.size), "여기에 놓으면\n놓아주고 마력을 받아요", 14, Color("#ffc9c9"), HORIZONTAL_ALIGNMENT_CENTER)
	zone.name = "Release"
	_battle = GameTheme.button(self, areas["spin"], "전투 시작", _start_battle, Color("#c92a2a"))
	_battle.add_theme_font_size_override("font_size", 22)
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
			var pad_fill: Color = Color(0.05, 0.06, 0.1, 0.55 if not locked else 0.35)
			var pad_line: Color = Color(1, 0.83, 0.23, 0.9) if manage and not locked else Color(1, 1, 1, 0.25)
			GameTheme.panel(_layer, rect, pad_fill, pad_line, 2, 12)
			GameTheme.label(_layer, Rect2(rect.position.x, rect.position.y - 18, rect.size.x, 16),
				"전열" if ref["index"] < 3 else "후열", 11, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			GameTheme.panel(_layer, rect, GameTheme.CARD, GameTheme.PANEL_LINE, 1, 8)
		if locked:
			GameTheme.label(_layer, rect, "잠김", 14, Color("#8a93ab"), HORIZONTAL_ALIGNMENT_CENTER)
		var inst: Variant = _at(state, ref)
		if inst != null:
			_draw_card(rect, inst, ref, can_drag and not locked, recommend.has(_key(ref)))
			if on_field and not locked:
				ready = true
	_battle.visible = manage
	_battle.disabled = not ready
	get_node("Release").visible = not _fighting


func _draw_card(rect: Rect2, inst: Dictionary, ref: Dictionary, draggable: bool, recommended: bool) -> void:
	var id: String = inst["speciesId"]
	var spec: Dictionary = _ctl.data["dragons"][id]
	var elements: Array = spec["elements"]
	var card: Panel = GameTheme.panel(_layer, rect, Color("#1e2230e6"), GameTheme.COLOR[elements[0]], 2, 10)
	var stripe_width: float = 100.0 / elements.size()
	for i: int in range(elements.size()):
		GameTheme.panel(card, Rect2(10 + i * stripe_width, 0, stripe_width, 6), GameTheme.COLOR[elements[i]])
	var image: TextureRect = GameTheme.dragon(card, Rect2(23, 7, 62, 62), id)
	for i: int in range(elements.size()):
		GameTheme.place(card, Marks.new(elements[i]), Rect2(92 - i * 22, 16, 20, 20))
	if recommended:
		var outline: Panel = GameTheme.panel(card, Rect2(-3, -3, 126, 94), Color.TRANSPARENT, GameTheme.RECOMMEND, 3, 10)
		outline.create_tween().set_loops().tween_property(outline, "modulate:a", 0.35, 0.5).from(1.0)
		GameTheme.label(card, Rect2(88, 37, 26, 28), "합체\n가능", 10, Color("#ffe066"), HORIZONTAL_ALIGNMENT_RIGHT)
	var tier: String = spec["tier"]
	var tier_color: Color = GameTheme.DIM if tier == "base" else Color("#ffd8a8")
	var dots: String = "●".repeat(inst["traits"].size()) + "○".repeat(maxi(0, _ctl.data["battle"]["maxTraits"] - inst["traits"].size()))
	if image != null:
		GameTheme.label(card, Rect2(6, 6, 50, 18), GameTheme.TIER_KO[tier], 11, tier_color)
		GameTheme.label(card, Rect2(0, 68, 120, 18), spec["nameKo"], 12, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var bonus: String = "\n+%d%%" % inst["bonusPct"] if inst["bonusPct"] else ""
		GameTheme.label(card, Rect2(6, 47, 75, 29), dots + bonus, 10, GameTheme.DIM)
	else:
		var title: Label = GameTheme.label(card, Rect2(8, 10, 80 if elements.size() == 1 else 60, 36), spec["nameKo"], 14)
		GameTheme.wrap(title)
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.label(card, Rect2(8, 46, 75, 20), GameTheme.TIER_KO[tier], 12, tier_color)
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
		var command: Dictionary = _drop_command(point)
		_cancel_drag()
		get_viewport().set_input_as_handled()
		if not command.is_empty():
			_ctl.dispatch(command)


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
				message = "진화 → " + _ctl.data["dragons"][preview["result"]]["nameKo"]
			else:
				message = "흡수: 능력치 +%d%%" % _ctl.data["battle"]["absorbBonusPct"].get(tier, 0)
				var trait_id: Variant = preview["trait"]
				if trait_id != null:
					message += ", 특성 「%s」" % _ctl.data["traits"][trait_id]["nameKo"]
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
		return Rect2(bench.position + Vector2(i % 2 * (CARD_SIZE.x + 8), i / 2 * (CARD_SIZE.y + 8)), CARD_SIZE)
	return GameTheme.pad_rect(_areas["width"], _ctl.data["battle"]["field"], i)


func _at(state: Dictionary, ref: Dictionary) -> Variant:
	return state[ref["zone"]][ref["index"]]


func _locked(state: Dictionary, ref: Dictionary) -> bool:
	return ref["zone"] == "nest" and ref["index"] >= state["nestOpen"]


func _key(ref: Dictionary) -> String:
	return "%s%d" % [ref["zone"], ref["index"]]


func _start_battle() -> void:
	_ctl.dispatch({"type": "startBattle"})
