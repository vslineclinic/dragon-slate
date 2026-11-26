extends TestCase
## 단련: 마력을 내고 드래곤을 한 단계씩 올린다. 올라갈수록 확률이 내려가고, 실패하면 안전 단계로 내려간다(드래곤은 그대로).

const RunRules = preload("res://godot/core/run.gd")
const FusionRules = preload("res://godot/core/fusion.gd")
const Ability = preload("res://godot/tests/test_ability.gd")
const B = preload("res://godot/tests/test_battle.gd")

var _data: Dictionary = GameData.load_all()


func _state(step: int = 0, mana: int = 50, seed: int = 1) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state["phase"] = "manage"
	state["mana"] = mana
	state["nest"][0] = {
		"uid": 1, "speciesId": "fire_raptor", "traits": [], "bonusPct": 0, "skills": {"fang": 1}, "skillPoints": 0,
		"level": 4, "xp": 3, "temper": step,
	}
	state["nextUid"] = 2
	return state


func _cmd(index: int = 0) -> Dictionary:
	return {"type": "temper", "at": {"zone": "nest", "index": index}}


func _reason(state: Dictionary, cmd: Dictionary) -> String:
	var result: Dictionary = RunRules.apply_command(_data, state, cmd)
	if result["events"].size() == 1 and result["events"][0]["t"] == "rejected":
		assert_true(result["state"] == state, "거절하면 상태를 바꾸지 않는다")
		return result["events"][0]["reason"]
	return ""


## 씨앗을 바꿔 가며 원하는 결과(성공 여부 want)가 나온 한 번의 시도.
func _attempt(step: int, want: bool) -> Dictionary:
	for seed: int in range(1, 300):
		var result: Dictionary = RunRules.apply_command(_data, _state(step, 50, seed), _cmd())
		for event: Dictionary in result["events"]:
			if event["t"] == "tempered" and event["ok"] == want:
				return result
	return {}


func test_data_has_one_cost_and_chance_per_step_and_chances_never_rise() -> void:
	var cfg: Dictionary = _data["battle"]["temper"]
	assert_eq(cfg["cost"].size(), cfg["chancePct"].size())
	for i: int in range(1, cfg["chancePct"].size()):
		assert_true(int(cfg["chancePct"][i]) <= int(cfg["chancePct"][i - 1]), "단계가 오르면 확률은 내려간다")
	for safe: Variant in cfg["safe"]:
		assert_true(int(safe) > 0 and int(safe) < cfg["cost"].size())


func test_first_step_always_succeeds_and_costs_mana() -> void:
	var result: Dictionary = RunRules.apply_command(_data, _state(0, 10), _cmd())
	var inst: Dictionary = result["state"]["nest"][0]
	assert_eq(inst["temper"], 1)
	assert_eq(result["state"]["mana"], 10 - int(_data["battle"]["temper"]["cost"][0]))
	assert_eq([inst["level"], inst["skills"], inst["speciesId"]], [4, {"fang": 1}, "fire_raptor"])


func test_rejections() -> void:
	assert_eq(_reason(_state(0, 1), _cmd()), "noMana")
	assert_eq(_reason(_state(9), _cmd()), "temperMax")
	assert_eq(_reason(_state(), _cmd(1)), "emptySlot")
	var fighting: Dictionary = _state()
	fighting["phase"] = "reward"
	assert_eq(_reason(fighting, _cmd()), "wrongPhase")


func test_failure_falls_to_the_last_safe_step_and_keeps_the_dragon() -> void:
	var result: Dictionary = _attempt(5, false)
	assert_true(not result.is_empty(), "실패하는 씨앗이 있다")
	var inst: Dictionary = result["state"]["nest"][0]
	assert_eq([inst["temper"], inst["temperFails"]], [3, 1])
	assert_eq([inst["level"], inst["skills"], inst["speciesId"]], [4, {"fang": 1}, "fire_raptor"])
	assert_eq(result["state"]["mana"], 50 - int(_data["battle"]["temper"]["cost"][5]), "실패해도 마력은 든다")
	assert_eq(_attempt(2, false)["state"]["nest"][0]["temper"], 0, "안전 단계 아래에서는 0으로")
	assert_eq(_attempt(3, false)["state"]["nest"][0]["temper"], 3, "안전 단계에서는 그대로")


