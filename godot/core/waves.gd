class_name Waves
extends RefCounted


static func is_boss(cfg: Dictionary, wave: int) -> bool:
	return wave <= cfg["maxWave"] and cfg["bossPct"].has(str(wave))


static func enemy_power(cfg: Dictionary, wave: int, mods: Dictionary = Calamity.NONE) -> int:
	var power: int = int(cfg["basePower"])
	var growth_pct: int = int(cfg["growthPct"])
	for w: int in range(2, wave + 1):
		power = Rng.fdiv(power * growth_pct, 100)

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


static func generate_enemies(
	data: Dictionary, wave: int, rng: Rng, run_seed: int, mods: Dictionary = Calamity.NONE,
) -> Array:
	var count: int = mini(1 + Rng.fdiv(wave, 2), 6)
	var specs: Array = data["dragons"].values()
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

	var cfg: Dictionary = data["waves"]
	var units: Array = []
	if is_boss(cfg, wave):
		var element: Variant = boss_element(run_seed, wave, GameData.active_elements(data))
		for spec: Dictionary in specs:
			if spec["tier"] == "t1" and not spec["elements"].is_empty() and spec["elements"][0] == element:
				units.append(_spec_unit(spec))
				break

	var pool: Array = []
	for spec: Dictionary in specs:
		if spec["tier"] == "base" or (wave > 5 and spec["tier"] == "t2"):
			pool.append(spec)
	while units.size() < count:
		units.append(_spec_unit(pool[rng.next_int(pool.size())]))

	var total: int = 0
	for unit: Dictionary in units:
		total += unit_power(unit)
	var scale_pct: int = maxi(50, Rng.fdiv(enemy_power(cfg, wave, mods) * 100, total))
	for unit: Dictionary in units:
		unit["hp"] = Rng.fdiv(unit["hp"] * scale_pct, 100)
		unit["atk"] = maxi(1, Rng.fdiv(unit["atk"] * scale_pct, 100))
	return units


static func _spec_unit(spec: Dictionary) -> Dictionary:
	var stats: Dictionary = spec["stats"]
	return {
		"speciesId": spec["id"],
		"elements": spec["elements"].duplicate(),
		"hp": int(stats["hp"]),
		"atk": int(stats["atk"]),
		"cooldownTicks": int(stats["cooldownTicks"]),
		"lifestealPct": 0,
	}
