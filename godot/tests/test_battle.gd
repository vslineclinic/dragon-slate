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
		"cooldownTicks": 20, "lifestealPct": 15, "escortBonus": 0, "escortPct": 0,
	})


func test_skills_raise_stats_and_escorts() -> void:
	var data: Dictionary = Fixture.mini_data()
	var inst: Dictionary = {
		"uid": 1, "speciesId": "fire_drake", "traits": [], "bonusPct": 0,
		"skills": {"fang": 2, "scale": 1, "pack": 1, "alpha": 2}, "skillPoints": 0,
	}
	var plain: Dictionary = Battle.to_unit(data, {"uid": 2, "speciesId": "fire_drake", "traits": [], "bonusPct": 0})
	var unit: Dictionary = Battle.to_unit(data, inst)
	assert_true(unit["hp"] > plain["hp"])
	assert_eq([unit["escortBonus"], unit["escortPct"]], [1, 50])
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([unit]), [_enemy("dragon", "fire", 1, 1, 1000, 0, 900)])
	var escorts: Array = result["units"].filter(func(u: Dictionary) -> bool: return u["kind"] == "escort")
	assert_eq(escorts.size(), 3)
	assert_eq(escorts[0]["hp"], Rng.fdiv(int(unit["hp"]) * int(_cfg["escort"]["hpPct"]) * 150, 10000))
	assert_true(plain["atk"] < unit["atk"])


func test_later_stage_waits_until_first_group_dies() -> void:
	var first: Dictionary = _enemy("minion", "fire", 30, 1, 1000, 0, 700, 5)
	var second: Dictionary = _enemy("dragon", "fire", 60, 1, 1000, 0, 860)
	second["stage"] = 1
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 500, 20)]), [first, second])
	var stage_events: Array = _of_kind(result, "stage")
	assert_eq(stage_events.size(), 1)
	var first_death: int = _of_kind(result, "death")[0]["tick"]
	assert_true(stage_events[0]["tick"] > first_death)
	for attack: Dictionary in _of_kind(result, "attack"):
		if attack["dst"] == 2:
			assert_true(attack["tick"] >= stage_events[0]["tick"])
	assert_eq(result["winner"], "ally")


func test_stage_timer_brings_next_group_even_if_first_survives() -> void:
	var first: Dictionary = _enemy("dragon", "fire", 100000, 1, 1000, 0, 860)
	var second: Dictionary = _enemy("dragon", "fire", 100000, 1, 1000, 1, 900)
	second["stage"] = 1
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100000, 1, 1000)]), [first, second])
	var stage_events: Array = _of_kind(result, "stage")
	assert_eq(stage_events.size(), 1)
	assert_eq(stage_events[0]["tick"], int(_cfg["field"]["stageTicks"]))


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


const SYNERGIES: Array = [
	{"element": "fire", "nameKo": "불길", "kind": "atkPct", "levels": [{"count": 2, "value": 50}, {"count": 4, "value": 100}]},
	{"element": "ice", "nameKo": "서리", "kind": "escortCount", "levels": [{"count": 2, "value": 1}]},
]


static func _inst(species: String) -> Dictionary:
	return {"uid": 1, "speciesId": species, "traits": [], "bonusPct": 0}


static func _synergy_data() -> Dictionary:
	var data: Dictionary = Fixture.mini_data()
	data["synergies"] = SYNERGIES
	return data


func test_one_dragon_shows_progress_but_no_synergy() -> void:
	var found: Array = Battle.synergies(_synergy_data(), [_inst("fire_drake")])
	assert_eq(found.size(), 1)
	assert_eq([found[0]["element"], found[0]["count"], found[0]["level"], found[0]["value"], found[0]["nextCount"]], ["fire", 1, 0, 0, 2])


func test_synergy_level_follows_dragon_count() -> void:
	var data: Dictionary = _synergy_data()
	var two: Array = Battle.synergies(data, [_inst("fire_drake"), _inst("fire_wyvern"), null])
	assert_eq([two[0]["level"], two[0]["value"], two[0]["nextCount"]], [1, 50, 4])
	var four: Array = Battle.synergies(data, [_inst("fire_drake"), _inst("fire_drake"), _inst("fire_wyvern"), _inst("fire_wyvern")])
	assert_eq([four[0]["level"], four[0]["value"], four[0]["nextCount"]], [2, 100, 0])


