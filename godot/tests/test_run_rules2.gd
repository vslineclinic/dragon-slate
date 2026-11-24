extends TestCase
## 새는 적, 전투 준비 미리 보기, 수동 궁극기 기록, 졸병 종류, 데려온 용, 저주.

const RunRules = preload("res://godot/core/run.gd")

var _data: Dictionary = GameData.load_all()


static func _inst(uid: int, species: String, level: int = 1, bonus: int = 0) -> Dictionary:
	return {"uid": uid, "speciesId": species, "traits": [], "bonusPct": bonus, "skills": {}, "skillPoints": 0, "level": level, "xp": 0}


func _manage(seed: int, wave: int, species: String, bonus: int = 0) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state["phase"] = "manage"
	state["wave"] = wave
	state["nest"][0] = _inst(1, species, 10, bonus)
	state["nextUid"] = 2
	return state


func test_leak_takes_more_lives_when_more_enemies_survive() -> void:
	var waves: Dictionary = {"lossLife": 1, "bossLossLife": 2, "leak": {"minion": 1, "leader": 4, "perLife": 5, "max": 3}}
	assert_eq(RunRules.leak_lives(waves, {"leaders": 0, "minions": 1}, false), 1)
	assert_eq(RunRules.leak_lives(waves, {"leaders": 0, "minions": 5}, false), 1)
	assert_eq(RunRules.leak_lives(waves, {"leaders": 0, "minions": 6}, false), 2)
	assert_eq(RunRules.leak_lives(waves, {"leaders": 1, "minions": 3}, false), 2)
	assert_eq(RunRules.leak_lives(waves, {"leaders": 3, "minions": 20}, false), 3, "한 번에 잃는 생명에는 한도가 있다")
	assert_eq(RunRules.leak_lives(waves, {"leaders": 0, "minions": 1}, true), 2, "보스전은 적어도 2")
	assert_eq(RunRules.leak_lives({"lossLife": 1, "bossLossLife": 2}, {"leaders": 3, "minions": 20}, false), 1, "자료가 없으면 예전처럼")


func test_losing_a_battle_uses_the_leak_and_reports_it() -> void:
	var state: Dictionary = _manage(3, 9, "fire_drake")
	var result: Dictionary = RunRules.apply_command(_data, state, {"type": "startBattle"})
	var lives: Dictionary = {}
	var left: Dictionary = {}
	for event: Dictionary in result["events"]:
		if event["t"] == "lives":
			lives = event
		elif event["t"] == "battle":
			left = event["result"]["left"]
	assert_true(not lives.is_empty(), "레벨 10 기본 용 한 마리로는 9웨이브를 못 이긴다")
	if lives.is_empty():
		return
	assert_eq(int(lives["lost"]), RunRules.leak_lives(_data["waves"], left, false))
	assert_eq(int(result["state"]["lives"]), int(state["lives"]) - int(lives["lost"]))
	assert_eq(int(result["state"]["livesLost"]), int(lives["lost"]))


func test_battle_setup_previews_the_real_battle_without_touching_the_state() -> void:
	var state: Dictionary = _manage(11, 6, "fire_god", 400)
	var before: String = RunRules.state_hash(state)
	var setup: Dictionary = RunRules.battle_setup(_data, state)
	assert_eq(RunRules.state_hash(state), before)
	var mine: Dictionary = Battle.simulate_battle(_data["battle"], setup["allies"], setup["enemies"], setup["rules"])
	var real: Dictionary = {}
	for event: Dictionary in RunRules.apply_command(_data, state, {"type": "startBattle"})["events"]:
		if event["t"] == "battle":
			real = event["result"]
	assert_eq(mine["events"], real["events"])
	assert_eq(RunRules.battle_setup(_data, RunRules.create_run(_data, 1)["state"]), {}, "둥지가 비면 준비할 전투가 없다")


func test_manual_battle_is_replayed_from_the_recorded_ultimates() -> void:
	var state: Dictionary = _manage(12, 6, "fire_god", 400)
	var setup: Dictionary = RunRules.battle_setup(_data, state, true)
	assert_true(setup["rules"].get("manualUlt", false))
	var sim: Dictionary = Battle.begin_battle(_data["battle"], setup["allies"], setup["enemies"], setup["rules"])
	var record: Dictionary = {}
	var guard: int = 0
	while not Battle.battle_over(sim) and guard < 10000:
		guard += 1
		var arm: Array = Battle.ready_ults(sim)
		if not arm.is_empty():
			record[int(sim["tick"]) + 1] = arm
		Battle.step_battle(sim, arm)
	var played: Dictionary = Battle.battle_result(sim)
	assert_true(not record.is_empty(), "궁극기를 한 번은 쐈다")
	## 저장 글(JSON)을 거치면 틱이 문자열 열쇠가 된다: 그래도 같아야 한다.
	var as_json: Dictionary = JSON.parse_string(JSON.stringify(record))
	var real: Dictionary = {}
	for event: Dictionary in RunRules.apply_command(_data, state, {"type": "startBattle", "manual": true, "ults": as_json})["events"]:
		if event["t"] == "battle":
			real = event["result"]
	assert_eq(real["winner"], played["winner"])
	assert_eq(real["events"], played["events"])


