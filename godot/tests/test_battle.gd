extends TestCase

const Fixture = preload("res://godot/tests/test_slot.gd")
const ELEMENTS: Array = ["fire", "ice", "lightning", "poison", "steel", "abyss"]

var _cfg: Dictionary = Fixture.mini_data()["battle"]
var _real: Dictionary = TestCase.load_json("res://data/battle.json")


## 아군 드래곤(to_unit 모양). tier에 따라 호위 수가 정해진다.
static func _ally(element: String, hp: int, atk: int, cd: int = 10, lifesteal_pct: int = 0, tier: String = "base") -> Dictionary:
	return {
		"speciesId": "x", "tier": tier, "elements": [element], "hp": hp,
		"atk": atk, "cooldownTicks": cd, "lifestealPct": lifesteal_pct,
	}


## 호위 없는 드래곤(1:1 숨결만 볼 때). escort.count에 없는 등급이라 호위 0.
static func _solo(element: String, hp: int, atk: int, cd: int = 10, lifesteal_pct: int = 0) -> Dictionary:
	return _ally(element, hp, atk, cd, lifesteal_pct, "none")


static func _enemy(kind: String, element: String, hp: int, atk: int, cd: int, lane: int, x: int, speed: int = 0) -> Dictionary:
	return {
		"kind": kind, "id": kind + "_" + element, "elements": [element], "hp": hp,
		"atk": atk, "cooldownTicks": cd, "speed": speed, "lane": lane, "x": x,
	}


static func _slots(front: Array = [], back: Array = []) -> Array:
	var nest: Array = [null, null, null, null, null, null]
	for i: int in range(front.size()):
		nest[i] = front[i]
	for i: int in range(back.size()):
		nest[3 + i] = back[i]
	return nest


static func _of_kind(result: Dictionary, kind: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


static func _unit_by_id(result: Dictionary, id: int) -> Dictionary:
	for unit: Dictionary in result["units"]:
		if unit["id"] == id:
			return unit
	return {}


func test_fire_beats_ice_at_135_percent() -> void:
	assert_eq(Battle.element_mult(_cfg, "fire", "ice"), 135)
	assert_eq(Battle.element_mult(_cfg, "ice", "lightning"), 135)
	assert_eq(Battle.element_mult(_cfg, "lightning", "fire"), 135)
	assert_eq(Battle.element_mult(_cfg, "fire", "fire"), 100)


func test_ice_versus_fire_is_75_percent() -> void:
	assert_eq(Battle.element_mult(_cfg, "ice", "fire"), 75)


func test_first_breath_uses_element_multiplier_and_floor() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100, 10)]),
		[_enemy("dragon", "ice", 1000, 1, 1000, 0, 900)])
	var attacks: Array = _of_kind(result, "attack")
	assert_true(not attacks.is_empty())
	if not attacks.is_empty():
		assert_eq(attacks[0], {"tick": 10, "kind": "attack", "src": 0, "dst": 1, "dmg": 13, "mult": 135, "heal": 0})


func test_dragon_targets_nearest_enemy() -> void:
	var enemies: Array = [_enemy("dragon", "fire", 500, 1, 1000, 0, 860), _enemy("minion", "fire", 500, 1, 1000, 0, 700)]
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100, 10)]), enemies)
	var attacks: Array = _of_kind(result, "attack")
	assert_true(not attacks.is_empty())
	if not attacks.is_empty():
		assert_eq(_unit_by_id(result, attacks[0]["dst"])["kind"], "minion")


func test_back_row_only_dragon_still_finishes_battle() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([], [_solo("fire", 300, 20)]),
		[_enemy("dragon", "fire", 200, 5, 20, 2, 900)])
	assert_eq(result["winner"], "ally")
	assert_true(result["ticks"] < _cfg["maxTicks"])


func test_escort_count_by_tier() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg,
		_slots([_ally("fire", 100, 10), _ally("ice", 100, 10, 10, 0, "t1")]),
		[_enemy("dragon", "fire", 1, 1, 1000, 0, 900)])
	var escorts: Dictionary = {}
	for unit: Dictionary in result["units"]:
		if unit["kind"] == "escort":
			escorts[unit["owner"]] = escorts.get(unit["owner"], 0) + 1
	assert_eq(escorts.values(), [2, 4])


func test_escort_stats_follow_owner() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_ally("fire", 200, 20)]),
		[_enemy("dragon", "fire", 1, 1, 1000, 0, 900)])
	var escort: Dictionary = result["units"][1]
	var expected_x: int = int(_cfg["field"]["frontX"]) + int(_cfg["escort"]["offsetX"])
	assert_eq([escort["kind"], escort["owner"], escort["hp"], escort["lane"], escort["x"]],
		["escort", 0, Rng.fdiv(200 * int(_cfg["escort"]["hpPct"]), 100), 0, expected_x])


