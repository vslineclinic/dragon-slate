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
const Icons = preload("res://godot/ui/icons.gd")
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
	"noItem": "전환의 룬이 없어요",
	"sameElement": "이미 그 원소예요",
	"cannotTransmute": "이 드래곤은 원소를 바꿀 수 없어요",
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
## 원정 길이(자동 저장에 적는다)와, 저장한 판을 이어 하는지.
var run_length: String = "long"
var resume: bool = false
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
## 새 판을 막 시작해서 시작 묶음을 아직 고르지 않았는지.
var _start_open: bool = false
var _defeat_note: String = ""


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
	if resume:
		## 이어 하기: 저장한 상태 그대로 그린다. 보스 예보는 이번 구간의 첫 웨이브 기준으로 다시 만든다.
		resume = false
		var probe: Dictionary = controller.state.duplicate()
		probe["wave"] = int(probe["wave"]) - (int(probe["wave"]) - 1) % 5
		controller.changed.emit([Run._wave_start(controller.data, probe)], controller.state)
		return
	_start_open = true
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
	_board.lineage.connect(_show_lineage)
	_battle.finished.connect(_battle_finished)
	_hud.boss_info.connect(flash)
	_dex_button = GameTheme.button(_hud, Rect2(width - 328, 0, 80, 44), "도감", _open_dex)
	var music: Node = Music.get_for(get_tree())
	_music_button = GameTheme.button(_hud, Rect2(width - 404, 0, 70, 44), Music.SET_KO[music.current_set()], _cycle_music)
	_music_button.tooltip_text = "배경음악: A, B, 끔"
	_battle.reinforced.connect(_on_reinforced)
	var field: Rect2 = _areas["field"]
	var center_x: float = field.position.x + (field.size.x - 800.0) / 2.0
	_banner = _notice(self, Rect2(center_x, 108, 800, 124), "", 40, GameTheme.GOLD_HI, Color("#1a1206"), 8, 60)
	_banner.modulate.a = 0.0
	_toast = _notice(self, Rect2(center_x, 210, 800, 80), "", 21, Color("#ffe9c4"), Color("#000000aa"), 6, 50)
	_toast.modulate.a = 0.0


func _on_resize() -> void:
	var width: float = GameTheme.areas(get_viewport_rect().size.x)["width"]
	if is_equal_approx(width, _built_width):
		return
	if (controller.busy and not _start_open) or not _pending.is_empty():
		# 굴림·전투 재생 중이면 끝난 뒤 다시 맞춘다(시작 묶음 화면은 바로 다시 그린다).
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
			"runeErased":
				flash("석판에서 %s 룬을 뺐어요.\n이제 묶음은 %d장이에요. 남은 룬이 더 자주 나와요." % [
					GameTheme.SYMBOL_LABEL.get(event["from"], event["from"]), state.get("slab", []).size(),
				])
			"runeReplaced":
				var slab: Array = state.get("slab", [])
				flash(("한 장 더 바꿀 수 있어요.\n" if state.get("runePending") != null else "") + "석판의 %s 룬을 %s 룬으로 바꿨어요.\n이제 %s 룬이 %d칸 중 %d칸이에요." % [
					GameTheme.SYMBOL_LABEL.get(event["from"], event["from"]), GameTheme.SYMBOL_LABEL.get(event["to"], event["to"]),
					GameTheme.SYMBOL_LABEL.get(event["to"], event["to"]), slab.size(), slab.count(event["to"]),
				])
			"item":
				if event["id"] == "transmute" and int(event["delta"]) > 0:
					flash("전환의 룬을 얻었어요!\n드래곤을 눌러 다른 원소의 같은 용으로 바꿀 수 있어요.")
			"transmuted":
				if event["ok"]:
					store.mark_discovered(event["to"])
					_announce("전환 성공!\n%s → %s" % [_dragon_name(event["from"]), _dragon_name(event["to"])], 1.4)
				else:
					flash("전환 실패… 룬이 부서졌어요.\n드래곤은 그대로이고, 다음 전환은 반드시 성공해요.")
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
	## 시작 묶음은 길잡이를 마친 사람에게만 묻는다(첫 판은 기본 묶음으로 단순하게).
	if _start_open and (not store.tutorial_done() or state["phase"] != "spin" or int(state["wave"]) != 1 or int(state["spinsThisWave"]) != 0):
		_start_open = false
	if _start_open:
		_show_start_choices(state)
	elif state["phase"] == "reward":
		_show_reward_choices(state)
	elif state["phase"] == "slab":
		_show_slab_edit(state)
	elif state["phase"] == "relic":
		_show_relic_choices(state)
	elif state["phase"] == "fork":
		_show_fork_choices(state)
	if state["phase"] in ["gameOver", "victory"]:
		store.clear_run()
		_show_result(state)
		run_finished.emit(state)
	else:
		## 자동 저장: 차례가 바뀔 때마다(시작 묶음을 고르는 중에는 아직 판이 아니다).
		if not _start_open:
			store.save_run(state, run_length)
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
		elif event["t"] == "battle" and not _pending["won"]:
			## 왜 졌는지 한 줄(판이 끝난 뒤 잠깐 떠 있는다).
			_defeat_note = _defeat_text(Hints.defeat_reason(controller.data["battle"], event["result"]))
	_announce(result, 0.9)
	_sequence = create_tween()
	_sequence.tween_interval(0.7)
	_sequence.tween_callback(_complete_battle)