func test_minion_types_in_the_preview_match_the_battle() -> void:
	var seen: Dictionary = {}
	for seed: int in [1, 4, 8]:
		for wave: int in range(1, 21):
			var enemies: Array = Waves.generate_enemies(_data, wave, Rng.new(seed + wave), seed)
			var preview: Array = Waves.lane_preview(_data, seed, wave)
			var counted: Array = [{}, {}, {}]
			for enemy: Dictionary in enemies:
				if enemy["kind"] == "minion" and not str(enemy["type"]).is_empty():
					counted[int(enemy["lane"])][enemy["type"]] = int(counted[int(enemy["lane"])].get(enemy["type"], 0)) + 1
					seen[enemy["type"]] = true
			for lane: int in range(3):
				assert_eq(preview[lane]["types"], counted[lane], "씨앗 %d 웨이브 %d 줄 %d" % [seed, wave, lane])
	assert_eq(seen.size(), 3, "방패병 · 돌격병 · 궁병이 모두 나온다")
	var first: Array = Waves.generate_enemies(_data, 1, Rng.new(1), 1)
	assert_true(first.all(func(e: Dictionary) -> bool: return e["kind"] != "minion" or str(e["type"]).is_empty()), "1웨이브는 보통 졸병뿐")


func test_minion_types_change_stats_and_archers_have_reach() -> void:
	var types: Dictionary = {}
	for row: Dictionary in _data["waves"]["squad"]["minionTypes"]:
		types[row["id"]] = row
	assert_true(int(types["guard"]["hpPct"]) > 100 and int(types["runner"]["speedPct"]) > 100 and int(types["archer"]["reach"]) > 0)
	for seed: int in range(1, 20):
		for enemy: Dictionary in Waves.generate_enemies(_data, 12, Rng.new(seed), seed):
			if enemy["kind"] == "minion":
				assert_eq(int(enemy["reach"]), int(types.get(enemy["type"], {}).get("reach", 0)))


func test_a_carried_dragon_starts_on_the_bench_at_level_one_with_its_traits() -> void:
	var carry: Dictionary = {"speciesId": "fire_god", "traits": ["tr_fire_wyvern", "no_such_trait", "tr_fire_drake", "tr_ice_drake"]}
	var state: Dictionary = RunRules.create_run(_data, 5, 0, "", carry)["state"]
	var inst: Dictionary = state["bench"][0]
	assert_eq([inst["speciesId"], inst["level"], inst["xp"], inst["skills"], inst["skillPoints"]], ["fire_god", 1, 0, {}, 0])
	assert_eq(inst["traits"], ["tr_fire_wyvern", "tr_fire_drake"], "아는 특성만, 한도까지")
	assert_eq(state["carry"], "fire_god")
	## 시작 묶음의 용과 함께 올 수 있다.
	var option: Dictionary = RunRules.start_options(_data, 5)[0]
	var both: Dictionary = RunRules.create_run(_data, 5, 0, option["id"], carry)["state"]
	assert_eq([both["bench"][0]["speciesId"], both["bench"][1]["speciesId"]], ["fire_god", option["speciesId"]])
	assert_eq(RunRules.create_run(_data, 5, 0, "", {"speciesId": "nope"})["state"]["bench"], [null, null, null, null])


func test_pact_makes_every_later_enemy_stronger_and_offers_a_relic() -> void:
	var state: Dictionary = RunRules.create_run(_data, 6)["state"]
	state["phase"] = "fork"
	state["forkChoices"] = ["elite", "rest", "merchant", "pact"]
	state["nest"][0] = _inst(1, "fire_drake")
	var done: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseFork", "option": "pact"})["state"]
	assert_eq(int(done["cursePct"]), int(_data["waves"]["fork"]["pactPowerPct"]))
	assert_eq(done["phase"], "relic")
	done["phase"] = "manage"
	var cursed: Dictionary = RunRules.battle_setup(_data, done)
	state["phase"] = "manage"
	var plain: Dictionary = RunRules.battle_setup(_data, state)
	var cursed_hp: int = 0
	var plain_hp: int = 0
	for enemy: Dictionary in cursed["enemies"]:
		cursed_hp += int(enemy["hp"])
	for enemy: Dictionary in plain["enemies"]:
		plain_hp += int(enemy["hp"])
	assert_true(cursed_hp > plain_hp, "저주를 받으면 적이 더 세다: %d > %d" % [cursed_hp, plain_hp])
