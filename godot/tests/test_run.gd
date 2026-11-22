extends TestCase

const RunRules = preload("res://godot/core/run.gd")
const F: String = "fire"
const I: String = "ice"
const L: String = "lightning"
const G: String = "gold"
const SPECIES: Dictionary = {F: "fire_drake", I: "ice_drake", L: "storm_drake", "wild": "fire_drake"}

var _data: Dictionary = _unit_test_data()


func test_create_run_previews_first_boss() -> void:
	var result: Dictionary = RunRules.create_run(_data, 9)
	_assert_fields(result["state"], {"wave": 1, "phase": "spin", "lives": 5, "mana": 3, "nestOpen": 3})
	assert_eq(result["events"], [_wave_start(9, 1)])


func test_pick_before_spin_returns_same_state() -> void:
	_assert_rejected(_fresh(), {"type": "pick", "index": 0}, "wrongPhase")


func test_first_spin_is_free_and_second_costs_two() -> void:
	var start: Dictionary = _owning()
	assert_eq(RunRules.spin_cost(_data, start), 0)
	var first: Dictionary = _apply(start, {"type": "spin"})["state"]
	_assert_fields(first, {"mana": 3, "phase": "pick"})
	_assert_fields(start, {"phase": "spin", "grid": null, "log": []})
	assert_eq(RunRules.spin_cost(_data, first), 2)
	var second: Dictionary = _apply(first, {"type": "spin"})["state"]
	assert_eq(second["mana"], 1)
	first["freeSpins"] = 1
	assert_eq(RunRules.spin_cost(_data, first), 0)
	var free: Dictionary = _apply(first, {"type": "spin"})["state"]
	_assert_fields(free, {"mana": 3, "freeSpins": 0})


func test_reroll_rejected_without_mana() -> void:
	var state: Dictionary = _apply(_owning(), {"type": "spin"})["state"]
	state = _apply(state, {"type": "spin"})["state"]
	_assert_rejected(state, {"type": "spin"}, "notEnoughMana")


func test_nudge_only_once_per_wave() -> void:
	var state: Dictionary = _apply(_fresh(), {"type": "spin"})["state"]
	var nudged: Dictionary = _apply(state, {"type": "nudge", "col": 1, "dir": 1})["state"]
	assert_eq(nudged["grid"]["offsets"], [0, 1, 0])
	_assert_rejected(nudged, {"type": "nudge", "col": 0, "dir": 1}, "noNudgeLeft")


func test_bonus_eggs_convert_to_mana_when_bench_is_full() -> void:
	var state: Dictionary = _fresh({
		"phase": "pick", "grid": _grid([[F, F, F], [I, L, I], [L, I, L]]),
		"bench": [_inst(1, "fire_drake"), _inst(2, "fire_drake"), _inst(3, "fire_drake"), null], "nextUid": 4,
	})
	var result: Dictionary = _apply(state, {"type": "pick", "index": 0})
	assert_eq(result["state"]["bench"][3]["speciesId"], "ice_drake")
	_assert_fields(result["state"], {"mana": 6, "phase": "manage", "grid": null})
	assert_true({"t": "mana", "delta": 1, "reason": "benchFull"} in result["events"])
	assert_eq(state["bench"][3], null)


func test_pick_rejected_when_bench_full() -> void:
	var state: Dictionary = _fresh({
		"phase": "pick", "grid": _grid([[I, L, I], [F, I, L], [L, F, F]]), "bench": _full_bench(),
	})
	_assert_rejected(state, {"type": "pick", "index": 0}, "benchFull")


func test_two_lines_of_one_element_give_a_t2_egg() -> void:
	var state: Dictionary = _fresh({"phase": "pick", "grid": _grid([[F, F, F], [F, L, I], [F, I, L]])})
	var result: Dictionary = _apply(state, {"type": "pick", "index": 1})
	var bonus: Array = result["events"].filter(func(event: Dictionary) -> bool:
		return event["t"] == "gained" and event["via"] == "bonus"
	)
	assert_eq(bonus.size(), 1)
	if not bonus.is_empty():
		assert_eq(_data["dragons"][bonus[0]["inst"]["speciesId"]]["tier"], "t2")


func test_battle_rejected_when_nest_empty() -> void:
	_assert_rejected(_fresh({"phase": "manage"}), {"type": "startBattle"}, "nestEmpty")


func test_spin_rejected_during_battle_phase() -> void:
	_assert_rejected(_fresh({"phase": "battle"}), {"type": "spin"}, "wrongPhase")


func test_move_and_merge_reject_locked_nest_slot() -> void:
	var state: Dictionary = _owning()
	state["phase"] = "manage"
	var bench: Dictionary = _ref("bench", 0)
	var locked: Dictionary = _ref("nest", 4)
	_assert_rejected(state, {"type": "move", "from": bench, "to": locked}, "slotLocked")
	state["nest"][4] = _inst(2, "fire_drake")
	_assert_rejected(state, {"type": "merge", "main": locked, "material": bench}, "slotLocked")


