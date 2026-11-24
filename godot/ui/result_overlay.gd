extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")


var _store: RefCounted
var _next_stage: int = -1
var _rings: Array = []
var _picked: Label


## store와 stage(지역 번호, 지역이 아니면 -1)를 주면 별을 보여 주고, 다음 지역으로 데려갈 용을 고르게 한다.
func setup(data: Dictionary, state: Dictionary, on_new: Callable, on_title: Callable, store: RefCounted = null, stage: int = -1) -> void:
	_store = store
	size = Vector2(1280, 720)
	z_index = 95
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#000000cc"))
	var won: bool = state["phase"] == "victory"
	var panel: Panel = GameTheme.frame(self, Rect2(290, 110, 700, 500), GameTheme.INK, GameTheme.GOLD if won else Color("#b05a5a"), 14)
	var sky: Control = Control.new()
	sky.clip_contents = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(panel, sky, Rect2(4, 4, 692, 492))
	GameTheme.picture(sky, Rect2(0, 0, 692, 492), "res://assets/backgrounds/chart.png")
	GameTheme.glow(panel, Vector2(350, 40), 300.0, Color(GameTheme.GOLD if won else Color("#c8401f"), 0.22))
	GameTheme.heading(panel, Rect2(24, 14, 652, 64), "클리어!" if won else "게임 오버", 46, GameTheme.GOLD_HI if won else Color("#ffb3a8"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	GameTheme.divider(panel, Rect2(150, 78, 400, 8), GameTheme.GOLD if won else Color("#b05a5a"))
	var summary: String = "%d웨이브까지 버텼어요" % state["wave"]
	if won:
		summary = "%d웨이브를 모두 버텼어요" % data["waves"]["maxWave"]
		if OS.has_feature("demo"):
			summary = "데모 클리어! 정식판에서는 40웨이브, 심판 보스 8종, 보스 유물, 재앙 5단계가 기다려요."
	var subheading: Label = GameTheme.label(panel, Rect2(32, 88, 636, 60), summary, 18, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.wrap(subheading)
	subheading.size.x = 636

	var stages: Array = data.get("stages", [])
	if won and stage >= 0 and store != null:
		var stars: int = store.stars_for(state)
		GameTheme.heading(panel, Rect2(470, 22, 200, 44), "★".repeat(stars) + "☆".repeat(3 - stars), 34, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_RIGHT)
		subheading.text = "「%s」을(를) 지켜 냈어요. 잃은 생명 %d." % [data["waves"].get("stageName", ""), int(state.get("livesLost", 0))]
		if stage + 1 < stages.size():
			subheading.text += " 다음 지역 「%s」이(가) 열렸어요." % stages[stage + 1]["nameKo"]
			_next_stage = stage + 1
			_carry_picker(panel, data, state, str(stages[stage + 1]["nameKo"]))
			var again: Button = GameTheme.cta(panel, Rect2(90, 418, 240, 58), "새 판 시작", on_new, "gold", 22)
			GameTheme.button(panel, Rect2(370, 418, 240, 58), "처음으로", on_title, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
			again.grab_focus()
			return
	var best: Dictionary = _strongest(data, state)
	if not best.is_empty():
		GameTheme.glow(panel, Vector2(179, 250), 130.0, Color(GameTheme.COLOR.get(best["elements"][0], GameTheme.GOLD), 0.4))
		DexOverlay.portrait(panel, Rect2(84, 165, 190, 170), best["id"])
		GameTheme.label(panel, Rect2(30, 338, 300, 22), "가장 강한 드래곤", 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.heading(panel, Rect2(30, 360, 300, 30), best["nameKo"], 20, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	var found: PackedStringArray = []
	for id: String in state["discovered"]:
		var dragon: Dictionary = data["dragons"].get(id, {})
		found.append(dragon.get("nameKo", id))
	GameTheme.heading(panel, Rect2(310, 160, 350, 36), "이번 판에서 만든 드래곤 %d종" % found.size(), 18, GameTheme.GOLD)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameTheme.place(panel, scroll, Rect2(310, 202, 350, 192))
	var discoveries: Label = Label.new()
	discoveries.text = "없음" if found.is_empty() else ", ".join(found)
	GameTheme.wrap(discoveries)
	discoveries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discoveries.add_theme_color_override("font_color", GameTheme.DIM)
	discoveries.add_theme_font_size_override("font_size", 16)
	scroll.add_child(discoveries)
	var restart: Button = GameTheme.cta(panel, Rect2(90, 418, 240, 58), "새 판 시작", on_new, "gold", 22)
	GameTheme.button(panel, Rect2(370, 418, 240, 58), "처음으로", on_title, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
	restart.grab_focus()


func _strongest(data: Dictionary, state: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var power: int = -1
	for zone: String in ["nest", "bench"]:
		for dragon: Variant in state[zone]:
			if dragon == null:
				continue
			var value: int = Waves.unit_power(Battle.to_unit(data, dragon))
			if value > power:
				power = value
				best = data["dragons"][dragon["speciesId"]]
	return best


## 다음 지역으로 데려갈 용 한 마리 고르기. 처음에는 가장 센 용이 골라져 있다.
func _carry_picker(panel: Panel, data: Dictionary, state: Dictionary, next_name: String) -> void:
	GameTheme.heading(panel, Rect2(24, 152, 652, 30), "「%s」(으)로 데려갈 용 한 마리" % next_name, 20, GameTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.label(panel, Rect2(24, 182, 652, 22), "종과 계승 특성은 그대로 가고, 레벨과 스킬은 처음부터 다시 키워요.", 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var roster: Array = []
	for zone: String in ["nest", "bench"]:
		for dragon: Variant in state[zone]:
			if dragon != null:
				roster.append({"inst": dragon, "power": Waves.unit_power(Battle.to_unit(data, dragon))})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["power"] > b["power"])
	roster = roster.slice(0, 9)
	var step: float = 70.0
	var left: float = (700.0 - (roster.size() * step - 6.0)) / 2.0
	_picked = GameTheme.heading(panel, Rect2(24, 318, 652, 28), "", 18, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 600)
	for i: int in range(roster.size()):
		var inst: Dictionary = roster[i]["inst"]
		var spec: Dictionary = data["dragons"][inst["speciesId"]]
		var rect: Rect2 = Rect2(left + i * step, 214, 64, 92)
		var tile: Button = GameTheme.button(panel, rect, "", _pick_carry.bind(i, inst, spec["nameKo"]), GameTheme.CARD, GameTheme.PANEL_LINE, 1)
		tile.tooltip_text = "%s · %s" % [spec["nameKo"], GameTheme.TIER_KO.get(spec["tier"], "")]
		GameTheme.glow(tile, Vector2(32, 34), 34.0, Color(GameTheme.COLOR.get(spec["elements"][0], GameTheme.GOLD), 0.4))
		DexOverlay.portrait(tile, Rect2(4, 4, 56, 56), spec["id"])
		GameTheme.label(tile, Rect2(0, 60, 64, 16), GameTheme.TIER_KO.get(spec["tier"], ""), 11, GameTheme.TIER_RING.get(spec["tier"], GameTheme.DIM), HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.label(tile, Rect2(0, 74, 64, 16), "⚔%d" % int(roster[i]["power"]), 11, Color("#ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER)
		var ring: Panel = GameTheme.panel(tile, Rect2(-3, -3, 70, 98), Color.TRANSPARENT, GameTheme.RECOMMEND, 3, 10)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.hide()
		_rings.append(ring)
	if not roster.is_empty():
		_pick_carry(0, roster[0]["inst"], data["dragons"][roster[0]["inst"]["speciesId"]]["nameKo"])
	var found: int = state["discovered"].size()
	GameTheme.label(panel, Rect2(24, 356, 652, 22), "이번 판에서 만든 드래곤 %d종" % found, 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)


func _pick_carry(index: int, inst: Dictionary, dragon_name: String) -> void:
	for i: int in range(_rings.size()):
		_rings[i].visible = i == index
	_picked.text = "데려가는 용: " + dragon_name
	if _store != null and _next_stage >= 0:
		_store.set_carry(_next_stage, inst)
