extends Control

const Controller = preload("res://godot/ui/controller.gd")
const GameTheme = preload("res://godot/ui/theme.gd")
const Store = preload("res://godot/ui/store.gd")
const Hud = preload("res://godot/ui/hud.gd")
const SlotPanel = preload("res://godot/ui/slot_panel.gd")
const Board = preload("res://godot/ui/board.gd")
const Field = preload("res://godot/ui/field.gd")
const AppWindow = preload("res://godot/ui/window.gd")
const SkillOverlay = preload("res://godot/ui/skill_overlay.gd")
const Build = preload("res://godot/ui/build.gd")
const DexOverlay = preload("res://godot/ui/dex_overlay.gd")
const ResultOverlay = preload("res://godot/ui/result_overlay.gd")
const Tutorial = preload("res://godot/ui/tutorial.gd")
const Marks = preload("res://godot/ui/marks.gd")
const Music = preload("res://godot/ui/music.gd")
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
	"noSkillPoint": "스킬 점수가 없어요. 레벨이 오르면 받아요",
	"skillMaxed": "이미 끝까지 찍은 스킬이에요",
	"skillLocked": "앞 스킬을 먼저 찍어야 해요",
}
const FORK_DONE_KO: Dictionary = {
	"elite": "정예 사냥! 다음 적이 강해져요.\n이기면 보상을 한 번 더 골라요.",
	"rest": "쉼터에서 쉬었어요.",
	"merchant": "상인에게 마력을 냈어요.",
}
const BONUS_REASONS: Array[String] = ["line", "goldLine", "wildLine", "goldCells", "benchFull"]

signal run_finished(state: Dictionary)
signal title_requested

var controller: Controller
var store: Store
var calamity: int = -1
var _hud: Hud
var _slot: SlotPanel
var _board: Board
var _battle: Field
var _areas: Dictionary = {}
var _wave_before: int = 1
var _built_width: float = 0.0
var _banner: Label
var _toast: Label
var _toast_animation: Tween
var _banner_animation: Tween
var _sequence: Tween
var _reward_overlay: Control
var _pending: Dictionary = {}
var _tutorial: Tutorial
var _result: ResultOverlay
var _dex_button: Button
var _music_button: Button
var _boss_fight: bool = false


func _ready() -> void:
	if controller == null:
		controller = Controller.new(Build.load_data(), int(Time.get_unix_time_from_system()))
	if store == null:
		store = Store.new()
	theme = GameTheme.create()
	_build_panels()
	_tutorial = Tutorial.new()
	add_child(_tutorial)
	_tutorial.setup(store, _areas)
	controller.changed.connect(_on_change)
	get_viewport().size_changed.connect(_on_resize)
	controller.restart(controller.state["seed"], calamity)


## 화면 폭에 맞춰 HUD · 전장 · 아래 띠 · 배치판을 만든다(창 크기가 바뀌면 다시 만듦).
func _build_panels() -> void:
	var preview: Dictionary = _hud._preview.duplicate() if _hud != null and is_instance_valid(_hud) else {}
	for panel: Variant in [_battle, _hud, _slot, _board, _banner, _toast]:
		if panel != null and is_instance_valid(panel):
			remove_child(panel)
			panel.queue_free()
	_areas = GameTheme.areas(get_viewport_rect().size.x)
	_built_width = _areas["width"]
	var width: float = _areas["width"]
	_battle = Field.new()
	_hud = Hud.new()
	_slot = SlotPanel.new()
	_board = Board.new()
	GameTheme.place(self, _battle, _areas["field"])
	GameTheme.place(self, _hud, _areas["hud"])
	GameTheme.place(self, _slot, _areas["left"])
	GameTheme.place(self, _board, Rect2(0, 0, width, GameTheme.HEIGHT))
	for panel: Control in [_battle, _hud, _slot, _board]:
		move_child(panel, 0)
	move_child(_board, 3)
	_battle.setup(controller.data, store, width)
	_hud.setup(store, width)
	_hud._preview = preview
	_slot.setup(controller, store)
	_board.setup(controller, _areas)
	_board.inspect.connect(_open_skills)
	_battle.finished.connect(_battle_finished)
	_hud.boss_info.connect(flash)
	_dex_button = GameTheme.button(_hud, Rect2(width - 328, 0, 80, 44), "도감", _open_dex)
	var music: Node = Music.get_for(get_tree())
	_music_button = GameTheme.button(_hud, Rect2(width - 404, 0, 70, 44), Music.SET_KO[music.current_set()], _cycle_music)
	_music_button.tooltip_text = "배경음악: A, B, 끔"
	_battle.reinforced.connect(_on_reinforced)
	var field: Rect2 = _areas["field"]
	var center_x: float = field.position.x + (field.size.x - 800.0) / 2.0
	_banner = _notice(self, Rect2(center_x, 108, 800, 124), "", 40, Color("#fff3bf"), Color("#5f3dc4"), 8, 60)
	_banner.modulate.a = 0.0
	_toast = _notice(self, Rect2(center_x, 210, 800, 80), "", 22, Color("#ffd8a8"), Color("#000000aa"), 7, 50)
	_toast.modulate.a = 0.0


