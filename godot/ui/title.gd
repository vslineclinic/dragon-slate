extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Build = preload("res://godot/ui/build.gd")
const Store = preload("res://godot/ui/store.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")
const Music = preload("res://godot/ui/music.gd")
const Sfx = preload("res://godot/ui/sfx.gd")
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
var _sfx_button: Button
var _calamity_label: Label
var _lower: Button
var _higher: Button
var _level: int = 0
var _length_button: Button
var _continue_button: Button
var _saved: Dictionary = {}
var _intro: Label
var _max_level: int = 0
var _slot_button: Button
var _slot_overlay: Control


func _ready() -> void:
	Store.carry_over_old_saves()
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
	## 양옆의 두 드래곤: 뒤에 원소 빛을 깔아 배경에서 떠오르게 한다.
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
	_intro = GameTheme.label(stage, Rect2(240, 290, 800, 78), "", 16, Color("#e9dcc4"), HORIZONTAL_ALIGNMENT_CENTER)
	_intro.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	GameTheme.outline(_intro, 4, Color(0, 0, 0, 0.6))
	## 원정 길이: 기본(20웨이브) ↔ 긴 원정(40웨이브). 데모판은 길이가 하나라 묻지 않는다.
	_length_button = GameTheme.button(stage, Rect2(500, 488, 280, 42), "", _toggle_length, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_length_button.tooltip_text = "누르면 지역을 바꿔요. 지역을 깨면 다음 지역이 열려요."
	_length_button.visible = not OS.has_feature("demo") and _data["waves"].has("standard")
	_show_length()
	_continue_button = GameTheme.cta(stage, Rect2(500, 424, 280, 52), "", _continue, "ember", 20)
	_show_continue()
	_start_button = GameTheme.cta(stage, Rect2(500, 540, 280, 64), "시작하기", _start, "gold", 26)
	_dex_button = GameTheme.button(stage, Rect2(530, 620, 220, 48), "드래곤 도감", _open_dex, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	var music: Node = Music.get_for(get_tree())
	music.play("title")
	_music_button = GameTheme.button(stage, Rect2(1160, 20, 100, 44), Music.SET_KO[music.current_set()], _cycle_music, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_music_button.tooltip_text = "배경음악: A, B, 끔"
	_sfx_button = GameTheme.button(stage, Rect2(1050, 20, 100, 44), "", _toggle_sfx, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_sfx_button.tooltip_text = "효과음 켜기 · 끄기"
	_show_sfx()
	## 저장 칸 셋: 칸마다 진행과 하던 판이 따로다. 데모판은 한 칸.
	_slot_button = GameTheme.button(stage, Rect2(20, 20, 150, 44), "", _open_slots, Color("#15131ccc"), GameTheme.GOLD_DIM, 1)
	_slot_button.tooltip_text = "저장 칸 바꾸기(셋까지)"
	_slot_button.visible = not OS.has_feature("demo")
	_show_slot()
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
	var heading: Label = GameTheme.label(stage, Rect2(140, 96, 1000, 140), "DRAGON SLATE", 88, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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


## 하던 판이 있으면 "이어 하기"를 보여 준다.
func _show_continue() -> void:
	_saved = {}
	## 저장은 그 판의 원정 길이로 풀어야 웨이브 수가 맞는다.
	var modes: Array = ["long", "standard"]
	for index: int in range(_data.get("stages", []).size()):
		modes.append("stage:%d" % index)
	for length: String in modes:
		var found: Dictionary = _store.load_run(_data if OS.has_feature("demo") else Build.for_mode(_data, length))
		if not found.is_empty() and (found["length"] == length or OS.has_feature("demo")):
			_saved = found
			break
	_continue_button.visible = not _saved.is_empty()
	if not _saved.is_empty():
		_continue_button.text = "이어 하기 · 웨이브 %d" % int(_saved["state"]["wave"])


func _continue() -> void:
	if _saved.is_empty():
		return
	var length: String = _saved["length"]
	var data: Dictionary = _data if OS.has_feature("demo") else Build.for_mode(_data, length)
	_game = GameScene.instantiate() as Game
	_game.controller = Controller.new(data, int(_saved["state"]["seed"]))
	_game.controller.state = _saved["state"]
	_game.store = _store
	_game.calamity = int(_saved["state"]["calamity"])
	_game.run_length = length
	## "이 지역 다시"를 누를 때도 데려온 드래곤이 함께 오게.
	if length.begins_with("stage:"):
		_game.controller.carry = _store.carry_for(int(length.substr(6)))
	_game.resume = true
	_game.title_requested.connect(_return_to_title)
	_menu.hide()
	add_child(_game)


## 고를 수 있는 원정: 열린 지역들("stage:0" …), 첫 지역을 깬 뒤에는 긴 원정("long")도.
func _modes() -> Array:
	var count: int = _data.get("stages", []).size()
	if count == 0:
		return ["standard", "long"]
	var cleared: int = _store.stages_cleared()
	var modes: Array = []
	for index: int in range(mini(cleared, count - 1) + 1):
		modes.append("stage:%d" % index)
	if cleared >= 1:
		modes.append("long")
	return modes


func _mode() -> String:
	var modes: Array = _modes()
	return modes[clampi(_store.stage_pick, 0, modes.size() - 1)]


func _run_data() -> Dictionary:
	return _data if OS.has_feature("demo") else Build.for_mode(_data, _mode())


func _toggle_length() -> void:
	_store.stage_pick = (clampi(_store.stage_pick, 0, _modes().size() - 1) + 1) % _modes().size()
	_show_length()


func _show_length() -> void:
	var data: Dictionary = _run_data()
	var waves: int = int(data["waves"]["maxWave"])
	var mode: String = _mode()
	var intro: String = "석판을 돌려 알을 얻고 · 드래곤 둘을 합쳐 신화룡을 깨우고 · %d웨이브를 버텨요" % waves
	if mode.begins_with("stage:") and not OS.has_feature("demo"):
		var index: int = int(mode.substr(6))
		var stars: int = _store.stage_stars(index)
		_length_button.text = "%d지역 · %s  %s  ⇄" % [index + 1, data["waves"]["stageName"], "★".repeat(stars) + "☆".repeat(3 - stars)]
		intro += "\n" + str(data["waves"]["stageRule"])
		var names: PackedStringArray = []
		for carried: Dictionary in Run.carry_list(_data, _store.carry_for(index)):
			names.append(str(_data["dragons"][carried["speciesId"]]["nameKo"]))
		if not names.is_empty():
			intro += "\n데려가는 드래곤: " + " · ".join(names)
	else:
		_length_button.text = "긴 원정 · %d웨이브  ⇄" % waves
	_intro.text = intro


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


func _show_slot() -> void:
	_slot_button.text = "저장 %d ▾" % _store.slot()


## 저장 칸 고르기: 칸마다 깬 지역 · 도감 · 하던 판을 한 줄로 보여 준다.
func _open_slots() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
	## 뒤쪽 메뉴를 잠근다: 창이 떠 있는 동안 키보드로 시작하기 등을 누를 수 없게.
	_lock_menu(true)
	_slot_overlay = Control.new()
	_slot_overlay.z_index = 90
	GameTheme.place(_menu, _slot_overlay, Rect2(Vector2.ZERO, _menu.size))
	var shade: Button = GameTheme.button(_slot_overlay, Rect2(Vector2.ZERO, _menu.size), "", _close_slots, Color("#000000b0"), Color.TRANSPARENT, 0)
	shade.focus_mode = Control.FOCUS_NONE
	var left: float = (_menu.size.x - 560.0) / 2.0
	var box: Panel = GameTheme.frame(_slot_overlay, Rect2(left, 150, 560, 400), GameTheme.INK, GameTheme.GOLD, 14)
	GameTheme.heading(box, Rect2(0, 18, 560, 40), "저장 칸", 28, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 800)
	GameTheme.label(box, Rect2(0, 58, 560, 22), "칸마다 지역 진행 · 도감 · 하던 판이 따로 저장돼요.", 14, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var first: Button = null
	for slot: int in range(1, Store.SLOTS + 1):
		var info: Dictionary = Store.slot_summary(slot)
		var text: String = "저장 %d  ·  " % slot
		if info["empty"]:
			text += "비어 있음"
		else:
			text += "깬 지역 %d · 도감 %d종" % [int(info["cleared"]), int(info["found"])]
			if int(info["wave"]) > 0:
				text += " · 하던 판 웨이브 %d" % int(info["wave"])
		var current: bool = slot == _store.slot()
		var row: Button = GameTheme.button(box, Rect2(30, 96 + (slot - 1) * 80, 500, 66), text, _pick_slot.bind(slot),
			Color("#2a2110") if current else GameTheme.CARD, GameTheme.GOLD if current else GameTheme.PANEL_LINE, 2 if current else 1)
		row.add_theme_font_size_override("font_size", 18)
		if current:
			first = row
	GameTheme.button(box, Rect2(200, 340, 160, 44), "닫기", _close_slots, Color("#1c1a24"), GameTheme.GOLD_DIM, 1)
	if first != null:
		first.grab_focus()


func _close_slots() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
		_slot_overlay = null
	_lock_menu(false)
	_start_button.grab_focus()


func _lock_menu(locked: bool) -> void:
	for button: Button in [_start_button, _continue_button, _length_button, _dex_button, _slot_button, _music_button, _sfx_button, _lower, _higher]:
		button.disabled = locked
		button.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	if not locked:
		## 재앙 단추는 고른 단계에 따라 다시 막는다.
		_select_level(0)


## 다른 칸으로 바꾸면 그 칸의 진행 기록을 읽어 타이틀을 다시 채운다.
func _pick_slot(slot: int) -> void:
	if slot != _store.slot():
		Store.set_active_slot(slot)
		_store = Store.new(slot)
		_level = 0
		_select_level(0)
		_show_continue()
		_show_length()
		_show_slot()
	_close_slots()


func _cycle_music() -> void:
	_music_button.text = Music.SET_KO[Music.get_for(get_tree()).cycle_set()]


func _toggle_sfx() -> void:
	Sfx.get_for(get_tree()).toggle()
	_show_sfx()


func _show_sfx() -> void:
	_sfx_button.text = "효과음 켬" if Sfx.get_for(get_tree()).is_on() else "효과음 끔"


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
	_game.controller = Controller.new(_run_data(), seed_value)
	_game.store = _store
	_game.calamity = _level
	_game.run_length = "long" if OS.has_feature("demo") else _mode()
	## 둘째 지역부터는 앞 지역에서 고른 드래곤들을 데려간다.
	if _game.run_length.begins_with("stage:"):
		_game.controller.carry = _store.carry_for(int(_game.run_length.substr(6)))
	_game.title_requested.connect(_return_to_title)
	_menu.hide()
	add_child(_game)


func _return_to_title() -> void:
	_game.hide()
	_game.queue_free()
	_game = null
	_select_level(0)
	_show_continue()
	_show_length()
	_show_sfx()
	_music_button.text = Music.SET_KO[Music.get_for(get_tree()).current_set()]
	_menu.show()
	_start_button.grab_focus()
