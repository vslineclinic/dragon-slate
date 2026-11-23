extends Control
## 드래곤 도감: 원소마다 계급 피라미드(정점 1 · 1티어 2 · 2티어 3 · 기본 4)를 보여 준다.
## 판을 하는 중에 열면 지금 가진 용과 다음에 만들 수 있는 용이 표시된다.

signal closed

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const ROWS: Array[String] = ["apex", "t1", "t2", "base"]
const ROW_NOTE: Dictionary = {"apex": "용의 황제", "t1": "전설의 용", "t2": "자란 용", "base": "새끼 용"}
const PANEL_W: float = 1200.0
const TILE: Vector2 = Vector2(80, 104)
const TILE_GAP: float = 6.0
const ROW_H: float = 118.0
const MIXED_PER_ROW: int = 8
const OWNED: Color = Color("#69db7c")

var _data: Dictionary
var _found: PackedStringArray
var _codex: Dictionary = {}
var _owned: Dictionary = {}
var _count: Dictionary = {}
var _entries: Control
var _detail: Label
var _tabs: Dictionary = {}
var _page: String = ""


func setup(data: Dictionary, store: Store, state: Dictionary = {}, width: float = 1280.0) -> void:
	_data = data
	_found = store.discovered()
	for inst: Variant in state.get("nest", []) + state.get("bench", []):
		if inst != null:
			_count[inst["speciesId"]] = int(_count.get(inst["speciesId"], 0)) + 1
			_owned[inst["speciesId"]] = maxi(int(_owned.get(inst["speciesId"], 0)), int(inst.get("level", 1)))
	var file: FileAccess = FileAccess.open("res://data/codex.json", FileAccess.READ)
	if file != null:
		var entries: Variant = JSON.parse_string(file.get_as_text())
		if entries is Array:
			for entry: Dictionary in entries:
				_codex[entry["id"]] = entry
	size = Vector2(width, 720)
	z_index = 90
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#000000bf"))
	var panel: Panel = GameTheme.panel(self, Rect2((width - PANEL_W) / 2.0, 24, PANEL_W, 672), GameTheme.INK, GameTheme.PANEL_LINE, 2, 12)
	var count: int = 0
	for dragon: Dictionary in _data["dragons"].values():
		if _known(dragon):
			count += 1
	GameTheme.label(panel, Rect2(24, 8, 300, 46), "드래곤 도감  %d / %d" % [count, _data["dragons"].size()], 20)
	var x: float = 300.0
	for element: String in GameData.active_elements(_data):
		_tabs[element] = GameTheme.button(panel, Rect2(x, 8, 84, 44), GameTheme.ELEMENT_KO[element], _show_page.bind(element), GameTheme.COLOR[element].darkened(0.45))
		x += 90.0
	_tabs["mixed"] = GameTheme.button(panel, Rect2(x, 8, 120, 44), "이중·숨은", _show_page.bind("mixed"), Color("#5f3dc4"))
	for tab: Button in _tabs.values():
		tab.toggle_mode = true
	var close_button: Button = GameTheme.button(panel, Rect2(PANEL_W - 130, 8, 110, 44), "닫기", _close)
	_entries = Control.new()
	_entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_entries)
	_detail = GameTheme.label(panel, Rect2(24, 544, PANEL_W - 48, 116), "", 15)
	GameTheme.wrap(_detail)
	_show_page(_first_page())
	close_button.grab_focus()


## 가진 용이 있으면 그 원소부터 보여 준다.
func _first_page() -> String:
	var best: String = GameData.active_elements(_data)[0]
	var best_level: int = 0
	for id: String in _owned:
		var elements: Array = _data["dragons"][id]["elements"]
		if elements.size() == 1 and int(_owned[id]) > best_level:
			best_level = int(_owned[id])
			best = elements[0]
	return best


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	hide()
	set_process_input(false)
	queue_free()
	closed.emit()


