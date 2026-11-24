extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Build = preload("res://godot/ui/build.gd")
const Store = preload("res://godot/ui/store.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")
const Music = preload("res://godot/ui/music.gd")
const Ambience = preload("res://godot/ui/ambience.gd")
const Game = preload("res://godot/ui/game.gd")
const GameScene = preload("res://godot/scenes/game.tscn")
const Controller = preload("res://godot/ui/controller.gd")
const AppWindow = preload("res://godot/ui/window.gd")

var _data: Dictionary
var _store: Store
var _menu: Control
var _game: Game
var _start_button: Button
var _dex_button: Button
var _music_button: Button
var _calamity_label: Label
var _lower: Button
var _higher: Button
var _level: int = 0
var _max_level: int = 0


func _ready() -> void:
	_data = Build.load_data()
	_store = Store.new()
	_max_level = Build.max_calamity(_data)
	theme = GameTheme.create()
	AppWindow.fit_first_time()
	var width: float = get_viewport_rect().size.x
	var full: Rect2 = Rect2(0, 0, maxf(width, 1280.0), 720)
	GameTheme.panel(self, full, GameTheme.INK)
	_menu = Control.new()
	GameTheme.place(self, _menu, full)
	GameTheme.picture(_menu, full, "res://assets/backgrounds/title.png")
	Ambience.particles(_menu, full, "embers")
	Ambience.vignette(_menu, full, 0.55)
	var left: float = (full.size.x - 1280.0) / 2.0
	var stage: Control = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(_menu, stage, Rect2(left, 0, 1280, 720))
	## 양옆의 두 용: 뒤에 원소 빛을 깔아 배경에서 떠오르게 한다.
	for hero: Array in [["zhulong", 30.0, true, "fire"], ["kuraokami", 930.0, false, "ice"]]:
		GameTheme.glow(stage, Vector2(hero[1] + 160.0, 410.0), 250.0, Color(GameTheme.COLOR[hero[3]], 0.3))
		var sprite: TextureRect = GameTheme.dragon(stage, Rect2(hero[1], 250, 320, 320), hero[0], hero[2])
		if sprite != null:
			var bob: Tween = sprite.create_tween().set_loops()
			bob.tween_property(sprite, "position:y", 242.0, 2.4).set_trans(Tween.TRANS_SINE)
			bob.tween_property(sprite, "position:y", 250.0, 2.4).set_trans(Tween.TRANS_SINE)
	GameTheme.glow(stage, Vector2(640, 150), 420.0, Color(0, 0, 0, 0.0))
	_logo(stage)
	var subtitle: String = "룬 석판 드래곤 로그라이트"
	if OS.has_feature("demo"):
		subtitle += " · 무료 데모"
	GameTheme.divider(stage, Rect2(390, 236, 500, 10))
	GameTheme.heading(stage, Rect2(240, 248, 800, 40), subtitle, 24, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var intro: String = "석판을 돌려 알을 얻고 · 드래곤 둘을 합쳐 신화룡을 깨우고 · %d웨이브를 버텨요" % _data["waves"]["maxWave"]
	GameTheme.outline(GameTheme.label(stage, Rect2(240, 290, 800, 30), intro, 16, Color("#e9dcc4"), HORIZONTAL_ALIGNMENT_CENTER), 4, Color(0, 0, 0, 0.6))
	_start_button = GameTheme.cta(stage, Rect2(500, 540, 280, 64), "시작하기", _start, "gold", 26)
	_dex_button = GameTheme.button(stage, Rect2(530, 620, 220, 48), "드래곤 도감", _open_dex, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	var music: Node = Music.get_for(get_tree())
	music.play("title")
	_music_button = GameTheme.button(stage, Rect2(1160, 20, 100, 44), Music.SET_KO[music.current_set()], _cycle_music, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_music_button.tooltip_text = "배경음악: A, B, 끔"
	_lower = GameTheme.button(stage, Rect2(850, 548, 44, 48), "◀", _select_level.bind(-1), Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_higher = GameTheme.button(stage, Rect2(1190, 548, 44, 48), "▶", _select_level.bind(1), Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_calamity_label = GameTheme.label(stage, Rect2(902, 524, 280, 96), "", 16, Color("#ffc078"), HORIZONTAL_ALIGNMENT_CENTER)
	_calamity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_level(0)
	_start_button.grab_focus()


## 금박 로고: 넓은 자간의 명조 대문자 + 위아래 금줄.
func _logo(stage: Control) -> void:
	var font: FontVariation = FontVariation.new()
	font.base_font = GameTheme.serif_font(900)
	font.spacing_glyph = 10
	var heading: Label = GameTheme.label(stage, Rect2(140, 96, 1000, 140), "WYRMSLOT", 104, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_override("font", font)
	heading.add_theme_color_override("font_outline_color", Color("#2a1405"))
	heading.add_theme_constant_override("outline_size", 14)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	heading.add_theme_constant_override("shadow_offset_y", 7)
	heading.add_theme_constant_override("shadow_outline_size", 22)
	var gilt: ShaderMaterial = ShaderMaterial.new()
	gilt.shader = load("res://godot/ui/gold_text.gdshader") as Shader
	gilt.set_shader_parameter("top_y", 22.0)
	gilt.set_shader_parameter("bottom_y", 118.0)
	heading.material = gilt


func _unhandled_input(event: InputEvent) -> void:
	if AppWindow.handle_shortcut(event):
		get_viewport().set_input_as_handled()


func _select_level(delta: int) -> void:
	var unlocked: int = mini(_store.unlocked(), _max_level)
	_level = clampi(_level + delta, 0, unlocked)
	_lower.visible = unlocked > 0
	_higher.visible = unlocked > 0
	_calamity_label.visible = unlocked > 0
	_lower.disabled = _level == 0
	_higher.disabled = _level == unlocked
	_calamity_label.text = "재앙 없음"
	for calamity: Dictionary in _data["calamity"]:
		if calamity["level"] == _level:
			_calamity_label.text = "%s\n%s (누적)" % [calamity["nameKo"], calamity["descKo"]]
			break


func _cycle_music() -> void:
	_music_button.text = Music.SET_KO[Music.get_for(get_tree()).cycle_set()]


func _open_dex() -> void:
	var dex: DexOverlay = DexOverlay.new()
	_menu.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	dex.closed.connect(_close_dex)
	add_child(dex)
	dex.setup(_data, _store)


func _close_dex() -> void:
	_menu.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_dex_button.grab_focus()


func _start() -> void:
	var seed_value: int = int(Time.get_unix_time_from_system() * 1000.0) % 1000000007
	_game = GameScene.instantiate() as Game
	_game.controller = Controller.new(_data, seed_value)
	_game.store = _store
	_game.calamity = _level
	_game.title_requested.connect(_return_to_title)
	_menu.hide()
	add_child(_game)


func _return_to_title() -> void:
	_game.hide()
	_game.queue_free()
	_game = null
	_select_level(0)
	_menu.show()
	_start_button.grab_focus()
