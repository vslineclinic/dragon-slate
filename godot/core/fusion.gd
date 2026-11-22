class_name Fusion
extends RefCounted


static func find_recipe(data: Dictionary, a: String, b: String) -> Variant:
	for recipe: Dictionary in data["recipes"]:
		if (recipe["a"] == a and recipe["b"] == b) or (recipe["a"] == b and recipe["b"] == a):
			return recipe["result"]
	return null


static func merge_preview(data: Dictionary, main: Dictionary, material: Dictionary) -> Dictionary:
	var result: Variant = find_recipe(data, main["speciesId"], material["speciesId"])
	if result != null:
		return {"kind": "evolve", "result": result}
	return {"kind": "absorb", "trait": _absorbed_trait(data, main, material)}


static func merge(data: Dictionary, main: Dictionary, material: Dictionary, new_uid: int) -> Dictionary:
	var preview: Dictionary = merge_preview(data, main, material)
	var traits: Array = main["traits"].duplicate()
	if preview["kind"] == "evolve":
		var evolved: Dictionary = {
			"uid": new_uid, "speciesId": preview["result"], "traits": traits, "bonusPct": 0,
		}
		return {"inst": evolved, "kind": "evolve", "trait": null}

	var spec: Dictionary = data["dragons"].get(material["speciesId"], {})
	var tier: String = spec.get("tier", "base")
	var bonus_pct: int = int(main["bonusPct"]) + int(data["battle"]["absorbBonusPct"].get(tier, 0))
	var inherited: Variant = preview["trait"]
	if inherited != null:
		traits.append(inherited)
	var absorbed: Dictionary = {
		"uid": main["uid"], "speciesId": main["speciesId"], "traits": traits, "bonusPct": bonus_pct,
	}
	return {"inst": absorbed, "kind": "absorb", "trait": inherited}


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
