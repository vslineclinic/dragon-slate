extends Control
## 전장: 배경 그림 + 부대 전투 재생(core events를 보간해서 보여 줌).

const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const Ambience = preload("res://godot/ui/ambience.gd")
const HAZARD_KO: Dictionary = {
	"burn": "화염 낙인! 가장 약한 드래곤이 타요",
	"rowBlast": "용암탄! 한 줄 전체가 피해를 입어요",
	"pulse": "월식의 파동! 아군 모두 피해를 입어요",
}
const TICK_SECONDS: float = 0.05
const SIZE_BY_KIND: Dictionary = {"dragon": 112.0, "escort": 62.0, "minion": 64.0}

signal finished
## 전투 도중 적 무리가 더 나타났다(음악을 급박하게 바꿀 때 쓴다).
signal reinforced

class UnitView:
	var root: Control
	var body: Control
	var bar: Panel
	var bar_back: Panel
	var gauge: Panel
	var gauge_full: float = 0.0
	var ult_need: int = 0
	var title: String = ""
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
var _plaque: Panel
var _air: Control
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
	GameTheme.panel(self, Rect2(Vector2.ZERO, size), Color("#0d0d13"))
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _background, Rect2(Vector2.ZERO, size))
	_air = Control.new()
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTheme.place(self, _air, Rect2(Vector2.ZERO, size))
	Ambience.vignette(self, Rect2(Vector2.ZERO, size), 0.5)
	_units_layer = Control.new()
	_units_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_units_layer)
	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_plaque = GameTheme.panel(self, Rect2(size.x / 2.0 - 230, 8, 460, 56), Color("#0b0b10c7"), Color(GameTheme.GOLD, 0.6), 1, 10, "flat")
	_plaque.hide()
	_caption = GameTheme.heading(self, Rect2(size.x / 2.0 - 360, 10, 720, 52), "", 17, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER, 600)
	_caption.add_theme_constant_override("line_spacing", 0)
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
	_say("")
	if state["phase"] not in ["gameOver", "victory"]:
		var wave: int = state["wave"]
		var kind: String = ""
		if Waves.is_boss(_data["waves"], wave):
			kind = " · 심판 보스"
		elif Waves.is_elite(_data["waves"], wave):
			kind = " · 중간 보스"
		var hunt: Dictionary = state.get("waveMod", {})
		if not hunt.is_empty():
			kind += " · 정예 사냥(보상 2번)"
		var mods: Dictionary = Calamity.mods(_data, state["calamity"]).duplicate()
		mods["enemyPowerPct"] = int(mods["enemyPowerPct"]) + int(hunt.get("powerPct", 0))
		var ours: int = 0
		for unit: Variant in Battle.team(_data, state["nest"], state["nestOpen"], Run.relic_bonus(_data, state)):
			if unit != null:
				ours += Waves.unit_power(unit)
		_say("다음 전투: 웨이브 %d%s\n적 전투력 %d · 우리 드래곤 %d" % [wave, kind, Waves.enemy_power(_data["waves"], wave, mods), ours])


func play(result: Dictionary, boss: bool, wave: int, elite: bool = false) -> void:
	_set_background(wave)
	_clear_units()
	for unit: Dictionary in result["units"]:
		var view: UnitView = _unit_view(unit)
		view.stage = int(unit.get("stage", 0))
		if view.stage > 0:
			view.root.hide()
		_views[unit["id"]] = view
	_say("심판 보스 전투!" if boss else ("중간 보스 등장!" if elite else "전투 중"))
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
	for child: Node in _air.get_children():
		_air.remove_child(child)
		child.queue_free()
	Ambience.particles(_air, Rect2(Vector2.ZERO, size), GameTheme.ambience_for(wave))


