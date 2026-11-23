extends Control
## 아래 띠: 가운데 석판(굴림 애니메이션 · 밀기 ▲▼), 오른쪽 안내 · 알 카드 3장 · 돌리기 버튼.
## 대기칸은 board.gd가 왼쪽에 그린다.

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Controller = preload("res://godot/ui/controller.gd")
const Store = preload("res://godot/ui/store.gd")
const RunRules = preload("res://godot/core/run.gd")
const SlotRules = preload("res://godot/core/slot.gd")
const HintRules = preload("res://godot/core/hints.gd")
const CELL: int = 54
const STRIDE_X: int = 62
const STRIDE_Y: int = 58
const SLAB_X: int = 296
const SLAB_Y: int = 36
const RIGHT_X: float = 530.0
const SPIN_EXTRA: int = 10

class LineOverlay extends Control:
	var paths: Array = []

	func _draw() -> void:
		for path: Dictionary in paths:
			var points: PackedVector2Array = path["points"]
			var color: Color = path["color"]
			draw_polyline(points, Color.WHITE, 7, true)
			draw_polyline(points, color, 4, true)
			for point: Vector2 in points:
				draw_circle(point, 9, Color.WHITE, true, -1.0, true)
				draw_circle(point, 6, color, true, -1.0, true)

var _ctl: Controller
var _store: Store
var _layer: Control
var _offers_layer: Control
var _spin: Button
var _hint: Label
var _reward: Label
var _opening: Tween
var _right_w: float
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(ctl: Controller, store: Store) -> void:
	_ctl = ctl
	_store = store
	_right_w = size.x - RIGHT_X - 16.0
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), GameTheme.PANEL, GameTheme.PANEL_LINE, 1)
	GameTheme.panel(self, Rect2(SLAB_X - 10, 2, STRIDE_X * 3 + 14, size.y - 4), Color("#1a1e2b"), GameTheme.PANEL_LINE, 1, 10)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_offers_layer = Control.new()
	_offers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_offers_layer)
	_hint = GameTheme.label(self, Rect2(RIGHT_X, 6, _right_w, 20), "", 14, GameTheme.DIM)
	GameTheme.wrap(_hint)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward = GameTheme.label(self, Rect2(RIGHT_X, 28, _right_w, 18), "", 12, Color("#ffe066"))
	GameTheme.wrap(_reward)
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spin = GameTheme.button(self, Rect2(RIGHT_X, size.y - 74, _right_w, 62), "", _dispatch.bind({"type": "spin"}), Color("#5f3dc4"))
	_spin.add_theme_font_size_override("font_size", 20)


