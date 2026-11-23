extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Build = preload("res://godot/ui/build.gd")
const Store = preload("res://godot/ui/store.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")
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
	GameTheme.panel(self, Rect2(0, 0, maxf(width, 1280.0), 720), Color("#141824"))
	_menu = Control.new()
	GameTheme.place(self, _menu, Rect2(maxf(0.0, (width - 1280.0) / 2.0), 0, 1280, 720))
	GameTheme.panel(_menu, Rect2(0, 0, 1280, 720), Color("#141824"))
	GameTheme.dragon(_menu, Rect2(135, 185, 230, 230), "zhulong")
	GameTheme.dragon(_menu, Rect2(915, 185, 230, 230), "kuraokami", false)
	GameTheme.dragon(_menu, Rect2(555, 110, 170, 170), "yinglong", false)
	var heading: Label = GameTheme.label(_menu, Rect2(200, 276, 880, 106), "Wyrmslot", 76, Color("#fff3bf"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override("font_outline_color", Color("#5f3dc4"))
	heading.add_theme_constant_override("outline_size", 10)
	var subtitle: String = "룬 석판 드래곤 로그라이트"
	if OS.has_feature("demo"):
		subtitle += " · 무료 데모"
	GameTheme.label(_menu, Rect2(240, 378, 800, 44), subtitle, 22, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var intro: String = "① 룬 석판을 돌려 알을 받아요\n② 드래곤 둘을 합쳐 신화룡을 찾아요\n③ 자동 전투로 %d웨이브를 버텨요" % _data["waves"]["maxWave"]
	GameTheme.label(_menu, Rect2(320, 428, 640, 92), intro, 18, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_start_button = GameTheme.button(_menu, Rect2(520, 538, 240, 60), "시작하기", _start, Color("#5f3dc4"))
	_dex_button = GameTheme.button(_menu, Rect2(540, 614, 200, 50), "드래곤 도감", _open_dex)
	_lower = GameTheme.button(_menu, Rect2(850, 544, 44, 48), "◀", _select_level.bind(-1))
	_higher = GameTheme.button(_menu, Rect2(1190, 544, 44, 48), "▶", _select_level.bind(1))
	_calamity_label = GameTheme.label(_menu, Rect2(902, 520, 280, 96), "", 16, Color("#ffc078"), HORIZONTAL_ALIGNMENT_CENTER)
	_calamity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_level(0)
	_start_button.grab_focus()


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
