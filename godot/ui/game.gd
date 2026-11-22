extends Control

const Controller = preload("res://godot/ui/controller.gd")
const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const Hud = preload("res://godot/ui/hud.gd")
const SlotPanel = preload("res://godot/ui/slot_panel.gd")
const NestPanel = preload("res://godot/ui/nest_panel.gd")
const BattlePanel = preload("res://godot/ui/battle_panel.gd")
const REJECT_KO: Dictionary = {
	"wrongPhase": "지금은 할 수 없어요",
	"notEnoughMana": "마력이 모자라요",
	"noNudgeLeft": "이번 웨이브 밀기를 다 썼어요",
	"benchFull": "대기칸이 꽉 찼어요",
	"emptySlot": "빈칸이에요",
	"slotLocked": "아직 잠긴 칸이에요",
	"nestEmpty": "둥지에 드래곤을 1마리 이상 놓아 주세요",
	"sameSlot": "같은 칸이에요",
	"needDragon": "드래곤이 최소 1마리는 있어야 해요",
}
const BONUS_REASONS: Array[String] = ["line", "goldLine", "wildLine", "goldCells", "benchFull"]

signal run_finished(state: Dictionary)

var controller: Controller
var store: Store
var _hud: Hud
var _slot: SlotPanel
var _nest: NestPanel
var _battle: BattlePanel
var _banner: Label
var _toast: Label
var _toast_animation: Tween
var _banner_animation: Tween
var _sequence: Tween
var _reward_overlay: Control
var _pending: Dictionary = {}


func _ready() -> void:
	if controller == null:
		controller = Controller.new(GameData.load_all(), int(Time.get_unix_time_from_system()))
	if store == null:
		store = Store.new()
	theme = GameTheme.create()
	_battle = BattlePanel.new()
	_hud = Hud.new()
	_nest = NestPanel.new()
	_slot = SlotPanel.new()
	GameTheme.place(self, _battle, GameTheme.AREA["battle"])
	GameTheme.place(self, _hud, GameTheme.AREA["hud"])
	GameTheme.place(self, _nest, GameTheme.AREA["nest"])
	GameTheme.place(self, _slot, GameTheme.AREA["slab"])
	_battle.setup(controller.data, store)
	_hud.setup(store)
	_nest.setup(controller)
	_slot.setup(controller, store)
	_battle.finished.connect(_battle_finished)
	_hud.boss_info.connect(flash)
	_banner = _notice(self, Rect2(240, 108, 800, 124), "", 40, Color("#fff3bf"), Color("#5f3dc4"), 8, 60)
	_banner.modulate.a = 0.0
	_toast = _notice(self, Rect2(240, 210, 800, 80), "", 22, Color("#ffd8a8"), Color("#000000aa"), 7, 50)
	_toast.modulate.a = 0.0
	controller.changed.connect(_on_change)
	controller.restart(controller.state["seed"])


func _on_change(events: Array, state: Dictionary) -> void:
	var fight: Dictionary = {}
	var bonus: PackedStringArray = PackedStringArray()
	var mana: int = 0
	var converted: bool = false
	for event: Dictionary in events:
		match event["t"]:
			"rejected":
				flash(REJECT_KO.get(event["reason"], "할 수 없어요"))
			"evolved", "gained":
				var id: String = event["inst"]["speciesId"]
				var first: bool = store.mark_discovered(id)
				if event["t"] == "evolved" and first:
					_announce("새로 발견!\n" + _dragon_name(id), 1.5)
				elif event.get("via") == "bonus":
					bonus.append(_dragon_name(id) + " 알")
			"mana":
				if event["reason"] in BONUS_REASONS:
					mana += event["delta"]
					converted = converted or event["reason"] == "benchFull"
			"battle":
				fight = event["result"]
	if mana != 0:
		bonus.append("마력 +%d" % mana)
	if not bonus.is_empty():
		flash("보너스! " + " · ".join(bonus) + ("\n(대기칸이 꽉 차서 보너스 알은 마력으로 바뀌었어요)" if converted else ""))
	if fight.is_empty():
		if not _pending.is_empty():
			if _sequence != null:
				_sequence.kill()
			_clear_reward()
			_pending = {}
		_render(events, state)
		return
	controller.busy = true
	_pending = {"events": events, "state": state, "won": fight["winner"] == "ally"}
	var lead: Variant = fight["enemies"].front() if not fight["enemies"].is_empty() else null
	var boss: bool = lead != null and controller.data["dragons"][lead["speciesId"]]["tier"] == "t1"
	_battle.play(fight, boss)