func test_team_applies_synergy_to_every_dragon() -> void:
	var data: Dictionary = _synergy_data()
	var plain: Dictionary = Battle.to_unit(data, _inst("ice_drake"))
	var nest: Array = [_inst("fire_drake"), _inst("fire_wyvern"), _inst("ice_drake"), null, null, null]
	var team: Array = Battle.team(data, nest, 3)
	assert_eq(team.size(), 6)
	assert_eq(team[2]["atk"], Rng.fdiv(int(plain["atk"]) * 150, 100))
	assert_eq(team[3], null)


func test_team_ignores_locked_slots() -> void:
	var data: Dictionary = _synergy_data()
	var nest: Array = [_inst("fire_drake"), null, null, _inst("fire_wyvern"), null, null]
	var team: Array = Battle.team(data, nest, 3)
	assert_eq(team[3], null)
	assert_eq(team[0]["atk"], Battle.to_unit(data, _inst("fire_drake"))["atk"])


func test_escort_synergy_adds_escorts() -> void:
	var data: Dictionary = _synergy_data()
	var team: Array = Battle.team(data, [_inst("ice_drake"), _inst("ice_wyvern"), null, null, null, null], 3)
	assert_eq(team[0]["escortBonus"], 1)


func test_real_synergy_table_covers_six_elements() -> void:
	var table: Array = TestCase.load_json("res://data/synergies.json")
	var seen: Array = []
	for row: Dictionary in table:
		seen.append(row["element"])
		assert_true(int(row["levels"][0]["count"]) < int(row["levels"][1]["count"]))
		assert_true(int(row["levels"][0]["value"]) < int(row["levels"][1]["value"]))
	assert_eq(seen, ELEMENTS)


func test_level_raises_stats_by_stat_pct() -> void:
	var data: Dictionary = Fixture.mini_data()
	data["battle"]["level"] = {"statPct": 10}
	var plain: Dictionary = Battle.to_unit(data, _inst("fire_drake"))
	var grown: Dictionary = _inst("fire_drake")
	grown["level"] = 6
	var unit: Dictionary = Battle.to_unit(data, grown)
	assert_eq(unit["hp"], Rng.fdiv(int(plain["hp"]) * 150, 100))
	assert_eq(unit["atk"], Rng.fdiv(int(plain["atk"]) * 150, 100))


func test_team_adds_extra_bonus_from_relics() -> void:
	var data: Dictionary = _synergy_data()
	var plain: Dictionary = Battle.to_unit(data, _inst("ice_drake"))
	var team: Array = Battle.team(data, [_inst("ice_drake"), null, null, null, null, null], 3, {"atkPct": 100, "escortCount": 2})
	assert_true(int(team[0]["atk"]) * 10 >= int(plain["atk"]) * 18)
	assert_eq(team[0]["escortBonus"], 2)


func test_strong_add_only_boosts_ally_advantage_hits() -> void:
	var enemy: Array = [_enemy("dragon", "ice", 100000, 1, 10, 0, 900)]
	var plain: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100000, 100)]), enemy)
	var boosted: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100000, 100)]), enemy, {"strongAddPct": 20})
	var first: Callable = func(result: Dictionary, src: int) -> Dictionary:
		return _of_kind(result, "attack").filter(func(e: Dictionary) -> bool: return e["src"] == src)[0]
	assert_eq(first.call(plain, 0)["dmg"], 135)
	assert_eq(first.call(boosted, 0)["dmg"], 155)
	assert_eq(first.call(boosted, 1)["dmg"], first.call(plain, 1)["dmg"])


static func _ult_cfg() -> Dictionary:
	var cfg: Dictionary = Fixture.mini_data()["battle"]
	cfg["ultimate"] = {"chargeHits": {"none": 3}, "powerPct": {"none": 200}, "targets": {"none": 2}}
	return cfg


