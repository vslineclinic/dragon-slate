extends TestCase
## 장비: 상점에서 얻어 드래곤 한 마리에게 채우고, 상점에서 제련한다. 실패하면 이번 방문에서 올린 단계만 잃는다.

const RunRules = preload("res://godot/core/run.gd")
const Ability = preload("res://godot/tests/test_ability.gd")
const B = preload("res://godot/tests/test_battle.gd")
const Shop = preload("res://godot/tests/test_shop.gd")
const Store = preload("res://godot/ui/store.gd")

var _data: Dictionary = GameData.load_all()


func _apply(state: Dictionary, cmd: Dictionary) -> Dictionary:
	return RunRules.apply_command(_data, state, cmd)


func _reason(state: Dictionary, cmd: Dictionary) -> String:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = _apply(state, cmd)
	if result["events"].size() == 1 and result["events"][0]["t"] == "rejected":
		assert_eq(result["state"], before, "거절하면 상태를 바꾸지 않는다")
		return result["events"][0]["reason"]
	return ""


## 상점이 열린 상태. gear = 들어올 때 가방에 든 장비.
func _shop(mana: int = 99, seed: int = 4, gear: Array = []) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state.merge({"phase": "fork", "forkChoices": ["elite", "rest", "merchant"], "wave": 4, "mana": mana,
		"nest": [Shop._inst(1, "fire_drake"), Shop._inst(2, "ice_wyvern"), null, null, null, null], "gear": gear}, true)
	return _apply(state, {"type": "chooseFork", "option": "merchant"})["state"]


func _manage(gear: Array = []) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state.merge({"phase": "manage", "nest": [Shop._inst(1, "fire_drake"), Shop._inst(2, "ice_wyvern"), null, null, null, null], "gear": gear}, true)
	return state


func _item(state: Dictionary, kind: String) -> int:
	var items: Array = state["shop"]["items"]
	for i: int in range(items.size()):
		if items[i]["kind"] == kind:
			return i
	return -1


func _unit(kind: String, value: int, hp: int = 100000, atk: int = 100, cd: int = 10) -> Dictionary:
	var unit: Dictionary = B._solo("fire", hp, atk, cd)
	unit["gear"] = {"kind": kind, "value": value}
	return unit


func test_data_every_gear_has_one_value_per_forge_level() -> void:
	var forge: Dictionary = _data["gear"]["forge"]
	assert_eq(forge["cost"].size(), forge["chancePct"].size())
	var kinds: Dictionary = {}
	for spec: Dictionary in _data["gear"]["items"]:
		assert_eq(spec["values"].size(), forge["cost"].size() + 1, spec["id"])
		assert_true(spec["descKo"].contains("{v}"), spec["id"])
		for i: int in range(1, spec["values"].size()):
			assert_true(int(spec["values"][i]) >= int(spec["values"][i - 1]), spec["id"])
		kinds[spec["kind"]] = true
	assert_eq(kinds.size(), _data["gear"]["items"].size(), "장비마다 효과가 다르다")


func test_shop_sells_one_gear_you_do_not_own_and_it_goes_to_the_bag() -> void:
	var state: Dictionary = _shop()
	var at: int = _item(state, "gear")
	assert_true(at >= 0, "상점에 장비 칸이 있다")
	var id: String = state["shop"]["items"][at]["detail"]
	var bought: Dictionary = _apply(state, {"type": "buy", "index": at})["state"]
	assert_eq(bought["gear"], [{"id": id, "level": 0}])
	assert_eq(_reason(bought, {"type": "buy", "index": at}), "soldOut")


func test_shop_never_offers_gear_you_already_own() -> void:
	var all: Array = _data["gear"]["items"].map(func(spec: Dictionary) -> Dictionary: return {"id": spec["id"], "level": 0})
	assert_eq(_item(_shop(99, 4, all), "gear"), -1)
	var but_one: Array = all.slice(1)
	var state: Dictionary = _shop(99, 4, but_one)
	assert_eq(state["shop"]["items"][_item(state, "gear")]["detail"], all[0]["id"])