func _complete_battle() -> void:
	var previous: Dictionary = _pending
	_pending = {}
	controller.busy = false
	_render(previous["events"], previous["state"])
	if not _defeat_note.is_empty():
		flash(_defeat_note)
		_defeat_note = ""


func _defeat_text(reason: Dictionary) -> String:
	match reason["kind"]:
		"weakElement":
			return "진 이유: 상성에서 밀렸어요.\n우리 용의 공격 %d%%가 약한 상성이었어요. 전환의 룬이나 다른 원소 용을 써 보세요." % int(reason["pct"])
		"offLane":
			return "진 이유: 줄이 어긋났어요.\n우리 용의 공격 %d%%가 다른 줄을 쳐서 약해졌어요. 적이 몰리는 줄에 용을 세워 보세요." % int(reason["pct"])
		"timeout":
			return "진 이유: 시간이 다 됐어요.\n버티기는 했지만 화력이 모자랐어요."
		"leaders":
			return "진 이유: 우두머리를 못 잡았어요.\n우두머리가 오는 줄에 가장 센 용을 세워 보세요."
	return "진 이유: 졸병에게 밀렸어요.\n적이 몰리는 줄에 용을 더 세우거나 합쳐서 키워 보세요."


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
	_start_open = true
	controller.restart(seed_value)


func _return_to_title() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://godot/scenes/main.tscn")
	else:
		title_requested.emit()


