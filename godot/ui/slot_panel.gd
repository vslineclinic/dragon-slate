extends Control
## 왼쪽 패널: 안내 문구, 석판(굴림 애니메이션 · 밀기 ▲▼), 알 카드 3장(세로), 돌리기 버튼.
## 대기칸과 놓아주기 칸은 board.gd가 그 아래에 그린다.

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Controller = preload("res://godot/ui/controller.gd")
const Store = preload("res://godot/ui/store.gd")
const RunRules = preload("res://godot/core/run.gd")
const SlotRules = preload("res://godot/core/slot.gd")
const HintRules = preload("res://godot/core/hints.gd")
const CELL: int = 64
const STRIDE_X: int = 70
const STRIDE_Y: int = 70
const SLAB_X: int = 53
const SLAB_Y: int = int(GameTheme.SLAB_TOP)
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
	_right_w = size.x - 32.0
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#14131b"))
	GameTheme.picture(self, Rect2(Vector2.ZERO, size), "res://assets/backgrounds/chart.png").modulate = Color(1, 1, 1, 0.5)
	GameTheme.panel(self, Rect2(size.x - 2, 0, 2, size.y), Color(GameTheme.GOLD_DIM, 0.7))
	## 룬 석판: 금박 테두리 돌판.
	GameTheme.frame(self, Rect2(SLAB_X - 8, SLAB_Y - 32, STRIDE_X * 3 + 10, STRIDE_Y * 3 + 62), Color("#1a1922"), GameTheme.GOLD_DIM, 10)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_offers_layer = Control.new()
	_offers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_offers_layer)
	_hint = GameTheme.label(self, Rect2(16, 4, _right_w, 20), "", 14, GameTheme.DIM)
	GameTheme.wrap(_hint)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward = GameTheme.label(self, Rect2(16, 26, _right_w, 18), "", 12, Color("#ffe066"))
	GameTheme.wrap(_reward)
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spin = GameTheme.cta(self, Rect2(16, GameTheme.SPIN_TOP, _right_w, 54), "", _dispatch.bind({"type": "spin"}), "gold", 21)


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
	_draw_slab_strip(state)
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
			_hint.text = "대기칸이 꽉 찼어요. 합치거나 놓아주세요." if state["bench"].all(_occupied) else "금빛 띠의 알 3개 중 하나를 골라요."
		"manage": _hint.text = "드래곤을 전장의 발판으로 끌어 놓고 전투를 시작해요."
		_: _hint.text = ""
	_hint.text = GameTheme.keep_words(_hint.text)
	_reward.position.y = _hint.position.y + _hint.get_minimum_size().y + 2.0
	_reward.text = GameTheme.keep_words(_reward_text(state, recommendation))


## 내 석판의 룬 묶음: 무늬마다 몇 칸인지 석판 위에 한 줄로 보여 준다.
func _draw_slab_strip(state: Dictionary) -> void:
	var slab: Array = state.get("slab", [])
	if slab.is_empty():
		return
	## 석판 틀 위쪽에 따로 한 줄(틀 안의 밀기 단추와 겹치지 않게).
	var stride: float = (size.x - 32.0) / 8.0
	var x: float = 16.0 + (stride - 30.0) / 2.0
	for symbol: String in GameData.active_elements(_ctl.data) + ["gold", "wild"]:
		var count: int = slab.count(symbol)
		var mark: Marks = Marks.new(symbol)
		mark.modulate.a = 1.0 if count > 0 else 0.3
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		mark.tooltip_text = "내 석판: %s 룬 %d칸 (모두 %d칸). 칸마다 이 묶음에서 하나가 나와요." % [GameTheme.SYMBOL_LABEL.get(symbol, symbol), count, slab.size()]
		GameTheme.place(_layer, mark, Rect2(x, SLAB_Y - 56, 16, 16))
		GameTheme.label(_layer, Rect2(x + 18, SLAB_Y - 59, 14, 20), str(count), 13, GameTheme.TEXT if count > 0 else GameTheme.DIM)
		x += stride