func test_equip_moves_gear_between_bag_and_dragons() -> void:
	var state: Dictionary = _manage([{"id": "first_fang", "level": 2}, {"id": "last_scale", "level": 0}])
	var on_first: Dictionary = _apply(state, {"type": "equip", "gear": "first_fang", "at": {"zone": "nest", "index": 0}})["state"]
	assert_eq(on_first["nest"][0]["gear"], {"id": "first_fang", "level": 2})
	assert_eq(on_first["gear"], [{"id": "last_scale", "level": 0}])
	## 다른 드래곤에게 옮기면 앞 드래곤은 벗는다.
	var moved: Dictionary = _apply(on_first, {"type": "equip", "gear": "first_fang", "at": {"zone": "nest", "index": 1}})["state"]
	assert_true(not moved["nest"][0].has("gear"))
	assert_eq(moved["nest"][1]["gear"]["id"], "first_fang")
	## 이미 찬 드래곤에게 다른 장비를 채우면 앞의 것은 가방으로.
	var swapped: Dictionary = _apply(moved, {"type": "equip", "gear": "last_scale", "at": {"zone": "nest", "index": 1}})["state"]
	assert_eq(swapped["nest"][1]["gear"]["id"], "last_scale")
	assert_eq(swapped["gear"], [{"id": "first_fang", "level": 2}])
	## 벗기기.
	var bare: Dictionary = _apply(swapped, {"type": "equip", "gear": "last_scale", "at": null})["state"]
	assert_true(not bare["nest"][1].has("gear"))
	assert_eq(RunRules.gear_owned(bare).size(), 2, "장비는 늘지도 줄지도 않는다")


func test_equip_rejections() -> void:
	var state: Dictionary = _manage([{"id": "first_fang", "level": 0}])
	assert_eq(_reason(state, {"type": "equip", "gear": "thorn_mail", "at": {"zone": "nest", "index": 0}}), "noGear")
	assert_eq(_reason(state, {"type": "equip", "gear": "first_fang", "at": {"zone": "bench", "index": 0}}), "emptySlot")
	var worn: Dictionary = _apply(state, {"type": "equip", "gear": "first_fang", "at": {"zone": "nest", "index": 0}})["state"]
	assert_eq(_reason(worn, {"type": "equip", "gear": "first_fang", "at": {"zone": "nest", "index": 0}}), "sameSlot")
	worn["phase"] = "reward"
	assert_eq(_reason(worn, {"type": "equip", "gear": "first_fang", "at": null}), "wrongPhase")


func test_released_or_merged_dragons_return_their_gear() -> void:
	var state: Dictionary = _manage()
	state["nest"][0]["gear"] = {"id": "first_fang", "level": 1}
	state["nest"][1]["gear"] = {"id": "last_scale", "level": 3}
	var released: Dictionary = _apply(state, {"type": "release", "from": {"zone": "nest", "index": 1}})["state"]
	assert_eq(released["gear"], [{"id": "last_scale", "level": 3}])
	var merged: Dictionary = _apply(state, {"type": "merge", "main": {"zone": "nest", "index": 0}, "material": {"zone": "nest", "index": 1}})["state"]
	assert_eq(merged["nest"][0]["gear"], {"id": "first_fang", "level": 1}, "주 드래곤의 장비는 그대로")
	assert_eq(merged["gear"], [{"id": "last_scale", "level": 3}], "재료의 장비는 가방으로")
	state["nest"][0].erase("gear")
	var inherited: Dictionary = _apply(state, {"type": "merge", "main": {"zone": "nest", "index": 0}, "material": {"zone": "nest", "index": 1}})["state"]
	assert_eq(inherited["nest"][0]["gear"], {"id": "last_scale", "level": 3}, "주 드래곤이 맨몸이면 물려받는다")


