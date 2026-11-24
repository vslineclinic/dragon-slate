extends RefCounted
## 화풍 "용 신전": 흑요석 판 · 금박 선 · 양피지색 글자. 제목은 명조(Noto Serif KR), 본문은 고딕(Noto Sans KR).

const OrnateBox = preload("res://godot/ui/ornate_box.gd")

const HEIGHT: float = 720.0
const MIN_WIDTH: float = 1280.0
const MAX_WIDTH: float = 1600.0
const HUD_H: float = 44.0
## 왼쪽 조작 패널의 폭(석판 한 장과 알 카드가 들어갈 만큼만). 나머지는 모두 전장이다.
const LEFT_W: float = 316.0
const FIELD_MARGIN: float = 30.0
## 세 줄의 높이. 전장 아래쪽은 대기칸 띠가 쓴다.
const LANE_Y: Array = [176.0, 340.0, 504.0]
const CARD_SIZE: Vector2 = Vector2(120, 88)
## 왼쪽 패널 안의 세로 배치(패널 맨 위에서 잰 값): 석판, 알 카드 3장, 돌리기 단추.
const SLAB_TOP: float = 136.0
const OFFER_TOP: float = 384.0
const OFFER_STEP: float = 60.0
const SPIN_TOP: float = 566.0
## 대기칸 띠: 전장 맨 아래.
const BENCH_Y: float = 622.0


static func left_width(_width: float) -> float:
	return LEFT_W


## 화면 폭(1280~1600)에 맞춘 배치(2026-11-24 개정). 위 HUD, 왼쪽 조작 패널(석판 · 알 카드 · 돌리기), 오른쪽 전장.
## 대기칸과 놓아주기 칸은 전장 아래쪽 띠에 있다.
static func areas(width: float) -> Dictionary:
	var w: float = clampf(width, MIN_WIDTH, MAX_WIDTH)
	var left: float = left_width(w)
	var inner: float = left - 32.0
	var bench_x: float = left + 52.0
	var bench_w: float = CARD_SIZE.x * 4 + 8 * 3
	return {
		"width": w,
		"hud": Rect2(0, 0, w, HUD_H),
		"left": Rect2(0, HUD_H, left, HEIGHT - HUD_H),
		"field": Rect2(left, HUD_H, w - left, HEIGHT - HUD_H),
		"spin": Rect2(16, HUD_H + SPIN_TOP, inner, 54),
		"offers": Rect2(16, HUD_H + OFFER_TOP, inner, OFFER_STEP * 3 - 6),
		"bench": Rect2(bench_x, BENCH_Y, bench_w, CARD_SIZE.y),
		"release": Rect2(bench_x + bench_w + 12, BENCH_Y, 168, CARD_SIZE.y),
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


## 배경 위에 떠다니는 빛: 평원 꽃가루 · 협곡 눈 · 화산 불티 · 심연 먼지.
static func ambience_for(wave: int) -> String:
	if wave <= 10:
		return "pollen"
	if wave <= 20:
		return "snow"
	if wave <= 30:
		return "embers"
	return "motes"


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
	"fire": Color("#f0622a"), "ice": Color("#58b8f5"), "lightning": Color("#f7b928"),
	"poison": Color("#8fd13c"), "steel": Color("#b4bcc8"), "abyss": Color("#7a54e0"),
	"gold": Color("#d9b25f"), "wild": Color("#f783ac"),
}
const ELEMENT_KO: Dictionary = {
	"fire": "불", "ice": "얼음", "lightning": "번개", "poison": "독", "steel": "강철", "abyss": "심연",
}
## 그 종의 형태별 능력을 "「이름」 설명"으로. 능력이 없으면 빈 글.
static func ability_text(data: Dictionary, species_id: String) -> String:
	var id: String = Battle.ability_of(data, species_id)
	if id.is_empty():
		return ""
	var spec: Dictionary = data["battle"]["abilities"][id]
	return "「%s」 %s" % [spec.get("nameKo", id), spec.get("descKo", "")]


