extends RefCounted

const HEIGHT: float = 720.0
const MIN_WIDTH: float = 1280.0
const MAX_WIDTH: float = 1600.0
const HUD_H: float = 44.0
const LEFT_RATIO: float = 0.34
const LEFT_MIN: float = 440.0
const LEFT_MAX: float = 544.0
const FIELD_MARGIN: float = 30.0
const LANE_Y: Array = [194.0, 382.0, 570.0]
const CARD_SIZE: Vector2 = Vector2(120, 88)


static func left_width(width: float) -> float:
	return clampf(roundf(clampf(width, MIN_WIDTH, MAX_WIDTH) * LEFT_RATIO), LEFT_MIN, LEFT_MAX)


## 화면 폭(1280~1600)에 맞춘 배치. 위 HUD, 왼쪽 조작 패널(약 34%), 오른쪽 전장.
static func areas(width: float) -> Dictionary:
	var w: float = clampf(width, MIN_WIDTH, MAX_WIDTH)
	var left: float = left_width(w)
	var inner: float = left - 32.0
	var bench_y: float = HUD_H + 430.0
	var bench_w: float = CARD_SIZE.x * 2 + 8
	return {
		"width": w,
		"hud": Rect2(0, 0, w, HUD_H),
		"left": Rect2(0, HUD_H, left, HEIGHT - HUD_H),
		"field": Rect2(left, HUD_H, w - left, HEIGHT - HUD_H),
		"spin": Rect2(16, HUD_H + 346, inner, 54),
		"offers": Rect2(238, HUD_H + 98, left - 238 - 16, 206),
		"bench": Rect2(16, bench_y, bench_w, CARD_SIZE.y * 2 + 8),
		"release": Rect2(16 + bench_w + 8, bench_y, inner - bench_w - 8, CARD_SIZE.y * 2 + 8),
	}


## core 전장 좌표(x 0~1000, 줄 0~2) → 화면 좌표(유닛 중심).
static func field_point(width: float, x: float, lane: float) -> Vector2:
	var w: float = clampf(width, MIN_WIDTH, MAX_WIDTH)
	var left: float = left_width(w)
	var lane_y: float = lerpf(LANE_Y[0], LANE_Y[2], clampf(lane, 0.0, 2.0) / 2.0)
	return Vector2(left + FIELD_MARGIN + x * (w - left - 2.0 * FIELD_MARGIN) / 1000.0, lane_y)


## 둥지 칸(0~5)의 발판 사각형. 전열 0~2, 후열 3~5, 줄 = 번호 % 3.
static func pad_rect(width: float, field_cfg: Dictionary, index: int) -> Rect2:
	var x: int = int(field_cfg["frontX"]) if index < 3 else int(field_cfg["backX"])
	var center: Vector2 = field_point(width, x, index % 3)
	return Rect2(center - CARD_SIZE / 2.0, CARD_SIZE)


## 배경 그림: 웨이브 구간별.
static func background_for(wave: int) -> String:
	if wave <= 10:
		return "res://assets/backgrounds/plains_ruins.png"
	if wave <= 20:
		return "res://assets/backgrounds/ice_canyon.png"
	if wave <= 30:
		return "res://assets/backgrounds/volcano.png"
	return "res://assets/backgrounds/abyss.png"
const COLOR: Dictionary = {
	"fire": Color("#e8590c"), "ice": Color("#4dabf7"), "lightning": Color("#fab005"),
	"poison": Color("#82c91e"), "steel": Color("#adb5bd"), "abyss": Color("#5f3dc4"),
	"gold": Color("#d4af37"), "wild": Color("#f783ac"),
}
const ELEMENT_KO: Dictionary = {
	"fire": "불", "ice": "얼음", "lightning": "번개", "poison": "독", "steel": "강철", "abyss": "심연",
}
const SYMBOL_LABEL: Dictionary = {
	"fire": "불", "ice": "얼음", "lightning": "번개", "poison": "독", "steel": "강철", "abyss": "심연",
	"gold": "금", "wild": "여의주",
}
const TIER_KO: Dictionary = {"base": "기본", "t2": "2티어", "t1": "1티어", "apex": "정점", "dual": "이중", "secret": "???"}
const NEW_COLOR: Color = Color("#66d9e8")
const PANEL: Color = Color("#232838")
const PANEL_LINE: Color = Color("#3a4157")
const TEXT: Color = Color("#e9ecf5")
const DIM: Color = Color("#8a93ab")
const CARD: Color = Color("#2b3045")
const INK: Color = Color("#1b1f2a")
const RECOMMEND: Color = Color("#ffd43b")
const FONT_PATH: String = "res://godot/fonts/NotoSansKR.ttf"
const FONT_WEIGHT: int = 500


