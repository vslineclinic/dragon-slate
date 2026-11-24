extends TestCase
## 전환의 룬: 용을 같은 등급·같은 형태의 다른 원소 용으로 바꾼다. 실패하면 룬만 사라지고 다음 시도는 반드시 성공한다.

const RunRules = preload("res://godot/core/run.gd")

var _data: Dictionary = GameData.load_all()


func _state(species: String, charges: int = 1, seed: int = 1) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state["phase"] = "manage"
	state["nest"][0] = {
		"uid": 1, "speciesId": species, "traits": ["tr_fire_wyvern"], "bonusPct": 7, "skills": {"fang": 2}, "skillPoints": 1,
		"level": 4, "xp": 3,
	}
	state["nextUid"] = 2
	state["items"] = {"transmute": charges}
	return state


func _cmd(element: String, index: int = 0) -> Dictionary:
	return {"type": "transmute", "at": {"zone": "nest", "index": index}, "element": element}


func _rejected(state: Dictionary, cmd: Dictionary) -> String:
	var result: Dictionary = RunRules.apply_command(_data, state, cmd)
	if result["events"].size() == 1 and result["events"][0]["t"] == "rejected":
		assert_true(result["state"] == state, "거절하면 상태를 바꾸지 않는다")
		return result["events"][0]["reason"]
	return ""


## 성공할 때까지 씨앗을 바꿔 가며 한 번 시도한 결과(성공 여부 want).
func _attempt(species: String, element: String, want: bool) -> Dictionary:
	for seed: int in range(1, 200):
		var result: Dictionary = RunRules.apply_command(_data, _state(species, 1, seed), _cmd(element))
		for event: Dictionary in result["events"]:
			if event["t"] == "transmuted" and event["ok"] == want:
				return result
	return {}


func test_every_convertible_dragon_has_a_twin_with_the_same_role_and_stats() -> void:
	var checked: int = 0
	for spec: Dictionary in _data["dragons"].values():
		if spec["tier"] in ["dual", "secret"]:
			assert_eq(RunRules.transmute_target(_data, spec["id"], "ice"), "", spec["id"])
			continue
		for element: String in GameData.active_elements(_data):
			var twin_id: String = RunRules.transmute_target(_data, spec["id"], element)
			if element == spec["elements"][0]:
				assert_eq(twin_id, "", "같은 원소로는 못 바꾼다")
				continue
			var twin: Dictionary = _data["dragons"].get(twin_id, {})
			assert_eq(twin.get("tier"), spec["tier"], spec["id"])
			assert_eq(twin.get("elements", [null])[0], element, spec["id"])
			assert_eq(twin.get("role"), spec["role"], spec["id"] + " → " + twin_id)
			assert_eq(twin.get("stats"), spec["stats"], spec["id"] + " → " + twin_id)
			checked += 1
	assert_true(checked >= 150 * 5, "전환할 수 있는 용이 150종 이상")


func test_twin_mapping_is_a_round_trip() -> void:
	var there: String = RunRules.transmute_target(_data, "fafnir", "abyss")
	assert_eq(RunRules.transmute_target(_data, there, "fire"), "fafnir")


func test_success_changes_species_and_keeps_growth() -> void:
	var result: Dictionary = _attempt("fire_drake", "ice", true)
	assert_true(not result.is_empty(), "성공하는 씨앗이 있다")
	if result.is_empty():
		return
	var inst: Dictionary = result["state"]["nest"][0]
	assert_eq(inst["speciesId"], "ice_drake")
	assert_eq([inst["uid"], inst["level"], inst["xp"], inst["bonusPct"], inst["skillPoints"]], [1, 4, 3, 7, 1])
	assert_eq(inst["traits"], ["tr_fire_wyvern"])
	assert_eq(inst["skills"], {"fang": 2})
	assert_eq(result["state"]["items"]["transmute"], 0)
	assert_eq(int(result["state"].get("transmuteFails", 0)), 0)
	assert_true("ice_drake" in result["state"]["discovered"])