## 승리 보상 3개 중 하나를 고른다.
func _show_reward_choices(state: Dictionary) -> void:
	var field: Rect2 = _open_choice("승리 보상을 하나 고르세요", "", GameTheme.GOLD_HI)
	var choices: Array = state["rewardChoices"]
	var odds: Dictionary = _reward_odds(Waves.is_boss(controller.data["waves"], int(state["wave"]) - 1))
	var tints: Dictionary = {"mana": Color("#b197fc"), "egg": GameTheme.GOLD, "t2egg": Color("#ffe27a"), "trait": Color("#f06595"), "nudge": Color("#74c0fc"), "freeSpin": Color("#8ce99a"), "life": Color("#ff8787"), "transmute": Color("#63e6be"), "erase": Color("#ff8787")}
	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		var reward: Dictionary = choice["reward"]
		var is_egg: bool = choice["detail"] != null and reward["kind"] in ["egg", "t2egg"]
		var is_rune: bool = choice["detail"] != null and reward["kind"] == "rune"
		var tint: Color = tints.get(reward["kind"], GameTheme.GOLD)
		if is_egg:
			tint = GameTheme.COLOR.get(controller.data["dragons"][choice["detail"]]["elements"][0], tint)
		if is_rune:
			tint = GameTheme.COLOR.get(choice["detail"], tint)
		var card: Button = _choice_card(i, choices.size(), field, {"type": "chooseReward", "index": i}, tint, reward["nameKo"], _reward_preview(reward, choice["detail"]), 280.0)
		var card_w: float = card.size.x
		var art: TextureRect = null
		if is_egg:
			art = GameTheme.dragon(card, Rect2((card_w - 116) / 2.0, 18, 116, 116), choice["detail"])
		if is_rune:
			GameTheme.place(card, Marks.new(choice["detail"]), Rect2((card_w - 88) / 2.0, 32, 88, 88))
		elif art == null:
			GameTheme.place(card, Icons.new(reward["kind"], tint), Rect2((card_w - 104) / 2.0, 24, 104, 104))
		var chance: String = "이 보상이 나올 확률 %d%%" % roundi(odds.get(reward["id"], 0.0) * 100.0)
		var chance_color: Color = GameTheme.DIM
		if is_egg:
			var share: float = _species_share(choice["detail"])
			chance += "\n그중 이 용일 확률 %.1f%%" % (share * 100.0)
			chance_color = GameTheme.rarity(Slot.species_weight(controller.data, choice["detail"]))[1] if reward["kind"] == "egg" else GameTheme.DIM
			if not store.discovered().has(choice["detail"]):
				GameTheme.new_badge(card, card.size)
		GameTheme.label(card, Rect2(8, 232, card_w - 16, 40), chance, 12, chance_color, HORIZONTAL_ALIGNMENT_CENTER)


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
	var field: Rect2 = _open_choice("보스 유물을 하나 고르세요", "유물은 이번 판이 끝날 때까지 계속 적용돼요.", GameTheme.GOLD_HI)
	var choices: Array = state["relicChoices"]
	for i: int in range(choices.size()):
		var relic: Dictionary = {}
		for candidate: Dictionary in controller.data["relics"]:
			if candidate["id"] == choices[i]:
				relic = candidate
		var card: Button = _choice_card(i, choices.size(), field, {"type": "chooseRelic", "index": i}, GameTheme.GOLD, relic.get("nameKo", ""), relic.get("descKo", ""), 250.0)
		GameTheme.place(card, Icons.new(str(relic.get("id", "")), GameTheme.GOLD), Rect2((card.size.x - 108) / 2.0, 22, 108, 108))


## 갈림길: 세 길 가운데 하나를 고른다.
func _show_fork_choices(state: Dictionary) -> void:
	var fork: Dictionary = controller.data["waves"].get("fork", {})
	var cost: int = int(fork.get("merchantCost", 0))
	var cards: Dictionary = {
		"elite": ["정예 사냥", "다음 웨이브의 적이 %d%% 강해져요. 이기면 보상을 한 번 더 골라요." % int(fork.get("elitePowerPct", 0)), Color("#e8573a")],
		"rest": ["쉼터", "생명 +%d(가득 차 있으면 그대로), 모든 드래곤 경험치 +%d." % [int(fork.get("restLives", 0)), int(fork.get("restXp", 0))], Color("#6fcf7a")],
		"merchant": ["떠돌이 상인", "마력 %d을 내고 유물 3개 가운데 하나를 골라요." % cost, GameTheme.GOLD],
	}
	var field: Rect2 = _open_choice("갈림길이에요. 어느 길로 갈까요?", "", GameTheme.GOLD_HI)
	var choices: Array = state["forkChoices"]
	for i: int in range(choices.size()):
		var option: String = choices[i]
		var info: Array = cards[option]
		var card: Button = _choice_card(i, choices.size(), field, {"type": "chooseFork", "option": option}, info[2], info[0], info[1], 262.0)
		GameTheme.place(card, Icons.new(option, info[2]), Rect2((card.size.x - 108) / 2.0, 22, 108, 108))
		if option == "merchant" and int(state["mana"]) < cost:
			card.disabled = true
			GameTheme.label(card, Rect2(8, 236, card.size.x - 16, 20), "마력이 모자라요 (지금 %d)" % int(state["mana"]), 13, Color("#ff8787"), HORIZONTAL_ALIGNMENT_CENTER)