func test_third_hit_becomes_an_ultimate_on_two_nearest_enemies() -> void:
	var enemies: Array = [
		_enemy("dragon", "fire", 100000, 1, 1000, 0, 900), _enemy("dragon", "fire", 100000, 1, 1000, 1, 900),
		_enemy("dragon", "fire", 100000, 1, 1000, 2, 990),
	]
	var result: Dictionary = Battle.simulate_battle(_ult_cfg(), _slots([_solo("fire", 100000, 10)]), enemies)
	var mine: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] in ["attack", "ult"] and e["src"] == 0)
	assert_eq([mine[0]["kind"], mine[0]["dmg"], mine[0]["charge"]], ["attack", 10, 1])
	assert_eq([mine[1]["dmg"], mine[1]["charge"]], [10, 2])
	assert_eq(mine[2]["kind"], "ult")
	assert_eq([mine[3]["kind"], mine[3]["dst"], mine[3]["dmg"], mine[3]["ult"], mine[3]["charge"]], ["attack", 1, 20, true, 0])
	assert_eq([mine[4]["dst"], mine[4]["dmg"]], [2, 20])
	assert_eq([mine[5]["kind"], mine[5]["dmg"], mine[5]["charge"]], ["attack", 10, 1])
	assert_eq(result["units"][0]["ultNeed"], 3)


func test_enemies_and_escorts_never_use_ultimates() -> void:
	var cfg: Dictionary = _ult_cfg()
	cfg["ultimate"]["chargeHits"]["base"] = 1
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_ally("fire", 100000, 10)]), [_enemy("dragon", "fire", 100000, 5, 5, 0, 320)])
	for event: Dictionary in _of_kind(result, "ult"):
		assert_eq(_unit_by_id(result, event["src"])["kind"], "dragon")
		assert_eq(_unit_by_id(result, event["src"])["side"], "ally")
	assert_true(_of_kind(result, "ult").size() > 0)


func test_real_ultimate_table_covers_every_tier() -> void:
	var real: Dictionary = TestCase.load_json("res://data/battle.json")
	for tier: String in ["base", "t2", "t1", "apex", "dual", "secret"]:
		for key: String in ["chargeHits", "powerPct", "targets"]:
			assert_true(int(real["ultimate"][key][tier]) > 0, key + " " + tier)
	for element: String in ELEMENTS:
		assert_true(real["ultimate"]["names"].has(element))


func test_dragons_crit_at_the_configured_rate_and_minions_never_do() -> void:
	var cfg: Dictionary = Fixture.mini_data()["battle"]
	cfg["crit"] = {"pct": 100, "dmgPct": 200}
	var enemies: Array = [_enemy("minion", "fire", 100000, 7, 10, 0, 300, 5)]
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 10)]), enemies, {"critSeed": 5})
	for hit: Dictionary in _of_kind(result, "attack"):
		if hit["src"] == 0:
			assert_eq([hit["dmg"], hit.get("crit", false)], [20, true])
		else:
			assert_eq([hit["dmg"], hit.get("crit", false)], [7, false])
	cfg["crit"]["pct"] = 0
	var calm: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 10)]), enemies, {"critSeed": 5})
	assert_true(_of_kind(calm, "attack").all(func(hit: Dictionary) -> bool: return not hit.has("crit")))


func test_crit_rolls_depend_only_on_the_seed() -> void:
	var cfg: Dictionary = Fixture.mini_data()["battle"]
	cfg["crit"] = {"pct": 30, "dmgPct": 200}
	var enemies: Array = [_enemy("dragon", "fire", 3000, 5, 10, 0, 900)]
	var first: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 3000, 10)]), enemies, {"critSeed": 9})
	var again: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 3000, 10)]), enemies, {"critSeed": 9})
	assert_eq(first["events"], again["events"])
	var crits: int = _of_kind(first, "attack").filter(func(hit: Dictionary) -> bool: return hit.get("crit", false)).size()
	assert_true(crits > 0 and crits < _of_kind(first, "attack").size())


func test_star_skills_ride_on_the_unit_only_when_learned() -> void:
	var data: Dictionary = GameData.load_all()
	var plain: Dictionary = Battle.to_unit(data, {"uid": 1, "speciesId": "fire_drake", "traits": [], "bonusPct": 0})
	assert_true(not (plain.has("critPct") or plain.has("guardPct") or plain.has("ultPowerPct") or plain.has("ultCharge")))
	var inst: Dictionary = {
		"uid": 2, "speciesId": "fire_drake", "traits": [], "bonusPct": 0,
		"skills": {"pierce": 3, "ragnarok": 2, "aegis": 2, "roar": 1}, "skillPoints": 0,
	}
	var unit: Dictionary = Battle.to_unit(data, inst)
	assert_eq([unit["critPct"], unit["ultPowerPct"], unit["guardPct"], unit["ultCharge"]], [15, 40, 10, 1])