func test_first_evolution_marks_discovered_once() -> void:
	var state: Dictionary = _fresh({"phase": "manage", "bench": _full_bench(), "nextUid": 5})
	var first: Dictionary = _apply(state, {"type": "merge", "main": _ref("bench", 0), "material": _ref("bench", 1)})
	_assert_fields(first["events"][0], {"t": "evolved", "firstTime": true})
	assert_eq(first["state"]["bench"][0]["speciesId"], "beowulf_firedrake")
	assert_eq(first["state"]["bench"][1], null)
	var second: Dictionary = _apply(first["state"], {
		"type": "merge", "main": _ref("bench", 2), "material": _ref("bench", 3),
	})
	_assert_fields(second["events"][0], {"t": "evolved", "firstTime": false})
	assert_eq(second["state"]["discovered"], ["beowulf_firedrake"])


func test_release_gives_mana_by_tier() -> void:
	var state: Dictionary = _owning()
	state["phase"] = "manage"
	state["bench"][1] = _inst(1, "fafnir")
	var result: Dictionary = _apply(state, {"type": "release", "from": _ref("bench", 1)})
	assert_eq(result["state"]["mana"], 5)
	assert_eq(result["state"]["bench"][1], null)


func test_boss_loss_costs_two_lives_and_unlocks_nest() -> void:
	var state: Dictionary = _weak_nest(5)
	var result: Dictionary = _apply(state, {"type": "startBattle"})
	_assert_fields(result["state"], {"lives": 3, "nestOpen": 4, "wave": 6, "phase": "spin"})
	assert_true(_wave_start(state["seed"], 6) in result["events"])


func test_zero_lives_ends_run() -> void:
	var state: Dictionary = _weak_nest(4)
	state["lives"] = 1
	var result: Dictionary = _apply(state, {"type": "startBattle"})
	assert_eq(result["state"]["phase"], "gameOver")
	assert_true({"t": "gameOver"} in result["events"])


func test_final_wave_win_ends_in_victory() -> void:
	var state: Dictionary = _fresh({
		"wave": _data["waves"]["maxWave"], "phase": "manage", "nestOpen": 5,
		"nest": [_inst(1, "tiamat", 5000), _inst(2, "tiamat", 5000), _inst(3, "tiamat", 5000), null, null, null],
	})
	var result: Dictionary = _apply(state, {"type": "startBattle"})
	assert_eq(result["state"]["phase"], "victory")
	assert_true({"t": "victory"} in result["events"])


func test_replaying_accepted_commands_is_deterministic() -> void:
	var a: Dictionary = _play_script(_fresh({}, 77))
	var b: Dictionary = _play_script(_fresh({}, 77))
	assert_eq(RunRules.state_hash(a), RunRules.state_hash(b))
	var replay: Dictionary = _fresh({}, 77)
	for cmd: Dictionary in a["log"]:
		replay = _apply(replay, cmd)["state"]
	assert_eq(RunRules.state_hash(replay), RunRules.state_hash(a))
	assert_true(a["log"].size() > 10)
	replay["log"].clear()
	assert_eq(RunRules.state_hash(replay), RunRules.state_hash(a))


func test_bench_can_be_cleared_during_pick() -> void:
	var state: Dictionary = _fresh({
		"phase": "pick", "grid": _grid([[I, L, I], [F, I, L], [L, F, F]]),
		"bench": [_inst(1, "fire_drake"), _inst(2, "fire_wyvern"), _inst(3, "ice_drake"), _inst(4, "ice_wyvern")],
	})
	state["nest"][0] = _inst(5, "storm_drake")
	var result: Dictionary = _apply(state, {"type": "release", "from": _ref("bench", 0)})
	assert_eq(result["events"], [{"t": "mana", "delta": _data["waves"]["releaseMana"]["base"], "reason": "release"}])
	assert_eq(result["state"]["phase"], "pick")
	assert_eq(_apply(result["state"], {"type": "pick", "index": 0})["state"]["phase"], "manage")


func test_mana_pick_rejected_if_it_leaves_no_dragons() -> void:
	var state: Dictionary = _fresh({"phase": "pick", "grid": _grid([[I, L, I], [F, G, L], [L, F, F]])})
	_assert_rejected(state, {"type": "pick", "index": 1}, "needDragon")


func test_releasing_last_dragon_is_rejected() -> void:
	_assert_rejected(_owning(), {"type": "release", "from": _ref("bench", 0)}, "needDragon")


func test_log_keeps_a_copy_of_each_command() -> void:
	var cmd: Dictionary = {"type": "move", "from": _ref("bench", 0), "to": _ref("nest", 0)}
	var state: Dictionary = _apply(_owning(), cmd)["state"]
	cmd["to"]["index"] = 1
	assert_eq(state["log"], [{"type": "move", "from": _ref("bench", 0), "to": _ref("nest", 0)}])


