extends TestCase

const Fixture = preload("res://godot/tests/test_slot.gd")


static func _data() -> Dictionary:
	var data: Dictionary = Fixture.mini_data()
	for extra: Array in [
		["fafnir", "t2", ["fire"], "tr_fafnir"],
		["xiuhcoatl", "t2", ["fire"], "tr_xiuh"],
		["zhulong", "t1", ["fire"], "tr_zhu"],
		["palraiyuk", "t2", ["ice"], "tr_pal"],
		["thermal_dragon", "dual", ["fire", "ice"], "tr_thermal"],
	]:
		var id: String = extra[0]
		var trait_id: String = extra[3]
		data["dragons"][id] = {
			"id": id, "nameKo": id, "tier": extra[1], "elements": extra[2],
			"role": "support", "stats": {"hp": 200, "atk": 20, "cooldownTicks": 20},
			"traitId": trait_id,
		}
		data["traits"][trait_id] = {
			"id": trait_id, "nameKo": trait_id, "kind": "hpPct", "value": 15,
		}
	data["battle"]["level"] = {
		"max": 10, "statPct": 6, "xpBase": 2, "xpStep": 1,
		"absorbXp": {"base": 3, "t2": 6}, "absorbLevelXp": 2,
		"evolveLevel": {"t2": 1, "t1": 3, "dual": 1},
	}
	data["dragons"]["ice_drake"]["traitId"] = "tr_icy"
	data["traits"]["tr_icy"] = {"id": "tr_icy", "nameKo": "icy", "kind": "hastePct", "value": 10}
	data["recipes"].append_array([
		{"a": "fire_drake", "b": "fire_wyvern", "result": "fafnir"},
		{"a": "fafnir", "b": "xiuhcoatl", "result": "zhulong"},
		{"a": "fafnir", "b": "palraiyuk", "result": "thermal_dragon"},
	])
	return data


static func _inst(uid: int, species_id: String, traits: Array = [], bonus_pct: int = 0) -> Dictionary:
	return {"uid": uid, "speciesId": species_id, "traits": traits, "bonusPct": bonus_pct, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}


static func _with_points(inst: Dictionary, points: int) -> Dictionary:
	inst["skillPoints"] = points
	return inst


static func _grown(inst: Dictionary, level: int, xp: int, points: int) -> Dictionary:
	inst["level"] = level
	inst["xp"] = xp
	inst["skillPoints"] = points
	return inst


func test_same_species_evolves_to_t2() -> void:
	var result: Dictionary = Fusion.merge(_data(), _inst(1, "fire_drake"), _inst(2, "fire_drake"), 9)
	assert_eq(result, {"inst": _inst(9, "beowulf_firedrake"), "kind": "evolve", "trait": null, "levels": 0})


func test_recipe_order_does_not_matter() -> void:
	var data: Dictionary = _data()
	assert_eq(Fusion.find_recipe(data, "fire_wyvern", "fire_drake"), "fafnir")
	assert_eq(Fusion.find_recipe(data, "fire_drake", "fire_wyvern"), "fafnir")
	assert_eq(Fusion.find_recipe(data, "fire_wyvern", "fire_wyvern"), null)


func test_t2_pair_evolves_to_t1() -> void:
	var preview: Dictionary = Fusion.merge_preview(_data(), _grown(_inst(1, "xiuhcoatl"), 3, 0, 0), _inst(2, "fafnir"))
	assert_eq(preview, {"kind": "evolve", "result": "zhulong"})


func test_evolution_waits_for_level_and_absorbs_meanwhile() -> void:
	var data: Dictionary = _data()
	var preview: Dictionary = Fusion.merge_preview(data, _grown(_inst(1, "xiuhcoatl"), 2, 0, 0), _inst(2, "fafnir"))
	assert_eq(preview["kind"], "absorb")
	assert_eq(preview["blocked"], {"result": "zhulong", "needLevel": 3})
	assert_eq(Fusion.merge(data, _inst(1, "xiuhcoatl"), _inst(2, "fafnir"), 9)["inst"]["speciesId"], "xiuhcoatl")
	assert_eq(Fusion.merge_preview(data, _inst(1, "xiuhcoatl"), _grown(_inst(2, "fafnir"), 3, 0, 0))["kind"], "evolve")


func test_xp_curve_levels_up_and_stops_at_max() -> void:
	var data: Dictionary = _data()
	assert_eq([Fusion.xp_needed(data, 1), Fusion.xp_needed(data, 2), Fusion.xp_needed(data, 10)], [2, 3, 0])
	var inst: Dictionary = _inst(1, "fafnir")
	assert_eq(Fusion.add_xp(data, inst, 6), 2)
	assert_eq([inst["level"], inst["xp"], inst["skillPoints"]], [3, 1, 2])
	assert_eq(Fusion.add_xp(data, inst, 9999), 7)
	assert_eq([inst["level"], inst["xp"], inst["skillPoints"]], [10, 0, 9])