func test_guard_cuts_damage_taken() -> void:
	var guarded: Dictionary = _solo("fire", 1000, 1, 100)
	guarded["guardPct"] = 50
	var foe: Dictionary = _enemy("dragon", "fire", 100000, 40, 10, 0, 900)
	var plain: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 1000, 1, 100)]), [foe])
	var cut: Dictionary = Battle.simulate_battle(_cfg, _slots([guarded]), [foe])
	var first_plain: Dictionary = plain["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["src"] != 0)[0]
	var first_cut: Dictionary = cut["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["src"] != 0)[0]
	assert_eq(first_cut["dmg"], Rng.fdiv(int(first_plain["dmg"]) * 50, 100))


func test_roar_shortens_the_ultimate_and_ragnarok_strengthens_it() -> void:
	var cfg: Dictionary = _cfg.duplicate(true)
	cfg["ultimate"] = {"chargeHits": {"base": 4}, "powerPct": {"base": 200}, "targets": {"base": 1}}
	var foe: Dictionary = _enemy("dragon", "fire", 100000, 0, 1000, 0, 900)
	var plain: Dictionary = Battle.simulate_battle(cfg, _slots([_ally("fire", 1000, 10, 10)]), [foe])
	var tuned_ally: Dictionary = _ally("fire", 1000, 10, 10)
	tuned_ally["ultCharge"] = 1
	tuned_ally["ultPowerPct"] = 50
	var tuned: Dictionary = Battle.simulate_battle(cfg, _slots([tuned_ally]), [foe])
	assert_eq([plain["units"][0]["ultNeed"], tuned["units"][0]["ultNeed"]], [4, 3])
	var ult_plain: Dictionary = plain["events"].filter(func(e: Dictionary) -> bool: return e.get("ult", false))[0]
	var ult_tuned: Dictionary = tuned["events"].filter(func(e: Dictionary) -> bool: return e.get("ult", false))[0]
	assert_eq([ult_plain["dmg"], ult_tuned["dmg"]], [20, 25])
	assert_true(ult_tuned["tick"] < ult_plain["tick"])


func test_every_skill_kind_is_one_the_battle_understands() -> void:
	var known: Array = ["hpPct", "atkPct", "hastePct", "lifestealPct", "escortCount", "escortPct", "critPct", "ultPowerPct", "guardPct", "ultCharge"]
	var data: Dictionary = GameData.load_all()
	assert_eq(data["skills"].size(), 12)
	for skill: Dictionary in data["skills"].values():
		assert_true(known.has(skill["kind"]), skill["id"])
		for need: String in skill["requires"]:
			assert_true(data["skills"].has(need), skill["id"])


## 줄 규칙을 켠 설정: 드래곤이 걷고, 사거리가 있고, 다른 줄을 치면 약해진다.
func _lane_cfg() -> Dictionary:
	var cfg: Dictionary = _cfg.duplicate(true)
	cfg["field"]["dragonSpeed"] = 3
	cfg["field"]["frontRange"] = 260
	cfg["field"]["backRange"] = 420
	cfg["field"]["leaderRange"] = 300
	cfg["field"]["crossLanePct"] = [100, 70, 50]
	return cfg


static func _first_attack_from(result: Dictionary, src: int) -> Dictionary:
	for event: Dictionary in result["events"]:
		if event["kind"] == "attack" and event["src"] == src:
			return event
	return {}


func test_dragon_walks_forward_until_its_range_reaches_the_enemy() -> void:
	var cfg: Dictionary = _lane_cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 10)]),
		[_enemy("minion", "fire", 100000, 1, 1000, 0, 900)])
	var last_x: int = int(cfg["field"]["frontX"])
	for event: Dictionary in _of_kind(result, "pos"):
		if event["xs"].has(0):
			last_x = int(event["xs"][0])
	assert_eq(last_x, 900 - 260, "앞줄 드래곤은 사거리 260까지 다가가 멈춘다")
	var hit: Dictionary = _first_attack_from(result, 0)
	assert_true(not hit.is_empty() and int(hit["tick"]) > 10, "닿기 전에는 치지 못한다")


