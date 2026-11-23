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


func test_squad_total_power_within_ten_percent_of_target() -> void:
	var data: Dictionary = _data()
	for wave: int in [1, 3, 6, 9]:
		var units: Array = Waves.generate_enemies(data, wave, Rng.new(wave), 77)
		var total: int = 0
		for unit: Dictionary in units:
			total += Waves.unit_power(unit)
		var target: int = Waves.enemy_power(data["waves"], wave)
		assert_true(absi(total - target) * 10 < target, "wave %d total %d target %d" % [wave, total, target])


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
