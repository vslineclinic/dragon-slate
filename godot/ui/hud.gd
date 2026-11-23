extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")

signal boss_info(message: String)

var _store: Store
var _wave: Label
var _lives: Label
var _mana: Label
var _boss: Button
var _speeds: Dictionary = {}
var _preview: Dictionary = {}


func setup(store: Store, width: float = 1280.0) -> void:
	_store = store
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#151925"))
	_wave = GameTheme.label(self, Rect2(16, 0, 160, 44), "", 20)
	_lives = GameTheme.label(self, Rect2(180, 0, 160, 44), "", 20, Color("#ff8787"))
	_mana = GameTheme.label(self, Rect2(340, 0, 130, 44), "", 20, Color("#b197fc"))
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
	var lives: int = maxi(0, state["lives"])
	_lives.text = "생명 " + ("♥".repeat(lives) if lives <= 6 else "♥ ×%d" % lives)
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
