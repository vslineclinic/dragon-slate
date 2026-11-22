extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Controller = preload("res://godot/ui/controller.gd")
const Store = preload("res://godot/ui/store.gd")
const RunRules = preload("res://godot/core/run.gd")
const SlotRules = preload("res://godot/core/slot.gd")
const HintRules = preload("res://godot/core/hints.gd")
const CELL: int = 70
const STRIDE: int = 76

class LineOverlay extends Control:
	var paths: Array = []

	func _draw() -> void:
		for path: Dictionary in paths:
			var points: PackedVector2Array = path["points"]
			var color: Color = path["color"]
			draw_polyline(points, Color.WHITE, 8, true)
			draw_polyline(points, color, 4, true)
			for point: Vector2 in points:
				draw_circle(point, 10, Color.WHITE, true, -1.0, true)
				draw_circle(point, 7, color, true, -1.0, true)

var _ctl: Controller
var _store: Store
var _layer: Control
var _spin: Button
var _hint: Label
var _reward: Label
var _opening: Tween


func setup(ctl: Controller, store: Store) -> void:
	_ctl = ctl
	_store = store
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), GameTheme.PANEL, GameTheme.PANEL_LINE, 1)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_hint = GameTheme.label(self, Rect2(290, 8, 330, 20), "", 14, GameTheme.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward = GameTheme.label(self, Rect2(290, 32, 330, 18), "", 13, Color("#ffe066"))
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spin = GameTheme.button(self, Rect2(290, 318, 330, 56), "", _dispatch.bind({"type": "spin"}), Color("#5f3dc4"))


func render(state: Dictionary, events: Array) -> void:
	if _opening != null:
		_opening.kill()
		_opening = null
	for child: Node in _layer.get_children():
		_layer.remove_child(child)
		child.queue_free()
	var spun: bool = events.any(func(event: Dictionary) -> bool: return event["t"] == "spun")
	var grid: Variant = state["grid"]
	var phase: String = state["phase"]
	var recommendation: Variant = HintRules.best_nudge(grid, state["nudgesLeft"]) if phase == "pick" else null
	if grid == null:
		for col: int in range(3):
			for row: int in range(3):
				_egg(_cell(col, row), Vector2(CELL, CELL), "")
	else:
		_draw_grid(state, grid, recommendation, spun)
	_draw_offers(state)
	var cost: int = RunRules.spin_cost(_ctl.data, state)
	var costs: Array = _ctl.data["slot"]["rerollCosts"]
	var owned: bool = state["nest"].any(_occupied) or state["bench"].any(_occupied)
	var base_cost: int = costs[mini(state["spinsThisWave"], costs.size() - 1)] if owned and not costs.is_empty() else 0
	var price: String = "마력 %d" % cost
	if cost == 0:
		price = "보상 무료 %d회" % state["freeSpins"] if base_cost > 0 else "무료"
	_spin.text = "%s (%s)" % ["다시 돌리기" if phase == "pick" else "룬 석판 돌리기", price]
	_spin.disabled = phase not in ["spin", "pick"] or state["mana"] < cost
	match phase:
		"spin": _hint.text = "석판을 돌리면 알 3개가 나와요."
		"pick":
			_hint.text = "대기칸이 꽉 찼어요. 합치거나 놓아주세요." if state["bench"].all(_occupied) else "보라 띠의 알 3개 중 하나를 카드에서 골라요."
		"manage": _hint.text = "둥지를 정리하고 전투를 시작해요."
		_: _hint.text = ""
	_reward.position.y = _hint.position.y + _hint.get_minimum_size().y + 4.0
	_reward.text = _reward_text(state, recommendation)


func _draw_grid(state: Dictionary, grid: Dictionary, recommendation: Variant, animate: bool) -> void:
	GameTheme.panel(_layer, Rect2(24, 127, 234, 76), Color(0.439, 0.282, 0.91, 0.28))
	GameTheme.label(_layer, Rect2(256, 136, 34, 56), "받을\n알 ▶", 12, Color("#d0bfff"))
	var seconds: float = 0.26 / _store.speed
	for col: int in range(3):
		var reel: Array = grid["reels"][col]
		var offset: int = grid["offsets"][col]
		for row: int in range(3):
			var cell: Dictionary = SlotRules.visible(grid, col, row)
			var symbol: String = cell["symbol"]
			var origin: Vector2 = _cell(col, row)
			var egg: Control = _egg(origin, Vector2(CELL, CELL), symbol)
			if symbol in ["gold", "wild"]:
				GameTheme.label(egg, Rect2(0, 51, 70, 18), "만능" if symbol == "wild" else "마력", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			if animate:
				egg.pivot_offset = Vector2(35, 35)
				egg.scale.y = 0.1
				var reveal: Tween = egg.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				reveal.tween_property(egg, "scale:y", 1.0, seconds).set_delay(col * seconds * 0.6)
		if state["phase"] == "pick" and state["nudgesLeft"] > 0:
			if offset > -1:
				_nudge_button(col, -1, reel[offset]["symbol"], recommendation)
			if offset < 1:
				_nudge_button(col, 1, reel[offset + 4]["symbol"], recommendation)
	var lines: LineOverlay = LineOverlay.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for group: Dictionary in SlotRules.evaluate_lines(grid):
		for index: int in group["lines"]:
			var points: PackedVector2Array = PackedVector2Array()
			for coords: Array in SlotRules.LINES[index]:
				points.append(_cell(coords[0], coords[1]) + Vector2(35, 35))
			lines.paths.append({"points": points, "color": GameTheme.COLOR[group["element"]]})
	_layer.add_child(lines)
	lines.modulate.a = 0.9
	if animate:
		lines.modulate.a = 0.0
		_ctl.busy = true
		var skip: Button = Button.new()
		skip.flat = true
		skip.focus_mode = Control.FOCUS_NONE
		skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		skip.pressed.connect(_finish_opening.bind(skip))
		GameTheme.place(_layer, skip, Rect2(20, 4, 248, 328))
		_opening = create_tween()
		_opening.tween_interval(seconds * 2.3)
		_opening.tween_callback(_unlock.bind(skip))
		_opening.tween_property(lines, "modulate:a", 0.9, 0.2)


func _finish_opening(skip: Button) -> void:
	_unlock(skip)
	render(_ctl.state, [])


func _unlock(skip: Button) -> void:
	_ctl.busy = false
	skip.hide()
	skip.queue_free()


func _nudge_button(col: int, direction: int, symbol: String, recommendation: Variant) -> void:
	var x: float = _cell(col, 0).x
	var y: float = 14 if direction == -1 else 282
	var recommended: bool = recommendation != null and recommendation["col"] == col and recommendation["dir"] == direction
	var tap: Button = GameTheme.button(_layer, Rect2(x, y, CELL, 34), "", _dispatch.bind({"type": "nudge", "col": col, "dir": direction}), Color("#5c4a00") if recommended else GameTheme.CARD, GameTheme.RECOMMEND if recommended else Color("#4c5470"), 2)
	GameTheme.label(tap, Rect2(16, 0, 18, 34), "▼" if direction == -1 else "▲", 18)
	GameTheme.place(tap, Marks.new(symbol), Rect2(36, 6, 22, 22))
	if recommended:
		GameTheme.label(_layer, Rect2(x, y - 17 if direction == -1 else y + 34, CELL, 16), "추천", 12, Color("#ffe066"), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_offers(state: Dictionary) -> void:
	var offers: Array = [] if state["grid"] == null else SlotRules.offers_from(_ctl.data, state["grid"])
	var reco: Variant = HintRules.recommend_offer(_ctl.data, state) if state["phase"] == "pick" else null
	for i: int in range(3):
		var rect: Rect2 = Rect2(290, 92 + i * 74, 330, 68)
		if i >= offers.size():
			GameTheme.panel(_layer, rect, GameTheme.CARD, GameTheme.PANEL_LINE, 1)
			continue
		var is_reco: bool = reco != null and reco["index"] == i
		var card: Button = GameTheme.button(_layer, rect, "", _dispatch.bind({"type": "pick", "index": i}), GameTheme.CARD, GameTheme.RECOMMEND if is_reco else GameTheme.PANEL_LINE, 3 if is_reco else 1)
		var offer: Dictionary = offers[i]
		if offer["kind"] == "egg":
			var id: String = offer["speciesId"]
			var spec: Dictionary = _ctl.data["dragons"][id]
			var element: String = spec["elements"][0]
			if GameTheme.dragon(card, Rect2(4, 4, 60, 60), id) == null:
				GameTheme.place(card, Marks.new(element, true), Rect2(6, 6, 56, 56))
			GameTheme.label(card, Rect2(72, 8, 250, 24), spec["nameKo"] + " 알", 18)
			GameTheme.label(card, Rect2(72, 36, 100, 20), "%s · %s" % [GameTheme.TIER_KO[spec["tier"]], GameTheme.SYMBOL_LABEL[element]], 13, GameTheme.DIM)
		else:
			GameTheme.place(card, Marks.new("gold", true), Rect2(6, 6, 56, 56))
			GameTheme.label(card, Rect2(72, 18, 250, 32), "마력 +%d" % offer["amount"], 19)
		if is_reco:
			var spec: Dictionary = _ctl.data["dragons"].get(reco.get("result"), {})
			var why: String = "추천 · 합치면 " + spec.get("nameKo", "진화") if reco["reason"] == "recipe" else "추천 · 둥지와 같은 원소"
			GameTheme.label(card, Rect2(154, 38, 170, 18), why, 12, Color("#ffe066"), HORIZONTAL_ALIGNMENT_RIGHT)


func _reward_text(state: Dictionary, recommendation: Variant) -> String:
	if state["phase"] == "spin":
		return "같은 그림 3개가 한 줄이면 알과 마력을 더 받아요. 가로·세로·대각선 모두 돼요."
	if state["phase"] != "pick":
		return ""
	var grid: Dictionary = state["grid"]
	var reward: Dictionary = HintRules.line_rewards(_ctl.data, grid)
	if reward["lines"] > 0:
		var groups: PackedStringArray = PackedStringArray()
		var wild: bool = false
		for group: Dictionary in SlotRules.evaluate_lines(grid):
			var element: String = group["element"]
			var label: String = "황금" if element == "gold" else GameTheme.SYMBOL_LABEL[element]
			groups.append("%s %d줄" % [label, group["lines"].size()])
			for index: int in group["lines"]:
				for point: Array in SlotRules.LINES[index]:
					if SlotRules.visible(grid, point[0], point[1])["symbol"] == "wild":
						wild = true
		return "%s 맞춤! 알을 고르면 함께 받아요: %s.%s" % [
			", ".join(groups), _describe(reward), "\n분홍 여의주는 어떤 그림으로든 쳐요." if wild else "",
		]
	if recommendation != null:
		var col: int = recommendation["col"]
		var direction: int = recommendation["dir"]
		var after: Dictionary = HintRules.line_rewards(_ctl.data, SlotRules.nudge(grid, col, direction))
		return "추천: %d번째 줄의 %s를 누르면 줄이 맞아요(보너스: %s)." % [
			col + 1, "▼" if direction == -1 else "▲", _describe(after),
		]
	var gold: String = "황금 칸 보너스: 마력 +%d. " % reward["mana"] if reward["mana"] > 0 else ""
	return gold + ("▼▲를 누르면 숨은 알이 들어오며 줄이 한 칸 밀려요(웨이브당 1번)." if state["nudgesLeft"] > 0 else "")


func _describe(reward: Dictionary) -> String:
	var eggs: PackedStringArray = PackedStringArray()
	for egg: Dictionary in reward["eggs"]:
		eggs.append(GameTheme.ELEMENT_KO[egg["element"]] + (" 2티어 알 1개" if egg["tier"] == "t2" else " 알 1개"))
	var mana: String = "마력 %d" % reward["mana"] if reward["mana"] > 0 else ""
	return ", ".join(eggs) + ("와 " if not eggs.is_empty() and not mana.is_empty() else "") + mana


func _cell(col: int, row: int) -> Vector2:
	return Vector2(30 + col * STRIDE, 54 + row * STRIDE)


func _egg(at: Vector2, dimensions: Vector2, symbol: String) -> Control:
	var egg: Control = Marks.new(symbol, true)
	GameTheme.place(_layer, egg, Rect2(at, dimensions))
	return egg


func _occupied(inst: Variant) -> bool:
	return inst != null


func _dispatch(command: Dictionary) -> void:
	_ctl.dispatch(command)
