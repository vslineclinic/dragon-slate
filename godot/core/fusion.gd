class_name Fusion
extends RefCounted


## 조합표가 수천 줄이라 "a|b" 색인을 만들어 둔다. 조합표 길이가 바뀌면 다시 만든다. 같은 쌍이 여러 번 있으면 앞의 것이 이긴다.
static func find_recipe(data: Dictionary, a: String, b: String) -> Variant:
	var recipes: Array = data["recipes"]
	if int(data.get("_recipeCount", -1)) != recipes.size():
		var index: Dictionary = {}
		for recipe: Dictionary in recipes:
			for key: String in [recipe["a"] + "|" + recipe["b"], recipe["b"] + "|" + recipe["a"]]:
				if not index.has(key):
					index[key] = recipe["result"]
		data["_recipeIndex"] = index
		data["_recipeCount"] = recipes.size()
	return data["_recipeIndex"].get(a + "|" + b)


## 그 등급 · 그 원소(한 원소)의 종을 자료 순서대로. role을 주면 그 역할만.
static func _ladder(data: Dictionary, tier: String, element: String, role: String = "") -> Array:
	var out: Array = []
	for spec: Dictionary in data["dragons"].values():
		if spec["tier"] == tier and spec["elements"].size() == 1 and spec["elements"][0] == element and (role.is_empty() or spec.get("role", "") == role):
			out.append(spec["id"])
	return out


## 계보 선택: 이 둘을 합치면 될 수 있는 종. [조합표의 결과] 또는 [조합표의 결과, 받는 쪽(main)의 갈래].
## 둘째 갈래: 두 재료의 역할이 다르면 main의 역할을 잇는 종, 같으면 그 역할의 다음 종.
## 조합이 없으면 빈 배열. 이중 · 비밀 결과와, 재료의 원소나 등급이 서로 다른 조합은 갈래가 없다.
static func merge_options(data: Dictionary, main: Dictionary, material: Dictionary) -> Array:
	var first: Variant = find_recipe(data, main["speciesId"], material["speciesId"])
	if first == null:
		return []
	var dragons: Dictionary = data["dragons"]
	var result: Dictionary = dragons[first]
	var a: Dictionary = dragons[main["speciesId"]]
	var b: Dictionary = dragons[material["speciesId"]]
	if result["tier"] in ["dual", "secret"] or result["elements"].size() != 1:
		return [first]
	if a["tier"] != b["tier"] or a["elements"].size() != 1 or a["elements"] != b["elements"]:
		return [first]
	var from: Array = _ladder(data, a["tier"], a["elements"][0])
	var group: Array = _ladder(data, result["tier"], result["elements"][0], a.get("role", ""))
	if group.is_empty():
		return [first]
	var turn: int = from.find(a["id"]) + from.find(b["id"])
	if a.get("role", "") == b.get("role", ""):
		turn += 1
	var second: String = group[turn % group.size()]
	return [first] if second == first else [first, second]


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
			return {"kind": "evolve", "result": result, "options": merge_options(data, main, material)}
		blocked = {"result": result, "needLevel": need}
	return {
		"kind": "absorb", "trait": _absorbed_trait(data, main, material),
		"xp": absorb_xp(data, material), "blocked": blocked,
	}


## choice = 계보 선택(merge_preview의 options에서 몇 번째). 범위를 벗어나면 첫째.
static func merge(data: Dictionary, main: Dictionary, material: Dictionary, new_uid: int, choice: int = 0) -> Dictionary:
	var preview: Dictionary = merge_preview(data, main, material)
	if preview["kind"] == "evolve":
		var options: Array = preview["options"]
		var species: String = options[choice] if choice >= 0 and choice < options.size() else preview["result"]
		## 레벨이 높은 쪽의 성장(레벨·스킬·특성)을 이어받는다. 같으면 주 드래곤.
		var carrier: Dictionary = material if level_of(material) > level_of(main) else main
		var evolved: Dictionary = {
			"uid": new_uid, "speciesId": species, "traits": carrier["traits"].duplicate(),
			"bonusPct": int(carrier.get("bonusPct", 0)),
			"skills": carrier.get("skills", {}).duplicate(), "skillPoints": int(carrier.get("skillPoints", 0)),
			"level": level_of(carrier), "xp": int(carrier.get("xp", 0)),
		}
		_keep_temper(evolved, main, material)
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
	_keep_temper(absorbed, main, material)
	var levels: int = add_xp(data, absorbed, int(preview["xp"]))
	return {"inst": absorbed, "kind": "absorb", "trait": inherited, "levels": levels}


## 단련 단계는 두 드래곤 중 높은 쪽을 잇는다(단련한 적이 없으면 칸을 만들지 않는다).
static func _keep_temper(into: Dictionary, main: Dictionary, material: Dictionary) -> void:
	var step: int = maxi(int(main.get("temper", 0)), int(material.get("temper", 0)))
	if step > 0:
		into["temper"] = step
	## 연달아 실패해 오른 확률은 주 드래곤의 것만 잇는다.
	if int(main.get("temperFails", 0)) > 0:
		into["temperFails"] = int(main["temperFails"])


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
