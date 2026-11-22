extends TestCase

const Fixture = preload("res://godot/tests/test_slot.gd")
const ELEMENTS: Array = ["fire", "ice", "lightning", "poison", "steel", "abyss"]

var _cfg: Dictionary = Fixture.mini_data()["battle"]
var _real: Dictionary = TestCase.load_json("res://data/battle.json")


static func _unit(element: String, hp: int, atk: int, cd: int = 10, lifesteal_pct: int = 0) -> Dictionary:
	return {
		"speciesId": "x", "elements": [element], "hp": hp,
		"atk": atk, "cooldownTicks": cd, "lifestealPct": lifesteal_pct,
	}


static func _ally_attacks(result: Dictionary) -> Array:
	var attacks: Array = []
	for event: Dictionary in result["events"]:
		if event["kind"] == "attack" and event["side"] == "ally":
			attacks.append(event)
	return attacks


func test_fire_beats_ice_at_135_percent() -> void:
	assert_eq(Battle.element_mult(_cfg, "fire", "ice"), 135)
	assert_eq(Battle.element_mult(_cfg, "ice", "lightning"), 135)
	assert_eq(Battle.element_mult(_cfg, "lightning", "fire"), 135)
	assert_eq(Battle.element_mult(_cfg, "fire", "fire"), 100)


func test_ice_versus_fire_is_75_percent() -> void:
	assert_eq(Battle.element_mult(_cfg, "ice", "fire"), 75)


func test_first_hit_uses_element_multiplier_and_floor() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, [_unit("fire", 100, 10)], [_unit("ice", 1000, 1, 1000)])
	var attacks: Array = _ally_attacks(result)
	assert_true(not attacks.is_empty())
	if attacks.is_empty():
		return
	assert_eq(attacks[0], {
		"tick": 10, "kind": "attack", "side": "ally", "src": 0, "dst": 0,
		"dmg": 13, "mult": 135, "heal": 0,
	})


func test_targets_front_row_first() -> void:
	var enemies: Array = [null, null, _unit("fire", 50, 1, 1000), _unit("fire", 50, 1, 1000)]
	var result: Dictionary = Battle.simulate_battle(_cfg, [_unit("fire", 100, 10)], enemies)
	var attacks: Array = _ally_attacks(result)
	assert_true(not attacks.is_empty())
	if not attacks.is_empty():
		assert_eq(attacks[0]["dst"], 2)


func test_timeout_is_enemy_win() -> void:
	var units: Array = [_unit("fire", 10000, 1, 100)]
	var result: Dictionary = Battle.simulate_battle(_cfg, units, units)
	assert_eq(result["winner"], "enemy")
	assert_eq(result["ticks"], _cfg["maxTicks"])


func test_lifesteal_heals_up_to_max_hp() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, [_unit("fire", 100, 20, 10, 50)], [_unit("fire", 1000, 30, 15)])
	var heals: Array = _ally_attacks(result)
	assert_true(heals.size() >= 2)
	if heals.size() >= 2:
		assert_eq(heals[0]["heal"], 0)
		assert_eq(heals[1]["heal"], 10)


func test_haste_shortens_cooldown_with_floor_five() -> void:
	var data: Dictionary = Fixture.mini_data()
	data["traits"]["tr_haste"] = {"id": "tr_haste", "nameKo": "h", "kind": "hastePct", "value": 99}
	var inst: Dictionary = {"uid": 1, "speciesId": "fire_drake", "traits": ["tr_haste"], "bonusPct": 0}
	assert_eq(Battle.to_unit(data, inst)["cooldownTicks"], 5)


func test_to_unit_applies_bonus_and_stat_traits() -> void:
	var data: Dictionary = Fixture.mini_data()
	data["traits"]["tr_hp"] = {"id": "tr_hp", "nameKo": "h", "kind": "hpPct", "value": 20}
	data["traits"]["tr_ls"] = {"id": "tr_ls", "nameKo": "l", "kind": "lifestealPct", "value": 15}
	var inst: Dictionary = {"uid": 1, "speciesId": "fire_drake", "traits": ["tr_hp", "tr_ls"], "bonusPct": 10}
	assert_eq(Battle.to_unit(data, inst), {
		"speciesId": "fire_drake", "elements": ["fire"], "hp": 169, "atk": 9,
		"cooldownTicks": 20, "lifestealPct": 15,
	})


func test_identical_input_produces_identical_events() -> void:
	var allies: Array = [_unit("fire", 300, 12), _unit("ice", 200, 15, 13)]
	var enemies: Array = [_unit("lightning", 250, 11, 9), _unit("ice", 220, 14, 17)]
	var a: Dictionary = Battle.simulate_battle(_cfg, allies, enemies)
	var b: Dictionary = Battle.simulate_battle(_cfg, allies, enemies)
	assert_eq(JSON.stringify(a, "", false), JSON.stringify(b, "", false))


func test_death_event_is_emitted_once() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, [_unit("fire", 100, 50, 5)], [_unit("fire", 60, 1, 1000)])
	var deaths: Array = []
	for event: Dictionary in result["events"]:
		if event["kind"] == "death":
			deaths.append(event)
	assert_eq(deaths, [{"tick": 10, "kind": "death", "side": "enemy", "idx": 0}])
	assert_eq(result["winner"], "ally")


func test_six_element_beats_table_is_balanced() -> void:
	for atk: String in ELEMENTS:
		var wins: int = 0
		var losses: int = 0
		for def: String in ELEMENTS:
			var mult: int = Battle.element_mult(_real, atk, def)
			if mult == _real["strongPct"]:
				wins += 1
				assert_eq(Battle.element_mult(_real, def, atk), _real["weakPct"])
			elif mult == _real["weakPct"]:
				losses += 1
		assert_eq([atk, wins, losses], [atk, 2, 2])


func test_six_element_table_preserves_original_triangle() -> void:
	assert_eq(Battle.element_mult(_real, "fire", "ice"), 135)
	assert_eq(Battle.element_mult(_real, "ice", "lightning"), 135)
	assert_eq(Battle.element_mult(_real, "lightning", "fire"), 135)


func test_six_element_table_has_neutral_pairs() -> void:
	assert_eq(Battle.element_mult(_real, "fire", "poison"), 100)
	assert_eq(Battle.element_mult(_real, "ice", "abyss"), 100)
	assert_eq(Battle.element_mult(_real, "lightning", "steel"), 100)
