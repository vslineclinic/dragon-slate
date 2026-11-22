extends RefCounted

const AREA: Dictionary = {
	"hud": Rect2(0, 0, 1280, 44),
	"battle": Rect2(0, 44, 1280, 286),
	"nest": Rect2(0, 330, 640, 390),
	"slab": Rect2(640, 330, 640, 390),
}
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
const TIER_KO: Dictionary = {"base": "기본", "t2": "2티어", "t1": "1티어", "dual": "이중", "secret": "???"}
const PANEL: Color = Color("#232838")
const PANEL_LINE: Color = Color("#3a4157")
const TEXT: Color = Color("#e9ecf5")
const DIM: Color = Color("#8a93ab")
const CARD: Color = Color("#2b3045")
const INK: Color = Color("#1b1f2a")
const RECOMMEND: Color = Color("#ffd43b")


static func create() -> Theme:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Apple SD Gothic Neo"])
	var skin: Theme = Theme.new()
	skin.default_font = font
	return skin


static func place(parent: Control, child: Control, rect: Rect2) -> void:
	child.position = rect.position
	child.size = rect.size
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