static func create() -> Theme:
	var skin: Theme = Theme.new()
	skin.default_font = korean_font()
	return skin


## 배포판에 넣는 Noto Sans KR(OFL, godot/fonts/OFL-NotoSansKR.txt). 없으면 시스템 글꼴로.
static func korean_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var bundled: Font = load(FONT_PATH) as Font
		if bundled != null:
			# 가변 글꼴이라 굵기를 정해 줘야 가늘게 나오지 않는다.
			var weighted: FontVariation = FontVariation.new()
			weighted.base_font = bundled
			weighted.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): FONT_WEIGHT}
			return weighted
	var system: SystemFont = SystemFont.new()
	system.font_names = PackedStringArray(["Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo"])
	return system


## 만분율을 "5.9%"처럼.
static func percent(odds: int) -> String:
	return "%d.%d%%" % [Rng.fdiv(odds, 100), Rng.fdiv(odds % 100, 10)]


## 알이 나올 확률(만분율)에 따른 희귀도 이름과 색.
static func rarity(odds: int) -> Array:
	if odds >= 500:
		return ["흔함", Color("#adb5bd")]
	if odds >= 400:
		return ["보통", Color("#8ce99a")]
	if odds >= 200:
		return ["드묾", Color("#74c0fc")]
	return ["희귀", Color("#ffd43b")]


## 도감에 없는 용에 붙이는 "새 용!" 표시(깜빡이는 테두리 + 꼬리표).
static func new_badge(card: Control, card_size: Vector2) -> void:
	var outline: Panel = panel(card, Rect2(Vector2(-3, -3), card_size + Vector2(6, 6)), Color.TRANSPARENT, NEW_COLOR, 3, 10)
	outline.create_tween().set_loops().tween_property(outline, "modulate:a", 0.3, 0.6).from(1.0)
	var tag: Panel = panel(card, Rect2(card_size.x - 58, -10, 62, 20), Color("#0b3d46"), NEW_COLOR, 2, 8)
	label(tag, Rect2(0, 0, 62, 20), "새 용!", 12, NEW_COLOR, HORIZONTAL_ALIGNMENT_CENTER)


static func place(parent: Control, child: Control, rect: Rect2) -> void:
	child.position = rect.position
	child.size = rect.size
	child.set_meta("placed_size", rect.size)
	parent.add_child(child)


static func style(fill: Color, border: Color, width: int = 0, radius: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box


static func panel(parent: Control, rect: Rect2, fill: Color, border: Color = PANEL_LINE, width: int = 0, radius: int = 0) -> Panel:
	var node: Panel = Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(fill, border, width, radius))
	place(parent, node, rect)
	return node


static func label(parent: Control, rect: Rect2, copy: String, pixels: int, color: Color = TEXT, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node: Label = Label.new()
	node.text = copy
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	place(parent, node, rect)
	return node


## 한글은 기본 줄바꿈이 음절 사이에서도 끊어서, 단어 안 글자 사이에 U+2060(단어 연결)을 넣어
## 띄어쓰기에서만 줄을 바꾼다(CSS keep-all). 한 단어가 너무 길면 WORD_SMART가 알아서 끊는다.
static func keep_words(copy: String) -> String:
	var out: String = ""
	var prev_word: bool = false
	for i in copy.length():
		var ch: String = copy[i]
		var word: bool = ch != " " and ch != "\n" and ch != "\t"
		if word and prev_word:
			out += "⁠"
		out += ch
		prev_word = word
	return out


static func wrap(node: Label) -> Label:
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text = keep_words(node.text)
	# 줄바꿈을 켜기 전에 긴 글자 때문에 넓어진 칸을 원래 너비로 되돌린다.
	if node.has_meta("placed_size"):
		node.size = node.get_meta("placed_size")
	return node


static func button(parent: Control, rect: Rect2, copy: String, action: Callable, fill: Color = CARD, border: Color = PANEL_LINE, width: int = 1) -> Button:
	var node: Button = Button.new()
	node.text = copy
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_stylebox_override("normal", style(fill, border, width, 8))
	node.add_theme_stylebox_override("hover", style(fill.lightened(0.12), border, width, 8))
	node.add_theme_stylebox_override("pressed", style(fill.darkened(0.15), border, width, 8))
	node.add_theme_stylebox_override("disabled", style(fill.darkened(0.4), border, width, 8))
	node.pressed.connect(action)
	place(parent, node, rect)
	return node


static func dragon(parent: Control, rect: Rect2, id: String, flip: bool = true) -> TextureRect:
	var path: String = "res://assets/dragons/%s.png" % id
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var image: TextureRect = TextureRect.new()
	image.texture = load(path) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.flip_h = flip
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(parent, image, rect)
	return image
