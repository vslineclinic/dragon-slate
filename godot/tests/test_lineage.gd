extends TestCase
## 계보 선택: 진화할 때 결과 후보가 둘 나온다. 첫째는 조합표의 결과, 둘째는 받는 쪽(주 드래곤)의 갈래.

const RunRules = preload("res://godot/core/run.gd")

var _data: Dictionary = GameData.load_all()


static func _inst(uid: int, species: String, level: int = 5) -> Dictionary:
	return {"uid": uid, "speciesId": species, "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": level, "xp": 0}


func _role(id: String) -> String:
	return _data["dragons"][id]["role"]


func test_different_roles_offer_the_recipe_result_and_the_main_dragons_own_branch() -> void:
	## 수호(드레이크) 위에 사수(와이번)를 합친다: 조합표는 남은 역할(지원), 둘째 후보는 받는 쪽 역할(수호).
	var main: Dictionary = _inst(1, "fire_drake")
	var material: Dictionary = _inst(2, "fire_wyvern")
	var options: Array = Fusion.merge_options(_data, main, material)
	assert_eq(options.size(), 2)
	assert_eq(options[0], Fusion.find_recipe(_data, "fire_drake", "fire_wyvern"))
	assert_eq(_role(options[0]), "support")
	assert_eq(_role(options[1]), "front")
	for id: String in options:
		assert_eq([_data["dragons"][id]["tier"], _data["dragons"][id]["elements"][0]], ["t2", "fire"])
	## 반대로 합치면 둘째 후보가 사수 갈래가 된다.
	var flipped: Array = Fusion.merge_options(_data, material, main)
	assert_eq(flipped[0], options[0])
	assert_eq(_role(flipped[1]), "back")


func test_same_roles_offer_two_species_of_that_role() -> void:
	var options: Array = Fusion.merge_options(_data, _inst(1, "fire_drake"), _inst(2, "fire_drake"))
	assert_eq(options.size(), 2)
	assert_eq(options[0], "beowulf_firedrake")
	assert_true(options[1] != options[0])
	assert_eq([_role(options[0]), _role(options[1])], ["front", "front"])


func test_no_second_branch_when_the_tier_has_one_species_per_role_or_for_two_element_dragons() -> void:
	## 정점은 역할마다 한 종뿐: 같은 역할 둘을 합치면 후보가 하나.
	var t1: Array = []
	for spec: Dictionary in _data["dragons"].values():
		if spec["tier"] == "t1" and spec["elements"] == ["fire"] and spec["role"] == "front":
			t1.append(spec["id"])
	var apex: Array = Fusion.merge_options(_data, _inst(1, t1[0], 15), _inst(2, t1[0], 15))
	assert_eq(apex.size(), 1)
	## 이중 원소 결과는 갈래가 없다.
	for recipe: Dictionary in _data["recipes"]:
		if _data["dragons"][recipe["result"]]["tier"] == "dual":
			assert_eq(Fusion.merge_options(_data, _inst(1, recipe["a"], 10), _inst(2, recipe["b"], 10)), [recipe["result"]])
			break
	assert_eq(Fusion.merge_options(_data, _inst(1, "fire_drake"), _inst(2, "ice_drake")), [], "조합이 없으면 후보도 없다")


func test_every_branch_is_a_real_species_of_the_result_tier_and_element() -> void:
	var seen_two: int = 0
	for recipe: Dictionary in _data["recipes"]:
		var result: Dictionary = _data["dragons"][recipe["result"]]
		for pair: Array in [[recipe["a"], recipe["b"]], [recipe["b"], recipe["a"]]]:
			var options: Array = Fusion.merge_options(_data, _inst(1, pair[0], 20), _inst(2, pair[1], 20))
			assert_true(options.size() in [1, 2] and options[0] == Fusion.find_recipe(_data, pair[0], pair[1]), "%s + %s" % pair)
			if options.size() == 2:
				seen_two += 1
				var branch: Dictionary = _data["dragons"].get(options[1], {})
				assert_eq([branch.get("tier"), branch.get("elements")], [result["tier"], result["elements"]], "%s + %s" % pair)
				assert_true(options[1] != options[0])
	assert_true(seen_two > 1000, "갈래가 둘인 조합이 충분히 많다: %d" % seen_two)


func test_merge_preview_lists_the_options_and_merge_takes_the_chosen_one() -> void:
	var main: Dictionary = _inst(1, "fire_drake", 6)
	main["traits"] = ["tr_fire_wyvern"]
	main["skills"] = {"fang": 1}
	var material: Dictionary = _inst(2, "fire_wyvern", 2)
	var preview: Dictionary = Fusion.merge_preview(_data, main, material)
	assert_eq(preview["kind"], "evolve")
	assert_eq(preview["options"], Fusion.merge_options(_data, main, material))
	assert_eq(Fusion.merge(_data, main, material, 9)["inst"]["speciesId"], preview["options"][0], "고르지 않으면 조합표의 결과")
	var second: Dictionary = Fusion.merge(_data, main, material, 9, 1)["inst"]
	assert_eq(second["speciesId"], preview["options"][1])
	assert_eq([second["level"], second["traits"], second["skills"]], [6, ["tr_fire_wyvern"], {"fang": 1}], "성장은 그대로 이어받는다")


func test_merge_command_accepts_a_choice_and_rejects_a_bad_one() -> void:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state["phase"] = "manage"
	state["nest"][0] = _inst(1, "fire_drake")
	state["bench"][0] = _inst(2, "fire_wyvern")
	state["nextUid"] = 3
	var options: Array = Fusion.merge_options(_data, state["nest"][0], state["bench"][0])
	var cmd: Dictionary = {"type": "merge", "main": {"zone": "nest", "index": 0}, "material": {"zone": "bench", "index": 0}, "choice": 1}
	var done: Dictionary = RunRules.apply_command(_data, state, cmd)
	assert_eq(done["state"]["nest"][0]["speciesId"], options[1])
	assert_true(options[1] in done["state"]["discovered"])
	cmd["choice"] = 2
	assert_eq(RunRules.apply_command(_data, state, cmd)["events"][0].get("reason"), "emptySlot")
	cmd.erase("choice")
	assert_eq(RunRules.apply_command(_data, state, cmd)["state"]["nest"][0]["speciesId"], options[0])


func test_absorb_ignores_the_choice() -> void:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state["phase"] = "manage"
	state["nest"][0] = _inst(1, "fire_drake", 1)
	state["bench"][0] = _inst(2, "ice_drake", 1)
	var cmd: Dictionary = {"type": "merge", "main": {"zone": "nest", "index": 0}, "material": {"zone": "bench", "index": 0}, "choice": 1}
	var done: Dictionary = RunRules.apply_command(_data, state, cmd)
	assert_eq(done["state"]["nest"][0]["speciesId"], "fire_drake")
	assert_true(done["events"].any(func(event: Dictionary) -> bool: return event["t"] == "absorbed"))