func test_failure_keeps_the_dragon_and_guarantees_the_next_try() -> void:
	var result: Dictionary = _attempt("fire_drake", "ice", false)
	assert_true(not result.is_empty(), "실패하는 씨앗이 있다")
	if result.is_empty():
		return
	var state: Dictionary = result["state"]
	assert_eq(state["nest"][0]["speciesId"], "fire_drake")
	assert_eq(state["items"]["transmute"], 0)
	assert_eq(int(state["transmuteFails"]), 1)
	assert_eq(RunRules.transmute_chance(_data, state), 100)
	state["items"]["transmute"] = 1
	var again: Dictionary = RunRules.apply_command(_data, state, _cmd("steel"))
	assert_eq(again["state"]["nest"][0]["speciesId"], "steel_drake")
	assert_eq(int(again["state"]["transmuteFails"]), 0)


func test_success_rate_matches_the_data() -> void:
	var cfg: Dictionary = _data["waves"]["transmute"]
	assert_eq(RunRules.transmute_chance(_data, _state("fire_drake")), int(cfg["successPct"]))
	var wins: int = 0
	for seed: int in range(1, 401):
		var result: Dictionary = RunRules.apply_command(_data, _state("fire_drake", 1, seed), _cmd("ice"))
		if result["state"]["nest"][0]["speciesId"] == "ice_drake":
			wins += 1
	var expected: int = 400 * int(cfg["successPct"]) / 100
	assert_true(absi(wins - expected) <= 30, "400번 중 %d번 성공(기대 %d)" % [wins, expected])
	assert_true(wins < 400, "실패도 있어야 한다")


func test_rejections_cost_nothing() -> void:
	assert_eq(_rejected(_state("fire_drake", 0), _cmd("ice")), "noItem")
	assert_eq(_rejected(_state("fire_drake"), _cmd("fire")), "sameElement")
	assert_eq(_rejected(_state("fire_drake"), _cmd("water")), "cannotTransmute")
	assert_eq(_rejected(_state("fire_drake"), _cmd("ice", 1)), "emptySlot")
	var battle: Dictionary = _state("fire_drake")
	battle["phase"] = "reward"
	assert_eq(_rejected(battle, _cmd("ice")), "wrongPhase")
	var dual_id: String = ""
	for spec: Dictionary in _data["dragons"].values():
		if spec["tier"] == "dual":
			dual_id = spec["id"]
			break
	assert_eq(_rejected(_state(dual_id), _cmd("ice")), "cannotTransmute")


func test_reward_card_gives_a_charge() -> void:
	var reward: Variant = null
	for row: Dictionary in _data["rewards"]:
		if row["kind"] == "transmute":
			reward = row
	assert_true(reward != null, "보상 목록에 전환의 룬이 있다")
	if reward == null:
		return
	var state: Dictionary = RunRules.create_run(_data, 3)["state"]
	state["phase"] = "reward"
	state["nest"][0] = {"uid": 1, "speciesId": "fire_drake", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}
	state["rewardChoices"] = [{"reward": reward, "detail": null}]
	var result: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseReward", "index": 0})
	assert_eq(int(result["state"]["items"]["transmute"]), int(reward["amount"]))


func test_first_boss_win_grants_a_charge() -> void:
	var waves: Array = _data["waves"]["transmute"]["grantAfterWaves"]
	assert_true(5 in waves)
	var state: Dictionary = RunRules.create_run(_data, 5)["state"]
	state["phase"] = "manage"
	state["wave"] = 5
	## 반드시 이기도록 아주 센 용 하나.
	state["nest"][0] = {"uid": 1, "speciesId": "fire_god", "traits": [], "bonusPct": 5000, "skills": {}, "skillPoints": 0, "level": 20, "xp": 0}
	var result: Dictionary = RunRules.apply_command(_data, state, {"type": "startBattle"})
	var gained: bool = false
	for event: Dictionary in result["events"]:
		gained = gained or (event["t"] == "item" and event["id"] == "transmute")
	assert_true(gained, "첫 심판 보스를 이기면 룬을 하나 받는다")
	assert_eq(int(result["state"]["items"]["transmute"]), 1)