func _show_page(page: String) -> void:
	_page = page
	for key: String in _tabs:
		_tabs[key].set_pressed_no_signal(key == page)
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var help: String = "드래곤을 누르면 설명과 만드는 법을 볼 수 있어요."
	if not _owned.is_empty():
		help += " 초록 테두리는 지금 가진 용, 노란 테두리는 지금 가진 용 둘로 만들 수 있는 용이에요."
	_detail.text = GameTheme.keep_words(help)
	var dragons: Array = _data["dragons"].values()
	if page == "mixed":
		var rest: Array = dragons.filter(func(dragon: Dictionary) -> bool: return dragon["tier"] == "dual")
		rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _element_rank(a) < _element_rank(b))
		rest.append_array(dragons.filter(func(dragon: Dictionary) -> bool: return dragon["tier"] == "secret"))
		var big: Vector2 = Vector2(118, 132)
		var mixed_left: float = (PANEL_W - (MIXED_PER_ROW * big.x + (MIXED_PER_ROW - 1) * 12.0)) / 2.0
		for i: int in range(rest.size()):
			@warning_ignore("integer_division")
			var row: int = i / MIXED_PER_ROW
			_card(rest[i], Rect2(mixed_left + i % MIXED_PER_ROW * (big.x + 12), 90 + row * (big.y + 16), big.x, big.y))
		return
	var tint: Color = GameTheme.COLOR[page]
	var needs: Dictionary = _data["battle"].get("level", {}).get("evolveLevel", {})
	for r: int in range(ROWS.size()):
		var tier: String = ROWS[r]
		var row: Array = dragons.filter(func(dragon: Dictionary) -> bool: return dragon["elements"] == [page] and dragon["tier"] == tier)
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
		var y: float = 60.0 + r * ROW_H
		var width: float = row.size() * TILE.x + maxi(0, row.size() - 1) * TILE_GAP
		var left: float = (PANEL_W - width) / 2.0 + 60.0
		## 계단 모양 받침: 위로 갈수록 좁아져 피라미드가 된다.
		GameTheme.panel(_entries, Rect2(left - 14, y, width + 28, TILE.y + 10), Color(tint, 0.10 + 0.05 * (ROWS.size() - 1 - r)), Color(tint, 0.45), 1, 10)
		var need: String = "알에서 얻어요" if tier == "base" else "레벨 %d부터 진화" % int(needs.get(tier, 1))
		GameTheme.label(_entries, Rect2(24, y + 16, 130, 26), GameTheme.TIER_KO[tier], 20, tint.lightened(0.35))
		GameTheme.label(_entries, Rect2(24, y + 44, 130, 20), ROW_NOTE[tier], 13, GameTheme.DIM)
		GameTheme.label(_entries, Rect2(24, y + 64, 130, 20), need, 12, GameTheme.DIM)
		for i: int in range(row.size()):
			_card(row[i], Rect2(left + i * (TILE.x + TILE_GAP), y + 5, TILE.x, TILE.y))


func _element_rank(dragon: Dictionary) -> String:
	var ranks: PackedStringArray = []
	for element: String in dragon["elements"]:
		ranks.append(str(GameData.ELEMENTS.find(element)))
	return ",".join(ranks)


func _known(dragon: Dictionary) -> bool:
	return _found.has(dragon["id"]) or _owned.has(dragon["id"])


## 이 종을 만드는 조합 가운데 지금 가진 재료 수가 가장 많은 것. {have, a, b}
func _best_recipe(id: String) -> Dictionary:
	var best: Dictionary = {}
	for recipe: Dictionary in _data["recipes"]:
		if recipe["result"] != id:
			continue
		var have: int = 0
		if recipe["a"] == recipe["b"]:
			have = mini(2, int(_count.get(recipe["a"], 0)))
		else:
			have = (1 if _owned.has(recipe["a"]) else 0) + (1 if _owned.has(recipe["b"]) else 0)
		if best.is_empty() or have > int(best["have"]):
			best = {"have": have, "a": recipe["a"], "b": recipe["b"]}
	return best


static func portrait(parent: Control, rect: Rect2, id: String) -> TextureRect:
	var sprite: TextureRect = GameTheme.dragon(parent, rect, id)
	if sprite != null:
		return sprite
	# 에디터에서 가져오기 전에도 공유 PNG로 도감을 열 수 있다.
	var path: String = "res://assets/dragons/%s.png" % id
	if not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	sprite = TextureRect.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.flip_h = true
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(parent, sprite, rect)
	return sprite