func render(state: Dictionary, events: Array) -> void:
	if _opening != null:
		_opening.kill()
		_opening = null
	for layer: Control in [_layer, _offers_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_offers_layer.modulate.a = 1.0
	var spun: bool = events.any(func(event: Dictionary) -> bool: return event["t"] == "spun")
	var grid: Variant = state["grid"]
	var phase: String = state["phase"]
	var recommendation: Variant = HintRules.best_nudge(grid, state["nudgesLeft"]) if phase == "pick" else null
	if grid == null:
		for col: int in range(3):
			for row: int in range(3):
				_cell_egg(_layer, _cell(col, row), "")
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
	_spin.visible = phase != "manage"
	match phase:
		"spin": _hint.text = "석판을 돌리면 알 3개가 나와요."
		"pick":
			_hint.text = "대기칸이 꽉 찼어요. 합치거나 놓아주세요." if state["bench"].all(_occupied) else "보라 띠의 알 3개 중 하나를 골라요."
		"manage": _hint.text = "드래곤을 전장의 발판으로 끌어 놓고 전투를 시작해요."
		_: _hint.text = ""
	_hint.text = GameTheme.keep_words(_hint.text)
	_reward.position.y = _hint.position.y + _hint.get_minimum_size().y + 2.0
	_reward.text = GameTheme.keep_words(_reward_text(state, recommendation))


func _draw_grid(state: Dictionary, grid: Dictionary, recommendation: Variant, animate: bool) -> void:
	GameTheme.panel(_layer, Rect2(SLAB_X - 4, SLAB_Y + STRIDE_Y - 3, STRIDE_X * 3 - 2, CELL + 6), Color(0.439, 0.282, 0.91, 0.32), Color(0.69, 0.59, 1.0, 0.6), 1, 6)
	GameTheme.label(_layer, Rect2(SLAB_X + STRIDE_X * 3 - 4, SLAB_Y + STRIDE_Y, 40, CELL), "받을\n알 ▶", 11, Color("#d0bfff"))
	var reels: Array = []
	for col: int in range(3):
		var reel: Array = grid["reels"][col]
		var offset: int = grid["offsets"][col]
		var finals: Array = []
		for row: int in range(3):
			finals.append(SlotRules.visible(grid, col, row)["symbol"])
		if animate:
			reels.append(_spinning_column(col, finals))
		else:
			for row: int in range(3):
				_cell_egg(_layer, _cell(col, row), finals[row])
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
				points.append(_cell(coords[0], coords[1]) + Vector2(CELL, CELL) / 2.0)
			lines.paths.append({"points": points, "color": GameTheme.COLOR[group["element"]]})
	_layer.add_child(lines)
	lines.modulate.a = 0.9
	if not animate:
		return
	lines.modulate.a = 0.0
	_offers_layer.modulate.a = 0.0
	_ctl.busy = true
	var skip: Button = Button.new()
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.pressed.connect(_finish_opening.bind(skip))
	GameTheme.place(_layer, skip, Rect2(SLAB_X - 10, 0, STRIDE_X * 3 + 14, size.y))
	var pace: float = 1.0 / sqrt(float(maxi(1, _store.speed)))
	_opening = create_tween().set_parallel()
	for col: int in range(3):
		var strip: Control = reels[col]
		var stop: float = (0.6 + col * 0.18) * pace
		_opening.tween_property(strip, "position:y", float(-SPIN_EXTRA * STRIDE_Y), stop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_opening.tween_callback(_land.bind(strip)).set_delay(stop * 0.8)
	_opening.chain().tween_callback(_unlock.bind(skip))
	_opening.tween_property(lines, "modulate:a", 0.9, 0.22)
	_opening.tween_property(_offers_layer, "modulate:a", 1.0, 0.22)


## 열 하나: 잘린 창 안에서 그림 띠가 흘러가다 실제 결과에서 멈춘다. 흘러가는 그림은 장식이고 결과는 core가 정한다.
func _spinning_column(col: int, finals: Array) -> Control:
	var window: Control = Control.new()
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_layer, window, Rect2(_cell(col, 0) - Vector2(0, 2), Vector2(CELL, STRIDE_Y * 3)))
	var strip: Control = Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(strip)
	var pool: Array = GameData.active_elements(_ctl.data) + ["gold", "wild"]
	var symbols: Array = []
	for i: int in range(SPIN_EXTRA):
		symbols.append(pool[_rng.randi_range(0, pool.size() - 1)])
	symbols.append_array(finals)
	symbols.append(pool[_rng.randi_range(0, pool.size() - 1)])
	for i: int in range(symbols.size()):
		var egg: Control = _cell_egg(strip, Vector2(0, 2 + i * STRIDE_Y), symbols[i])
		egg.pivot_offset = Vector2(CELL, CELL) / 2.0
		if i >= SPIN_EXTRA and i < SPIN_EXTRA + 3:
			egg.set_meta("final", true)
	return strip


func _land(strip: Control) -> void:
	for egg: Node in strip.get_children():
		if egg is Control and egg.has_meta("final"):
			var pop: Tween = egg.create_tween()
			pop.tween_property(egg, "scale", Vector2(1.18, 1.18), 0.07)
			pop.tween_property(egg, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _cell_egg(parent: Control, at: Vector2, symbol: String) -> Control:
	var egg: Control = Marks.new(symbol, true)
	GameTheme.place(parent, egg, Rect2(at, Vector2(CELL, CELL)))
	if symbol in ["gold", "wild"]:
		GameTheme.label(egg, Rect2(0, CELL - 17, CELL, 16), "만능" if symbol == "wild" else "마력", 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	return egg


func _finish_opening(skip: Button) -> void:
	_unlock(skip)
	render(_ctl.state, [])


func _unlock(skip: Button) -> void:
	_ctl.busy = false
	if is_instance_valid(skip):
		skip.hide()
		skip.queue_free()


func _nudge_button(col: int, direction: int, symbol: String, recommendation: Variant) -> void:
	var x: float = _cell(col, 0).x
	var y: float = 4.0 if direction == -1 else SLAB_Y + STRIDE_Y * 3 - 2.0
	var recommended: bool = recommendation != null and recommendation["col"] == col and recommendation["dir"] == direction
	var tap: Button = GameTheme.button(_layer, Rect2(x, y, CELL, 28), "", _dispatch.bind({"type": "nudge", "col": col, "dir": direction}), Color("#5c4a00") if recommended else GameTheme.CARD, GameTheme.RECOMMEND if recommended else Color("#4c5470"), 2)
	GameTheme.label(tap, Rect2(8, 0, 18, 28), "▼" if direction == -1 else "▲", 16)
	GameTheme.place(tap, Marks.new(symbol), Rect2(28, 4, 20, 20))
	if recommended:
		tap.create_tween().set_loops().tween_property(tap, "modulate:a", 0.55, 0.45).from(1.0)


func _draw_offers(state: Dictionary) -> void:
	var offers: Array = [] if state["grid"] == null else SlotRules.offers_from(_ctl.data, state["grid"])
	var reco: Variant = HintRules.recommend_offer(_ctl.data, state) if state["phase"] == "pick" else null
	var card_w: float = (_right_w - 16.0) / 3.0
	for i: int in range(3):
		var rect: Rect2 = Rect2(RIGHT_X + i * (card_w + 8.0), 62, card_w, 92)
		if i >= offers.size():
			GameTheme.panel(_offers_layer, rect, GameTheme.CARD, GameTheme.PANEL_LINE, 1, 8)
			continue
		var is_reco: bool = reco != null and reco["index"] == i
		var card: Button = GameTheme.button(_offers_layer, rect, "", _dispatch.bind({"type": "pick", "index": i}), GameTheme.CARD, GameTheme.RECOMMEND if is_reco else GameTheme.PANEL_LINE, 3 if is_reco else 1)
		var offer: Dictionary = offers[i]
		var text_w: float = card_w - 84.0
		if offer["kind"] == "egg":
			var id: String = offer["speciesId"]
			var spec: Dictionary = _ctl.data["dragons"][id]
			var element: String = spec["elements"][0]
			if GameTheme.dragon(card, Rect2(4, 10, 72, 72), id) == null:
				GameTheme.place(card, Marks.new(element, true), Rect2(8, 14, 64, 64))
			var title: Label = GameTheme.label(card, Rect2(80, 8, text_w, 40), spec["nameKo"] + " 알", 16)
			title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			GameTheme.wrap(title)
			GameTheme.label(card, Rect2(80, 50, text_w, 18), "%s · %s" % [GameTheme.TIER_KO[spec["tier"]], GameTheme.SYMBOL_LABEL[element]], 12, GameTheme.DIM)
		else:
			GameTheme.place(card, Marks.new("gold", true), Rect2(8, 14, 64, 64))
			GameTheme.label(card, Rect2(80, 26, text_w, 32), "마력 +%d" % offer["amount"], 19)
		if is_reco:
			var spec: Dictionary = _ctl.data["dragons"].get(reco.get("result"), {})
			var why: String = "추천 · 합치면 " + spec.get("nameKo", "진화") if reco["reason"] == "recipe" else "추천 · 같은 원소"
			var tag: Label = GameTheme.label(card, Rect2(80, 70, text_w, 16), why, 11, Color("#ffe066"))
			tag.clip_text = true


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
			", ".join(groups), _describe(reward), " 분홍 여의주는 어떤 그림으로든 쳐요." if wild else "",
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
	return Vector2(SLAB_X + col * STRIDE_X, SLAB_Y + row * STRIDE_Y)


func _occupied(inst: Variant) -> bool:
	return inst != null


func _dispatch(command: Dictionary) -> void:
	_ctl.dispatch(command)