func _on_resize() -> void:
	var width: float = GameTheme.areas(get_viewport_rect().size.x)["width"]
	if is_equal_approx(width, _built_width):
		return
	if controller.busy or not _pending.is_empty():
		# 굴림·전투 재생 중이면 끝난 뒤 다시 맞춘다.
		get_tree().create_timer(0.5).timeout.connect(_on_resize)
		return
	_build_panels()
	_tutorial.setup(store, _areas)
	_tutorial._step = -1
	_render([], controller.state)


func _unhandled_input(event: InputEvent) -> void:
	if AppWindow.handle_shortcut(event):
		get_viewport().set_input_as_handled()


func _on_change(events: Array, state: Dictionary) -> void:
	var fight: Dictionary = {}
	var bonus: PackedStringArray = PackedStringArray()
	var mana: int = 0
	var converted: bool = false
	var leveled: int = 0
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
			"reward":
				flash("보상: %s\n%s" % [event["reward"]["nameKo"], _reward_detail(event["reward"], event["detail"])])
			"absorbed":
				if int(event.get("levels", 0)) > 0:
					flash("레벨 업! Lv.%d\n드래곤을 눌러 스킬을 찍어요." % int(event["inst"].get("level", 1)))
				else:
					flash("경험치를 받았어요.")
			"leveled":
				leveled += 1
			"fork":
				flash(FORK_DONE_KO.get(event["option"], ""))
			"relic":
				for relic: Dictionary in controller.data.get("relics", []):
					if relic["id"] == event["id"]:
						flash("유물 획득: %s\n%s" % [relic["nameKo"], relic["descKo"]])
	if leveled > 0:
		flash("드래곤 %d마리가 레벨 업!\n눌러서 스킬을 찍어요." % leveled)
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
	_tutorial.hide()
	_pending = {"events": events, "state": state, "won": fight["winner"] == "ally"}
	var boss: bool = Waves.is_boss(controller.data["waves"], _wave_before)
	var elite: bool = Waves.is_elite(controller.data["waves"], _wave_before)
	_boss_fight = boss or elite
	var final: bool = _wave_before >= int(controller.data["waves"]["maxWave"])
	Music.get_for(get_tree()).play(("final_boss" if final else "boss") if _boss_fight else "battle_calm")
	_board.set_fighting(true)
	_slot.modulate = Color(0.55, 0.55, 0.62)
	_battle.play(fight, boss, _wave_before, elite)


func _render(events: Array, state: Dictionary) -> void:
	for event: Dictionary in events:
		if event["t"] == "waveStart":
			var boss: Variant = event["boss"]
			_hud.set_boss_preview(event["wave"], event["bossPreview"], boss)
			if boss != null:
				flash("예보: %d웨이브에 「%s」\n%s" % [event["wave"] + 4, boss["nameKo"], boss["hintKo"]])
	_hud.render(state, controller.data["waves"]["maxWave"])
	Music.get_for(get_tree()).play("prepare")
	_wave_before = state["wave"]
	_slot.render(state, events)
	_slot.modulate = Color.WHITE
	_board.set_fighting(false)
	_board.render(state)
	_battle.show_idle(state)
	_clear_reward()
	if state["phase"] == "reward":
		_show_reward_choices(state)
	elif state["phase"] == "relic":
		_show_relic_choices(state)
	elif state["phase"] == "fork":
		_show_fork_choices(state)
	if state["phase"] in ["gameOver", "victory"]:
		_show_result(state)
		run_finished.emit(state)
	else:
		_tutorial.update(state)