func test_back_row_dragon_stops_farther_away() -> void:
	var cfg: Dictionary = _lane_cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([], [_solo("fire", 100000, 10)]),
		[_enemy("minion", "fire", 100000, 1, 1000, 0, 900)])
	var last_x: int = int(cfg["field"]["backX"])
	for event: Dictionary in _of_kind(result, "pos"):
		if event["xs"].has(0):
			last_x = int(event["xs"][0])
	assert_eq(last_x, 900 - 420)


func test_cross_lane_attacks_are_weaker_by_distance() -> void:
	var cfg: Dictionary = _lane_cfg()
	var dmg: Array = []
	for lane: int in range(3):
		var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 100)]),
			[_enemy("minion", "fire", 100000, 1, 1000, lane, 400)])
		var hit: Dictionary = _first_attack_from(result, 0)
		dmg.append(int(hit.get("dmg", 0)))
		assert_eq(int(hit.get("lane", 100)), [100, 70, 50][lane])
	assert_eq(dmg, [100, 70, 50])


func test_dragon_prefers_its_own_lane_over_a_nearer_enemy_elsewhere() -> void:
	var cfg: Dictionary = _lane_cfg()
	var enemies: Array = [_enemy("minion", "fire", 100000, 1, 1000, 1, 300), _enemy("minion", "ice", 100000, 1, 1000, 0, 480)]
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 10)]), enemies)
	assert_eq(int(_first_attack_from(result, 0).get("dst", -1)), 2, "같은 줄의 적을 먼저 친다")


func test_dragon_turns_to_other_lanes_when_its_lane_is_empty() -> void:
	var cfg: Dictionary = _lane_cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 10)]),
		[_enemy("minion", "fire", 100000, 1, 1000, 2, 400)])
	assert_eq(int(_first_attack_from(result, 0).get("dst", -1)), 1)


func test_ultimate_ignores_the_lane_penalty() -> void:
	var cfg: Dictionary = _lane_cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 2}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([_solo("fire", 100000, 100)]),
		[_enemy("minion", "fire", 100000, 1, 1000, 2, 400)])
	var hits: Array = _of_kind(result, "attack").filter(func(e: Dictionary) -> bool: return e["src"] == 0)
	assert_eq(int(hits[0]["dmg"]), 50)
	assert_true(hits[1].get("ult", false))
	assert_eq(int(hits[1]["dmg"]), 200)


func test_enemy_leader_also_walks_and_pays_the_lane_penalty() -> void:
	var cfg: Dictionary = _lane_cfg()
	var result: Dictionary = Battle.simulate_battle(cfg, _slots([null, _solo("fire", 100000, 1, 1000)]),
		[_enemy("dragon", "fire", 100000, 100, 10, 0, 900)])
	var hit: Dictionary = _first_attack_from(result, 1)
	assert_eq(int(hit.get("dmg", 0)), 70)
	var moved: bool = false
	for event: Dictionary in _of_kind(result, "pos"):
		moved = moved or event["xs"].has(1)
	assert_true(moved, "적 우두머리도 사거리까지 걸어온다")


func test_lane_rules_are_off_without_the_field_keys() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg, _slots([_solo("fire", 100000, 100)]),
		[_enemy("minion", "fire", 100000, 1, 1000, 2, 900)])
	var hit: Dictionary = _first_attack_from(result, 0)
	assert_eq(int(hit["dmg"]), 100)
	assert_true(not hit.has("lane"))
	assert_eq(int(hit["tick"]), 10)


func test_real_battle_data_turns_the_lane_rules_on() -> void:
	var field: Dictionary = _real["field"]
	assert_true(int(field["dragonSpeed"]) > 0)
	assert_true(int(field["backRange"]) > int(field["frontRange"]))
	assert_eq(field["crossLanePct"].size(), 3)
	assert_eq(int(field["crossLanePct"][0]), 100)
	assert_true(int(field["crossLanePct"][2]) < int(field["crossLanePct"][1]))