## 위쪽 명판에 한두 줄을 띄운다. 빈 글이면 명판도 숨긴다.
func _say(text: String) -> void:
	_caption.text = text
	_plaque.visible = not text.is_empty()
	if _plaque.visible:
		var lines: int = text.count("\n") + 1
		var wide: float = 60.0
		for line: String in text.split("\n"):
			wide = maxf(wide, GameTheme.serif_font(600).get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		_plaque.size = Vector2(wide + 56.0, 16.0 + 24.0 * lines)
		_plaque.position = Vector2((size.x - _plaque.size.x) / 2.0, 8)
		_caption.position.y = 8
		_caption.size.y = _plaque.size.y


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
	if view.kind == "dragon":
		view.title = str(_data["dragons"].get(unit["ref"], {}).get("nameKo", ""))
	var elements: Array = unit["elements"]
	view.element = "fire" if elements.is_empty() else elements[0]
	view.hp = int(unit["hp"])
	view.max_hp = maxi(view.hp, 1)
	if view.kind != "dragon":
		var id: int = int(unit["id"])
		view.offset = Vector2((id % 2) * 16.0 - 8.0, (id * 7 % 3 - 1) * 34.0)
	view.center = _point(unit["x"], unit["lane"]) + view.offset
	var edge: float = SIZE_BY_KIND.get(view.kind, 56.0) * (1.4 if unit.get("elite", false) else 1.0)
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
	view.ult_need = int(unit.get("ultNeed", 0))
	if view.ult_need > 0:
		view.gauge_full = bar_w
		GameTheme.panel(view.root, Rect2((edge - bar_w) / 2.0, -1, bar_w, 4), Color(0, 0, 0, 0.6))
		view.gauge = GameTheme.panel(view.root, Rect2((edge - bar_w) / 2.0, -1, 0, 4), Color("#ffd43b"))
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
			reinforced.emit()
			if animate:
				_say("%d번째 무리 등장! (%d / %d)" % [int(event["stage"]) + 1, int(event["stage"]) + 1, int(event["total"])])
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
				_say("광폭화! 적의 공격력이 올라가요")
				_flash.color.a = 0.3
				_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
		"hazard":
			var victim: UnitView = _views.get(int(event["id"]))
			if victim == null:
				return
			_change_hp(victim, -int(event["dmg"]))
			if animate:
				_say(HAZARD_KO.get(event["name"], ""))
				_hit(victim, int(event["dmg"]), Color("#b197fc"), false)
		"ult":
			var caster: UnitView = _views.get(int(event["src"]))
			if caster == null or not animate:
				return
			var tint: Color = GameTheme.COLOR[caster.element]
			var ult_name: String = str(_data["battle"].get("ultimate", {}).get("names", {}).get(caster.element, ""))
			_say("궁극기! " + ult_name)
			_callout("%s의 %s!" % [caster.title, ult_name], tint.lightened(0.45), tint.darkened(0.6))
			_shake(7.0)
			_flash.color = Color(tint, 0.28)
			var glow: Tween = _flash.create_tween()
			glow.tween_property(_flash, "color:a", 0.0, 0.4)
			glow.tween_callback(func() -> void: _flash.color = Color(1, 0.8, 0.1, 0))
			var pulse: Tween = caster.root.create_tween()
			pulse.tween_property(caster.root, "scale", Vector2(1.3, 1.3), 0.1 / _store.speed)
			pulse.tween_property(caster.root, "scale", Vector2.ONE, 0.2 / _store.speed)
			_pause = 0.12
		"attack":
			var attacker: UnitView = _views.get(int(event["src"]))
			var defender: UnitView = _views.get(int(event["dst"]))
			if attacker == null or defender == null:
				return
			_change_hp(defender, -int(event["dmg"]))
			_change_hp(attacker, int(event["heal"]))
			if attacker.gauge != null and event.has("charge"):
				attacker.gauge.size.x = attacker.gauge_full * int(event["charge"]) / attacker.ult_need
			if animate:
				var strong: bool = int(event["mult"]) > 100
				if event.get("ult", false):
					_breath(attacker, defender, true, int(event["dmg"]), 34.0, 2)
				elif event.get("crit", false):
					## 치명타: 누가 쳤는지 이름을 띄우고, 잠깐 멈췄다가 크게 터뜨린다.
					_name_tag(attacker, attacker.title + " 치명타!", Color("#ffe066") if attacker.side == "ally" else Color("#ff8787"))
					_pause = maxf(_pause, 0.07)
					_breath(attacker, defender, true, int(event["dmg"]), 26.0, 1)
				elif attacker.kind == "dragon":
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


## 전장 가운데 위에 크게 뜨는 한 줄(궁극기 이름 등).
func _callout(text: String, tint: Color, outline: Color) -> void:
	var banner: Label = GameTheme.label(_fx_layer, Rect2(0, 86, size.x, 50), text, 34, tint, HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_color_override("font_outline_color", outline)
	banner.add_theme_constant_override("outline_size", 10)
	banner.z_index = 70
	banner.pivot_offset = Vector2(size.x / 2.0, 25)
	banner.scale = Vector2(1.5, 1.5)
	var show: Tween = banner.create_tween()
	show.tween_property(banner, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_interval(0.7)
	show.tween_property(banner, "modulate:a", 0.0, 0.25)
	show.tween_callback(banner.queue_free)


## 유닛 머리 위에 뜨는 이름표(치명타를 낸 용).
func _name_tag(view: UnitView, text: String, tint: Color) -> void:
	if _store.speed >= 4:
		return
	var tag: Label = GameTheme.label(_fx_layer, Rect2(view.center.x - 140, view.center.y - 104, 280, 30), text, 22, tint, HORIZONTAL_ALIGNMENT_CENTER)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 7)
	tag.z_index = 65
	tag.pivot_offset = Vector2(140, 15)
	tag.scale = Vector2(1.4, 1.4)
	var rise: Tween = tag.create_tween()
	rise.tween_property(tag, "scale", Vector2.ONE, 0.1)
	rise.tween_property(tag, "position:y", tag.position.y - 22, 0.6)
	rise.parallel().tween_property(tag, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	rise.tween_callback(tag.queue_free)


func _shake(amount: float) -> void:
	var shake: Tween = _units_layer.create_tween()
	for i: int in range(3):
		shake.tween_property(_units_layer, "position", Vector2(amount * (1 if i % 2 == 0 else -1), amount * 0.4 * (-1 if i % 2 == 0 else 1)), 0.03)
		amount *= 0.6
	shake.tween_property(_units_layer, "position", Vector2.ZERO, 0.04)


## 맞은 자리에서 퍼지는 고리. 셀수록 크고 두 겹.
func _impact(at: Vector2, tint: Color, power: int) -> void:
	for ring_index: int in range(2 if power > 0 else 1):
		var reach: float = (46.0 + 30.0 * power) * (1.0 - 0.35 * ring_index)
		var ring: Panel = GameTheme.panel(_fx_layer, Rect2(at - Vector2(8, 8), Vector2(16, 16)), Color(tint, 0.25), Color.WHITE if ring_index == 0 else tint, 3, 8)
		ring.z_index = 55
		ring.pivot_offset = Vector2(8, 8)
		var seconds: float = 0.2 + 0.06 * power
		var burst: Tween = ring.create_tween().set_parallel()
		burst.tween_property(ring, "scale", Vector2.ONE * reach / 8.0, seconds).set_ease(Tween.EASE_OUT)
		burst.tween_property(ring, "modulate:a", 0.0, seconds)
		burst.chain().tween_callback(ring.queue_free)


func _breath(attacker: UnitView, defender: UnitView, strong: bool, damage: int, orb_size: float = 18.0, power: int = 0) -> void:
	var half: Vector2 = Vector2(orb_size, orb_size) / 2.0
	var orb: Panel = GameTheme.panel(_fx_layer, Rect2(attacker.center - half, half * 2.0),
		GameTheme.COLOR[attacker.element], Color(1, 1, 1, 0.9), 2, int(orb_size / 2.0))
	orb.z_index = 50
	var seconds: float = 0.18 / _store.speed
	var flight: Tween = orb.create_tween()
	flight.tween_property(orb, "position", defender.center - half, seconds)
	flight.tween_callback(orb.queue_free)
	flight.tween_callback(_hit.bind(defender, damage, Color("#ffe066") if strong else Color.WHITE, strong, power, GameTheme.COLOR[attacker.element]))


func _lunge(attacker: UnitView, defender: UnitView) -> void:
	if attacker.dead:
		return
	var direction: float = signf(defender.center.x - attacker.center.x)
	var body: Control = attacker.body
	var lunge: Tween = body.create_tween()
	lunge.tween_property(body, "position:x", 10.0 * direction, 0.06 / _store.speed)
	lunge.tween_property(body, "position:x", 0.0, 0.08 / _store.speed)


## power: 0 보통, 1 치명타, 2 궁극기.
func _hit(view: UnitView, damage: int, color: Color, strong: bool, power: int = 0, tint: Color = Color.WHITE) -> void:
	if view.dead and view.root.modulate.a <= 0.0:
		return
	if view.kind == "dragon" or power > 0:
		_impact(view.center, tint, power)
	if not view.dead:
		## 맞은 쪽이 뒤로 밀렸다가 돌아온다.
		var push: float = (6.0 + 6.0 * power) * (1.0 if view.side == "enemy" else -1.0)
		var recoil: Tween = view.body.create_tween()
		recoil.tween_property(view.body, "position:x", push, 0.04)
		recoil.tween_property(view.body, "position:x", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if power > 0:
		_shake(4.0 + 3.0 * power)
	if view.flash != null:
		view.flash.kill()
	view.body.modulate = color * 1.6 if color != Color.WHITE else Color(2, 2, 2)
	view.flash = view.body.create_tween()
	view.flash.tween_property(view.body, "modulate", Color.WHITE, 0.14)
	if (view.kind == "dragon" or power > 0) and _store.speed < 4:
		var number_size: int = 30 if power > 0 else (22 if strong else 17)
		var number_text: String = str(damage) + ("!" if power > 0 else "")
		var number: Label = GameTheme.label(_fx_layer, Rect2(view.center.x - 60, view.center.y - 74, 120, 34), number_text, number_size, Color("#ff6b6b") if power == 1 else color, HORIZONTAL_ALIGNMENT_CENTER)
		number.pivot_offset = Vector2(60, 17)
		if power > 0:
			number.scale = Vector2(1.7, 1.7)
			number.create_tween().tween_property(number, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
