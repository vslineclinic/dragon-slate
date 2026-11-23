extends Control
## 전장: 배경 그림 + 부대 전투 재생(core events를 보간해서 보여 줌).

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const HAZARD_KO: Dictionary = {
	"burn": "화염 낙인! 가장 약한 드래곤이 타요",
	"rowBlast": "용암탄! 한 줄 전체가 피해를 입어요",
	"pulse": "월식의 파동! 아군 모두 피해를 입어요",
}
const TICK_SECONDS: float = 0.05
const SIZE_BY_KIND: Dictionary = {"dragon": 112.0, "escort": 62.0, "minion": 64.0}

signal finished

class UnitView:
	var root: Control
	var body: Control
	var bar: Panel
	var bar_back: Panel
	var kind: String
	var side: String
	var element: String
	var hp: int
	var max_hp: int
	var center: Vector2
	var offset: Vector2 = Vector2.ZERO
	var stage: int = 0
	var move: Tween
	var flash: Tween
	var dead: bool = false

var _data: Dictionary
var _store: Store
var _width: float
var _background: TextureRect
var _background_path: String = ""
var _units_layer: Control
var _fx_layer: Control
var _caption: Label
var _skip: Button
var _flash: ColorRect
var _views: Dictionary = {}
var _result: Dictionary = {}
var _events: Array = []
var _next_event: int
var _clock: float
var _pause: float
var _pos_every: int = 4


func setup(data: Dictionary, store: Store, width: float) -> void:
	_data = data
	_store = store
	_width = width
	_pos_every = int(data["battle"]["field"]["posEveryTicks"])
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#161a24"))
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _background, Rect2(Vector2.ZERO, size))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.1, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, shade, Rect2(Vector2.ZERO, size))
	_units_layer = Control.new()
	_units_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_units_layer)
	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_caption = GameTheme.label(self, Rect2(size.x / 2.0 - 360, 10, 720, 30), "", 18, Color("#fff3bf"), HORIZONTAL_ALIGNMENT_CENTER)
	_caption.add_theme_constant_override("outline_size", 5)
	_caption.add_theme_color_override("font_outline_color", Color("#000000cc"))
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.8, 0.1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _flash, Rect2(Vector2.ZERO, size))
	_skip = GameTheme.button(self, Rect2(size.x - 140, 10, 124, 40), "건너뛰기 ▶▶", _skip_playback)
	_skip.hide()
	set_process(false)


func show_idle(state: Dictionary) -> void:
	_set_background(state["wave"])
	_clear_units()
	_result = {}
	_events = []
	_skip.hide()
	set_process(false)
	_caption.text = ""
	if state["phase"] not in ["gameOver", "victory"]:
		var boss: bool = Waves.is_boss(_data["waves"], state["wave"])
		_caption.text = "다음 전투: 웨이브 %d%s" % [state["wave"], " · 심판 보스" if boss else ""]


func play(result: Dictionary, boss: bool, wave: int) -> void:
	_set_background(wave)
	_clear_units()
	for unit: Dictionary in result["units"]:
		var view: UnitView = _unit_view(unit)
		view.stage = int(unit.get("stage", 0))
		if view.stage > 0:
			view.root.hide()
		_views[unit["id"]] = view
	_caption.text = "심판 보스 전투!" if boss else "전투 중"
	_result = result
	_events = result["events"]
	_next_event = 0
	_clock = 0.0
	_pause = 0.4
	_skip.show()
	set_process(true)


func _set_background(wave: int) -> void:
	var path: String = GameTheme.background_for(wave)
	if path == _background_path:
		return
	_background_path = path
	_background.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null