func _draw_grid(state: Dictionary, grid: Dictionary, recommendation: Variant, animate: bool) -> void:
	GameTheme.panel(_layer, Rect2(SLAB_X - 4, SLAB_Y + STRIDE_Y - 3, STRIDE_X * 3 + 2, CELL + 6), Color(GameTheme.GOLD, 0.2), Color(GameTheme.GOLD_HI, 0.75), 1, 8, "flat")
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
	GameTheme.place(_layer, skip, Rect2(SLAB_X - 8, SLAB_Y - 32, STRIDE_X * 3 + 10, STRIDE_Y * 3 + 62))
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
	var y: float = SLAB_Y - 30.0 if direction == -1 else SLAB_Y + STRIDE_Y * 3 - 4.0
	var recommended: bool = recommendation != null and recommendation["col"] == col and recommendation["dir"] == direction
	var tap: Button = GameTheme.button(_layer, Rect2(x, y, CELL, 28), "", _dispatch.bind({"type": "nudge", "col": col, "dir": direction}), Color("#5c4a00") if recommended else GameTheme.CARD, GameTheme.RECOMMEND if recommended else Color("#5a4d38"), 2)
	GameTheme.label(tap, Rect2(12, 0, 18, 28), "▼" if direction == -1 else "▲", 16)
	GameTheme.place(tap, Marks.new(symbol), Rect2(34, 4, 20, 20))
	if recommended:
		tap.create_tween().set_loops().tween_property(tap, "modulate:a", 0.55, 0.45).from(1.0)


func _draw_offers(state: Dictionary) -> void:
	var offers: Array = [] if state["grid"] == null else SlotRules.offers_from(_ctl.data, state["grid"])
	var reco: Variant = HintRules.recommend_offer(_ctl.data, state) if state["phase"] == "pick" else null
	## 알 카드 3장: 석판 바로 아래에 세로로.
	var card_w: float = size.x - 32.0
	for i: int in range(3):
		var rect: Rect2 = Rect2(16, GameTheme.OFFER_TOP + i * GameTheme.OFFER_STEP, card_w, GameTheme.OFFER_STEP - 4.0)
		if i >= offers.size():
			GameTheme.well(_offers_layer, rect, 8)
			continue
		var is_reco: bool = reco != null and reco["index"] == i
		var card: Button = GameTheme.button(_offers_layer, rect, "", _dispatch.bind({"type": "pick", "index": i}), GameTheme.CARD, GameTheme.RECOMMEND if is_reco else GameTheme.PANEL_LINE, 3 if is_reco else 1)
		var offer: Dictionary = offers[i]
		var text_w: float = card_w - 64.0
		if offer["kind"] == "egg":
			var id: String = offer["speciesId"]
			var spec: Dictionary = _ctl.data["dragons"][id]
			var element: String = spec["elements"][0]
			if GameTheme.dragon(card, Rect2(3, 6, 58, 58), id) == null:
				GameTheme.place(card, Marks.new(element, true), Rect2(8, 11, 48, 48))
			## 네 줄: 이름 / 전투력 · 등급 · 역할 · 강약 / 능력 · 다음 보스 상성 / 등장 확률(오른쪽에 추천 이유).
			var brief: Dictionary = GameTheme.dragon_brief(_ctl.data, id)
			var title: Label = GameTheme.label(card, Rect2(62, 1, text_w, 20), spec["nameKo"] + " 알", 14)
			title.clip_text = true
			## 전투력은 둘째 줄 맨 앞에("새 용!" 꼬리표가 오른쪽 위를 쓴다).
			var power: Label = GameTheme.label(card, Rect2(62, 19, 40, 18), "⚔%d" % int(brief["power"]), 13, Color("#ffd8a8"))
			power.add_theme_font_override("font", GameTheme.bold_font())
			GameTheme.label(card, Rect2(102, 20, text_w - 40, 16), "%s · %s · %s" % [brief["tier"], brief["role"], brief["grade"]], 11, brief["gradeColor"])
			var odds: int = SlotRules.species_odds(_ctl.data, id, state.get("slab", []))
			var rarity: Array = GameTheme.rarity(SlotRules.species_weight(_ctl.data, id))
			GameTheme.label(card, Rect2(62, 50, 62, 16), "%s %s" % [rarity[0], GameTheme.percent(odds)], 11, rarity[1])
			var third: PackedStringArray = PackedStringArray()
			if not str(brief["ability"]).is_empty():
				third.append("능력 「%s」" % brief["ability"])
			var matchup: String = GameTheme.boss_matchup(_ctl.data, state, id)
			if not matchup.is_empty():
				third.append("다음 보스에 " + matchup)
			var third_color: Color = Color("#ff8f7a") if matchup == "약함" else (Color("#8ce99a") if matchup == "강함" else GameTheme.DIM)
			var detail: Label = GameTheme.label(card, Rect2(62, 35, text_w, 16), " · ".join(third), 11, third_color)
			detail.clip_text = true
			var ability_text: String = GameTheme.ability_text(_ctl.data, id)
			card.tooltip_text = "%s (%s · %s)\n체력 %d · 공격력 %d · 전투력 %d (같은 등급에서 %s)\n%s" % [
				spec["nameKo"], brief["tier"], brief["role"], int(spec["stats"]["hp"]), int(spec["stats"]["atk"]), int(brief["power"]), brief["grade"],
				"능력 " + ability_text if not ability_text.is_empty() else "형태 능력 없음",
			]
			if not _store.discovered().has(id):
				GameTheme.new_badge(card, rect.size)
		else:
			GameTheme.place(card, Marks.new("gold", true), Rect2(8, 11, 48, 48))
			GameTheme.label(card, Rect2(62, 19, text_w, 32), "마력 +%d" % offer["amount"], 17)
		if is_reco:
			var spec: Dictionary = _ctl.data["dragons"].get(reco.get("result"), {})
			## 추천 이유는 넷째 줄 오른쪽에(다른 줄의 글자와 겹치지 않는다). 길면 잘리고, 전문은 마우스를 올리면 보인다.
			var long_why: String = "추천: 가진 용과 합치면 %s(으)로 진화해요" % spec.get("nameKo", "윗계급 용") if reco["reason"] == "recipe" else "추천: 가진 용과 같은 원소예요"
			var why: String = "추천 → " + spec.get("nameKo", "진화") if reco["reason"] == "recipe" else "추천 · 같은 원소"
			var tag: Label = GameTheme.label(card, Rect2(126, 50, card_w - 134, 16), why, 11, Color("#ffe066"), HORIZONTAL_ALIGNMENT_RIGHT)
			tag.clip_text = true
			card.tooltip_text = long_why + ("\n" + card.tooltip_text if not card.tooltip_text.is_empty() else "")


