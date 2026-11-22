extends Control

const GameTheme = preload("res://godot/ui/theme.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Store = preload("res://godot/ui/store.gd")
const HAZARD_KO: Dictionary = {
	"burn": "화염 낙인! 가장 약한 드래곤이 타요",
	"rowBlast": "용암탄! 한 줄 전체가 피해를 입어요",
	"pulse": "월식의 파동! 아군 모두 피해를 입어요",
}
const UNIT_SIZE: Vector2 = Vector2(116, 70)
const TICK_SECONDS: float = 0.05

signal finished

class UnitView:
	var card: Panel
	var bar: Panel
	var origin: Vector2
	var hp: int
	var max_hp: int
	var lunge: Tween
	var flash: Tween

var _data: Dictionary
var _store: Store
var _layer: Control
var _caption: Label
var _skip: Button
var _flash: ColorRect
var _views: Dictionary
var _result: Dictionary = {}
var _events: Array = []
var _next_event: int
var _clock: float
var _pause: float


func setup(data: Dictionary, store: Store) -> void:
	_data = data
	_store = store
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#161a24"))
	GameTheme.panel(self, Rect2(639, 10, 2, size.y - 20), GameTheme.CARD)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_caption = GameTheme.label(self, Rect2(280, size.y - 40, 720, 28), "", 16, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.8, 0.1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _flash, Rect2(Vector2.ZERO, size))
	_skip = GameTheme.button(self, Rect2(1140, 8, 124, 44), "건너뛰기 ▶▶", _skip_playback)
	_skip.hide()
	set_process(false)


func show_idle(state: Dictionary) -> void:
	_result = {}
	_events = []
	_skip.hide()
	set_process(false)
	var allies: Array = []
	for inst: Variant in state["nest"]:
		allies.append(null if inst == null else {"speciesId": inst["speciesId"], "hp": 1})
	_draw_units(allies, [])
	_caption.text = ""
	if state["phase"] not in ["gameOver", "victory"]:
		var boss: bool = Waves.is_boss(_data["waves"], state["wave"])
		_caption.text = "다음 전투: 웨이브 %d%s" % [state["wave"], " (심판 보스)" if boss else ""]


func play(result: Dictionary, boss: bool) -> void:
	_draw_units(result["allies"], result["enemies"])
	_caption.text = "심판 보스 전투!" if boss else "전투 중"
	_result = result
	_events = result["events"]
	_next_event = 0
	_clock = 0.0
	_pause = 0.0
	_skip.show()
	set_process(true)


func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause = maxf(0.0, _pause - delta)
		return
	_clock += delta * _store.speed / TICK_SECONDS
	_apply_through(mini(floori(_clock), _result["ticks"]), true)
	if _clock >= _result["ticks"] and _pause == 0.0:
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


func _draw_units(allies: Array, enemies: Array) -> void:
	for child: Node in _layer.get_children():
		_layer.remove_child(child)
		child.queue_free()
	_views = {"ally": [], "enemy": []}
	for side: String in _views:
		var units: Array = allies if side == "ally" else enemies
		for i: int in range(units.size()):
			var unit: Variant = units[i]
			_views[side].append(null if unit == null else _unit_view(side, i, unit))


func _unit_view(side: String, index: int, unit: Dictionary) -> UnitView:
	var view: UnitView = UnitView.new()
	var ally: bool = side == "ally"
	var front: bool = index < 3
	view.origin = Vector2((480 if front else 340) if ally else (684 if front else 824), 16 + index % 3 * 86)
	var id: String = unit["speciesId"]
	var spec: Dictionary = _data["dragons"].get(id, {})
	var elements: Array = unit.get("elements", spec.get("elements", ["fire"]))
	var element: String = "fire" if elements.is_empty() else elements[0]
	var border: Color = GameTheme.COLOR[element]
	border.a = 1.0 if ally else 0.7
	view.card = GameTheme.panel(_layer, Rect2(view.origin, UNIT_SIZE), Color("#1e2230"), border, 3)
	var image: TextureRect = GameTheme.dragon(view.card, Rect2(4, 2, 60, 60), id, ally)
	var name_rect: Rect2 = Rect2(64, 8, 48, 44) if image else Rect2(6, 8, 76, 44)
	if image == null:
		GameTheme.place(view.card, Marks.new(element), Rect2(86, 8, 24, 24))
	var title: Label = GameTheme.label(view.card, name_rect, spec.get("nameKo", id), 12 if image else 13)
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameTheme.panel(view.card, Rect2(6, 56, 104, 8), Color(0, 0, 0, 0.5))
	view.bar = GameTheme.panel(view.card, Rect2(6, 56, 104, 8), Color("#51cf66"))
	view.hp = unit["hp"]
	view.max_hp = maxi(view.hp, 1)
	return view


func _apply(event: Dictionary, animate: bool) -> void:
	match event["kind"]:
		"death":
			var dead: UnitView = _views[event["side"]][event["idx"]]
			dead.card.modulate.a = 0.25
			if animate:
				_pause = 0.06
		"enrage":
			if animate:
				_caption.text = "광폭화! 적의 공격력이 올라가요"
				_flash.color.a = 0.3
				_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
		"hazard":
			var victim: UnitView = _views["ally"][event["idx"]]
			_change_hp(victim, -event["dmg"])
			if animate:
				_caption.text = HAZARD_KO[event["name"]]
				_hit(victim, event["dmg"], Color("#b197fc"), false)
		"attack":
			var ally: bool = event["side"] == "ally"
			var attacker: UnitView = _views[event["side"]][event["src"]]
			var defender: UnitView = _views["enemy" if ally else "ally"][event["dst"]]
			_change_hp(defender, -event["dmg"])
			_change_hp(attacker, event["heal"])
			if animate:
				var strong: bool = event["mult"] > 100
				_lunge(attacker, 18.0 if ally else -18.0)
				_hit(defender, event["dmg"], Color("#ffe066") if strong else Color.WHITE, strong)
				if strong and defender.max_hp > 400:
					_shake()


func _change_hp(view: UnitView, amount: int) -> void:
	view.hp = clampi(view.hp + amount, 0, view.max_hp)
	view.bar.size.x = 104.0 * view.hp / view.max_hp


func _lunge(view: UnitView, distance: float) -> void:
	if view.lunge != null:
		view.lunge.kill()
	view.card.position.x = view.origin.x
	view.lunge = view.card.create_tween()
	view.lunge.tween_property(view.card, "position:x", view.origin.x + distance, 0.07 / _store.speed)
	view.lunge.tween_property(view.card, "position:x", view.origin.x, 0.07 / _store.speed)


func _hit(view: UnitView, damage: int, color: Color, strong: bool) -> void:
	if view.flash != null:
		view.flash.kill()
	var background: StyleBoxFlat = view.card.get_theme_stylebox("panel") as StyleBoxFlat
	background.bg_color = color
	view.flash = view.card.create_tween()
	view.flash.tween_property(background, "bg_color", Color("#1e2230"), 0.12)
	if _store.speed < 4:
		var number: Label = GameTheme.label(_layer, Rect2(view.origin.x, view.origin.y - 8, UNIT_SIZE.x, 24), str(damage), 24 if strong else 18, color, HORIZONTAL_ALIGNMENT_CENTER)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 5)
		var animation: Tween = number.create_tween().set_parallel()
		animation.tween_property(number, "position:y", number.position.y - 26, 0.4)
		animation.tween_property(number, "modulate:a", 0.0, 0.4)
		animation.chain().tween_callback(number.queue_free)


func _shake() -> void:
	var animation: Tween = _layer.create_tween()
	animation.tween_property(_layer, "position:x", 4.0, 0.03)
	animation.tween_property(_layer, "position:x", -4.0, 0.04)
	animation.tween_property(_layer, "position:x", 0.0, 0.05)