## 역할 이름과 한 줄 설명. 전열·후열(놓는 자리)과 헷갈리지 않게 수호·사수·지원이라 부른다.
const ROLE_KO: Dictionary = {"front": "수호", "back": "사수", "support": "지원"}
const ROLE_NOTE: Dictionary = {
	"front": "체력이 높아 앞에서 버텨요",
	"back": "멀리 쏘고, 다른 줄을 쳐도 덜 약해져요",
	"support": "고루 갖췄어요",
}
const SYMBOL_LABEL: Dictionary = {
	"fire": "불", "ice": "얼음", "lightning": "번개", "poison": "독", "steel": "강철", "abyss": "심연",
	"gold": "금", "wild": "여의주",
}
const TIER_KO: Dictionary = {"base": "기본", "t2": "2티어", "t1": "1티어", "apex": "정점", "dual": "이중", "secret": "???"}
## 계급마다 메달 테두리 색: 청동 → 은 → 금 → 백금빛.
const TIER_RING: Dictionary = {
	"base": Color("#a8774a"), "t2": Color("#c3ccd6"), "t1": Color("#e6bd55"), "apex": Color("#fff0b8"),
	"dual": Color("#c9a3ff"), "secret": Color("#ff9ec4"),
}
const NEW_COLOR: Color = Color("#6fe3ee")
const INK: Color = Color("#0d0d13")
const PANEL: Color = Color("#191821")
const CARD: Color = Color("#24222d")
const WELL: Color = Color("#111017")
const PANEL_LINE: Color = Color("#4d4334")
const GOLD: Color = Color("#d9b25f")
const GOLD_HI: Color = Color("#f7e4a8")
const GOLD_DIM: Color = Color("#8a6f3a")
const EMBER: Color = Color("#c8401f")
const MYSTIC: Color = Color("#5b40c0")
const TEXT: Color = Color("#f0e8d6")
const DIM: Color = Color("#9f9786")
const RECOMMEND: Color = Color("#ffd75e")
const FONT_PATH: String = "res://godot/fonts/NotoSansKR.ttf"
const SERIF_PATH: String = "res://godot/fonts/NotoSerifKR.ttf"
const FONT_WEIGHT: int = 500

static var _fonts: Dictionary = {}


static func create() -> Theme:
	var skin: Theme = Theme.new()
	skin.default_font = korean_font()
	skin.set_stylebox("panel", "TooltipPanel", style(Color("#0b0b10f2"), GOLD_DIM, 1, 6))
	skin.set_color("font_color", "TooltipLabel", TEXT)
	skin.set_font_size("font_size", "TooltipLabel", 14)
	return skin


## 배포판에 넣는 Noto Sans KR(OFL, godot/fonts/OFL-NotoSansKR.txt). 없으면 시스템 글꼴로.
static func korean_font() -> Font:
	return _font(FONT_PATH, FONT_WEIGHT, ["Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo"])


## 피해 숫자처럼 굵게 눈에 띄어야 하는 글자.
static func bold_font() -> Font:
	return _font(FONT_PATH, 900, ["Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo"])


## 제목용 명조: Noto Serif KR(OFL, godot/fonts/OFL-NotoSerifKR.txt).
static func serif_font(weight: int = 700) -> Font:
	return _font(SERIF_PATH, weight, ["Noto Serif KR", "Batang", "AppleMyungjo"])


static func _font(path: String, weight: int, fallback: Array) -> Font:
	var key: String = "%s:%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var made: Font
	var bundled: Font = load(path) as Font if ResourceLoader.exists(path) else null
	if bundled != null:
		# 가변 글꼴이라 굵기를 정해 줘야 가늘게 나오지 않는다.
		var weighted: FontVariation = FontVariation.new()
		weighted.base_font = bundled
		weighted.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		made = weighted
	else:
		var system: SystemFont = SystemFont.new()
		system.font_names = PackedStringArray(fallback)
		system.font_weight = weight
		made = system
	_fonts[key] = made
	return made


## 만분율을 "5.9%"처럼.
static func percent(odds: int) -> String:
	return "%d.%d%%" % [Rng.fdiv(odds, 100), Rng.fdiv(odds % 100, 10)]


