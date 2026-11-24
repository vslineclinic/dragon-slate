extends TestCase

const Fixture = preload("res://godot/tests/test_slot.gd")
const EL3: Array = ["fire", "ice", "lightning"]


static func _data() -> Dictionary:
	var data: Dictionary = Fixture.mini_data()
	for extra: Array in [
		["zhulong", "t1", "fire"],
		["kuraokami", "t1", "ice"],
		["yinglong", "t1", "lightning"],
		["palraiyuk", "t2", "ice"],
	]:
		var id: String = extra[0]
		data["dragons"][id] = {
			"id": id, "nameKo": id, "tier": extra[1], "elements": [extra[2]],
			"role": "support", "stats": {"hp": 480, "atk": 48, "cooldownTicks": 18},
			"traitId": "tr_ember",
		}
	return data


func test_power_for_waves_one_through_three() -> void:
	var cfg: Dictionary = _data()["waves"]
	assert_eq(Waves.enemy_power(cfg, 1), 100)
	assert_eq(Waves.enemy_power(cfg, 2), 118)
	assert_eq(Waves.enemy_power(cfg, 3), 139)


func test_boss_wave_five_applies_165_percent() -> void:
	assert_eq(Waves.enemy_power(_data()["waves"], 5), 318)


func test_only_five_and_ten_are_bosses_within_max_wave_ten() -> void:
	var cfg: Dictionary = _data()["waves"]
	var bosses: Array = []
	for wave: int in range(1, 21):
		if Waves.is_boss(cfg, wave):
			bosses.append(wave)
	assert_eq(bosses, [5, 10])


func test_boss_element_is_stable_per_seed() -> void:
	assert_eq(Waves.boss_element(123, 5, EL3), Waves.boss_element(123, 5, EL3))
	var seen: Dictionary = {}
	for run_seed: int in range(1, 51):
		seen[Waves.boss_element(run_seed, 10, EL3)] = true
	assert_eq(seen.size(), 3)


func test_squad_total_power_within_fifteen_percent_of_target() -> void:
	var data: Dictionary = _data()
	for wave: int in [1, 3, 6, 9]:
		var units: Array = Waves.generate_enemies(data, wave, Rng.new(wave), 77)
		var total: int = 0
		for unit: Dictionary in units:
			total += Waves.unit_power(unit)
		var target: int = Waves.enemy_power(data["waves"], wave)
		assert_true(absi(total - target) * 100 < target * 15, "wave %d total %d target %d" % [wave, total, target])


static func _count(units: Array, kind: String) -> int:
	return units.filter(func(u: Dictionary) -> bool: return u["kind"] == kind).size()


func test_squad_minion_count_grows_and_caps() -> void:
	var data: Dictionary = _data()
	var squad: Dictionary = data["waves"]["squad"]
	for wave: int in [1, 4, 9, 30]:
		var units: Array = Waves.generate_enemies(data, wave, Rng.new(wave), 3)
		assert_eq(_count(units, "minion"), mini(int(squad["minionBase"]) + Rng.fdiv(wave, 2), int(squad["minionMax"])))


func test_leader_count_by_wave() -> void:
	var data: Dictionary = _data()
	var counts: Array = []
	for wave: int in [1, 7, 8, 13, 14]:
		counts.append(_count(Waves.generate_enemies(data, wave, Rng.new(wave), 3), "dragon"))
	assert_eq(counts, [1, 1, 2, 2, 3])


func test_minions_take_a_leader_element_and_spread_over_lanes() -> void:
	var data: Dictionary = _data()
	var units: Array = Waves.generate_enemies(data, 6, Rng.new(6), 9)
	var leader_elements: Array = []
	var lanes: Dictionary = {}
	for unit: Dictionary in units:
		if unit["kind"] == "dragon":
			leader_elements.append(unit["elements"][0])
	for unit: Dictionary in units:
		if unit["kind"] == "minion":
			assert_true(unit["elements"][0] in leader_elements)
			assert_true(unit["speed"] > 0)
			lanes[unit["lane"]] = true
	assert_eq(lanes.size(), 3)


func test_early_waves_only_use_base_species() -> void:
	var data: Dictionary = _data()
	for unit: Dictionary in Waves.generate_enemies(data, 4, Rng.new(4), 1):
		if unit["kind"] == "dragon":
			assert_eq(data["dragons"][unit["id"]]["tier"], "base")


func test_boss_first_leader_is_t1_of_boss_element() -> void:
	var data: Dictionary = _data()
	var units: Array = Waves.generate_enemies(data, 10, Rng.new(1), 42)
	var spec: Dictionary = data["dragons"][units[0]["id"]]
	assert_eq(spec["tier"], "t1")
	assert_eq(spec["elements"][0], Waves.boss_element(42, 10, EL3))


func test_enemies_are_split_into_stages_with_first_leader_last() -> void:
	var data: Dictionary = _data()
	var squad: Dictionary = data["waves"]["squad"]
	for wave: int in [1, 5, 9]:
		var units: Array = Waves.generate_enemies(data, wave, Rng.new(wave), 3)
		var stages: int = int(squad["stages"]) if wave >= int(squad["stagesFromWave"]) else int(squad["stagesEarly"])
		var seen: Dictionary = {}
		for unit: Dictionary in units:
			seen[unit["stage"]] = true
		assert_eq(seen.size(), stages)
		assert_eq(units[0]["kind"], "dragon")
		assert_eq(units[0]["stage"], stages - 1)