func test_forge_only_in_the_shop_and_first_level_always_succeeds() -> void:
	var state: Dictionary = _shop(20, 4, [{"id": "first_fang", "level": 0}])
	var result: Dictionary = _apply(state, {"type": "forge", "gear": "first_fang"})
	assert_eq(result["state"]["gear"][0]["level"], 1)
	assert_eq(result["state"]["mana"], 20 - int(_data["gear"]["forge"]["cost"][0]))
	assert_eq(_reason(state, {"type": "forge", "gear": "thorn_mail"}), "noGear")
	assert_eq(_reason(_shop(1, 4, [{"id": "first_fang", "level": 0}]), {"type": "forge", "gear": "first_fang"}), "notEnoughMana")
	assert_eq(_reason(_shop(99, 4, [{"id": "first_fang", "level": 5}]), {"type": "forge", "gear": "first_fang"}), "forgeMax")
	assert_eq(_reason(_manage([{"id": "first_fang", "level": 0}]), {"type": "forge", "gear": "first_fang"}), "wrongPhase")


func test_failed_forge_loses_only_what_this_visit_gained() -> void:
	## 들어올 때 2단계. 올리다가 실패하면 2단계로 돌아간다(그 아래로는 내려가지 않는다).
	var seen_fail: bool = false
	for seed: int in range(1, 60):
		var state: Dictionary = _shop(999, seed, [{"id": "first_fang", "level": 2}])
		var peak: int = 2
		for i: int in range(12):
			var offer: Dictionary = RunRules.forge_offer(_data, state, "first_fang")
			if offer.is_empty():
				break
			assert_eq(offer["fall"], 2)
			var result: Dictionary = _apply(state, {"type": "forge", "gear": "first_fang"})
			state = result["state"]
			var forged: Dictionary = result["events"].filter(func(e: Dictionary) -> bool: return e["t"] == "forged")[0]
			if forged["ok"]:
				peak += 1
				assert_eq(state["gear"][0]["level"], peak)
			else:
				seen_fail = true
				assert_eq(state["gear"][0]["level"], 2)
				peak = 2
	assert_true(seen_fail, "실패하는 경우를 한 번은 본다")


func test_forging_worn_gear_changes_the_dragons_gear() -> void:
	var state: Dictionary = _shop(99, 4)
	state["nest"][0]["gear"] = {"id": "thorn_mail", "level": 0}
	state["shop"]["forgeBase"] = {"thorn_mail": 0}
	var forged: Dictionary = _apply(state, {"type": "forge", "gear": "thorn_mail"})["state"]
	assert_eq(forged["nest"][0]["gear"]["level"], 1)
	var spec: Dictionary = Battle.gear_spec(_data, "thorn_mail")
	assert_eq(Battle.to_unit(_data, forged["nest"][0])["gear"], {"kind": "thorns", "value": int(spec["values"][1])})
	assert_true(not Battle.to_unit(_data, Shop._inst(9, "fire_drake")).has("gear"))


func test_opener_boosts_only_the_first_normal_attack() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("opener", 60)]), [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)])
	var hits: Array = Ability._hits(result, 0)
	assert_eq([int(hits[0]["dmg"]), int(hits[1]["dmg"])], [160, 100])


func test_reach_gives_back_part_of_the_lane_falloff() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var foe: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 1, 400)]
	var plain: Array = Ability._hits(Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 100)]), foe), 0)
	var worn: Array = Ability._hits(Battle.simulate_battle(cfg, B._slots([_unit("reach", 20)]), foe), 0)
	var far: Array = Ability._hits(Battle.simulate_battle(cfg, B._slots([_unit("reach", 50)]), foe), 0)
	assert_eq([int(plain[0]["dmg"]), int(worn[0]["dmg"]), int(far[0]["dmg"])], [70, 90, 100])


func test_endure_survives_one_killing_blow() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("endure", 30, 100, 1, 1000)]), [B._enemy("dragon", "fire", 100000, 500, 10, 0, 400)])
	var hits: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["dst"] == 0)
	assert_eq(hits.size(), 2, "한 번 버티고 다음에 쓰러진다")
	assert_true(hits[0].get("endure", false) and not hits[1].get("endure", false))
	var deaths: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "death" and e["id"] == 0)
	assert_eq([deaths.size(), deaths[0]["tick"]], [1, hits[1]["tick"]])


func test_thorns_return_damage_and_can_finish_the_attacker() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("thorns", 25, 100000, 1, 1000)]), [B._enemy("dragon", "fire", 30, 100, 10, 0, 400)])
	var back: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e.get("via") == "thorns")
	assert_eq([back.size(), int(back[0]["dmg"]), back[0]["src"], int(back[1]["dmg"])], [2, 25, 0, 25])
	assert_true(result["winner"] == "ally", "가시에 쓰러진 적으로 이긴다")