func _clear_units() -> void:
	for layer: Control in [_units_layer, _fx_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_views = {}


func _point(x: float, lane: float) -> Vector2:
	return GameTheme.field_point(_width, x, lane) - position


func _unit_view(unit: Dictionary) -> UnitView:
	var view: UnitView = UnitView.new()
	view.kind = unit["kind"]
	view.side = unit["side"]
	var elements: Array = unit["elements"]
	view.element = "fire" if elements.is_empty() else elements[0]
	view.hp = int(unit["hp"])
	view.max_hp = maxi(view.hp, 1)
	if view.kind != "dragon":
		var id: int = int(unit["id"])
		view.offset = Vector2((id % 2) * 16.0 - 8.0, (id * 7 % 3 - 1) * 34.0)
	view.center = _point(unit["x"], unit["lane"]) + view.offset
	var edge: float = SIZE_BY_KIND.get(view.kind, 56.0)
	view.root = Control.new()
	view.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.root.size = Vector2(edge, edge)
	view.root.position = view.center - view.root.size / 2.0
	view.root.pivot_offset = view.root.size / 2.0
	view.root.z_index = int(unit["lane"]) * 10 + (2 if view.kind == "dragon" else 0)
	_units_layer.add_child(view.root)
	var ally: bool = view.side == "ally"
	var shadow: Panel = GameTheme.panel(view.root, Rect2(edge * 0.15, edge * 0.82, edge * 0.7, edge * 0.16),
		Color(0, 0, 0, 0.35), GameTheme.COLOR[view.element] if ally and view.kind == "dragon" else Color.TRANSPARENT,
		2 if ally and view.kind == "dragon" else 0, int(edge * 0.1))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if view.kind == "minion":
		var path: String = "res://assets/minions/%s.png" % unit["ref"]
		var sprite: TextureRect = TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(path):
			sprite.texture = load(path) as Texture2D
		sprite.flip_h = ally
		GameTheme.place(view.root, sprite, Rect2(Vector2.ZERO, view.root.size))
		view.body = sprite
	else:
		var image: TextureRect = GameTheme.dragon(view.root, Rect2(Vector2.ZERO, view.root.size), unit["ref"], ally)
		view.body = image if image != null else GameTheme.panel(view.root, Rect2(Vector2.ZERO, view.root.size), GameTheme.COLOR[view.element], Color.WHITE, 2, int(edge / 2))
	var bar_w: float = edge * 0.8
	view.bar_back = GameTheme.panel(view.root, Rect2((edge - bar_w) / 2.0, -8, bar_w, 6), Color(0, 0, 0, 0.6))
	view.bar = GameTheme.panel(view.root, Rect2((edge - bar_w) / 2.0, -8, bar_w, 6), Color("#51cf66") if ally else Color("#ff6b6b"))
	var always: bool = view.kind == "dragon"
	view.bar.visible = always
	view.bar_back.visible = always
	return view


func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause = maxf(0.0, _pause - delta)
		return
	_clock += delta * _store.speed / TICK_SECONDS
	_apply_through(mini(floori(_clock), _result["ticks"]), true)
	if _clock >= _result["ticks"] + 8 and _pause == 0.0:
		_end()


func _apply_through(tick: int, animate: bool) -> void:
	while _next_event < _events.size() and _events[_next_event]["tick"] <= tick:
		var event: Dictionary = _events[_next_event]
		_next_event += 1
		_apply(event, animate)


func _skip_playback() -> void:
	if not _result.is_empty():
		_apply_through(_result["ticks"], false)
		_end()


func _end() -> void:
	set_process(false)
	_result = {}
	_events = []
	_skip.hide()
	finished.emit()


func _apply(event: Dictionary, animate: bool) -> void:
	match event["kind"]:
		"stage":
			for view: UnitView in _views.values():
				if view.stage != int(event["stage"]) or view.dead:
					continue
				view.root.show()
				if animate:
					view.root.modulate.a = 0.0
					view.root.create_tween().tween_property(view.root, "modulate:a", 1.0, 0.3 / _store.speed)
			if animate:
				_caption.text = "%d번째 무리 등장! (%d / %d)" % [int(event["stage"]) + 1, int(event["stage"]) + 1, int(event["total"])]
				_flash.color.a = 0.18
				_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
		"pos":
			var seconds: float = _pos_every * TICK_SECONDS / _store.speed
			for id: Variant in event["xs"]:
				var view: UnitView = _views.get(int(id))
				if view == null or view.dead:
					continue
				view.center = _point(event["xs"][id], event["lanes"][id]) + view.offset
				var target: Vector2 = view.center - view.root.size / 2.0
				view.root.z_index = int(event["lanes"][id]) * 10 + (2 if view.kind == "dragon" else 0)
				if view.move != null:
					view.move.kill()
				if animate:
					view.move = view.root.create_tween()
					view.move.tween_property(view.root, "position", target, seconds)
				else:
					view.root.position = target
		"death":
			var dead: UnitView = _views.get(int(event["id"]))
			if dead == null or dead.dead:
				return
			dead.dead = true
			dead.bar.hide()
			dead.bar_back.hide()
			if animate:
				var fade: Tween = dead.root.create_tween().set_parallel()
				fade.tween_property(dead.root, "modulate:a", 0.0, 0.35 / _store.speed)
				fade.tween_property(dead.root, "scale", Vector2(0.7, 0.7), 0.35 / _store.speed)
				if dead.kind == "dragon":
					_pause = 0.08
			else:
				dead.root.modulate.a = 0.0
		"enrage":
			if animate:
				_caption.text = "광폭화! 적의 공격력이 올라가요"
				_flash.color.a = 0.3
				_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
		"hazard":
			var victim: UnitView = _views.get(int(event["id"]))
			if victim == null:
				return
			_change_hp(victim, -int(event["dmg"]))
			if animate:
				_caption.text = HAZARD_KO.get(event["name"], "")
				_hit(victim, int(event["dmg"]), Color("#b197fc"), false)
		"attack":
			var attacker: UnitView = _views.get(int(event["src"]))
			var defender: UnitView = _views.get(int(event["dst"]))
			if attacker == null or defender == null:
				return
			_change_hp(defender, -int(event["dmg"]))
			_change_hp(attacker, int(event["heal"]))
			if animate:
				var strong: bool = int(event["mult"]) > 100
				if attacker.kind == "dragon":
					_breath(attacker, defender, strong, int(event["dmg"]))
				else:
					_lunge(attacker, defender)
					_hit(defender, int(event["dmg"]), Color("#ffe066") if strong else Color.WHITE, strong)


func _change_hp(view: UnitView, amount: int) -> void:
	view.hp = clampi(view.hp + amount, 0, view.max_hp)
	var full: float = view.bar_back.size.x
	view.bar.size.x = full * view.hp / view.max_hp
	if amount < 0 and view.kind != "dragon" and not view.dead:
		view.bar.visible = true
		view.bar_back.visible = true


func _breath(attacker: UnitView, defender: UnitView, strong: bool, damage: int) -> void:
	var orb: Panel = GameTheme.panel(_fx_layer, Rect2(attacker.center - Vector2(9, 9), Vector2(18, 18)),
		GameTheme.COLOR[attacker.element], Color(1, 1, 1, 0.9), 2, 9)
	orb.z_index = 50
	var seconds: float = 0.18 / _store.speed
	var flight: Tween = orb.create_tween()
	flight.tween_property(orb, "position", defender.center - Vector2(9, 9), seconds)
	flight.tween_callback(orb.queue_free)
	flight.tween_callback(_hit.bind(defender, damage, Color("#ffe066") if strong else Color.WHITE, strong))


func _lunge(attacker: UnitView, defender: UnitView) -> void:
	if attacker.dead:
		return
	var direction: float = signf(defender.center.x - attacker.center.x)
	var body: Control = attacker.body
	var lunge: Tween = body.create_tween()
	lunge.tween_property(body, "position:x", 10.0 * direction, 0.06 / _store.speed)
	lunge.tween_property(body, "position:x", 0.0, 0.08 / _store.speed)


func _hit(view: UnitView, damage: int, color: Color, strong: bool) -> void:
	if view.dead and view.root.modulate.a <= 0.0:
		return
	if view.flash != null:
		view.flash.kill()
	view.body.modulate = color * 1.6 if color != Color.WHITE else Color(2, 2, 2)
	view.flash = view.body.create_tween()
	view.flash.tween_property(view.body, "modulate", Color.WHITE, 0.14)
	if view.kind == "dragon" and _store.speed < 4:
		var number: Label = GameTheme.label(_fx_layer, Rect2(view.center.x - 40, view.center.y - 70, 80, 24), str(damage), 22 if strong else 17, color, HORIZONTAL_ALIGNMENT_CENTER)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 5)
		number.z_index = 60
		var animation: Tween = number.create_tween().set_parallel()
		animation.tween_property(number, "position:y", number.position.y - 26, 0.4)
		animation.tween_property(number, "modulate:a", 0.0, 0.4)
		animation.chain().tween_callback(number.queue_free)
	if strong and view.kind == "dragon":
		var animation: Tween = _units_layer.create_tween()
		animation.tween_property(_units_layer, "position:x", 4.0, 0.03)
		animation.tween_property(_units_layer, "position:x", -4.0, 0.04)
		animation.tween_property(_units_layer, "position:x", 0.0, 0.05)
