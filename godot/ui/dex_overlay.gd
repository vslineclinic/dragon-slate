extends Control
## 드래곤 도감 "용의 계보": 원소마다 세계수 한 그루. 뿌리(기본 용)에서 가지를 타고 꼭대기(정점)까지 올라간다.
## 가지는 "같은 용 둘을 합치면 되는 용"을 잇는다. 판을 하는 중에 열면 가진 용과 지금 만들 수 있는 용이 빛난다.

signal closed

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Store = preload("res://godot/ui/store.gd")
const ROWS: Array[String] = ["apex", "t1", "t2", "base"]
const ROW_NOTE: Dictionary = {"apex": "용의 황제", "t1": "전설의 용", "t2": "다 자란 용", "base": "새끼 용"}
const ROLE_KO: Dictionary = GameTheme.ROLE_KO
const STAGE: Vector2 = Vector2(1240, 688)
const TREE: Rect2 = Rect2(16, 66, 848, 608)
const SIDE: Rect2 = Rect2(876, 66, 348, 608)
const ROW_Y: Dictionary = {"apex": 92.0, "t1": 222.0, "t2": 352.0, "base": 482.0}
const ROW_SIZE: Dictionary = {"apex": 92.0, "t1": 78.0, "t2": 66.0, "base": 56.0}
const OWNED: Color = Color("#7be08a")
const GUTTER: float = 112.0
const SHADOW: Color = Color(0.2, 0.19, 0.27, 0.95)


## 메달 모양 마디. 계급은 테두리 색으로, 상태는 빛과 꼬리표로 보여 준다.
class Medal extends Control:
	var ring: Color = Color.WHITE
	var tint: Color = Color.WHITE
	var known: bool = false
	var owned: bool = false
	var crown: bool = false
	var picked: bool = false

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = size.x / 2.0 - 4.0
		draw_circle(center + Vector2(0, 3), radius + 2.0, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(center, radius, Color("#100f17"), true, -1.0, true)
		draw_circle(center, radius - 1.0, Color(tint, 0.26 if known else 0.07), true, -1.0, true)
		draw_arc(center, radius * 0.72, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.07 if known else 0.03), radius * 0.36, true)
		var line: Color = OWNED if owned else Color(ring, 1.0 if known else 0.4)
		draw_arc(center, radius, 0, TAU, 56, line.darkened(0.45), 5.0, true)
		draw_arc(center, radius, 0, TAU, 56, line, 2.5, true)
		if crown:
			draw_arc(center, radius + 5.0, 0, TAU, 56, Color(line, 0.55), 1.0, true)
			for i: int in range(8):
				var out: Vector2 = Vector2.from_angle(TAU * i / 8.0 - PI / 2.0)
				draw_line(center + out * (radius + 5.0), center + out * (radius + 11.0), Color(line, 0.8), 2.0, true)
		if picked:
			draw_arc(center, radius + 4.0, 0, TAU, 56, Color.WHITE, 2.0, true)


## 가지(마디를 잇는 굽은 선).
class Branches extends Control:
	var curves: Array = []

	func _draw() -> void:
		for lit: bool in [false, true]:
			for curve: Dictionary in curves:
				if bool(curve["lit"]) != lit:
					continue
				var points: PackedVector2Array = curve["points"]
				var color: Color = curve["color"]
				if lit:
					draw_polyline(points, Color(color, 0.22), 9.0, true)
					draw_polyline(points, color, 3.0, true)
				else:
					draw_polyline(points, Color(0, 0, 0, 0.5), 5.0, true)
					draw_polyline(points, color, 2.0, true)


var _data: Dictionary
var _found: PackedStringArray
var _codex: Dictionary = {}
var _owned: Dictionary = {}
var _count: Dictionary = {}
var _recipes: Dictionary = {}
var _stage: Control
var _entries: Control
var _detail: Control
var _tabs: Dictionary = {}
var _medals: Dictionary = {}
var _page: String = ""
var _picked: String = ""


## 판 안에서 열면 내 석판 기준으로 알 확률을 보여 준다.
var _slab: Array = []