func _cycle_music() -> void:
	_music_button.text = Music.SET_KO[Music.get_for(get_tree()).cycle_set()]


## 일반 전투에서 적이 더 몰려오면 급박한 곡으로 바꾼다. 보스전은 처음부터 보스 곡이다.
func _on_reinforced() -> void:
	if not _boss_fight and controller.busy:
		Music.get_for(get_tree()).play("battle_rush")


func _battle_finished() -> void:
	if _pending.is_empty():
		return
	var result: String = "승리!" if _pending["won"] else "패배"
	for event: Dictionary in _pending["events"]:
		if event["t"] == "lives":
			result += "\n생명 %d 남음" % event["lives"]
	_announce(result, 0.9)
	_sequence = create_tween()
	_sequence.tween_interval(0.7)
	_sequence.tween_callback(_complete_battle)


func _complete_battle() -> void:
	var previous: Dictionary = _pending
	_pending = {}
	controller.busy = false
	_render(previous["events"], previous["state"])


func _open_dex() -> void:
	if controller.busy:
		return
	_set_modal(true)
	var dex: DexOverlay = DexOverlay.new()
	dex.closed.connect(_close_dex)
	add_child(dex)
	dex.setup(controller.data, store, controller.state, _areas["width"])


func _close_dex() -> void:
	_set_modal(false)
	_dex_button.grab_focus()


func _show_result(state: Dictionary) -> void:
	if is_instance_valid(_result):
		return
	_tutorial.finish()
	store.record_run(state, Build.max_calamity(controller.data))
	_set_modal(true)
	_result = ResultOverlay.new()
	add_child(_result)
	_result.setup(controller.data, state, _start_new_run, _return_to_title)


func _set_modal(active: bool) -> void:
	controller.busy = active
	for panel: Control in [_hud, _slot, _board, _tutorial]:
		panel.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED if active else Control.FOCUS_BEHAVIOR_INHERITED


func _start_new_run() -> void:
	_result.hide()
	_result.queue_free()
	_result = null
	_set_modal(false)
	var seed_value: int = (int(controller.state["seed"]) * 7 + 13) % 1000000007
	controller.restart(seed_value)


func _return_to_title() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://godot/scenes/main.tscn")
	else:
		title_requested.emit()


## 승리 보상 3개 중 하나를 고른다.
func _show_reward_choices(state: Dictionary) -> void:
	var field: Rect2 = _areas["field"]
	_reward_overlay = Control.new()
	_reward_overlay.z_index = 70
	GameTheme.place(self, _reward_overlay, field)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	GameTheme.place(_reward_overlay, dim, Rect2(Vector2.ZERO, field.size))
	var title: Label = _notice(_reward_overlay, Rect2(0, 120, field.size.x, 50), "승리 보상을 하나 고르세요", 32, Color("#fff3bf"), Color("#5f3dc4"), 8, 0)
	title.pivot_offset = Vector2.ZERO
	var choices: Array = state["rewardChoices"]
	var odds: Dictionary = _reward_odds(Waves.is_boss(controller.data["waves"], int(state["wave"]) - 1))
	var card_w: float = 230.0
	var gap: float = 20.0
	var total: float = choices.size() * card_w + (choices.size() - 1) * gap
	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		var reward: Dictionary = choice["reward"]
		var rect: Rect2 = Rect2((field.size.x - total) / 2.0 + i * (card_w + gap), 200, card_w, 250)
		var card: Button = GameTheme.button(_reward_overlay, rect, "", controller.dispatch.bind({"type": "chooseReward", "index": i}), Color("#2b3045"), GameTheme.RECOMMEND, 2)
		var art: TextureRect = null
		if choice["detail"] != null and reward["kind"] in ["egg", "t2egg"]:
			art = GameTheme.dragon(card, Rect2((card_w - 110) / 2.0, 14, 110, 110), choice["detail"])
		if art == null:
			GameTheme.place(card, Marks.new("gold" if reward["kind"] == "mana" else "wild", true), Rect2((card_w - 90) / 2.0, 24, 90, 90))
		GameTheme.label(card, Rect2(8, 134, card_w - 16, 28), reward["nameKo"], 20, Color("#fff3bf"), HORIZONTAL_ALIGNMENT_CENTER)
		var detail: Label = GameTheme.label(card, Rect2(12, 166, card_w - 24, 46), _reward_preview(reward, choice["detail"]), 14, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.wrap(detail)
		var chance: String = "이 보상이 나올 확률 %d%%" % roundi(odds.get(reward["id"], 0.0) * 100.0)
		var chance_color: Color = GameTheme.DIM
		if choice["detail"] != null and reward["kind"] in ["egg", "t2egg"]:
			var share: float = _species_share(choice["detail"])
			chance += "\n그중 이 용일 확률 %.1f%%" % (share * 100.0)
			chance_color = GameTheme.rarity(Slot.species_weight(controller.data, choice["detail"]))[1] if reward["kind"] == "egg" else GameTheme.DIM
			if not store.discovered().has(choice["detail"]):
				GameTheme.new_badge(card, rect.size)
		GameTheme.label(card, Rect2(8, 200, card_w - 16, 40), chance, 12, chance_color, HORIZONTAL_ALIGNMENT_CENTER)
		card.pivot_offset = rect.size / 2.0
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0
		var pop: Tween = card.create_tween().set_parallel()
		pop.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.08)
		pop.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.08)


