class_name Fusion
extends RefCounted


static func find_recipe(data: Dictionary, a: String, b: String) -> Variant:
	for recipe: Dictionary in data["recipes"]:
		if (recipe["a"] == a and recipe["b"] == b) or (recipe["a"] == b and recipe["b"] == a):
			return recipe["result"]
	return null


static func level_of(inst: Dictionary) -> int:
	return maxi(1, int(inst.get("level", 1)))


## 다음 레벨까지 필요한 경험치. 최고 레벨이면 0.
static func xp_needed(data: Dictionary, level: int) -> int:
	var cfg: Dictionary = data["battle"].get("level", {})
	if level >= int(cfg.get("max", 1)):
		return 0
	return int(cfg.get("xpBase", 1)) + int(cfg.get("xpStep", 0)) * (level - 1)


## 경험치를 더하고 오른 레벨 수를 돌려준다. 레벨이 오를 때마다 스킬 점수 1.
static func add_xp(data: Dictionary, inst: Dictionary, amount: int) -> int:
	var level: int = level_of(inst)
	var xp: int = int(inst.get("xp", 0)) + maxi(0, amount)
	var gained: int = 0
	var need: int = xp_needed(data, level)
	while need > 0 and xp >= need:
		xp -= need
		level += 1
		gained += 1
		need = xp_needed(data, level)
	if need == 0:
		xp = 0
	inst["level"] = level
	inst["xp"] = xp
	inst["skillPoints"] = int(inst.get("skillPoints", 0)) + gained
	return gained


## 그 종으로 전직(합체)하는 데 필요한 레벨. 둘 중 하나만 채우면 된다.
static func evolve_level(data: Dictionary, result_species: String) -> int:
	var spec: Dictionary = data["dragons"].get(result_species, {})
	var needs: Dictionary = data["battle"].get("level", {}).get("evolveLevel", {})
	return int(needs.get(spec.get("tier", "base"), 1))


static func absorb_xp(data: Dictionary, material: Dictionary) -> int:
	var cfg: Dictionary = data["battle"].get("level", {})
	var spec: Dictionary = data["dragons"].get(material["speciesId"], {})
	return int(cfg.get("absorbXp", {}).get(spec.get("tier", "base"), 1)) + int(cfg.get("absorbLevelXp", 0)) * (level_of(material) - 1)


## kind: evolve(전직) 또는 absorb(흡수). 조합은 맞지만 레벨이 모자라면 absorb에 blocked가 붙는다.
static func merge_preview(data: Dictionary, main: Dictionary, material: Dictionary) -> Dictionary:
	var result: Variant = find_recipe(data, main["speciesId"], material["speciesId"])
	var blocked: Variant = null
	if result != null:
		var need: int = evolve_level(data, result)
		if maxi(level_of(main), level_of(material)) >= need:
			return {"kind": "evolve", "result": result}
		blocked = {"result": result, "needLevel": need}
	return {
		"kind": "absorb", "trait": _absorbed_trait(data, main, material),
		"xp": absorb_xp(data, material), "blocked": blocked,
	}


static func merge(data: Dictionary, main: Dictionary, material: Dictionary, new_uid: int) -> Dictionary:
	var preview: Dictionary = merge_preview(data, main, material)
	if preview["kind"] == "evolve":
		## 레벨이 높은 쪽의 성장(레벨·스킬·특성)을 이어받는다. 같으면 주 드래곤.
		var carrier: Dictionary = material if level_of(material) > level_of(main) else main
		var evolved: Dictionary = {
			"uid": new_uid, "speciesId": preview["result"], "traits": carrier["traits"].duplicate(),
			"bonusPct": int(carrier.get("bonusPct", 0)),
			"skills": carrier.get("skills", {}).duplicate(), "skillPoints": int(carrier.get("skillPoints", 0)),
			"level": level_of(carrier), "xp": int(carrier.get("xp", 0)),
		}
		return {"inst": evolved, "kind": "evolve", "trait": null, "levels": 0}

	var traits: Array = main["traits"].duplicate()
	var inherited: Variant = preview["trait"]
	if inherited != null:
		traits.append(inherited)
	var absorbed: Dictionary = {
		"uid": main["uid"], "speciesId": main["speciesId"], "traits": traits, "bonusPct": int(main.get("bonusPct", 0)),
		"skills": main.get("skills", {}).duplicate(), "skillPoints": int(main.get("skillPoints", 0)),
		"level": level_of(main), "xp": int(main.get("xp", 0)),
	}
	var levels: int = add_xp(data, absorbed, int(preview["xp"]))
	return {"inst": absorbed, "kind": "absorb", "trait": inherited, "levels": levels}


## 스킬 맵: 찍을 수 있으면 "" 아니면 거부 이유.
static func skill_rejection(data: Dictionary, inst: Dictionary, node: String) -> String:
	var skill: Variant = data["skills"].get(node)
	if skill == null:
		return "unknownSkill"
	if int(inst.get("skillPoints", 0)) <= 0:
		return "noSkillPoint"
	var learned: Dictionary = inst.get("skills", {})
	if int(learned.get(node, 0)) >= int(skill["max"]):
		return "skillMaxed"
	var needs: Dictionary = skill.get("requires", {})
	for need: String in needs:
		if int(learned.get(need, 0)) < int(needs[need]):
			return "skillLocked"
	return ""


static func _absorbed_trait(data: Dictionary, main: Dictionary, material: Dictionary) -> Variant:
	var dragons: Dictionary = data["dragons"]
	var material_spec: Dictionary = dragons.get(material["speciesId"], {})
	var main_spec: Dictionary = dragons.get(main["speciesId"], {})
	var trait_id: Variant = material_spec.get("traitId")
	var traits: Array = main["traits"]
	if trait_id == null or trait_id == main_spec.get("traitId"):
		return null
	if traits.has(trait_id) or traits.size() >= data["battle"]["maxTraits"]:
		return null
	return trait_id