func _reward_text(state: Dictionary, recommendation: Variant) -> String:
	if state["phase"] == "spin":
		return "같은 그림 3개가 한 줄이면 알과 마력을 더 받아요. 가로·세로·대각선 모두 돼요."
	if state["phase"] != "pick":
		return ""
	var grid: Dictionary = state["grid"]
	var crown: bool = RunRules.relic_bonus(_ctl.data, _ctl.state).has("wildLineEgg")
	var reward: Dictionary = HintRules.line_rewards(_ctl.data, grid, crown)
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
		var after: Dictionary = HintRules.line_rewards(_ctl.data, SlotRules.nudge(grid, col, direction), crown)
		return "추천: %d번째 줄의 %s를 누르면 줄이 맞아요(보너스: %s)." % [
			col + 1, "▼" if direction == -1 else "▲", _describe(after),
		]
	var gold: String = "황금 칸 보너스: 마력 +%d. " % reward["mana"] if reward["mana"] > 0 else ""
	return gold + ("▼▲를 누르면 숨은 알이 들어오며 줄이 한 칸 밀려요(웨이브당 1번)." if state["nudgesLeft"] > 0 else "")


func _describe(reward: Dictionary) -> String:
	var eggs: PackedStringArray = PackedStringArray()
	for egg: Dictionary in reward["eggs"]:
		eggs.append(GameTheme.ELEMENT_KO.get(egg["element"], "아무 원소") + (" 2티어 알 1개" if egg["tier"] == "t2" else " 알 1개"))
	var mana: String = "마력 %d" % reward["mana"] if reward["mana"] > 0 else ""
	return ", ".join(eggs) + ("와 " if not eggs.is_empty() and not mana.is_empty() else "") + mana


func _cell(col: int, row: int) -> Vector2:
	return Vector2(SLAB_X + col * STRIDE_X, SLAB_Y + row * STRIDE_Y)


func _occupied(inst: Variant) -> bool:
	return inst != null


func _dispatch(command: Dictionary) -> void:
	_ctl.dispatch(command)
