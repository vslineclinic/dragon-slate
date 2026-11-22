extends TestCase

var _data: Dictionary = GameData.load_all()


func test_load_all_maps_ids_and_keeps_the_data_shape() -> void:
	assert_eq(_data.keys(), [
		"dragons", "traits", "recipes", "slot", "waves", "battle", "rewards", "bosses", "calamity",
	])
	for key: String in ["dragons", "traits"]:
		var entries: Array = TestCase.load_json("res://data/" + key + ".json")
		assert_eq(_data[key].size(), entries.size())
		for entry: Dictionary in entries:
			assert_eq(_data[key].get(entry["id"]), entry)
	for key: String in ["recipes", "slot", "waves", "battle", "rewards", "bosses", "calamity"]:
		assert_eq(_data[key], TestCase.load_json("res://data/" + key + ".json"))
	assert_eq(typeof(_data["waves"]["basePower"]), TYPE_INT)
	assert_eq(GameData.active_elements(_data), ["fire", "ice", "lightning", "poison", "steel", "abyss"])


func test_calamity_zero_changes_nothing() -> void:
	assert_eq(Calamity.mods(_data, 0), {
		"enemyPowerPct": 0, "bossPowerPct": 0, "winManaPct": 0, "rerollCostAdd": 0, "startLivesAdd": 0,
	})


func test_level_one_raises_enemy_power_fifteen_percent() -> void:
	var cfg: Dictionary = _data["waves"]
	assert_eq(Waves.enemy_power(cfg, 3, Calamity.mods(_data, 1)),
		Rng.fdiv(Waves.enemy_power(cfg, 3) * 115, 100))


func test_levels_stack() -> void:
	assert_eq(Calamity.mods(_data, 5), {
		"enemyPowerPct": 30, "bossPowerPct": 25, "winManaPct": -20,
		"rerollCostAdd": 1, "startLivesAdd": -1,
	})


func test_boss_power_adds_on_boss_waves_only() -> void:
	var cfg: Dictionary = _data["waves"]
	var mods: Dictionary = Calamity.mods(_data, 3)
	assert_eq(Waves.enemy_power(cfg, 5, mods),
		Rng.fdiv(Rng.fdiv(Waves.enemy_power(cfg, 5) * 115, 100) * 125, 100))
	assert_eq(Waves.enemy_power(cfg, 4, mods), Rng.fdiv(Waves.enemy_power(cfg, 4) * 115, 100))
