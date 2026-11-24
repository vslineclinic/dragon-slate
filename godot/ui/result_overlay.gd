extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")


func setup(data: Dictionary, state: Dictionary, on_new: Callable, on_title: Callable) -> void:
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