func test_melee_needs_same_lane_so_walker_changes_lane() -> void:
	var minion: Dictionary = _enemy("minion", "fire", 400, 1, 1000, 1, 330, 4)
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 5000, 1, 1000)]), [minion])
	var lane_moves: Array = []
	for event: Dictionary in _of_kind(result, "pos"):
		for id: Variant in event["lanes"]:
			if _unit_by_id(result, int(id))["kind"] == "minion" and event["lanes"][id] == 0:
				lane_moves.append(event["tick"])
	assert_true(not lane_moves.is_empty())
	var minion_hits: Array = _of_kind(result, "attack").filter(func(e: Dictionary) -> bool:
		return _unit_by_id(result, e["src"])["kind"] == "minion")
	assert_true(not minion_hits.is_empty())
	if not minion_hits.is_empty() and not lane_moves.is_empty():
		assert_true(minion_hits[0]["tick"] >= lane_moves[0] - int(_cfg["field"]["posEveryTicks"]))


func test_escorts_die_with_owner() -> void:
	var rules: Dictionary = {"burn": {"everyTicks": 3, "pct": 100}}
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_ally("fire", 20, 1, 1000)]),
		[_enemy("dragon", "fire", 9000, 1, 1000, 0, 900)], rules)
	var deaths: Array = _of_kind(result, "death")
	var owner_deaths: Array = deaths.filter(func(e: Dictionary) -> bool: return e["id"] == 0)
	var followers: Array = deaths.filter(func(e: Dictionary) -> bool: return e["cause"] == "owner")
	assert_eq(owner_deaths.size(), 1)
	assert_eq(followers.size(), 2)
	if owner_deaths.size() == 1:
		for event: Dictionary in followers:
			assert_eq(event["tick"], owner_deaths[0]["tick"])
	assert_eq(result["winner"], "enemy")


func test_timeout_is_enemy_win() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100000, 1, 100)]),
		[_enemy("dragon", "fire", 100000, 1, 100, 0, 900)])
	assert_eq(result["winner"], "enemy")
	assert_eq(result["ticks"], _cfg["maxTicks"])


func test_lifesteal_heals_up_to_max_hp() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100, 20, 10, 50)]),
		[_enemy("dragon", "fire", 1000, 30, 15, 0, 900)])
	var heals: Array = _of_kind(result, "attack").filter(func(e: Dictionary) -> bool: return e["src"] == 0)
	assert_true(heals.size() >= 2)
	if heals.size() >= 2:
		assert_eq(heals[0]["heal"], 0)
		assert_eq(heals[1]["heal"], 10)


func test_burn_hits_lowest_hp_dragon_only() -> void:
	var rules: Dictionary = {"burn": {"everyTicks": 3, "pct": 10}}
	var result: Dictionary = Battle.simulate_battle(_cfg,
		_slots([_ally("fire", 500, 1, 1000), _ally("ice", 300, 1, 1000)]),
		[_enemy("dragon", "fire", 100000, 1, 1000, 0, 900)], rules)
	var hits: Array = _of_kind(result, "hazard")
	assert_true(not hits.is_empty())
	if not hits.is_empty():
		var victim: Dictionary = _unit_by_id(result, hits[0]["id"])
		assert_eq([victim["kind"], victim["slot"]], ["dragon", 1])


func test_row_blast_hits_row_dragons_and_their_escorts() -> void:
	var rules: Dictionary = {"rowBlast": {"everyTicks": 3, "pct": 10}}
	var result: Dictionary = Battle.simulate_battle(_cfg,
		_slots([_ally("fire", 500, 1, 1000)], [_ally("ice", 500, 1, 1000)]),
		[_enemy("dragon", "fire", 100000, 1, 1000, 0, 900)], rules)
	var first_tick: Array = _of_kind(result, "hazard").filter(func(e: Dictionary) -> bool: return e["tick"] == 3)
	var slots: Array = []
	for event: Dictionary in first_tick:
		slots.append(_unit_by_id(result, event["id"])["slot"])
	assert_eq(slots, [0, 0, 0])


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
		"speciesId": "fire_drake", "tier": "base", "elements": ["fire"], "hp": 169, "atk": 9,
		"cooldownTicks": 20, "lifestealPct": 15,
	})


func test_identical_input_produces_identical_events() -> void:
	var allies: Array = _slots([_ally("fire", 300, 12)], [_ally("ice", 200, 15, 13)])
	var enemies: Array = [_enemy("dragon", "lightning", 250, 11, 9, 1, 860), _enemy("minion", "ice", 120, 6, 14, 0, 700, 5)]
	var a: Dictionary = Battle.simulate_battle(_cfg, allies, enemies)
	var b: Dictionary = Battle.simulate_battle(_cfg, allies, enemies)
	assert_eq(JSON.stringify(a, "", false), JSON.stringify(b, "", false))


func test_death_event_is_emitted_once_per_unit() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_ally("fire", 300, 20)]),
		[_enemy("dragon", "fire", 200, 5, 20, 0, 860), _enemy("minion", "ice", 60, 3, 14, 0, 700, 5)])
	var seen: Dictionary = {}
	for event: Dictionary in _of_kind(result, "death"):
		assert_true(not seen.has(event["id"]))
		seen[event["id"]] = true


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