## 종의 등장 비율(weight)에 따른 희귀도 이름과 색.
static func rarity(weight: int) -> Array:
	if weight >= 35:
		return ["흔함", Color("#b4bcc8")]
	if weight >= 25:
		return ["보통", Color("#8ce99a")]
	if weight >= 15:
		return ["드묾", Color("#74c0fc")]
	return ["희귀", Color("#ffd75e")]


## 도감에 없는 용에 붙이는 "새 용!" 표시(깜빡이는 테두리 + 꼬리표).
static func new_badge(card: Control, card_size: Vector2) -> void:
	var edge: Panel = panel(card, Rect2(Vector2(-3, -3), card_size + Vector2(6, 6)), Color.TRANSPARENT, NEW_COLOR, 3, 10)
	edge.create_tween().set_loops().tween_property(edge, "modulate:a", 0.3, 0.6).from(1.0)
	var tag: Panel = panel(card, Rect2(card_size.x - 58, -10, 62, 20), Color("#0b3d46"), NEW_COLOR, 2, 8)
	label(tag, Rect2(0, 0, 62, 20), "새 용!", 12, NEW_COLOR, HORIZONTAL_ALIGNMENT_CENTER)


static func place(parent: Control, child: Control, rect: Rect2) -> void:
	child.position = rect.position
	child.size = rect.size
	child.set_meta("placed_size", rect.size)
	parent.add_child(child)


## 테두리도 둥근 모서리도 없으면 그냥 색 막대, 아니면 광택 있는 판.
static func style(fill: Color, border: Color, width: int = 0, radius: int = 0, kind: String = "auto") -> StyleBox:
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = fill
	flat.border_color = border
	flat.set_border_width_all(width)
	flat.set_corner_radius_all(radius)
	flat.anti_aliasing_size = 0.8
	if width == 0 and radius == 0 and kind == "auto":
		return flat
	var box: OrnateBox = OrnateBox.new()
	box.base = flat
	box.kind = kind
	return box


static func panel(parent: Control, rect: Rect2, fill: Color, border: Color = PANEL_LINE, width: int = 0, radius: int = 0, kind: String = "auto") -> Panel:
	var node: Panel = Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(fill, border, width, radius, kind))
	place(parent, node, rect)
	return node


## 금박 테두리 큰 판(창 · 카드 묶음). 그림자와 모서리 장식이 붙는다.
static func frame(parent: Control, rect: Rect2, fill: Color = PANEL, border: Color = GOLD, radius: int = 12) -> Panel:
	var node: Panel = panel(parent, rect, fill, border, 2, radius, "frame")
	var box: OrnateBox = node.get_theme_stylebox("panel") as OrnateBox
	box.base.shadow_color = Color(0, 0, 0, 0.55)
	box.base.shadow_size = 18
	box.base.shadow_offset = Vector2(0, 6)
	return node


## 움푹 들어간 칸(빈 자리 · 석판 바닥).
static func well(parent: Control, rect: Rect2, radius: int = 8, line: Color = Color("#2c2820")) -> Panel:
	var node: Panel = panel(parent, rect, WELL, line, 1, radius, "flat")
	var shade: StyleBoxFlat = StyleBoxFlat.new()
	shade.bg_color = Color(0, 0, 0, 0.28)
	shade.corner_radius_top_left = radius
	shade.corner_radius_top_right = radius
	var top: Panel = Panel.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", shade)
	place(node, top, Rect2(1, 1, rect.size.x - 2, minf(8.0, rect.size.y / 3.0)))
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


## 명조 제목. 아래로 살짝 그림자가 져서 돌에 새긴 금박처럼 보인다.
static func heading(parent: Control, rect: Rect2, copy: String, pixels: int, color: Color = GOLD_HI, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, weight: int = 700) -> Label:
	var node: Label = label(parent, rect, copy, pixels, color, alignment)
	node.add_theme_font_override("font", serif_font(weight))
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", maxi(1, int(pixels / 14.0)))
	node.add_theme_constant_override("shadow_outline_size", maxi(2, int(pixels / 8.0)))
	return node


