extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const Icons = preload("res://godot/ui/icons.gd")

signal boss_info(message: String)

var _store: Store
var _wave: Label
var _lives: Label
var _mana: Label
var _wave_bar: Panel
var _boss: Button
var _speeds: Dictionary = {}
var _preview: Dictionary = {}


func setup(store: Store, width: float = 1280.0) -> void:
	_store = store
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#0b0b10"))
	GameTheme.panel(self, Rect2(0, size.y - 2, size.x, 2), Color(GameTheme.GOLD_DIM, 0.55))
	_wave = GameTheme.heading(self, Rect2(16, 0, 160, 40), "", 20, GameTheme.GOLD_HI)
	GameTheme.panel(self, Rect2(16, 36, 140, 3), Color(1, 1, 1, 0.08))
	_wave_bar = GameTheme.panel(self, Rect2(16, 36, 0, 3), GameTheme.GOLD)
	_lives = GameTheme.label(self, Rect2(180, 0, 160, 44), "", 19, Color("#ff7b8c"))
	GameTheme.place(self, Icons.new("mana", Color("#a58bff"), false), Rect2(336, 11, 22, 22))
	_mana = GameTheme.heading(self, Rect2(362, 0, 108, 44), "", 20, Color("#c9b8ff"))
	_boss = GameTheme.button(self, Rect2(470, 0, maxf(300.0, width - 404 - 470 - 8), 44), "", _show_boss_info)
	_boss.clip_text = true
	_boss.flat = true
	_boss.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss.add_theme_font_size_override("font_size", 16)
	for name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		_boss.add_theme_color_override(name, Color("#ffc078"))
	for i: int in range(3):
		var speed: int = 1 << i
		_speeds[speed] = GameTheme.button(self, Rect2(width - 240 + i * 78, 0, 70, 44), "%dx" % speed, _set_speed.bind(speed))
	_refresh_speed()


func set_boss_preview(wave: int, element: Variant, spec: Variant) -> void:
	if element != null:
		_preview = {"wave": wave + 4, "element": element, "spec": spec}
	elif wave == 1 or (not _preview.is_empty() and wave > _preview["wave"]):
		_preview.clear()


func render(state: Dictionary, max_wave: int) -> void:
	_wave.text = "웨이브 %d / %d" % [state["wave"], max_wave]
	_wave_bar.size.x = 140.0 * clampf(float(state["wave"]) / maxf(1.0, max_wave), 0.0, 1.0)
	var lives: int = maxi(0, state["lives"])
	_lives.text = "♥".repeat(lives) if lives <= 6 else "♥ ×%d" % lives
	_lives.tooltip_text = "생명"
	_mana.text = "마력 %d" % state["mana"]
	_boss.visible = not _preview.is_empty()
	if _preview.is_empty():
		return
	var spec: Variant = _preview["spec"]
	var name: String = "" if spec == null else spec["nameKo"] + " · "
	_boss.text = "%d웨이브 보스: %s%s 원소%s" % [
		_preview["wave"], name, GameTheme.ELEMENT_KO.get(_preview["element"], _preview["element"]),
		"" if spec == null else "  (눌러서 보기)",
	]
	_boss.disabled = spec == null


func _show_boss_info() -> void:
	var spec: Variant = _preview.get("spec")
	if spec != null:
		boss_info.emit("%s\n%s\n대응: %s" % [spec["nameKo"], spec["descKo"], spec["hintKo"]])


func _set_speed(speed: int) -> void:
	_store.speed = speed
	_refresh_speed()


func _refresh_speed() -> void:
	for speed: int in _speeds:
		_speeds[speed].modulate.a = 1.0 if speed == _store.speed else 0.45