func test_absorbing_a_grown_dragon_gives_more_xp() -> void:
	var data: Dictionary = _data()
	assert_eq(Fusion.absorb_xp(data, _inst(2, "ice_drake")), 3)
	assert_eq(Fusion.absorb_xp(data, _grown(_inst(2, "ice_drake"), 4, 0, 0)), 9)


func test_evolution_inherits_growth_of_the_higher_level_dragon() -> void:
	var material: Dictionary = _grown(_inst(2, "fire_drake", ["tr_x"]), 4, 2, 1)
	material["skills"] = {"scale": 2}
	var result: Dictionary = Fusion.merge(_data(), _inst(1, "fire_drake", ["tr_icy"]), material, 7)
	var expected: Dictionary = _grown(_inst(7, "beowulf_firedrake", ["tr_x"]), 4, 2, 1)
	expected["skills"] = {"scale": 2}
	assert_eq(result["inst"], expected)


func test_cross_element_t2_gives_dual() -> void:
	var result: Dictionary = Fusion.merge(_data(), _inst(1, "palraiyuk"), _inst(2, "fafnir"), 5)
	assert_eq(result["inst"]["speciesId"], "thermal_dragon")


func test_no_recipe_absorbs_trait_and_bonus() -> void:
	var data: Dictionary = _data()
	var main: Dictionary = _inst(1, "fafnir")
	var material: Dictionary = _inst(2, "ice_drake")
	assert_eq(Fusion.merge(data, main, material, 9), {
		"inst": _grown(_inst(1, "fafnir", ["tr_icy"]), 2, 1, 1), "kind": "absorb", "trait": "tr_icy", "levels": 1,
	})
	assert_eq(Fusion.merge_preview(data, main, material), {"kind": "absorb", "trait": "tr_icy", "xp": 3, "blocked": null})


func test_absorb_skips_duplicate_trait() -> void:
	var main: Dictionary = _inst(1, "fafnir", ["tr_icy"], 12)
	var result: Dictionary = Fusion.merge(_data(), main, _inst(2, "ice_drake"), 9)
	assert_eq(result["inst"], _grown(_inst(1, "fafnir", ["tr_icy"], 12), 2, 1, 1))
	assert_eq(result["trait"], null)


func test_absorb_respects_max_traits_but_still_adds_bonus() -> void:
	var main: Dictionary = _inst(1, "zhulong", ["tr_a", "tr_b"])
	var result: Dictionary = Fusion.merge(_data(), main, _inst(2, "fafnir"), 9)
	assert_eq(result["inst"], _grown(_inst(1, "zhulong", ["tr_a", "tr_b"]), 3, 1, 2))
	assert_eq(result["trait"], null)


func test_absorb_does_not_copy_main_species_own_trait() -> void:
	var result: Dictionary = Fusion.merge(_data(), _inst(1, "fafnir"), _inst(2, "fafnir"), 9)
	assert_eq(result["trait"], null)
	assert_eq(result["inst"]["traits"], [])


func test_evolve_keeps_main_traits_skills_and_points() -> void:
	var main: Dictionary = _with_points(_inst(1, "fire_drake", ["tr_icy"]), 2)
	main["skills"] = {"fang": 3}
	var material: Dictionary = _inst(2, "fire_drake", ["tr_x"])
	var result: Dictionary = Fusion.merge(_data(), main, material, 7)
	var expected: Dictionary = _with_points(_inst(7, "beowulf_firedrake", ["tr_icy"]), 2)
	expected["skills"] = {"fang": 3}
	assert_eq(result["inst"], expected)


func test_skill_needs_point_prerequisite_and_room() -> void:
	var data: Dictionary = _data()
	var inst: Dictionary = _inst(1, "fafnir")
	assert_eq(Fusion.skill_rejection(data, inst, "fang"), "noSkillPoint")
	inst["skillPoints"] = 1
	assert_eq(Fusion.skill_rejection(data, inst, "fang"), "")
	assert_eq(Fusion.skill_rejection(data, inst, "frenzy"), "skillLocked")
	inst["skills"] = {"fang": 5}
	assert_eq(Fusion.skill_rejection(data, inst, "fang"), "skillMaxed")
	assert_eq(Fusion.skill_rejection(data, inst, "frenzy"), "")
	assert_eq(Fusion.skill_rejection(data, inst, "nope"), "unknownSkill")