func _render(events: Array, state: Dictionary) -> void:
	for event: Dictionary in events:
		if event["t"] == "waveStart":
			var boss: Variant = event["boss"]
			_hud.set_boss_preview(event["wave"], event["bossPreview"], boss)
			if boss != null:
				flash("예보: %d웨이브에 「%s」\n%s" % [event["wave"] + 4, boss["nameKo"], boss["hintKo"]])
	_hud.render(state, controller.data["waves"]["maxWave"])
	_slot.render(state, events)
	_nest.render(state)
	_battle.show_idle(state)
	if state["phase"] in ["gameOver", "victory"]:
		run_finished.emit(state)


func _battle_finished() -> void:
	var result: String = "승리!" if _pending["won"] else "패배"
	var reward: Dictionary = {}
	for event: Dictionary in _pending["events"]:
		if event["t"] == "lives":
			result += "\n생명 %d 남음" % event["lives"]
		elif event["t"] == "reward":
			reward = event
	_announce(result, 0.9)
	_sequence = create_tween()
	_sequence.tween_interval(0.7)
	_sequence.tween_callback(_complete_battle if reward.is_empty() else _show_reward.bind(reward))


func _complete_battle() -> void:
	var previous: Dictionary = _pending
	_pending = {}
	controller.busy = false
	_render(previous["events"], previous["state"])


func _show_reward(event: Dictionary) -> void:
	_reward_overlay = Control.new()
	_reward_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_overlay.z_index = 70
	add_child(_reward_overlay)
	var chest: Panel = GameTheme.panel(_reward_overlay, Rect2(594, 160, 92, 60), Color("#5f3dc4"), GameTheme.PANEL_LINE, 0, 10)
	chest.pivot_offset = chest.size / 2.0
	chest.rotation_degrees = -8
	GameTheme.panel(chest, Rect2(0, 24, 92, 10), GameTheme.RECOMMEND)
	GameTheme.panel(chest, Rect2(40, 0, 12, 60), GameTheme.RECOMMEND)
	var reward: Dictionary = event["reward"]
	var caption: String = "웨이브 보상: %s\n%s" % [reward["nameKo"], _reward_detail(reward, event["detail"])]
	var reveal: Label = _notice(_reward_overlay, Rect2(240, 212, 800, 76), caption, 24, Color("#fff3bf"), Color.BLACK, 5, 0)
	reveal.modulate.a = 0.0
	reveal.scale = Vector2(0.6, 0.6)
	_sequence = create_tween()
	for i: int in range(8):
		_sequence.tween_property(chest, "rotation_degrees", 8.0 if i % 2 == 0 else -8.0, 0.09)
	_sequence.tween_property(chest, "scale", Vector2(1.4, 1.4), 0.22)
	_sequence.parallel().tween_property(chest, "modulate:a", 0.0, 0.22)
	_sequence.parallel().tween_property(reveal, "modulate:a", 1.0, 0.22)
	_sequence.parallel().tween_property(reveal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(reveal, "modulate:a", 0.0, 0.25).set_delay(1.4)
	_sequence.tween_callback(_clear_reward)
	_sequence.tween_callback(_complete_battle)


func _clear_reward() -> void:
	if is_instance_valid(_reward_overlay):
		_reward_overlay.queue_free()
		_reward_overlay = null


func _reward_detail(reward: Dictionary, detail: Variant) -> String:
	var amount: int = reward["amount"]
	match reward["kind"]:
		"mana": return "마력 +%d" % amount
		"egg", "t2egg": return _dragon_name(detail) + " 알을 얻었어요" if detail != null else "드래곤 알을 얻었어요"
		"trait":
			if detail == null:
				return "마력 +3"
			var trait_data: Dictionary = controller.data["traits"].get(detail, {})
			return "특성 「%s」 계승!" % trait_data.get("nameKo", detail)
		"nudge": return "다음 웨이브 밀기 +%d" % amount
		"freeSpin": return "다시 돌리기 %d회 무료" % amount
		_: return "생명 +%d (가득 차 있으면 마력 +3)" % amount


func _dragon_name(id: String) -> String:
	var spec: Dictionary = controller.data["dragons"].get(id, {})
	return spec.get("nameKo", id)


func _notice(parent: Control, rect: Rect2, message: String, pixels: int, tint: Color, outline: Color, width: int, depth: int) -> Label:
	var label: Label = GameTheme.label(parent, rect, message, pixels, tint, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", width)
	label.add_theme_color_override("font_outline_color", outline)
	label.pivot_offset = rect.size / 2.0
	label.z_index = depth
	return label


func _announce(message: String, hold: float) -> void:
	if _banner_animation != null:
		_banner_animation.kill()
	_banner.text = message
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(0.7, 0.7)
	_banner_animation = create_tween()
	_banner_animation.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_animation.parallel().tween_property(_banner, "modulate:a", 0.0, 0.35).set_delay(hold)


func flash(message: String) -> void:
	if _toast_animation != null:
		_toast_animation.kill()
	_toast.text = message
	_toast.modulate.a = 1.0
	_toast_animation = create_tween()
	_toast_animation.tween_property(_toast, "modulate:a", 0.0, 0.4).set_delay(1.6)