func setup(data: Dictionary, store: Store, state: Dictionary = {}, width: float = 1280.0) -> void:
	_data = data
	_slab = state.get("slab", [])
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
	for recipe: Dictionary in _data["recipes"]:
		if not _recipes.has(recipe["result"]):
			_recipes[recipe["result"]] = []
		_recipes[recipe["result"]].append(recipe)
	size = Vector2(width, 720)
	z_index = 90
	var dim: Panel = GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#000000d9"))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	GameTheme.place(self, _stage, Rect2((width - STAGE.x) / 2.0, 16, STAGE.x, STAGE.y))
	GameTheme.frame(_stage, Rect2(Vector2.ZERO, STAGE), GameTheme.INK, GameTheme.GOLD, 14)
	var sky: Control = Control.new()
	sky.clip_contents = true
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_stage, sky, Rect2(4, 4, STAGE.x - 8, STAGE.y - 8))
	GameTheme.picture(sky, Rect2(0, 0, STAGE.x - 8, STAGE.y - 8), "res://assets/backgrounds/chart.png").modulate = Color(1, 1, 1, 0.9)
	var count: int = 0
	for dragon: Dictionary in _data["dragons"].values():
		if _known(dragon):
			count += 1
	GameTheme.heading(_stage, Rect2(28, 12, 160, 44), "용의 계보", 26)
	GameTheme.label(_stage, Rect2(164, 16, 130, 40), "발견 %d / %d" % [count, _data["dragons"].size()], 15, GameTheme.DIM)
	var x: float = 300.0
	for element: String in GameData.active_elements(_data):
		_tabs[element] = _tab(Rect2(x, 14, 88, 40), GameTheme.ELEMENT_KO[element], element, GameTheme.COLOR[element])
		x += 94.0
	_tabs["mixed"] = _tab(Rect2(x, 14, 128, 40), "이중·숨은", "", GameTheme.TIER_RING["dual"])
	var close_button: Button = GameTheme.button(_stage, Rect2(STAGE.x - 118, 14, 96, 40), "닫기", _close, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
	GameTheme.divider(_stage, Rect2(24, 58, STAGE.x - 48, 8), GameTheme.GOLD_DIM)
	_entries = Control.new()
	_entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_stage, _entries, TREE)
	GameTheme.frame(_stage, SIDE, Color("#14131cf2"), GameTheme.GOLD_DIM, 12)
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_stage, _detail, SIDE)
	_show_page(_first_page())
	close_button.grab_focus()