## 계보 선택: 합쳐서 진화할 때 갈래가 둘이면 어느 종이 될지 고른다. 성장(레벨 · 스킬 · 계승 특성)은 어느 쪽이든 같다.
func _show_lineage(command: Dictionary) -> void:
	var state: Dictionary = controller.state
	var main: Variant = state[command["main"]["zone"]][command["main"]["index"]]
	var material: Variant = state[command["material"]["zone"]][command["material"]["index"]]
	## 다른 선택 화면(보상 · 유물 · 석판 · 시작 묶음)이 떠 있으면 그 선택이 먼저다.
	if main == null or material == null or controller.busy or is_instance_valid(_reward_overlay):
		return
	var preview: Dictionary = Fusion.merge_preview(controller.data, main, material)
	if preview["kind"] != "evolve" or preview["options"].size() < 2:
		controller.dispatch(command)
		return
	_clear_reward()
	var carrier: Dictionary = material if Fusion.level_of(material) > Fusion.level_of(main) else main
	var kept: PackedStringArray = PackedStringArray(["레벨 %d" % Fusion.level_of(carrier)])
	var skill_total: int = 0
	for learned: Variant in carrier.get("skills", {}).values():
		skill_total += int(learned)
	if skill_total > 0:
		kept.append("스킬 %d단계" % skill_total)
	for trait_id: String in carrier["traits"]:
		kept.append("계승 특성 「%s」" % controller.data["traits"].get(trait_id, {}).get("nameKo", trait_id))
	var field: Rect2 = _open_choice("어느 계보로 이을까요?", "이어받는 것: %s (어느 쪽을 골라도 같아요)" % " · ".join(kept), GameTheme.GOLD_HI)
	var labels: Array = ["조합의 갈래", "%s의 갈래" % _dragon_name(main["speciesId"])]
	for i: int in range(preview["options"].size()):
		var id: String = preview["options"][i]
		var spec: Dictionary = controller.data["dragons"][id]
		var tint: Color = GameTheme.COLOR.get(spec["elements"][0], GameTheme.GOLD)
		var role: String = spec.get("role", "")
		var chosen: Dictionary = command.duplicate(true)
		chosen["choice"] = i
		var ability: String = GameTheme.ability_text(controller.data, id)
		var body: String = "%s · %s" % [GameTheme.ROLE_KO.get(role, ""), GameTheme.ROLE_NOTE.get(role, "")]
		var card: Button = _choice_card(i, preview["options"].size(), field, {}, tint, spec["nameKo"], body, 346.0, _choose_lineage.bind(chosen))
		var card_w: float = card.size.x
		GameTheme.dragon(card, Rect2((card_w - 116) / 2.0, 18, 116, 116), id)
		GameTheme.label(card, Rect2(8, 4, card_w - 16, 18), labels[i], 12, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var stats: Dictionary = spec["stats"]
		GameTheme.label(card, Rect2(8, 236, card_w - 16, 20), "체력 %d · 공격력 %d" % [int(stats["hp"]), int(stats["atk"])], 13, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var own: Dictionary = controller.data["traits"].get(spec["traitId"], {})
		GameTheme.label(card, Rect2(8, 256, card_w - 16, 18), "고유 특성 「%s」" % own.get("nameKo", ""), 12, tint.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
		var ability_line: Label = GameTheme.label(card, Rect2(10, 276, card_w - 20, 60), "능력 " + ability if not ability.is_empty() else "형태 능력 없음", 12, GameTheme.GOLD_HI if not ability.is_empty() else GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		ability_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		GameTheme.wrap(ability_line)
		card.tooltip_text = "%s: %s\n고유 특성 「%s」 %s" % [GameTheme.ROLE_KO.get(role, ""), GameTheme.ROLE_NOTE.get(role, ""), own.get("nameKo", ""), own.get("descKo", "")]
		if not store.discovered().has(id):
			GameTheme.new_badge(card, card.size)
	var mid: float = field.size.x / 2.0
	GameTheme.cta(_reward_overlay, Rect2(mid - 110, 560, 220, 44), "그만두기", _clear_reward, "mystic", 17)


func _choose_lineage(command: Dictionary) -> void:
	_clear_reward()
	controller.dispatch(command)


## 새 판의 시작 묶음 고르기: 이번 판에 나온 원소 묶음 셋(용 한 마리와 함께) 또는 기본 묶음.
func _show_start_choices(state: Dictionary) -> void:
	var options: Array = Run.start_options(controller.data, int(state["seed"]))
	if options.is_empty():
		_start_open = false
		return
	controller.busy = true
	var field: Rect2 = _open_choice("시작 묶음을 고르세요", "석판의 칸은 내 룬 묶음에서 뽑혀요. 한 원소에 힘을 실으면 그 원소의 알과 줄이 자주 나와요.", GameTheme.GOLD_HI)
	var focus: Dictionary = controller.data["slot"]["slab"]["focus"]
	for i: int in range(options.size()):
		var option: Dictionary = options[i]
		var element: String = option["id"]
		var tint: Color = GameTheme.COLOR[element]
		var element_name: String = GameTheme.SYMBOL_LABEL.get(element, element)
		var body: String = "%s 룬 %d장" % [element_name, int(focus["own"])]
		if not str(option["speciesId"]).is_empty():
			body += "\n%s 함께 시작해요" % _with(_dragon_name(option["speciesId"]))
		var card: Button = _choice_card(i, options.size(), field, {}, tint, "%s의 묶음" % element_name, body, 280.0, _choose_start.bind(element))
		if str(option["speciesId"]).is_empty() or GameTheme.dragon(card, Rect2((card.size.x - 116) / 2.0, 18, 116, 116), option["speciesId"]) == null:
			GameTheme.place(card, Marks.new(element), Rect2((card.size.x - 88) / 2.0, 32, 88, 88))
		var fewer: PackedStringArray = PackedStringArray()
		for beaten: String in controller.data["battle"]["beats"].get(element, []):
			fewer.append(GameTheme.SYMBOL_LABEL.get(beaten, beaten))
		GameTheme.label(card, Rect2(8, 240, card.size.x - 16, 20), "대신 %s 룬은 %d장씩" % [" · ".join(fewer), int(focus["beaten"])], 12, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var mid: float = field.size.x / 2.0
	GameTheme.cta(_reward_overlay, Rect2(mid - 150, 500, 300, 46), "고르게 섞인 묶음으로", _choose_start.bind(""), "mystic", 18)
	GameTheme.label(_reward_overlay, Rect2(0, 550, field.size.x, 20), "모든 원소 2장씩. 용 없이 시작해요.", 13, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)


## 이름 뒤에 "와/과"를 받침에 맞춰 붙인다.
static func _with(word: String) -> String:
	if word.is_empty():
		return word
	var code: int = word.unicode_at(word.length() - 1)
	var closed: bool = code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0
	return word + ("과" if closed else "와")


func _choose_start(element: String) -> void:
	_start_open = false
	if element.is_empty():
		controller.busy = false
		_clear_reward()
		flash("고르게 섞인 묶음으로 시작해요.")
		return
	controller.restart(int(controller.state["seed"]), int(controller.state["calamity"]), element)
	flash("%s의 묶음으로 시작해요.\n석판 위의 숫자가 내 룬 묶음이에요." % GameTheme.SYMBOL_LABEL.get(element, element))


## 내 석판 고치기: 받은 룬을 묶음의 어느 룬과 바꿀지 고른다(같은 무늬끼리 모아서 보여 준다).
## 룬 지우기(runePending이 "erase")면 뺄 룬을 고른다.
func _show_slab_edit(state: Dictionary) -> void:
	var rune: String = str(state.get("runePending", ""))
	var erasing: bool = rune == "erase"
	var slab: Array = state.get("slab", [])
	var tint: Color = GameTheme.EMBER.lightened(0.3) if erasing else GameTheme.COLOR.get(rune, GameTheme.GOLD)
	var rune_name: String = GameTheme.SYMBOL_LABEL.get(rune, rune)
	var title: String = "석판에서 뺄 룬을 고르세요" if erasing else "%s 룬을 석판에 넣어요" % rune_name
	var note: String = "묶음이 줄면 남은 룬이 더 자주 나와요." if erasing else "대신 뺄 룬을 하나 누르세요. 석판의 칸은 모두 이 묶음에서 뽑혀요."
	var field: Rect2 = _open_choice(title, note, tint.lightened(0.35))
	var mid: float = field.size.x / 2.0
	var odds: String = ""
	if erasing:
		GameTheme.place(_reward_overlay, Icons.new("erase", tint), Rect2(mid - 38, 194, 76, 76))
		odds = "지금 %d장 → 빼면 %d장 (가장 적게는 %d장까지)" % [slab.size(), slab.size() - 1, int(controller.data["slot"]["slab"].get("minSize", 0))]
	else:
		GameTheme.glow(_reward_overlay, Vector2(mid, 232), 80.0, Color(tint, 0.5))
		GameTheme.place(_reward_overlay, Marks.new(rune), Rect2(mid - 34, 198, 68, 68))
		var have: int = slab.count(rune)
		odds = "지금 %s 룬 %d칸 → 넣으면 %d칸 (칸마다 %d%%)" % [rune_name, have, have + 1, roundi((have + 1) * 100.0 / maxf(1.0, slab.size()))]
	GameTheme.heading(_reward_overlay, Rect2(0, 274, field.size.x, 28), odds, 18, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var order: Array = GameData.active_elements(controller.data) + ["gold", "wild"]
	var cells: Array = range(slab.size())
	cells.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = order.find(slab[a])
		var rb: int = order.find(slab[b])
		return ra < rb if ra != rb else a < b)
	var per_row: int = 9
	var tile: float = 62.0
	var stride: float = 72.0
	var left: float = mid - (per_row * stride - (stride - tile)) / 2.0
	var top: float = 322.0
	for k: int in range(cells.size()):
		var index: int = cells[k]
		var symbol: String = slab[index]
		var rect: Rect2 = Rect2(left + (k % per_row) * stride, top + (k / per_row) * 86.0, tile, tile)
		var button: Button = GameTheme.button(_reward_overlay, rect, "", controller.dispatch.bind({"type": "replaceRune", "index": index}),
			Color("#1a1822"), GameTheme.COLOR.get(symbol, GameTheme.GOLD), 2)
		GameTheme.place(button, Marks.new(symbol), Rect2(9, 9, tile - 18, tile - 18))
		var symbol_name: String = GameTheme.SYMBOL_LABEL.get(symbol, symbol)
		button.tooltip_text = "%s 룬을 빼요" % symbol_name if erasing else "%s 룬을 빼고 %s 룬을 넣어요" % [symbol_name, rune_name]
		if symbol == rune:
			button.disabled = true
			button.modulate = Color(0.42, 0.42, 0.42)
			button.tooltip_text = "이미 %s 룬이에요" % rune_name
		GameTheme.label(_reward_overlay, Rect2(rect.position.x - 5, rect.position.y + tile + 1, tile + 10, 18), symbol_name, 12, GameTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var rows: int = (cells.size() + per_row - 1) / per_row
	GameTheme.cta(_reward_overlay, Rect2(mid - 120, top + rows * 86.0 + 10, 240, 46), "그대로 두기", controller.dispatch.bind({"type": "skipRune"}), "mystic", 18)


## 보상 · 유물 · 갈림길이 함께 쓰는 선택 화면 바탕과 제목.
func _open_choice(heading: String, note: String, tint: Color) -> Rect2:
	var field: Rect2 = _areas["field"]
	_reward_overlay = Control.new()
	_reward_overlay.z_index = 70
	GameTheme.place(self, _reward_overlay, field)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	GameTheme.place(_reward_overlay, dim, Rect2(Vector2.ZERO, field.size))
	GameTheme.glow(_reward_overlay, Vector2(field.size.x / 2.0, 150), 360.0, Color(tint, 0.2))
	GameTheme.heading(_reward_overlay, Rect2(0, 96, field.size.x, 50), heading, 34, tint, HORIZONTAL_ALIGNMENT_CENTER, 800)
	GameTheme.divider(_reward_overlay, Rect2(field.size.x / 2.0 - 220, 148, 440, 8), tint)
	if not note.is_empty():
		GameTheme.label(_reward_overlay, Rect2(0, 160, field.size.x, 24), note, 15, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	return field


## 선택 카드 한 장: 위에 그림 자리, 가운데 이름, 아래 설명. 돌려주는 값은 카드(그림은 호출한 쪽이 얹는다).
## action을 주면 명령을 보내는 대신 그 함수를 부른다.
func _choice_card(index: int, count: int, field: Rect2, command: Dictionary, tint: Color, title: String, body: String, height: float = 262.0, action: Callable = Callable()) -> Button:
	var card_w: float = 232.0
	var gap: float = 22.0
	var total: float = count * card_w + (count - 1) * gap
	var rect: Rect2 = Rect2((field.size.x - total) / 2.0 + index * (card_w + gap), 198, card_w, height)
	var card: Button = GameTheme.button(_reward_overlay, rect, "", action if action.is_valid() else controller.dispatch.bind(command), Color("#1a1822"), tint, 2)
	for state: String in ["normal", "hover", "pressed"]:
		var box: StyleBox = card.get_theme_stylebox(state)
		box.set("kind", "frame")
		box.get("base").set("shadow_color", Color(0, 0, 0, 0.6))
		box.get("base").set("shadow_size", 14)
		box.get("base").set("shadow_offset", Vector2(0, 6))
		box.get("base").set_corner_radius_all(12)
	GameTheme.glow(card, Vector2(card_w / 2.0, 78), 92.0, Color(tint, 0.28))
	GameTheme.heading(card, Rect2(8, 140, card_w - 16, 30), title, 21, GameTheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	GameTheme.divider(card, Rect2(40, 172, card_w - 80, 8), Color(tint, 0.8))
	var detail: Label = GameTheme.label(card, Rect2(16, 184, card_w - 32, 48), body, 14, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	GameTheme.wrap(detail)
	card.pivot_offset = rect.size / 2.0
	card.scale = Vector2(0.8, 0.8)
	card.modulate.a = 0.0
	var pop: Tween = card.create_tween().set_parallel()
	pop.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(index * 0.08)
	pop.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(index * 0.08)
	return card


func _reward_preview(reward: Dictionary, detail: Variant) -> String:
	var amount: int = reward["amount"]
	match reward["kind"]:
		"mana": return "마력 +%d" % amount
		"egg", "t2egg": return _dragon_name(detail) + " 알을 받아요" if detail != null else "드래곤 알을 받아요"
		"trait": return "드래곤 하나가 새 계승 특성을 얻어요"
		"nudge": return "다음 웨이브에 밀기 +%d" % amount
		"freeSpin": return "다시 돌리기 %d회 무료" % amount
		"transmute": return "드래곤 하나를 다른 원소의 같은 용으로 바꿔요 (성공 %d%%)" % int(controller.data["waves"].get("transmute", {}).get("successPct", 100))
		"rune": return "내 석판의 룬 하나를 %s 룬으로 바꿔요" % GameTheme.SYMBOL_LABEL.get(detail, "새") if detail != null else "마력 +3"
		"erase":
			var least: int = int(controller.data["slot"].get("slab", {}).get("minSize", 0))
			return "내 석판에서 룬 하나를 빼요. 남은 룬이 더 자주 나와요" if controller.state.get("slab", []).size() > least else "묶음을 더 줄일 수 없어요. 마력 +3"
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
		"transmute": return "전환의 룬 +%d · 드래곤을 눌러서 써요" % amount
		"rune": return "%s 룬 · 석판의 어느 룬과 바꿀지 골라요" % GameTheme.SYMBOL_LABEL.get(detail, "새") if detail != null else "마력 +3"
		"erase": return "석판에서 뺄 룬을 골라요" if controller.state.get("runePending") == "erase" else "묶음을 더 줄일 수 없어서 마력 +3"
		_: return "생명 +%d (가득 차 있으면 마력 +3)" % amount


func _dragon_name(id: String) -> String:
	var spec: Dictionary = controller.data["dragons"].get(id, {})
	return spec.get("nameKo", id)


func _notice(parent: Control, rect: Rect2, message: String, pixels: int, tint: Color, outline: Color, width: int, depth: int) -> Label:
	var label: Label = GameTheme.label(parent, rect, message, pixels, tint, HORIZONTAL_ALIGNMENT_CENTER)
	if pixels >= 30:
		label.add_theme_font_override("font", GameTheme.serif_font(800))
	## 글 뒤에 양옆이 흐려지는 어두운 띠를 깔아 배경 위에서도 읽히게 한다.
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.02, 0.04, 0.78), Color(0.02, 0.02, 0.04, 0.78), Color(0, 0, 0, 0)])
	var strip: GradientTexture2D = GradientTexture2D.new()
	strip.gradient = fade
	strip.width = 256
	strip.height = 4
	var ribbon: TextureRect = TextureRect.new()
	ribbon.texture = strip
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.show_behind_parent = true
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band: float = minf(rect.size.y, pixels * 2.9)
	GameTheme.place(label, ribbon, Rect2(0, (rect.size.y - band) / 2.0, rect.size.x, band))
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
