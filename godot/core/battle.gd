class_name Battle
extends RefCounted


static func element_mult(cfg: Dictionary, atk: Variant, def: Variant) -> int:
	var beats: Dictionary = cfg["beats"]
	if def in beats.get(atk, []):
		return int(cfg["strongPct"])
	if atk in beats.get(def, []):
		return int(cfg["weakPct"])
	return 100


## 종 고유 특성과 계승 특성을 모두 적용한다.
static func to_unit(data: Dictionary, inst: Dictionary) -> Dictionary:
	var species_id: String = inst["speciesId"]
	var spec: Variant = data["dragons"].get(species_id)
	if spec == null:
		push_error("unknown species " + species_id)
		return {}
	var hp_pct: int = 0
	var atk_pct: int = 0
	var haste_pct: int = 0
	var lifesteal_pct: int = 0
	for id: String in [spec["traitId"]] + inst["traits"]:
		var trait_spec: Variant = data["traits"].get(id)
		if trait_spec == null:
			continue
		var value: int = int(trait_spec["value"])
		match trait_spec["kind"]:
			"hpPct":
				hp_pct += value
			"atkPct":
				atk_pct += value
			"hastePct":
				haste_pct += value
			_:
				lifesteal_pct += value

	var stats: Dictionary = spec["stats"]
	var bonus_pct: int = int(inst["bonusPct"])
	return {
		"speciesId": spec["id"],
		"elements": spec["elements"].duplicate(),
		"hp": Rng.fdiv(int(stats["hp"]) * (100 + bonus_pct + hp_pct), 100),
		"atk": Rng.fdiv(int(stats["atk"]) * (100 + bonus_pct + atk_pct), 100),
		"cooldownTicks": maxi(5, Rng.fdiv(int(stats["cooldownTicks"]) * (100 - haste_pct), 100)),
		"lifestealPct": lifesteal_pct,
	}


