extends Control

signal closed

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const TIERS: Array[String] = ["base", "t2", "t1"]

var _data: Dictionary
var _found: PackedStringArray
var _codex: Dictionary = {}
var _entries: Control
var _detail: Label
var _element_tab: Button
var _dual_tab: Button


func setup(data: Dictionary, store: Store) -> void:
	_data = data
	_found = store.discovered()
	var file: FileAccess = FileAccess.open("res://data/codex.json", FileAccess.READ)
	if file != null:
		var entries: Variant = JSON.parse_string(file.get_as_text())
		if entries is Array:
			for entry: Dictionary in entries:
				_codex[entry["id"]] = entry
	size = Vector2(1280, 720)
	z_index = 90
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#000000bf"))
	var panel: Panel = GameTheme.panel(self, Rect2(40, 24, 1200, 672), GameTheme.INK, GameTheme.PANEL_LINE, 2, 12)
	var count: int = 0
	for dragon: Dictionary in _data["dragons"].values():
		if _known(dragon):
			count += 1
	GameTheme.label(panel, Rect2(24, 8, 480, 46), "드래곤 도감   발견 %d / %d" % [count, _data["dragons"].size()], 22)
	_element_tab = GameTheme.button(panel, Rect2(580, 8, 150, 44), "원소별", _show_page.bind(false), Color("#5f3dc4"))
	_dual_tab = GameTheme.button(panel, Rect2(740, 8, 150, 44), "이중·숨은", _show_page.bind(true), Color("#5f3dc4"))
	_element_tab.toggle_mode = true
	_dual_tab.toggle_mode = true
	var close_button: Button = GameTheme.button(panel, Rect2(1070, 8, 110, 44), "닫기", _close)
	_entries = Control.new()
	_entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_entries)
	_detail = GameTheme.label(panel, Rect2(24, 567, 1152, 90), "", 16)
	GameTheme.wrap(_detail)
	_show_page(false)
	close_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	hide()
	set_process_input(false)
	queue_free()
	closed.emit()


func _show_page(dual: bool) -> void:
	_element_tab.set_pressed_no_signal(not dual)
	_dual_tab.set_pressed_no_signal(dual)
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	_detail.text = GameTheme.keep_words("드래곤을 누르면 설명이나 힌트를 볼 수 있어요.")
	var dragons: Array = _data["dragons"].values()
	if dual:
		var rest: Array = dragons.filter(func(dragon: Dictionary) -> bool: return dragon["tier"] == "dual")
		rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _element_rank(a) < _element_rank(b))
		rest.append_array(dragons.filter(func(dragon: Dictionary) -> bool: return dragon["tier"] == "secret"))
		for i: int in range(rest.size()):
			@warning_ignore("integer_division")
			var row: int = i / 4
			_card(rest[i], Rect2(80 + i % 4 * 258, 64 + row * 116, 250, 108))
		return
	var y: int = 64
	for element: String in GameData.active_elements(_data):
		GameTheme.label(_entries, Rect2(24, y, 70, 76), GameTheme.ELEMENT_KO[element], 15, GameTheme.DIM)
		var row: Array = dragons.filter(func(dragon: Dictionary) -> bool: return dragon["elements"] == [element] and dragon["tier"] in TIERS)
		row.sort_custom(_tier_order)
		for i: int in range(row.size()):
			_card(row[i], Rect2(100 + i * 178, y, 170, 76))
		y += 82


func _tier_order(a: Dictionary, b: Dictionary) -> bool:
	var first: int = TIERS.find(a["tier"])
	var second: int = TIERS.find(b["tier"])
	return a["id"] < b["id"] if first == second else first < second


func _element_rank(dragon: Dictionary) -> String:
	var ranks: PackedStringArray = []
	for element: String in dragon["elements"]:
		ranks.append(str(GameData.ELEMENTS.find(element)))
	return ",".join(ranks)


func _known(dragon: Dictionary) -> bool:
	return dragon["tier"] == "base" or _found.has(dragon["id"])


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


func _card(dragon: Dictionary, rect: Rect2) -> void:
	var known: bool = _known(dragon)
	var border: Color = GameTheme.COLOR.get(dragon["elements"].front(), GameTheme.PANEL_LINE) if known else GameTheme.PANEL_LINE
	var card: Button = GameTheme.button(_entries, rect, "", _show_detail.bind(dragon), GameTheme.PANEL, border, 2)
	var caption: String = dragon["nameKo"] if known else "???"
	var tier: String = GameTheme.TIER_KO[dragon["tier"]]
	card.tooltip_text = "%s (%s)" % [caption, tier]
	var side: float = rect.size.y - 22.0
	if dragon["tier"] == "secret" and not known:
		GameTheme.label(card, Rect2(8, 0, side, rect.size.y), "?", 40, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var image: TextureRect = portrait(card, Rect2(8, 11, side, side), dragon["id"])
		if image != null and not known:
			image.modulate = Color(0, 0, 0, 0.85)
	var name_x: float = side + 16.0
	GameTheme.label(card, Rect2(name_x, 6, rect.size.x - name_x - 6, 20), tier, 12, GameTheme.DIM)
	var name_label: Label = GameTheme.label(card, Rect2(name_x, 27, rect.size.x - name_x - 6, rect.size.y - 31), caption, 14, GameTheme.TEXT if known else GameTheme.DIM)
	GameTheme.wrap(name_label)
	name_label.size.x = rect.size.x - name_x - 6


func _show_detail(dragon: Dictionary) -> void:
	var entry: Dictionary = _codex.get(dragon["id"], {})
	var tier: String = GameTheme.TIER_KO[dragon["tier"]]
	if _known(dragon):
		_detail.text = GameTheme.keep_words("%s (%s)\n%s" % [dragon["nameKo"], tier, entry.get("loreKo", "")])
	else:
		var category: String = "숨은 드래곤" if dragon["tier"] == "secret" else tier
		_detail.text = GameTheme.keep_words("??? (%s)\n힌트: %s" % [category, entry.get("hintKo", "아직 알려지지 않았어요.")])