func test_early_wave_pct_softens_only_listed_waves() -> void:
	var cfg: Dictionary = _data()["waves"].duplicate(true)
	cfg["earlyPct"] = {"1": 50}
	assert_eq(Waves.enemy_power(cfg, 1), 50)
	assert_eq(Waves.enemy_power(cfg, 2), 118)


func test_elite_wave_has_one_strong_leader() -> void:
	var data: Dictionary = GameData.load_all()
	var cfg: Dictionary = data["waves"]
	assert_true(Waves.is_elite(cfg, 7))
	assert_true(not Waves.is_elite(cfg, 5) and not Waves.is_elite(cfg, 6))
	var plain: Dictionary = cfg.duplicate(true)
	plain["elitePct"] = {}
	assert_eq(Waves.enemy_power(cfg, 7), Rng.fdiv(Waves.enemy_power(plain, 7) * int(cfg["elitePct"]["7"]), 100))
	var enemies: Array = Waves.generate_enemies(data, 17, Rng.new(5), 5)
	var leaders: Array = enemies.filter(func(unit: Dictionary) -> bool: return unit["kind"] == "dragon")
	assert_eq(leaders.size(), 1)
	assert_eq(leaders[0].get("elite", false), true)


## 줄 편성을 켠 자료: 졸병이 줄마다 3:2:1로 몰린다.
static func _lane_data() -> Dictionary:
	var data: Dictionary = _data()
	data["waves"]["squad"]["lanePatterns"] = [{"from": 1, "weights": [3, 2, 1]}]
	return data


static func _lane_counts(enemies: Array, kind: String) -> Array:
	var counts: Array = [0, 0, 0]
	for enemy: Dictionary in enemies:
		if (enemy["kind"] == "minion") == (kind == "minion"):
			counts[int(enemy["lane"])] += 1
	return counts


func test_lane_plan_is_a_stable_permutation_of_the_three_lanes() -> void:
	var cfg: Dictionary = _lane_data()["waves"]
	var seen: Dictionary = {}
	for wave: int in range(1, 31):
		var plan: Dictionary = Waves.lane_plan(cfg, 77, wave)
		var order: Array = plan["order"].duplicate()
		assert_eq(plan, Waves.lane_plan(cfg, 77, wave))
		seen[str(order)] = true
		order.sort()
		assert_eq(order, [0, 1, 2])
		for i: int in range(3):
			assert_eq(int(plan["weights"][int(plan["order"][i])]), [3, 2, 1][i])
	assert_true(seen.size() >= 4, "웨이브마다 몰리는 줄이 달라진다")


func test_lane_plan_is_even_without_patterns() -> void:
	var plan: Dictionary = Waves.lane_plan(_data()["waves"], 77, 3)
	assert_eq(plan["weights"], [1, 1, 1])
	assert_eq(plan["order"], [1, 0, 2])


func test_minions_crowd_the_heavy_lane_and_leaders_follow_the_plan() -> void:
	var data: Dictionary = _lane_data()
	for wave: int in [2, 9, 14, 26]:
		var plan: Dictionary = Waves.lane_plan(data["waves"], 5, wave)
		var enemies: Array = Waves.generate_enemies(data, wave, Rng.new(wave), 5)
		var minions: Array = _lane_counts(enemies, "minion")
		var heavy: int = int(plan["order"][0])
		var light: int = int(plan["order"][2])
		assert_true(int(minions[heavy]) > int(minions[light]), "웨이브 %d: %s" % [wave, str(minions)])
		var leaders: Array = enemies.filter(func(e: Dictionary) -> bool: return e["kind"] == "dragon")
		for i: int in range(leaders.size()):
			assert_eq(int(leaders[i]["lane"]), int(plan["order"][i]), "우두머리 %d" % i)


func test_lane_preview_matches_the_generated_squad() -> void:
	var data: Dictionary = _lane_data()
	for seed: int in [1, 5, 9]:
		for wave: int in range(1, 31):
			var enemies: Array = Waves.generate_enemies(data, wave, Rng.new(seed * 100 + wave), seed)
			var preview: Array = Waves.lane_preview(data, seed, wave)
			var minions: Array = _lane_counts(enemies, "minion")
			var leaders: Array = _lane_counts(enemies, "dragon")
			for lane: int in range(3):
				assert_eq(int(preview[lane]["minions"]), int(minions[lane]), "씨앗 %d 웨이브 %d 줄 %d 졸병" % [seed, wave, lane])
				assert_eq(int(preview[lane]["leaders"]), int(leaders[lane]), "씨앗 %d 웨이브 %d 줄 %d 우두머리" % [seed, wave, lane])


func test_minions_in_one_lane_do_not_stand_on_the_same_spot() -> void:
	var data: Dictionary = _lane_data()
	var enemies: Array = Waves.generate_enemies(data, 20, Rng.new(3), 3)
	var spots: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy["kind"] != "minion":
			continue
		var key: String = "%d/%d/%d" % [enemy["stage"], enemy["lane"], enemy["x"]]
		assert_true(not spots.has(key), key)
		spots[key] = true


func test_real_waves_use_lane_patterns() -> void:
	var patterns: Array = TestCase.load_json("res://data/waves.json")["squad"]["lanePatterns"]
	assert_true(patterns.size() >= 2)
	for pattern: Dictionary in patterns:
		assert_eq(pattern["weights"].size(), 3)
		assert_true(int(pattern["weights"][0]) > int(pattern["weights"][2]))