static func simulate_battle(
	cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {},
) -> Dictionary:
	var ally_slow_pct: int = int(rules.get("allySlowPct", 0))
	var ally_fighters: Array = _prepare(allies, ally_slow_pct)
	var enemy_fighters: Array = _prepare(enemies, 0)
	var burn: Variant = rules.get("burn")
	var row_blast: Variant = rules.get("rowBlast")
	var pulse: Variant = rules.get("pulse")
	var enrage: Variant = rules.get("enrage")
	var heal_cut_pct: int = int(rules.get("healCutPct", 0))
	var heal_cut_from: int = int(rules.get("healCutFromTick", 0))

	var events: Array = []
	var tick: int = 0
	var winner: String = ""
	var blast_front: bool = true
	var enraged: bool = false
	while winner.is_empty() and tick < cfg["maxTicks"]:
		tick += 1
		if _hazard_due(burn, tick):
			var lowest: int = -1
			for idx: int in range(ally_fighters.size()):
				var fighter: Variant = ally_fighters[idx]
				if fighter != null and fighter["hp"] > 0:
					if lowest < 0 or fighter["hp"] < ally_fighters[lowest]["hp"]:
						lowest = idx
			if lowest >= 0:
				_hurt_ally(ally_fighters[lowest], tick, lowest, "burn", int(burn["pct"]), events)
		if _hazard_due(row_blast, tick):
			var start: int = 0 if blast_front else 3
			blast_front = not blast_front
			for idx: int in range(start, mini(start + 3, ally_fighters.size())):
				_hurt_ally(ally_fighters[idx], tick, idx, "rowBlast", int(row_blast["pct"]), events)
		if _hazard_due(pulse, tick):
			for idx: int in range(ally_fighters.size()):
				_hurt_ally(ally_fighters[idx], tick, idx, "pulse", int(pulse["pct"]), events)
		if enrage != null and not enraged and tick >= enrage["atTick"]:
			enraged = true
			events.append({"tick": tick, "kind": "enrage"})
		if _first_alive(ally_fighters) < 0:
			winner = "enemy"
			break

		for side: String in ["ally", "enemy"]:
			var is_ally: bool = side == "ally"
			var mine: Array = ally_fighters if is_ally else enemy_fighters
			var theirs: Array = enemy_fighters if is_ally else ally_fighters
			var opposing_side: String = "enemy" if is_ally else "ally"
			for idx: int in range(mine.size()):
				var fighter: Variant = mine[idx]
				if fighter == null or fighter["hp"] <= 0:
					continue
				fighter["timer"] += 1
				if fighter["timer"] < fighter["unit"]["cooldownTicks"]:
					continue
				var dst: int = _first_alive(theirs)
				if dst < 0:
					break
				fighter["timer"] = 0

				var target: Dictionary = theirs[dst]
				var unit: Dictionary = fighter["unit"]
				var mult: int = element_mult(cfg, _primary(unit), _primary(target["unit"]))
				var dmg: int = maxi(1, Rng.fdiv(int(unit["atk"]) * mult, 100))
				if not is_ally and enraged:
					dmg = Rng.fdiv(dmg * int(enrage["atkPct"]), 100)
				target["hp"] -= dmg

				var raw_heal: int = Rng.fdiv(dmg * int(unit["lifestealPct"]), 100)
				if is_ally and heal_cut_pct != 0 and tick >= heal_cut_from:
					raw_heal = Rng.fdiv(raw_heal * (100 - heal_cut_pct), 100)
				var heal: int = maxi(0, mini(raw_heal, int(unit["hp"]) - int(fighter["hp"])))
				fighter["hp"] += heal
				events.append({
					"tick": tick, "kind": "attack", "side": side, "src": idx,
					"dst": dst, "dmg": dmg, "mult": mult, "heal": heal,
				})
				if target["hp"] <= 0:
					events.append({"tick": tick, "kind": "death", "side": opposing_side, "idx": dst})

		if _first_alive(enemy_fighters) < 0:
			winner = "ally"
		elif _first_alive(ally_fighters) < 0:
			winner = "enemy"

	return {
		"winner": "enemy" if winner.is_empty() else winner,
		"ticks": tick, "allies": allies, "enemies": enemies, "events": events,
	}


static func _prepare(units: Array, slow_pct: int) -> Array:
	var fighters: Array = []
	for item: Variant in units:
		if item == null:
			fighters.append(null)
			continue
		var unit: Dictionary = item
		if slow_pct != 0:
			unit = unit.duplicate()
			unit["cooldownTicks"] = Rng.fdiv(int(unit["cooldownTicks"]) * (100 + slow_pct), 100)
		fighters.append({"unit": unit, "hp": int(unit["hp"]), "timer": 0})
	return fighters


static func _first_alive(fighters: Array) -> int:
	for idx: int in range(fighters.size()):
		var fighter: Variant = fighters[idx]
		if fighter != null and fighter["hp"] > 0:
			return idx
	return -1


static func _primary(unit: Dictionary) -> Variant:
	var elements: Array = unit["elements"]
	return null if elements.is_empty() else elements[0]


static func _hazard_due(hazard: Variant, tick: int) -> bool:
	if hazard == null:
		return false
	var interval: int = int(hazard["everyTicks"])
	return interval != 0 and tick % interval == 0


static func _hurt_ally(
	fighter: Variant, tick: int, idx: int, hazard_name: String, pct: int, events: Array,
) -> void:
	if fighter == null or fighter["hp"] <= 0:
		return
	var dmg: int = maxi(1, Rng.fdiv(int(fighter["unit"]["hp"]) * pct, 100))
	fighter["hp"] -= dmg
	events.append({"tick": tick, "kind": "hazard", "name": hazard_name, "idx": idx, "dmg": dmg})
	if fighter["hp"] <= 0:
		events.append({"tick": tick, "kind": "death", "side": "ally", "idx": idx})