## 글자에 어두운 테두리를 둘러 그림 위에서도 읽히게 한다.
static func outline(node: Label, pixels: int = 5, color: Color = Color(0, 0, 0, 0.82)) -> Label:
	node.add_theme_constant_override("outline_size", pixels)
	node.add_theme_color_override("font_outline_color", color)
	return node


## 가운데 마름모가 박힌 금박 가로줄.
static func divider(parent: Control, rect: Rect2, color: Color = GOLD) -> Control:
	var node: Control = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(parent, node, rect)
	node.draw.connect(func() -> void:
		var mid: Vector2 = node.size / 2.0
		var reach: float = node.size.x / 2.0
		for side: float in [-1.0, 1.0]:
			node.draw_polyline_colors(
				PackedVector2Array([mid + Vector2(side * 10.0, 0), mid + Vector2(side * reach, 0)]),
				PackedColorArray([Color(color, 0.9), Color(color, 0.0)]), 1.0, true)
		node.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4), mid + Vector2(5, 0), mid + Vector2(0, 4), mid + Vector2(-5, 0)]), color)
	)
	return node


## 부드러운 빛 덩어리(더하기 합성).
static func glow(parent: Control, center: Vector2, radius: float, color: Color) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = load("res://assets/ui/glow.png") as Texture2D
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = additive
	place(parent, node, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	return node


static func picture(parent: Control, rect: Rect2, path: String, cover: bool = true) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", GOLD_HI)
	node.add_theme_color_override("font_focus_color", TEXT)
	node.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	node.add_theme_font_size_override("font_size", 18)
	var hover_line: Color = border.lightened(0.35)
	node.add_theme_stylebox_override("normal", style(fill, border, width, 8, "button"))
	node.add_theme_stylebox_override("hover", style(fill.lightened(0.1), hover_line, width, 8, "button"))
	node.add_theme_stylebox_override("pressed", style(fill.darkened(0.2), border, width, 8, "button"))
	node.add_theme_stylebox_override("disabled", style(fill.darkened(0.45), Color(border, border.a * 0.5), width, 8, "flat"))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color(GOLD_HI, 0.7), 2, 8, "flat"))
	node.pressed.connect(action)
	place(parent, node, rect)
	return node


## 그림 위에 얹는 보이지 않는 단추(누르는 자리만). 초점이 오면 금빛 테두리만 보인다.
static func ghost(parent: Control, rect: Rect2, action: Callable, radius: int = 10) -> Button:
	var node: Button = Button.new()
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	node.add_theme_stylebox_override("hover", style(Color(1, 1, 1, 0.05), Color(GOLD_HI, 0.35), 1, radius, "flat"))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color(GOLD_HI, 0.6), 2, radius, "flat"))
	node.pressed.connect(action)
	place(parent, node, rect)
	return node


## 눈에 띄는 큰 단추. tone: gold(금판 · 어두운 글자) · ember(붉은 전투) · mystic(보라 석판)
static func cta(parent: Control, rect: Rect2, copy: String, action: Callable, tone: String = "gold", pixels: int = 21) -> Button:
	var fills: Dictionary = {"gold": Color("#c99a3c"), "ember": EMBER, "mystic": MYSTIC}
	var lines: Dictionary = {"gold": GOLD_HI, "ember": Color("#ffb38a"), "mystic": Color("#c0adff")}
	var node: Button = button(parent, rect, copy, action, fills[tone], lines[tone], 2)
	node.add_theme_font_override("font", serif_font(800))
	node.add_theme_font_size_override("font_size", pixels)
	var ink: Color = Color("#231704") if tone == "gold" else Color("#fff6e6")
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, ink)
	for state: String in ["normal", "hover", "pressed"]:
		var box: OrnateBox = node.get_theme_stylebox(state) as OrnateBox
		box.gloss = 1.5
		box.base.shadow_color = Color(0, 0, 0, 0.5)
		box.base.shadow_size = 6
		box.base.shadow_offset = Vector2(0, 3)
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