## 보상 종류마다, 세 장 가운데 한 장으로 나올 확률(0~1). 겹치지 않게 세 번 뽑는 경우를 모두 센다.
func _reward_odds(boss: bool) -> Dictionary:
	var key: String = "bossWeight" if boss else "weight"
	var pool: Array = controller.data["rewards"].filter(func(reward: Dictionary) -> bool: return int(reward[key]) > 0)
	var odds: Dictionary = {}
	_walk_reward_draws(pool, key, [], 1.0, odds)
	return odds


func _walk_reward_draws(pool: Array, key: String, taken: Array, chance: float, odds: Dictionary) -> void:
	var total: float = 0.0
	for reward: Dictionary in pool:
		if reward["id"] not in taken:
			total += float(reward[key])
	if taken.size() >= Run.REWARD_CHOICES or total <= 0.0:
		for id: String in taken:
			odds[id] = float(odds.get(id, 0.0)) + chance
		return
	for reward: Dictionary in pool:
		if reward["id"] not in taken:
			_walk_reward_draws(pool, key, taken + [reward["id"]], chance * float(reward[key]) / total, odds)


## 알 보상에서 같은 계급 가운데 이 종이 뽑힐 비율(0~1).
func _species_share(id: String) -> float:
	var tier: String = controller.data["dragons"][id]["tier"]
	var total: float = 0.0
	for spec: Dictionary in controller.data["dragons"].values():
		if spec["tier"] == tier:
			total += float(Slot.species_weight(controller.data, spec["id"]))
	return float(Slot.species_weight(controller.data, id)) / maxf(1.0, total)


## 보스를 이기면 유물 3개 중 하나를 고른다. 유물은 판이 끝날 때까지 남는다.
func _show_relic_choices(state: Dictionary) -> void:
	var field: Rect2 = _areas["field"]
	_reward_overlay = Control.new()
	_reward_overlay.z_index = 70
	GameTheme.place(self, _reward_overlay, field)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	GameTheme.place(_reward_overlay, dim, Rect2(Vector2.ZERO, field.size))
	var title: Label = _notice(_reward_overlay, Rect2(0, 110, field.size.x, 50), "보스 유물을 하나 고르세요", 32, Color("#ffe066"), Color("#7a5c00"), 8, 0)
	title.pivot_offset = Vector2.ZERO
	GameTheme.label(_reward_overlay, Rect2(0, 162, field.size.x, 24), "유물은 이번 판이 끝날 때까지 계속 적용돼요.", 15, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var choices: Array = state["relicChoices"]
	var card_w: float = 230.0
	var gap: float = 20.0
	var total: float = choices.size() * card_w + (choices.size() - 1) * gap
	for i: int in range(choices.size()):
		var relic: Dictionary = {}
		for candidate: Dictionary in controller.data["relics"]:
			if candidate["id"] == choices[i]:
				relic = candidate
		var rect: Rect2 = Rect2((field.size.x - total) / 2.0 + i * (card_w + gap), 210, card_w, 220)
		var card: Button = GameTheme.button(_reward_overlay, rect, "", controller.dispatch.bind({"type": "chooseRelic", "index": i}), Color("#2e2710"), Color("#d4af37"), 2)
		GameTheme.place(card, Marks.new("gold", true), Rect2((card_w - 80) / 2.0, 18, 80, 80))
		GameTheme.label(card, Rect2(8, 108, card_w - 16, 28), relic.get("nameKo", ""), 20, Color("#ffe066"), HORIZONTAL_ALIGNMENT_CENTER)
		var detail: Label = GameTheme.label(card, Rect2(14, 142, card_w - 28, 66), relic.get("descKo", ""), 15, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.wrap(detail)
		card.pivot_offset = rect.size / 2.0
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0
		var pop: Tween = card.create_tween().set_parallel()
		pop.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.08)
		pop.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.08)