func test_fractional_slot_index_is_rejected() -> void:
	_assert_rejected(_owning(), {"type": "move", "from": _ref("bench", 0), "to": _ref("nest", 0.5)}, "emptySlot")


func test_arranging_is_allowed_before_spinning() -> void:
	var start: Dictionary = _owning()
	var result: Dictionary = _apply(start, {"type": "move", "from": _ref("bench", 0), "to": _ref("nest", 0)})
	assert_eq(result["events"], [])
	assert_eq(result["state"]["nest"][0], start["bench"][0])
	assert_eq(result["state"]["bench"][0], null)


func test_reroll_is_free_without_dragons() -> void:
	var state: Dictionary = _fresh({
		"phase": "pick", "mana": 0, "spinsThisWave": 2, "grid": _grid([[I, L, I], [F, I, L], [L, F, F]]),
	})
	var result: Dictionary = _apply(state, {"type": "spin"})
	_assert_fields(result["events"][0], {"t": "spun", "cost": 0})


func test_final_boss_loss_with_lives_left_retries_final_wave() -> void:
	var wave: int = _data["waves"]["maxWave"]
	var result: Dictionary = _apply(_weak_nest(wave), {"type": "startBattle"})
	_assert_fields(result["state"], {"wave": wave, "phase": "spin", "lives": 3})


func _play_script(state: Dictionary) -> Dictionary:
	for step: int in range(30):
		var cmd: Dictionary
		match state["phase"]:
			"spin":
				cmd = {"type": "spin"}
			"pick":
				cmd = {"type": "pick", "index": step % 3}
			"manage":
				var from: int = state["bench"].find_custom(func(inst: Variant) -> bool: return inst != null)
				var to: int = state["nest"].find(null)
				if from >= 0 and to >= 0 and to < state["nestOpen"]:
					cmd = {"type": "move", "from": _ref("bench", from), "to": _ref("nest", to)}
				else:
					cmd = {"type": "startBattle"}
			_:
				break
		state = _apply(state, cmd)["state"]
	return state


func _assert_rejected(state: Dictionary, cmd: Dictionary, reason: String) -> void:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = _apply(state, cmd)
	assert_eq(result["events"], [{"t": "rejected", "reason": reason}])
	assert_true(is_same(result["state"], state), "거절 시 입력 상태 객체를 반환해야 함")
	assert_eq(state, before, "거절 시 입력 상태를 보존해야 함")


func _assert_fields(actual: Dictionary, expected: Dictionary) -> void:
	for key: String in expected:
		assert_true(actual.has(key), key + " 키 누락")
		assert_eq(actual.get(key), expected[key], key)


func _weak_nest(wave: int) -> Dictionary:
	var state: Dictionary = _fresh({"phase": "manage", "wave": wave})
	state["nest"][0] = _inst(1, "fire_wyvern")
	return state


func _owning() -> Dictionary:
	return _fresh({"bench": [_inst(99, "fire_drake"), null, null, null]})


func _fresh(overrides: Dictionary = {}, seed: int = 1) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state.merge(overrides, true)
	return state


func _apply(state: Dictionary, cmd: Dictionary) -> Dictionary:
	return RunRules.apply_command(_data, state, cmd)


func _wave_start(seed: int, wave: int) -> Dictionary:
	var preview: Variant = Waves.boss_element(seed, wave + 4, GameData.active_elements(_data))
	return {"t": "waveStart", "wave": wave, "bossPreview": preview, "boss": null}


static func _unit_test_data() -> Dictionary:
	# TypeScript의 판 단위 테스트도 보상과 보스 사양을 넣지 않는다.
	var data: Dictionary = GameData.load_all()
	data["rewards"] = []
	data["bosses"] = []
	return data


static func _inst(uid: int, species_id: String, bonus_pct: int = 0) -> Dictionary:
	return {"uid": uid, "speciesId": species_id, "traits": [], "bonusPct": bonus_pct}


static func _ref(zone: String, index: Variant) -> Dictionary:
	return {"zone": zone, "index": index}


static func _full_bench() -> Array:
	return [_inst(1, "fire_drake"), _inst(2, "fire_drake"), _inst(3, "fire_drake"), _inst(4, "fire_drake")]


static func _grid(rows: Array) -> Dictionary:
	var reels: Array = []
	for col: int in range(3):
		var reel: Array = [{"symbol": G, "speciesId": null}]
		for row: int in range(3):
			var symbol: String = rows[row][col]
			reel.append({"symbol": symbol, "speciesId": SPECIES.get(symbol)})
		reel.append({"symbol": G, "speciesId": null})
		reels.append(reel)
	return {"reels": reels, "offsets": [0, 0, 0]}
