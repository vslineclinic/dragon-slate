class_name Waves
extends RefCounted


static func is_boss(cfg: Dictionary, wave: int) -> bool:
	return wave <= cfg["maxWave"] and cfg["bossPct"].has(str(wave))


## 중간 보스(정예 우두머리) 웨이브: 보스가 아닌 웨이브 가운데 elitePct에 적힌 것.
static func is_elite(cfg: Dictionary, wave: int) -> bool:
	return wave <= cfg["maxWave"] and cfg.get("elitePct", {}).has(str(wave)) and not is_boss(cfg, wave)


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
	if is_elite(cfg, wave):
		power = Rng.fdiv(power * int(cfg["elitePct"][str(wave)]), 100)
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


static func leader_count(cfg: Dictionary, wave: int) -> int:
	var squad: Dictionary = cfg["squad"]
	var count: int = 1
	if wave >= int(squad["secondLeaderWave"]):
		count += 1
	if wave >= int(squad["thirdLeaderWave"]):
		count += 1
	return count


static func minion_count(cfg: Dictionary, wave: int) -> int:
	var squad: Dictionary = cfg["squad"]
	return mini(int(squad["minionBase"]) + Rng.fdiv(wave, 2), int(squad["minionMax"]))


static func stage_count(cfg: Dictionary, wave: int) -> int:
	var squad: Dictionary = cfg["squad"]
	var stages: int = int(squad.get("stages", 1)) if wave >= int(squad.get("stagesFromWave", 1)) else int(squad.get("stagesEarly", 1))
	return maxi(1, stages)


## 이번 웨이브에 적이 어느 줄로 몰리는지. 판 씨앗과 웨이브만으로 정해져서 전투 전에 미리 보여 줄 수 있다.
## order = 많이 몰리는 줄부터(우두머리도 이 순서로 선다), weights = 줄 번호별 비중.
## squad.lanePatterns가 없으면 예전처럼 고르게 선다.
static func lane_plan(cfg: Dictionary, run_seed: int, wave: int) -> Dictionary:
	var pattern: Array = []
	for row: Dictionary in cfg["squad"].get("lanePatterns", []):
		if wave >= int(row["from"]):
			pattern = row["weights"]
	if pattern.is_empty():
		return {"order": [1, 0, 2], "minionOrder": [0, 1, 2], "weights": [1, 1, 1]}
	var rng: Rng = Rng.new((run_seed ^ Rng.imul(wave, 104729)) & Rng.M32)
	var order: Array = [0, 1, 2]
	for i: int in range(2, 0, -1):
		var j: int = rng.next_int(i + 1)
		var kept: int = order[i]
		order[i] = order[j]
		order[j] = kept
	var weights: Array = [0, 0, 0]
	for i: int in range(3):
		weights[int(order[i])] = int(pattern[i])
	return {"order": order, "minionOrder": order, "weights": weights}


## 졸병 count마리가 차례로 서는 줄(줄 번호의 배열). 비중에 비해 가장 덜 채워진 줄부터 채워서,
## 앞에서 몇 마리를 끊어도 비중대로 섞여 있다(무리마다 고르게 나뉜다).
static func lane_sequence(plan: Dictionary, count: int) -> Array:
	var weights: Array = plan["weights"]
	var total: int = 0
	for weight: int in weights:
		total += weight
	var placed: Array = [0, 0, 0]
	var out: Array = []
	for k: int in range(1, count + 1):
		var best: int = -1
		var best_gap: int = 0
		for lane: int in plan["minionOrder"]:
			var gap: int = k * int(weights[lane]) - int(placed[lane]) * total
			if best < 0 or gap > best_gap:
				best = lane
				best_gap = gap
		placed[best] += 1
		out.append(best)
	return out