func test_each_failure_in_a_row_raises_the_next_chance_until_a_success() -> void:
	var cfg: Dictionary = _data["battle"]["temper"]
	var inst: Dictionary = {"temper": 6, "temperFails": 2}
	assert_eq(RunRules.temper_offer(_data, inst)["chance"], int(cfg["chancePct"][6]) + 2 * int(cfg["failAddPct"]))
	assert_eq(RunRules.temper_offer(_data, {"temper": 0, "temperFails": 9})["chance"], 100, "100%를 넘지 않는다")
	var won: Dictionary = _attempt(4, true)["state"]["nest"][0]
	assert_eq([won["temper"], won["temperFails"]], [5, 0])
	assert_eq(RunRules.temper_offer(_data, {"temper": 5}), {"step": 5, "next": 6, "cost": int(cfg["cost"][5]), "chance": int(cfg["chancePct"][5]), "fall": 3})


func test_out_of_range_steps_from_a_broken_save_are_clamped() -> void:
	var low: Dictionary = _state(-10)
	var high: Dictionary = _state(99)
	assert_eq(RunRules.temper_offer(_data, low["nest"][0])["step"], 0)
	assert_eq(_reason(high, _cmd()), "temperMax")
	assert_eq(Battle.to_unit(_data, high["nest"][0])["atk"], Battle.to_unit(_data, _state(9)["nest"][0])["atk"])
	assert_eq(Battle.to_unit(_data, low["nest"][0])["atk"], Battle.to_unit(_data, _state(0)["nest"][0])["atk"])


func test_absorbing_keeps_the_main_dragons_raised_chance() -> void:
	var main: Dictionary = _state(3)["nest"][0]
	main["temperFails"] = 2
	var material: Dictionary = main.duplicate(true)
	material["uid"] = 2
	material.erase("temperFails")
	assert_eq(FusionRules.merge(_data, main, material, 3)["inst"]["temperFails"], 2)


func test_same_seed_gives_the_same_outcome() -> void:
	var a: Dictionary = RunRules.apply_command(_data, _state(6, 50, 7), _cmd())
	var b: Dictionary = RunRules.apply_command(_data, _state(6, 50, 7), _cmd())
	assert_eq(a["state"], b["state"])


func test_each_step_adds_stats_and_thresholds_boost_the_ability() -> void:
	var plain: Dictionary = Battle.to_unit(_data, _state(0)["nest"][0])
	var two: Dictionary = Battle.to_unit(_data, _state(2)["nest"][0])
	var six: Dictionary = Battle.to_unit(_data, _state(6)["nest"][0])
	assert_true(int(two["atk"]) > int(plain["atk"]) and int(two["hp"]) > int(plain["hp"]))
	assert_true(not plain.has("abilityBoost") and not two.has("abilityBoost"))
	assert_eq(six["abilityBoost"], int(_data["battle"]["temper"]["abilityPct"]["6"]))
	assert_eq(Battle.temper_boost(_data, {"temper": 9}), int(_data["battle"]["temper"]["abilityPct"]["9"]))


func test_merging_keeps_the_higher_step() -> void:
	var main: Dictionary = _state(2)["nest"][0]
	var material: Dictionary = main.duplicate(true)
	material["uid"] = 2
	material["temper"] = 5
	material["level"] = 1
	assert_eq(FusionRules.merge(_data, main, material, 3)["inst"]["temper"], 5)
	material["temper"] = 0
	assert_eq(FusionRules.merge(_data, main, material, 3)["inst"]["temper"], 2)
	main.erase("temper")
	assert_true(not FusionRules.merge(_data, main, material, 3)["inst"].has("temper"), "단련한 적이 없으면 칸이 없다")


func test_boosted_pierce_hits_the_enemy_behind_harder() -> void:
	var ability: Ability = Ability.new()
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 470)]
	var unit: Dictionary = Ability._able("pierce", 100000, 100)
	unit["abilityBoost"] = 50
	var result: Dictionary = Battle.simulate_battle(ability._cfg(), B._slots([unit]), enemies)
	var first: Array = Ability._at_tick(Ability._hits(result, 0), 10)
	assert_eq([first[1]["dmg"], first[1].get("via")], [90, "pierce"])


func test_boosted_ward_blocks_more_for_its_lane_mate() -> void:
	var ability: Ability = Ability.new()
	var warder: Dictionary = Ability._able("ward", 100000, 1, 1000)
	var mate: Dictionary = B._solo("fire", 100000, 1, 1000)
	var foe: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)
	var plain: Dictionary = Battle.simulate_battle(ability._cfg(), B._slots([mate], [warder]), [foe])
	warder["abilityBoost"] = 100
	var boosted: Dictionary = Battle.simulate_battle(ability._cfg(), B._slots([mate], [warder]), [foe])
	var hit_of: Callable = func(result: Dictionary) -> int:
		for event: Dictionary in result["events"]:
			if event["kind"] == "attack" and event["dst"] == 0:
				return int(event["dmg"])
		return -1
	assert_eq([hit_of.call(plain), hit_of.call(boosted)], [80, 60])
