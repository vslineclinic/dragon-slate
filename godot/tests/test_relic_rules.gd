extends TestCase
## 규칙을 바꾸는 유물: 매의 눈(후열은 줄 감쇠 없음) · 쌍둥이 끌(룬 두 장 바꾸기) · 현자의 돌(전환 반드시 성공) · 여의주 왕관(여의주 줄에 2티어 알).

const RunRules = preload("res://godot/core/run.gd")
const Fixture = preload("res://godot/tests/test_slot.gd")
const B = preload("res://godot/tests/test_battle.gd")

var _data: Dictionary = GameData.load_all()


static func _inst(uid: int, species: String, level: int = 1, bonus: int = 0) -> Dictionary:
	return {"uid": uid, "speciesId": species, "traits": [], "bonusPct": bonus, "skills": {}, "skillPoints": 0, "level": level, "xp": 0}


func _relic(id: String) -> Dictionary:
	for relic: Dictionary in _data["relics"]:
		if relic["id"] == id:
			return relic
	return {}


func test_the_four_rule_relics_exist_with_copy() -> void:
	for id: String in ["hawkeye", "chisel", "philosopher", "crown"]:
		var relic: Dictionary = _relic(id)
		assert_true(not relic.is_empty(), id)
		assert_true(not str(relic.get("nameKo", "")).is_empty() and not str(relic.get("descKo", "")).is_empty(), id)


func test_hawkeye_lets_back_row_dragons_ignore_the_lane_penalty() -> void:
	var cfg: Dictionary = Fixture.mini_data()["battle"].duplicate(true)
	cfg["field"]["dragonSpeed"] = 3
	cfg["field"]["frontRange"] = 260
	cfg["field"]["backRange"] = 420
	cfg["field"]["leaderRange"] = 300
	cfg["field"]["crossLanePct"] = [100, 70, 50]
	var foe: Array = [B._enemy("dragon", "fire", 100000, 100, 10, 2, 400)]
	for row: int in range(2):
		var allies: Array = B._slots([B._solo("fire", 100000, 100)]) if row == 0 else B._slots([], [B._solo("fire", 100000, 100)])
		var plain: Dictionary = Battle.simulate_battle(cfg, allies, foe)
		var keen: Dictionary = Battle.simulate_battle(cfg, allies, foe, {"backRowNoLane": true})
		assert_eq(int(B._first_attack_from(plain, 0)["dmg"]), 50)
		assert_eq(int(B._first_attack_from(keen, 0)["dmg"]), 50 if row == 0 else 100, "전열은 그대로, 후열만 제 힘으로")
		assert_eq(int(B._first_attack_from(keen, 1)["dmg"]), 50, "적은 그대로 줄 감쇠를 받는다")


func test_hawkeye_reaches_the_battle_through_the_run() -> void:
	var lane_hits: Array = []
	for relics: Array in [[], ["hawkeye"]]:
		var state: Dictionary = RunRules.create_run(_data, 7)["state"]
		state["phase"] = "manage"
		state["wave"] = 6
		state["nestOpen"] = 6
		state["relics"] = relics
		state["nest"][4] = _inst(1, "fire_god", 20, 3000)
		var result: Dictionary = RunRules.apply_command(_data, state, {"type": "startBattle"})
		var count: int = 0
		for event: Dictionary in result["events"]:
			if event["t"] == "battle":
				for hit: Dictionary in event["result"]["events"]:
					if hit["kind"] == "attack" and hit["src"] == 0 and hit.has("lane"):
						count += 1
		lane_hits.append(count)
	assert_true(int(lane_hits[0]) > 0, "유물이 없으면 다른 줄을 칠 때 약해진다")
	assert_eq(int(lane_hits[1]), 0, "매의 눈이 있으면 후열 용은 약해지지 않는다")


func _rune_state(relics: Array) -> Dictionary:
	var reward: Dictionary = {}
	for row: Dictionary in _data["rewards"]:
		if row["kind"] == "rune":
			reward = row
	var state: Dictionary = RunRules.create_run(_data, 4)["state"]
	state["phase"] = "reward"
	state["relics"] = relics
	state["nest"][0] = _inst(1, "fire_drake")
	state["rewardChoices"] = [{"reward": reward, "detail": "fire"}]
	return RunRules.apply_command(_data, state, {"type": "chooseReward", "index": 0})["state"]


func test_chisel_lets_one_rune_card_replace_two_runes() -> void:
	var plain: Dictionary = RunRules.apply_command(_data, _rune_state([]), {"type": "replaceRune", "index": 2})["state"]
	assert_eq(plain["phase"], "spin")
	var first: Dictionary = RunRules.apply_command(_data, _rune_state(["chisel"]), {"type": "replaceRune", "index": 2})["state"]
	assert_eq([first["phase"], first["runePending"], first["slab"][2]], ["slab", "fire", "fire"])
	var second: Dictionary = RunRules.apply_command(_data, first, {"type": "replaceRune", "index": 4})["state"]
	assert_eq([second["phase"], second["runePending"], second["slab"][4]], ["spin", null, "fire"])
	assert_eq(second["slab"].count("fire"), _data["slot"]["slab"]["start"].count("fire") + 2)
	var stopped: Dictionary = RunRules.apply_command(_data, first, {"type": "skipRune"})["state"]
	assert_eq([stopped["phase"], stopped["runePending"]], ["spin", null])


func test_philosopher_makes_transmuting_certain_and_brings_a_rune() -> void:
	var state: Dictionary = RunRules.create_run(_data, 3)["state"]
	assert_true(RunRules.transmute_chance(_data, state) < 100)
	state["phase"] = "relic"
	state["relicChoices"] = ["philosopher"]
	var got: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseRelic", "index": 0})["state"]
	assert_eq(RunRules.transmute_chance(_data, got), 100)
	assert_eq(int(got["items"].get("transmute", 0)), 1)


func test_crown_turns_a_wild_line_into_a_second_tier_egg() -> void:
	var cell: Dictionary = {"symbol": "wild", "speciesId": "fire_drake"}
	var other: Dictionary = {"symbol": "gold", "speciesId": null}
	var reels: Array = []
	for col: int in range(3):
		reels.append([other, other, cell, other, other])
	var gained: Array = []
	for relics: Array in [[], ["crown"]]:
		var state: Dictionary = RunRules.create_run(_data, 5)["state"]
		state["phase"] = "pick"
		state["relics"] = relics
		state["grid"] = {"reels": reels, "offsets": [0, 0, 0]}
		var result: Dictionary = RunRules.apply_command(_data, state, {"type": "pick", "index": 0})
		var tiers: Array = []
		for event: Dictionary in result["events"]:
			if event["t"] == "gained" and event["via"] == "bonus":
				tiers.append(_data["dragons"][event["inst"]["speciesId"]]["tier"])
		gained.append(tiers)
	assert_eq(gained[0], [], "유물이 없으면 여의주 줄은 마력만 준다")
	assert_eq(gained[1], ["t2"], "여의주 왕관이 있으면 2티어 알도 온다")