## 졸병 count마리의 종류(""는 보통 졸병). 판 씨앗과 웨이브만으로 정해져서 미리보기와 실제 편성이 같다.
## squad.minionTypes: [{"id", "fromWave", "weight", "hpPct", "atkPct", "speedPct", "reach"?}], squad.plainWeight = 보통 졸병의 비중.
static func minion_types(cfg: Dictionary, run_seed: int, wave: int, count: int) -> Array:
	var squad: Dictionary = cfg["squad"]
	var pool: Array = [""]
	var weights: Array = [maxi(1, int(squad.get("plainWeight", 1)))]
	for row: Dictionary in squad.get("minionTypes", []):
		if wave >= int(row.get("fromWave", 1)) and int(row.get("weight", 0)) > 0:
			pool.append(row["id"])
			weights.append(int(row["weight"]))
	var out: Array = []
	if pool.size() == 1:
		out.resize(count)
		out.fill("")
		return out
	var rng: Rng = Rng.new((run_seed ^ Rng.imul(wave, 15485863)) & Rng.M32)
	for i: int in range(count):
		out.append(rng.pick_weighted(pool, weights))
	return out


static func minion_type(cfg: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in cfg["squad"].get("minionTypes", []):
		if row["id"] == id:
			return row
	return {}


## 졸병 count마리가 서는 자리: i번째 졸병의 {"stage", "lane", "order"(그 무리 · 그 줄에서 몇 번째)}.
static func minion_layout(cfg: Dictionary, plan: Dictionary, wave: int, count: int) -> Array:
	var stages: int = stage_count(cfg, wave)
	var lanes: Array = lane_sequence(plan, count)
	var out: Array = []
	out.resize(count)
	var turn: int = 0
	for stage: int in range(stages):
		var placed: Array = [0, 0, 0]
		for i: int in range(stage, count, stages):
			var lane: int = int(lanes[turn])
			turn += 1
			out[i] = {"stage": stage, "lane": lane, "order": int(placed[lane])}
			placed[lane] += 1
	return out


## 전투 전에 보여 줄 줄별 적 수(줄 번호 순): {"minions": 졸병 수, "leaders": 우두머리 수, "types": {종류: 수}}.
static func lane_preview(data: Dictionary, run_seed: int, wave: int) -> Array:
	var cfg: Dictionary = data["waves"]
	var plan: Dictionary = lane_plan(cfg, run_seed, wave)
	var out: Array = []
	for lane: int in range(3):
		out.append({"minions": 0, "leaders": 0, "types": {}})
	var minions: int = 0 if data["minions"].is_empty() else minion_count(cfg, wave)
	var kinds: Array = minion_types(cfg, run_seed, wave, minions)
	var layout: Array = minion_layout(cfg, plan, wave, minions)
	for i: int in range(minions):
		var lane: int = int(layout[i]["lane"])
		out[lane]["minions"] += 1
		if not str(kinds[i]).is_empty():
			out[lane]["types"][kinds[i]] = int(out[lane]["types"].get(kinds[i], 0)) + 1
	var leaders: int = 1 if is_elite(cfg, wave) else leader_count(cfg, wave)
	for i: int in range(leaders):
		out[int(plan["order"][i])]["leaders"] += 1
	return out


## 적 부대: 우두머리 드래곤(1~3) + 졸병 무리. 힘 예산을 둘로 나눠 맞춘다.
static func generate_enemies(
	data: Dictionary, wave: int, rng: Rng, run_seed: int, mods: Dictionary = Calamity.NONE,
) -> Array:
	var cfg: Dictionary = data["waves"]
	var squad: Dictionary = cfg["squad"]
	var specs: Array = data["dragons"].values()
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

	var leaders_wanted: int = leader_count(cfg, wave)
	var leaders: Array = []
	if is_boss(cfg, wave):
		var element: Variant = boss_element(run_seed, wave, GameData.active_elements(data))
		var boss_tier: String = "apex" if wave >= int(squad.get("bossApexFromWave", 9999)) else "t1"
		for spec: Dictionary in specs:
			if spec["tier"] == boss_tier and not spec["elements"].is_empty() and spec["elements"][0] == element:
				leaders.append(_spec_unit(spec, data))
				break
	var tiers: Array = ["base"] if wave <= 5 else ["base", "t2"]
	for band: Dictionary in squad.get("leaderTiers", []):
		if wave >= int(band["from"]):
			tiers = band["tiers"]
	var pool: Array = []
	for spec: Dictionary in specs:
		if spec["tier"] in tiers:
			pool.append(spec)
	while leaders.size() < leaders_wanted:
		leaders.append(_spec_unit(pool[rng.next_int(pool.size())], data))

	var minion_specs: Array = data["minions"].values()
	minion_specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var minions: Array = []
	var kinds: Array = minion_types(cfg, run_seed, wave, 0 if minion_specs.is_empty() else minion_count(cfg, wave))
	if not minion_specs.is_empty():
		for i: int in range(minion_count(cfg, wave)):
			var leader: Dictionary = leaders[rng.next_int(leaders.size())]
			var element: Variant = null if leader["elements"].is_empty() else leader["elements"][0]
			var chosen: Dictionary = minion_specs[0]
			for spec: Dictionary in minion_specs:
				if spec["element"] == element:
					chosen = spec
					break
			minions.append(_minion_unit(chosen, minion_type(cfg, str(kinds[i]))))

	var target: int = enemy_power(cfg, wave, mods)
	var elite: bool = is_elite(cfg, wave)
	var share: int = int(squad.get("eliteLeaderSharePct", squad["leaderSharePct"])) if elite else int(squad["leaderSharePct"])
	var leader_budget: int = target if minions.is_empty() else Rng.fdiv(target * share, 100)
	if elite:
		## 중간 보스는 우두머리 하나가 힘을 거의 다 가진다.
		leaders.resize(1)
		leaders[0]["elite"] = true
	_scale_to(leaders, leader_budget)
	_scale_to(minions, target - leader_budget)

	## 작은 무리(stage): 졸병은 무리마다 고르게, 우두머리는 뒤쪽 무리에. 첫 우두머리(보스)는 마지막 무리.
	var stages: int = stage_count(cfg, wave)
	var plan: Dictionary = lane_plan(cfg, run_seed, wave)
	for i: int in range(leaders.size()):
		leaders[i]["lane"] = int(plan["order"][i])
		leaders[i]["x"] = int(squad["leaderX"]) if i == 0 else int(squad["extraLeaderX"])
		leaders[i]["stage"] = maxi(0, stages - 1 - (i % 2))
	## 졸병: 무리(stage) 순서대로 줄 비중에 맞춰 세운다. 같은 무리의 같은 줄에서는 뒤로 한 칸씩 물러선다.
	var layout: Array = minion_layout(cfg, plan, wave, minions.size())
	for i: int in range(minions.size()):
		var spot: Dictionary = layout[i]
		var base_x: int = int(squad["minionX"]) if int(spot["stage"]) == 0 else int(squad.get("lateMinionX", squad["minionX"]))
		minions[i]["stage"] = spot["stage"]
		minions[i]["lane"] = spot["lane"]
		minions[i]["x"] = mini(1000, base_x + int(spot["order"]) * int(squad["minionSpacingX"]))
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


## kind_spec = 졸병 종류(방패병 · 돌격병 · 궁병). 비어 있으면 보통 졸병.
static func _minion_unit(spec: Dictionary, kind_spec: Dictionary = {}) -> Dictionary:
	return {
		"kind": "minion", "id": spec["id"], "elements": [spec["element"]],
		"hp": maxi(1, Rng.fdiv(int(spec["hp"]) * int(kind_spec.get("hpPct", 100)), 100)),
		"atk": maxi(1, Rng.fdiv(int(spec["atk"]) * int(kind_spec.get("atkPct", 100)), 100)),
		"cooldownTicks": int(spec["cooldownTicks"]),
		"speed": maxi(1, Rng.fdiv(int(spec["speed"]) * int(kind_spec.get("speedPct", 100)), 100)),
		"lane": 0, "x": 0, "stage": 0, "type": str(kind_spec.get("id", "")), "reach": int(kind_spec.get("reach", 0)),
	}


static func _spec_unit(spec: Dictionary, data: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = spec["stats"]
	return {
		"ability": "" if data.is_empty() else Battle.ability_of(data, spec["id"]),
		"kind": "dragon", "id": spec["id"],
		"elements": spec["elements"].duplicate(),
		"role": spec.get("role", ""),
		"tier": spec.get("tier", ""),
		"hp": int(stats["hp"]),
		"atk": int(stats["atk"]),
		"cooldownTicks": int(stats["cooldownTicks"]),
		"speed": 0, "lane": 0, "x": 0, "stage": 0,
	}