## 작은 칸: 위에 그림, 아래에 이름. 가진 용은 초록, 다음에 만들 수 있는 용은 노랑.
func _card(dragon: Dictionary, rect: Rect2) -> void:
	var id: String = dragon["id"]
	var known: bool = _known(dragon)
	var owned: bool = _owned.has(id)
	var recipe: Dictionary = _best_recipe(id)
	var reachable: bool = not owned and not recipe.is_empty() and int(recipe["have"]) >= 2
	var border: Color = GameTheme.PANEL_LINE
	var width: int = 1
	if owned:
		border = OWNED
		width = 3
	elif reachable:
		border = GameTheme.RECOMMEND
		width = 2
	elif known:
		border = GameTheme.COLOR.get(dragon["elements"].front(), GameTheme.PANEL_LINE)
		width = 2
	var card: Button = GameTheme.button(_entries, rect, "", _show_detail.bind(dragon), GameTheme.PANEL if known else Color("#171a24"), border, width)
	var caption: String = dragon["nameKo"] if known else "???"
	card.tooltip_text = caption
	var side: float = rect.size.x - 22.0
	if dragon["tier"] == "secret" and not known:
		GameTheme.label(card, Rect2(0, 6, rect.size.x, side), "?", 36, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var image: TextureRect = portrait(card, Rect2(11, 12, side, side), id)
		if image != null and not known:
			image.modulate = Color(0, 0, 0, 0.85)
	var name_label: Label = GameTheme.label(card, Rect2(2, side + 12, rect.size.x - 4, rect.size.y - side - 14), caption, 11, GameTheme.TEXT if known else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.wrap(name_label)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var tag: String = ""
	var tag_color: Color = GameTheme.DIM
	if owned:
		tag = "보유 Lv.%d" % int(_owned[id])
		tag_color = OWNED
	elif reachable:
		tag = "합체 가능"
		tag_color = GameTheme.RECOMMEND
	if not tag.is_empty():
		var strip: Panel = GameTheme.panel(card, Rect2(0, 0, rect.size.x, 14), Color(0, 0, 0, 0.55))
		GameTheme.label(strip, Rect2(0, -1, rect.size.x, 14), tag, 10, tag_color, HORIZONTAL_ALIGNMENT_CENTER)


func _show_detail(dragon: Dictionary) -> void:
	var entry: Dictionary = _codex.get(dragon["id"], {})
	var tier: String = GameTheme.TIER_KO[dragon["tier"]]
	var lines: PackedStringArray = PackedStringArray()
	if _known(dragon):
		var stats: Dictionary = dragon["stats"]
		lines.append("%s (%s) · 체력 %d · 공격력 %d" % [dragon["nameKo"], tier, stats["hp"], stats["atk"]])
		lines.append(entry.get("loreKo", ""))
	else:
		lines.append("??? (%s)" % ("숨은 드래곤" if dragon["tier"] == "secret" else tier))
		lines.append("힌트: " + entry.get("hintKo", "아직 알려지지 않았어요."))
	var recipe: Dictionary = _best_recipe(dragon["id"])
	if dragon["tier"] == "base":
		lines.append("얻는 법: 룬 석판의 알 (칸마다 등장 확률 %s)" % GameTheme.percent(Slot.species_odds(_data, dragon["id"])))
	elif not recipe.is_empty() and (_known(dragon) or int(recipe["have"]) > 0):
		var need: int = Fusion.evolve_level(_data, dragon["id"])
		lines.append("만드는 법: %s + %s (둘 중 하나가 레벨 %d 이상)" % [_name_or_unknown(recipe["a"]), _name_or_unknown(recipe["b"]), need])
	_detail.text = GameTheme.keep_words("\n".join(lines))


func _name_or_unknown(id: String) -> String:
	var dragon: Dictionary = _data["dragons"][id]
	return dragon["nameKo"] if _known(dragon) else "???"
