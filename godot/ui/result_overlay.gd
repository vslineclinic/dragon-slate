extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")


func setup(data: Dictionary, state: Dictionary, on_new: Callable, on_title: Callable) -> void:
	size = Vector2(1280, 720)
	z_index = 95
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#000000b3"))
	var panel: Panel = GameTheme.panel(self, Rect2(290, 110, 700, 500), GameTheme.INK, GameTheme.PANEL_LINE, 2, 12)
	var won: bool = state["phase"] == "victory"
	GameTheme.label(panel, Rect2(24, 16, 652, 70), "클리어!" if won else "게임 오버", 44, Color("#fff3bf") if won else Color("#ffa8a8"), HORIZONTAL_ALIGNMENT_CENTER)
	var summary: String = "%d웨이브까지 버텼어요" % state["wave"]
	if won:
		summary = "%d웨이브를 모두 버텼어요" % data["waves"]["maxWave"]
		if OS.has_feature("demo"):
			summary = "데모 클리어! 정식판에서는 40웨이브, 심판 보스 8종, 보스 유물, 재앙 5단계가 기다려요."
	var subheading: Label = GameTheme.label(panel, Rect2(32, 79, 636, 64), summary, 18, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.wrap(subheading)
	subheading.size.x = 636

	var best: Dictionary = _strongest(data, state)
	if not best.is_empty():
		DexOverlay.portrait(panel, Rect2(84, 165, 190, 170), best["id"])
		GameTheme.label(panel, Rect2(30, 339, 300, 60), "가장 강한 드래곤\n" + best["nameKo"], 17, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var found: PackedStringArray = []
	for id: String in state["discovered"]:
		var dragon: Dictionary = data["dragons"].get(id, {})
		found.append(dragon.get("nameKo", id))
	GameTheme.label(panel, Rect2(310, 160, 350, 40), "이번 판에서 만든 드래곤 %d종" % found.size(), 18, Color("#ffd8a8"))
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
	var restart: Button = GameTheme.button(panel, Rect2(90, 420, 240, 58), "새 판 시작", on_new, Color("#2f9e44"))
	GameTheme.button(panel, Rect2(370, 420, 240, 58), "처음으로", on_title)
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