func test_thorns_answer_even_the_blow_that_fells_the_wearer() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("thorns", 50, 80, 1, 1000)]), [B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)])
	var back: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e.get("via") == "thorns")
	assert_eq([back.size(), int(back[0]["dmg"])], [1, 50])


func test_an_attacker_felled_by_thorns_does_not_finish_its_extra_strike() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	var foe: Dictionary = B._enemy("dragon", "fire", 20, 100, 10, 0, 400)
	foe["ability"] = "twin"
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("thorns", 50, 100000, 1, 1000)]), [foe])
	var taken: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["dst"] == 0)
	assert_eq(taken.size(), 1, "첫 타의 가시에 쓰러져 연속 공격은 나가지 않는다")


func test_gear_bought_this_visit_falls_back_to_zero() -> void:
	var state: Dictionary = _shop()
	var bought: Dictionary = _apply(state, {"type": "buy", "index": _item(state, "gear")})["state"]
	var id: String = bought["gear"][0]["id"]
	var forged: Dictionary = _apply(bought, {"type": "forge", "gear": id})["state"]
	assert_eq(RunRules.forge_offer(_data, forged, id)["fall"], 0)


func test_equip_rejects_a_target_that_is_not_a_slot() -> void:
	var state: Dictionary = _manage()
	state["nest"][0]["gear"] = {"id": "first_fang", "level": 1}
	assert_eq(_reason(state, {"type": "equip", "gear": "first_fang", "at": "nest"}), "emptySlot")


func test_saves_with_broken_or_duplicate_gear_do_not_load() -> void:
	var loads: Callable = func(state: Dictionary) -> bool:
		return not Store.unpack_run(Store.pack_run(state, "standard", false), _data, false).is_empty()
	var good: Dictionary = _manage([{"id": "first_fang", "level": 2}])
	good["nest"][0]["gear"] = {"id": "last_scale", "level": 5}
	assert_true(loads.call(good), "온전한 저장은 열린다")
	assert_true(loads.call(_manage()), "장비 없는 저장도 열린다")
	for level: Variant in [-1, 99, 2.5, {}, "3"]:
		var bad: Dictionary = good.duplicate(true)
		bad["gear"][0]["level"] = level
		assert_true(not loads.call(bad), str(level))
	var twin: Dictionary = good.duplicate(true)
	twin["nest"][0]["gear"] = {"id": "first_fang", "level": 0}
	assert_true(not loads.call(twin), "같은 장비가 둘")
	var unknown: Dictionary = good.duplicate(true)
	unknown["gear"][0]["id"] = "no_such_gear"
	assert_true(not loads.call(unknown))


func test_trophy_charges_the_ultimate_on_a_kill() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 9}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	var foes: Array = [B._enemy("minion", "fire", 50, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 430)]
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_unit("trophy", 3)]), foes)
	var charges: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "charge")
	assert_eq([charges.size(), charges[0]["id"], int(charges[0]["charge"])], [1, 0, 4], "첫 타로 1, 쓰러뜨려 +3")


func test_stepping_matches_simulating_with_gear() -> void:
	var cfg: Dictionary = Ability.new()._cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 4}, "powerPct": {"none": 200}, "targets": {"none": 2}}
	var allies: Array = B._slots([_unit("opener", 80, 400, 30), _unit("thorns", 30, 400, 20), _unit("endure", 40, 200, 25)],
		[_unit("reach", 30, 300, 40), _unit("trophy", 2, 300, 35)])
	var foes: Array = []
	for i: int in range(8):
		foes.append(B._enemy("minion", "ice", 120, 30, 12, i % 3, 400 + i * 30, 2))
	var whole: Dictionary = Battle.simulate_battle(cfg, allies, foes, {"critSeed": 5})
	var sim: Dictionary = Battle.begin_battle(cfg, allies, foes, {"critSeed": 5})
	while not Battle.battle_over(sim):
		Battle.step_battle(sim)
	assert_eq(Battle.battle_result(sim), whole)