## 갈림길: 세 길 가운데 하나를 고른다.
func _show_fork_choices(state: Dictionary) -> void:
	var field: Rect2 = _areas["field"]
	var fork: Dictionary = controller.data["waves"].get("fork", {})
	var cost: int = int(fork.get("merchantCost", 0))
	var cards: Dictionary = {
		"elite": ["정예 사냥", "다음 웨이브의 적이 %d%% 강해져요. 이기면 보상을 한 번 더 골라요." % int(fork.get("elitePowerPct", 0)), Color("#c92a2a"), "fire"],
		"rest": ["쉼터", "생명 +%d(가득 차 있으면 그대로), 모든 드래곤 경험치 +%d." % [int(fork.get("restLives", 0)), int(fork.get("restXp", 0))], Color("#2f9e44"), "poison"],
		"merchant": ["떠돌이 상인", "마력 %d을 내고 유물 3개 가운데 하나를 골라요." % cost, Color("#d4af37"), "gold"],
	}
	_reward_overlay = Control.new()
	_reward_overlay.z_index = 70
	GameTheme.place(self, _reward_overlay, field)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	GameTheme.place(_reward_overlay, dim, Rect2(Vector2.ZERO, field.size))
	var title: Label = _notice(_reward_overlay, Rect2(0, 110, field.size.x, 50), "갈림길이에요. 어느 길로 갈까요?", 32, Color("#fff3bf"), Color("#5f3dc4"), 8, 0)
	title.pivot_offset = Vector2.ZERO
	var choices: Array = state["forkChoices"]
	var card_w: float = 230.0
	var gap: float = 20.0
	var total: float = choices.size() * card_w + (choices.size() - 1) * gap
	for i: int in range(choices.size()):
		var option: String = choices[i]
		var info: Array = cards[option]
		var rect: Rect2 = Rect2((field.size.x - total) / 2.0 + i * (card_w + gap), 200, card_w, 230)
		var card: Button = GameTheme.button(_reward_overlay, rect, "", controller.dispatch.bind({"type": "chooseFork", "option": option}), Color("#2b3045"), info[2], 2)
		GameTheme.place(card, Marks.new(info[3], true), Rect2((card_w - 80) / 2.0, 18, 80, 80))
		GameTheme.label(card, Rect2(8, 108, card_w - 16, 28), info[0], 20, Color("#fff3bf"), HORIZONTAL_ALIGNMENT_CENTER)
		var detail: Label = GameTheme.label(card, Rect2(14, 142, card_w - 28, 60), info[1], 14, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.wrap(detail)
		if option == "merchant" and int(state["mana"]) < cost:
			card.disabled = true
			GameTheme.label(card, Rect2(8, 202, card_w - 16, 20), "마력이 모자라요 (지금 %d)" % int(state["mana"]), 13, Color("#ff8787"), HORIZONTAL_ALIGNMENT_CENTER)


func _reward_preview(reward: Dictionary, detail: Variant) -> String:
	var amount: int = reward["amount"]
	match reward["kind"]:
		"mana": return "마력 +%d" % amount
		"egg", "t2egg": return _dragon_name(detail) + " 알을 받아요" if detail != null else "드래곤 알을 받아요"
		"trait": return "드래곤 하나가 새 계승 특성을 얻어요"
		"nudge": return "다음 웨이브에 밀기 +%d" % amount
		"freeSpin": return "다시 돌리기 %d회 무료" % amount
		_: return "생명 +%d (가득 차 있으면 마력 +3)" % amount


func _open_skills(ref: Dictionary) -> void:
	if controller.busy or controller.state["phase"] not in ["manage", "pick", "spin"]:
		return
	var overlay: SkillOverlay = SkillOverlay.new()
	add_child(overlay)
	overlay.setup(controller, ref, Vector2(_areas["width"], GameTheme.HEIGHT))


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