func _tab(rect: Rect2, copy: String, element: String, tint: Color) -> Button:
	var tab: Button = GameTheme.button(_stage, rect, "", _show_page.bind("mixed" if element.is_empty() else element), Color("#1c1a24"), Color(tint, 0.55), 1)
	tab.toggle_mode = true
	tab.add_theme_stylebox_override("pressed", GameTheme.style(tint.darkened(0.55), tint.lightened(0.3), 2, 8, "button"))
	var text_x: float = 8.0
	if not element.is_empty():
		GameTheme.place(tab, Marks.new(element), Rect2(10, 10, 20, 20))
		text_x = 34.0
	GameTheme.label(tab, Rect2(text_x, 0, rect.size.x - text_x - 8, rect.size.y), copy, 16, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	return tab


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
	_picked = ""
	_medals = {}
	for key: String in _tabs:
		_tabs[key].set_pressed_no_signal(key == page)
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	if page == "mixed":
		_draw_twilight()
	else:
		_draw_tree(page)
	_show_detail({})


## 원소 한 그루: 아래 뿌리(기본)에서 위 꼭대기(정점)까지.
func _draw_tree(element: String) -> void:
	var tint: Color = GameTheme.COLOR[element]
	GameTheme.glow(_entries, Vector2(GUTTER + (TREE.size.x - GUTTER) / 2.0, 150), 330.0, Color(tint, 0.16))
	var branches: Branches = Branches.new()
	branches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_entries, branches, Rect2(Vector2.ZERO, TREE.size))
	var needs: Dictionary = _data["battle"].get("level", {}).get("evolveLevel", {})
	var order: Dictionary = {}
	var centers: Dictionary = {}
	for tier: String in ROWS:
		var row: Array = _data["dragons"].values().filter(func(dragon: Dictionary) -> bool: return dragon["elements"] == [element] and dragon["tier"] == tier)
		## 위 계급의 순서를 따라 줄을 세우면 가지가 서로 엇갈리지 않는다.
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var rank_a: int = int(order.get(_parent(a["id"]), 99))
			var rank_b: int = int(order.get(_parent(b["id"]), 99))
			return rank_a < rank_b if rank_a != rank_b else a["id"] < b["id"])
		var edge: float = ROW_SIZE[tier]
		var span: float = TREE.size.x - GUTTER - 6.0
		var stride: float = minf(edge + 46.0, span / maxf(1.0, row.size()))
		var left: float = GUTTER + (span - stride * row.size()) / 2.0
		var note: String = "알에서 얻어요" if tier == "base" else "Lv.%d부터 진화" % int(needs.get(tier, 1))
		_row_label(tier, note, tint)
		for i: int in range(row.size()):
			var id: String = row[i]["id"]
			order[id] = i + int(order.get(_parent(id), 0)) * 100
			var spread: float = (i + 0.5) / row.size() * 2.0 - 1.0
			centers[id] = Vector2(left + stride * (i + 0.5), float(ROW_Y[tier]) + 16.0 * spread * spread)
		for i: int in range(row.size()):
			order[row[i]["id"]] = i
		for dragon: Dictionary in row:
			var id: String = dragon["id"]
			var parent: String = _parent(id)
			if centers.has(parent):
				var lit: bool = _owned.has(id) or (_known(dragon) and _found.has(parent))
				var from: Vector2 = centers[id] - Vector2(0, edge / 2.0 - 4.0)
				var to: Vector2 = centers[parent] + Vector2(0, float(ROW_SIZE[_data["dragons"][parent]["tier"]]) / 2.0 - 4.0)
				branches.curves.append({"points": _curve(from, to), "lit": lit, "color": tint.lightened(0.2) if lit else Color(GameTheme.GOLD_DIM, 0.42)})
			_node(dragon, centers[id], edge, stride)
	branches.queue_redraw()
	var legend: Label = GameTheme.label(_entries, Rect2(8, TREE.size.y - 34, TREE.size.x - 16, 26),
		"가지: 같은 용 둘을 합치면 올라가는 길 · 다른 용끼리 합치면 다른 가지로 건너가요 · 초록 = 가진 용, 금빛 = 지금 합칠 수 있는 용", 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	legend.clip_text = true


func _row_label(tier: String, note: String, tint: Color) -> void:
	var y: float = float(ROW_Y[tier]) - 30.0
	GameTheme.heading(_entries, Rect2(10, y, GUTTER, 24), GameTheme.TIER_KO[tier], 19, GameTheme.TIER_RING[tier])
	GameTheme.label(_entries, Rect2(10, y + 25, GUTTER, 18), ROW_NOTE[tier], 12, tint.lightened(0.4))
	GameTheme.label(_entries, Rect2(10, y + 42, GUTTER, 18), note, 12, GameTheme.DIM)


## 같은 용 둘을 합치면 되는 윗계급 용("" = 없음).
func _parent(id: String) -> String:
	var result: Variant = Fusion.find_recipe(_data, id, id)
	return "" if result == null else str(result)


static func _curve(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var bend: float = (from.y - to.y) * 0.5
	for i: int in range(17):
		points.append(from.bezier_interpolate(from - Vector2(0, bend), to + Vector2(0, bend), to, i / 16.0))
	return points


## 이중·숨은 용: 여섯 원소를 육각으로 두르고, 두 원소 사이에 이중 용을 둔다. 한가운데는 숨은 용.
func _draw_twilight() -> void:
	var center: Vector2 = Vector2(TREE.size.x / 2.0, TREE.size.y / 2.0 - 8.0)
	var reach: float = 262.0
	GameTheme.glow(_entries, center, 300.0, Color(GameTheme.TIER_RING["dual"], 0.14))
	var branches: Branches = Branches.new()
	branches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_entries, branches, Rect2(Vector2.ZERO, TREE.size))
	var elements: Array = GameData.active_elements(_data)
	var anchor: Dictionary = {}
	for i: int in range(elements.size()):
		anchor[elements[i]] = center + Vector2.from_angle(TAU * i / elements.size() - PI / 2.0) * reach
	for dragon: Dictionary in _data["dragons"].values():
		if dragon["tier"] != "dual":
			continue
		var a: int = elements.find(dragon["elements"][0])
		var b: int = elements.find(dragon["elements"][1])
		if a < 0 or b < 0:
			continue
		var gap: int = absi(a - b)
		gap = mini(gap, elements.size() - gap)
		var mid: Vector2 = (anchor[elements[a]] + anchor[elements[b]]) / 2.0
		var at: Vector2 = center + (mid - center) * (0.9 if gap == 1 else 1.15)
		if gap == 3:
			var low: int = mini(a, b)
			var side: float = 1.0 if low % 2 == 0 else -1.0
			at = center + Vector2.from_angle(TAU * low / elements.size() - PI / 2.0 + side * PI / 2.0) * 74.0
		var known: bool = _known(dragon)
		for element: String in dragon["elements"]:
			var tint: Color = GameTheme.COLOR[element]
			branches.curves.append({"points": PackedVector2Array([anchor[element], at]), "lit": known, "color": tint if known else Color(tint, 0.22)})
		_node(dragon, at, 60.0, 84.0)
	for element: String in elements:
		var tint: Color = GameTheme.COLOR[element]
		var spot: Vector2 = anchor[element]
		GameTheme.glow(_entries, spot, 46.0, Color(tint, 0.45))
		var sigil: Control = Marks.new(element)
		GameTheme.place(_entries, sigil, Rect2(spot - Vector2(17, 17), Vector2(34, 34)))
		GameTheme.outline(GameTheme.label(_entries, Rect2(spot.x - 40, spot.y + 18, 80, 20), GameTheme.ELEMENT_KO[element], 13, tint.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER), 4)
	for dragon: Dictionary in _data["dragons"].values():
		if dragon["tier"] == "secret":
			_node(dragon, center, 64.0, 96.0)
	branches.queue_redraw()
	GameTheme.heading(_entries, Rect2(10, 4, 300, 26), "황혼의 고리", 19, GameTheme.TIER_RING["dual"])
	GameTheme.label(_entries, Rect2(10, 30, 330, 18), "서로 다른 두 원소의 2티어 용을 합치면 태어나요", 12, GameTheme.DIM)


func _known(dragon: Dictionary) -> bool:
	return _found.has(dragon["id"]) or _owned.has(dragon["id"])


## 이 종을 만드는 조합 가운데 지금 가진 재료 수가 가장 많은 것. {have, a, b}
func _best_recipe(id: String) -> Dictionary:
	var best: Dictionary = {}
	for recipe: Dictionary in _recipes.get(id, []):
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


## 마디 하나: 메달 + 그림 + 아래 이름. 가진 용은 초록, 지금 만들 수 있는 용은 금빛으로 깜빡인다.
func _node(dragon: Dictionary, center: Vector2, edge: float, name_width: float) -> void:
	var id: String = dragon["id"]
	var known: bool = _known(dragon)
	var owned: bool = _owned.has(id)
	var recipe: Dictionary = _best_recipe(id)
	var reachable: bool = not owned and not recipe.is_empty() and int(recipe["have"]) >= 2
	var rect: Rect2 = Rect2(center - Vector2(edge, edge) / 2.0, Vector2(edge, edge))
	if owned:
		GameTheme.glow(_entries, center, edge * 0.85, Color(OWNED, 0.5))
	elif reachable:
		var halo: TextureRect = GameTheme.glow(_entries, center, edge * 0.9, Color(GameTheme.RECOMMEND, 0.75))
		halo.create_tween().set_loops().tween_property(halo, "modulate:a", 0.25, 0.7).from(0.75)
	var medal: Medal = Medal.new()
	medal.ring = GameTheme.RECOMMEND if reachable else GameTheme.TIER_RING[dragon["tier"]]
	medal.tint = GameTheme.COLOR.get(dragon["elements"].front(), GameTheme.GOLD)
	medal.known = known or reachable
	medal.owned = owned
	medal.crown = dragon["tier"] in ["apex", "secret"]
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_entries, medal, rect)
	_medals[id] = medal
	var caption: String = dragon["nameKo"] if known else "???"
	if dragon["tier"] == "secret" and not known:
		GameTheme.heading(medal, Rect2(0, 0, edge, edge), "?", int(edge * 0.5), GameTheme.TIER_RING["secret"], HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var inset: float = edge * 0.14
		var image: TextureRect = portrait(medal, Rect2(inset, inset, edge - inset * 2.0, edge - inset * 2.0), id)
		if image != null and not known:
			image.modulate = SHADOW
	var tap: Button = GameTheme.ghost(_entries, rect, _show_detail.bind(dragon), int(edge / 2.0))
	tap.tooltip_text = caption
	var name_label: Label = GameTheme.label(_entries, Rect2(center.x - name_width / 2.0, center.y + edge / 2.0 - 2.0, name_width, 30), caption, 11,
		GameTheme.TEXT if known else Color(GameTheme.DIM, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.wrap(name_label)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.add_theme_constant_override("line_spacing", -3)
	GameTheme.outline(name_label, 4, Color(0, 0, 0, 0.7))
	var tag: String = ""
	var tag_color: Color = OWNED
	if owned:
		tag = "Lv.%d" % int(_owned[id])
	elif reachable:
		tag = "합체"
		tag_color = GameTheme.RECOMMEND
	if not tag.is_empty():
		var pill: Panel = GameTheme.panel(_entries, Rect2(center.x + edge * 0.12, rect.position.y - 5, 40, 17), Color("#0b0b10"), tag_color, 1, 8, "flat")
		GameTheme.label(pill, Rect2(0, 0, 40, 16), tag, 11, tag_color, HORIZONTAL_ALIGNMENT_CENTER)


## 오른쪽 설명 판. 빈 값이면 안내 문구.
func _show_detail(dragon: Dictionary) -> void:
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if _medals.has(_picked):
		_medals[_picked].picked = false
		_medals[_picked].queue_redraw()
	var w: float = SIDE.size.x
	if dragon.is_empty():
		_picked = ""
		GameTheme.heading(_detail, Rect2(0, 190, w, 34), "용을 골라 보세요", 22, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.divider(_detail, Rect2(60, 230, w - 120, 8), GameTheme.GOLD_DIM)
		var help: String = "마디를 누르면 설명과 만드는 법이 여기에 나와요."
		if not _owned.is_empty():
			help += "\n\n초록 테두리는 지금 가진 용이에요. 금빛으로 깜빡이는 용은 지금 가진 용 둘로 바로 만들 수 있어요."
		var guide: Label = GameTheme.label(_detail, Rect2(34, 246, w - 68, 150), help, 15, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		GameTheme.wrap(guide)
		guide.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		return
	var id: String = dragon["id"]
	_picked = id
	if _medals.has(id):
		_medals[id].picked = true
		_medals[id].queue_redraw()
	var known: bool = _known(dragon)
	var entry: Dictionary = _codex.get(id, {})
	var tier: String = dragon["tier"]
	var tint: Color = GameTheme.COLOR.get(dragon["elements"].front(), GameTheme.GOLD)
	GameTheme.glow(_detail, Vector2(w / 2.0, 104), 150.0, Color(tint, 0.4 if known else 0.12))
	var medal: Medal = Medal.new()
	medal.ring = GameTheme.TIER_RING[tier]
	medal.tint = tint
	medal.known = known
	medal.owned = _owned.has(id)
	medal.crown = tier in ["apex", "secret"]
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_detail, medal, Rect2(w / 2.0 - 80, 24, 160, 160))
	if tier == "secret" and not known:
		GameTheme.heading(medal, Rect2(0, 0, 160, 160), "?", 80, GameTheme.TIER_RING["secret"], HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var image: TextureRect = portrait(medal, Rect2(20, 20, 120, 120), id)
		if image != null and not known:
			image.modulate = SHADOW
	GameTheme.heading(_detail, Rect2(8, 190, w - 16, 34), dragon["nameKo"] if known else "???", 24, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	var elements: PackedStringArray = PackedStringArray()
	for element: String in dragon["elements"]:
		elements.append(GameTheme.ELEMENT_KO.get(element, element))
	var kind: String = "숨은 드래곤" if tier == "secret" else GameTheme.TIER_KO[tier]
	GameTheme.label(_detail, Rect2(8, 224, w - 16, 22), "%s · %s · %s" % [kind, "+".join(elements), ROLE_KO.get(dragon.get("role", ""), "")], 14, GameTheme.TIER_RING[tier], HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.divider(_detail, Rect2(40, 250, w - 80, 8), GameTheme.GOLD_DIM)
	var y: float = 266.0
	if known:
		var stats: Dictionary = dragon["stats"]
		_stat(Rect2(24, y, (w - 56) / 2.0, 44), "체력", str(int(stats["hp"])), Color("#8ce99a"))
		_stat(Rect2(24 + (w - 56) / 2.0 + 8, y, (w - 56) / 2.0, 44), "공격력", str(int(stats["atk"])), Color("#ffa58a"))
		y += 54.0
		var trait_spec: Variant = _data["traits"].get(dragon.get("traitId", ""))
		if trait_spec != null:
			GameTheme.label(_detail, Rect2(24, y, w - 48, 20), "특성 「%s」" % trait_spec["nameKo"], 14, GameTheme.GOLD)
			y += 26.0
		var ability: String = GameTheme.ability_text(_data, id)
		if not ability.is_empty():
			y = _paragraph("능력 " + ability, y, GameTheme.GOLD_HI) + 6.0
		y = _paragraph(entry.get("loreKo", ""), y, GameTheme.TEXT) + 8.0
		if _owned.has(id):
			GameTheme.label(_detail, Rect2(24, y, w - 48, 20), "지금 가지고 있어요 · 레벨 %d" % int(_owned[id]), 14, OWNED)
			y += 26.0
	else:
		y = _paragraph("힌트: " + entry.get("hintKo", "아직 알려지지 않았어요."), y, GameTheme.DIM) + 8.0
	var recipe: Dictionary = _best_recipe(id)
	if tier == "base":
		var rarity: Array = GameTheme.rarity(Slot.species_weight(_data, id))
		GameTheme.heading(_detail, Rect2(24, y, w - 48, 24), "얻는 법", 16, GameTheme.GOLD)
		GameTheme.label(_detail, Rect2(24, y + 26, w - 48, 20), "룬 석판의 알 · %s · 칸마다 %s" % [rarity[0], GameTheme.percent(Slot.species_odds(_data, id, _slab))], 14, rarity[1])
		y += 56.0
	elif not recipe.is_empty() and (known or int(recipe["have"]) > 0):
		GameTheme.heading(_detail, Rect2(24, y, w - 48, 24), "만드는 법", 16, GameTheme.GOLD)
		y += 28.0
		_ingredient(Rect2(24, y, 64, 64), recipe["a"])
		GameTheme.heading(_detail, Rect2(88, y, 28, 64), "+", 22, GameTheme.GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_ingredient(Rect2(116, y, 64, 64), recipe["b"])
		var need: int = Fusion.evolve_level(_data, id)
		var how: Label = GameTheme.label(_detail, Rect2(190, y, w - 208, 64),
			"%s + %s\n둘 중 하나가 레벨 %d 이상" % [_name_or_unknown(recipe["a"]), _name_or_unknown(recipe["b"]), need], 12, GameTheme.TEXT)
		GameTheme.wrap(how)
		y += 70.0
		GameTheme.label(_detail, Rect2(24, y, w - 48, 18), "이 용이 되는 조합은 모두 %d가지예요" % _recipes.get(id, []).size(), 12, GameTheme.DIM)
		y += 24.0
	var next: String = _parent(id)
	if not next.is_empty() and y < SIDE.size.y - 30.0:
		GameTheme.label(_detail, Rect2(24, y, w - 48, 20), "같은 용 둘을 합치면 → %s" % _name_or_unknown(next), 13, tint.lightened(0.45))


func _stat(rect: Rect2, title: String, value: String, tint: Color) -> void:
	var box: Panel = GameTheme.well(_detail, rect, 8)
	GameTheme.label(box, Rect2(10, 0, 60, rect.size.y), title, 12, GameTheme.DIM)
	GameTheme.heading(box, Rect2(0, 0, rect.size.x - 12, rect.size.y), value, 20, tint, HORIZONTAL_ALIGNMENT_RIGHT)


func _paragraph(copy: String, y: float, color: Color) -> float:
	var text: Label = GameTheme.label(_detail, Rect2(24, y, SIDE.size.x - 48, 20), copy, 14, color)
	GameTheme.wrap(text)
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var lines: int = maxi(1, ceili(GameTheme.korean_font().get_multiline_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, SIDE.size.x - 48, 14).y / 20.0))
	text.size.y = lines * 22.0
	return y + lines * 22.0


func _ingredient(rect: Rect2, id: String) -> void:
	var dragon: Dictionary = _data["dragons"][id]
	var medal: Medal = Medal.new()
	medal.ring = GameTheme.TIER_RING[dragon["tier"]]
	medal.tint = GameTheme.COLOR.get(dragon["elements"].front(), GameTheme.GOLD)
	medal.known = _known(dragon)
	medal.owned = _owned.has(id)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_detail, medal, rect)
	var image: TextureRect = portrait(medal, Rect2(9, 9, rect.size.x - 18, rect.size.y - 18), id)
	if image != null and not medal.known:
		image.modulate = SHADOW


func _name_or_unknown(id: String) -> String:
	var dragon: Dictionary = _data["dragons"][id]
	return dragon["nameKo"] if _known(dragon) else "???"
