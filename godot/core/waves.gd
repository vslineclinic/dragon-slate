class_name Waves
extends RefCounted


static func is_boss(cfg: Dictionary, wave: int) -> bool:
	return wave <= cfg["maxWave"] and cfg["bossPct"].has(str(wave))


static func enemy_power(cfg: Dictionary, wave: int, mods: Dictionary = Calamity.NONE) -> int:
	var power: int = int(cfg["basePower"])
	## 구간별 성장률: growthBands의 from 이상인 마지막 구간을 쓴다. 없으면 growthPct.
	var bands: Array = cfg.get("growthBands", [])
	for w: int in range(2, wave + 1):
		var growth_pct: int = int(cfg["growthPct"])
		for band: Dictionary in bands:
			if w >= int(band["from"]):
				growth_pct = int(band["pct"])
		power = Rng.fdiv(power * growth_pct, 100)

	var early: Dictionary = cfg.get("earlyPct", {})
	if early.has(str(wave)):
		power = Rng.fdiv(power * int(early[str(wave)]), 100)
	var boss: bool = is_boss(cfg, wave)
	if boss:
		power = Rng.fdiv(power * int(cfg["bossPct"][str(wave)]), 100)
	var enemy_power_pct: int = int(mods["enemyPowerPct"])
	var boss_power_pct: int = int(mods["bossPowerPct"])
	if enemy_power_pct != 0:
		power = Rng.fdiv(power * (100 + enemy_power_pct), 100)
	if boss and boss_power_pct != 0:
		power = Rng.fdiv(power * (100 + boss_power_pct), 100)
	return power


static func boss_element(run_seed: int, wave: int, elements: Array) -> Variant:
	var rng: Rng = Rng.new((run_seed ^ Rng.imul(wave, 7919)) & Rng.M32)
	var index: int = rng.next_int(maxi(1, elements.size()))
	return null if elements.is_empty() else elements[index]


static func unit_power(unit: Dictionary) -> int:
	return Rng.fdiv(int(unit["hp"]), 4) + Rng.fdiv(int(unit["atk"]) * 20, int(unit["cooldownTicks"]))


## 적 부대: 우두머리 드래곤(1~3) + 졸병 무리. 힘 예산을 둘로 나눠 맞춘다.
static func generate_enemies(
	data: Dictionary, wave: int, rng: Rng, run_seed: int, mods: Dictionary = Calamity.NONE,
) -> Array:
	var cfg: Dictionary = data["waves"]
	var squad: Dictionary = cfg["squad"]
	var specs: Array = data["dragons"].values()
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

	var leader_count: int = 1
	if wave >= int(squad["secondLeaderWave"]):
		leader_count += 1
	if wave >= int(squad["thirdLeaderWave"]):
		leader_count += 1
	var leaders: Array = []
	if is_boss(cfg, wave):
		var element: Variant = boss_element(run_seed, wave, GameData.active_elements(data))
		var boss_tier: String = "apex" if wave >= int(squad.get("bossApexFromWave", 9999)) else "t1"
		for spec: Dictionary in specs:
			if spec["tier"] == boss_tier and not spec["elements"].is_empty() and spec["elements"][0] == element:
				leaders.append(_spec_unit(spec))
				break
	var tiers: Array = ["base"] if wave <= 5 else ["base", "t2"]
	for band: Dictionary in squad.get("leaderTiers", []):
		if wave >= int(band["from"]):
			tiers = band["tiers"]
	var pool: Array = []
	for spec: Dictionary in specs:
		if spec["tier"] in tiers:
			pool.append(spec)
	while leaders.size() < leader_count:
		leaders.append(_spec_unit(pool[rng.next_int(pool.size())]))

	var minion_specs: Array = data["minions"].values()
	minion_specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var minions: Array = []
	var minion_count: int = mini(int(squad["minionBase"]) + Rng.fdiv(wave, 2), int(squad["minionMax"]))
	if not minion_specs.is_empty():
		for i: int in range(minion_count):
			var leader: Dictionary = leaders[rng.next_int(leaders.size())]
			var element: Variant = null if leader["elements"].is_empty() else leader["elements"][0]
			var chosen: Dictionary = minion_specs[0]
			for spec: Dictionary in minion_specs:
				if spec["element"] == element:
					chosen = spec
					break
			minions.append(_minion_unit(chosen))

	var target: int = enemy_power(cfg, wave, mods)
	var leader_budget: int = target if minions.is_empty() else Rng.fdiv(target * int(squad["leaderSharePct"]), 100)
	_scale_to(leaders, leader_budget)
	_scale_to(minions, target - leader_budget)

	## 작은 무리(stage): 졸병은 무리마다 고르게, 우두머리는 뒤쪽 무리에. 첫 우두머리(보스)는 마지막 무리.
	var stages: int = int(squad.get("stages", 1)) if wave >= int(squad.get("stagesFromWave", 1)) else int(squad.get("stagesEarly", 1))
	stages = maxi(1, stages)
	var leader_lanes: Array = [1, 0, 2]
	for i: int in range(leaders.size()):
		leaders[i]["lane"] = leader_lanes[i]
		leaders[i]["x"] = int(squad["leaderX"]) if i == 0 else int(squad["extraLeaderX"])
		leaders[i]["stage"] = maxi(0, stages - 1 - (i % 2))
	var per_stage: Dictionary = {}
	for i: int in range(minions.size()):
		var stage: int = i % stages
		var order: int = per_stage.get(stage, 0)
		per_stage[stage] = order + 1
		minions[i]["stage"] = stage
		minions[i]["lane"] = order % 3
		var base_x: int = int(squad["minionX"]) if stage == 0 else int(squad.get("lateMinionX", squad["minionX"]))
		minions[i]["x"] = mini(1000, base_x + Rng.fdiv(order, 3) * int(squad["minionSpacingX"]))
	return leaders + minions


static func _scale_to(units: Array, budget: int) -> void:
	if units.is_empty():
		return
	var total: int = 0
	for unit: Dictionary in units:
		total += unit_power(unit)
	var scale_pct: int = maxi(50, Rng.fdiv(budget * 100, maxi(1, total)))
	for unit: Dictionary in units:
		unit["hp"] = maxi(1, Rng.fdiv(unit["hp"] * scale_pct, 100))
		unit["atk"] = maxi(1, Rng.fdiv(unit["atk"] * scale_pct, 100))


static func _minion_unit(spec: Dictionary) -> Dictionary:
	return {
		"kind": "minion", "id": spec["id"], "elements": [spec["element"]],
		"hp": int(spec["hp"]), "atk": int(spec["atk"]),
		"cooldownTicks": int(spec["cooldownTicks"]), "speed": int(spec["speed"]),
		"lane": 0, "x": 0, "stage": 0,
	}


static func _spec_unit(spec: Dictionary) -> Dictionary:
	var stats: Dictionary = spec["stats"]
	return {
		"kind": "dragon", "id": spec["id"],
		"elements": spec["elements"].duplicate(),
		"hp": int(stats["hp"]),
		"atk": int(stats["atk"]),
		"cooldownTicks": int(stats["cooldownTicks"]),
		"speed": 0, "lane": 0, "x": 0, "stage": 0,
	}
