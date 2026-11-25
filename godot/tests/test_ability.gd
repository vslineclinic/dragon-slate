extends TestCase
## 형태별 능력: 꿰뚫기 · 연속 공격 · 돌봄 · 방패막 · 맞대결. 보통 공격에만 붙고 궁극기에는 붙지 않는다.

const Fixture = preload("res://godot/tests/test_slot.gd")
const B = preload("res://godot/tests/test_battle.gd")

var _data: Dictionary = GameData.load_all()


func _cfg() -> Dictionary:
	var cfg: Dictionary = Fixture.mini_data()["battle"].duplicate(true)
	cfg["field"]["dragonSpeed"] = 3
	cfg["field"]["frontRange"] = 260
	cfg["field"]["backRange"] = 420
	cfg["field"]["leaderRange"] = 300
	cfg["field"]["crossLanePct"] = [100, 70, 50]
	cfg["abilities"] = {
		"pierce": {"pct": 60}, "twin": {"pct": 50}, "mend": {"pct": 40}, "ward": {"pct": 20}, "duel": {"pct": 25},
		"vanguard": {"pct": 12}, "ambush": {"pct": 15}, "rally": {"pct": 12},
	}
	return cfg


static func _able(ability: String, hp: int, atk: int, cd: int = 10) -> Dictionary:
	var unit: Dictionary = B._solo("fire", hp, atk, cd)
	unit["ability"] = ability
	return unit


static func _hits(result: Dictionary, src: int) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["src"] == src)


static func _at_tick(events: Array, tick: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["tick"] == tick)


func test_pierce_also_hits_the_next_enemy_in_that_lane() -> void:
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 470),
		B._enemy("minion", "fire", 100000, 1, 1000, 1, 400)]
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("pierce", 100000, 100)]), enemies)
	var first: Array = _at_tick(_hits(result, 0), 10)
	assert_eq(first.size(), 2)
	assert_eq([first[0]["dst"], first[0]["dmg"], first[0].has("via")], [1, 100, false])
	assert_eq([first[1]["dst"], first[1]["dmg"], first[1].get("via")], [2, 60, "pierce"])


func test_pierce_needs_a_second_enemy_in_the_same_lane() -> void:
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 1, 400)]
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("pierce", 100000, 100)]), enemies)
	assert_eq(_at_tick(_hits(result, 0), 10).size(), 1)


func test_twin_strikes_the_same_target_again_at_half_power() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("twin", 100000, 100)]),
		[B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)])
	var first: Array = _at_tick(_hits(result, 0), 10)
	assert_eq(first.size(), 2)
	assert_eq([first[0]["dmg"], first[1]["dmg"], first[1].get("via")], [100, 50, "twin"])
	assert_true(not first[1].get("crit", false))


func test_twin_does_not_strike_a_target_that_already_died() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("twin", 100000, 100)]),
		[B._enemy("minion", "fire", 50, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 480)])
	assert_eq(_at_tick(_hits(result, 0), 10).size(), 1)


func test_mend_heals_the_most_hurt_ally_dragon_in_its_own_or_next_lane() -> void:
	## 0번 줄 돌봄 드래곤, 1번 줄 다친 드래곤, 2번 줄 더 다친 드래곤(멀어서 못 고친다).
	var cfg: Dictionary = _cfg()
	var near: Dictionary = B._solo("fire", 1000, 1, 1000)
	var far: Dictionary = B._solo("fire", 1000, 1, 1000)
	var foe: Dictionary = B._enemy("dragon", "fire", 100000, 300, 5, 1, 400)
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_able("mend", 100000, 100, 20), near, far]), [foe])
	var heals: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "heal")
	assert_true(not heals.is_empty(), "돌봄이 한 번은 일어난다")
	if heals.is_empty():
		return
	assert_eq([heals[0]["src"], heals[0]["dst"], heals[0]["amount"]], [0, 1, 40])
	for heal: Dictionary in heals:
		assert_true(int(heal["dst"]) != 2, "두 줄 건너의 드래곤은 못 고친다")


func test_mend_does_nothing_when_nobody_is_hurt() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("mend", 100000, 100)]),
		[B._enemy("minion", "fire", 300, 1, 1000, 0, 400)])
	assert_eq(result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "heal").size(), 0)


func test_ward_shields_other_ally_dragons_in_its_lane_but_not_itself() -> void:
	var cfg: Dictionary = _cfg()
	var foe: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)
	## 앞줄 방패막 + 같은 줄 뒷줄 드래곤. 적은 가까운 앞줄부터 친다.
	var guarded: Dictionary = Battle.simulate_battle(cfg, B._slots([_able("ward", 150, 1, 1000)], [B._solo("fire", 100000, 1, 1000)]), [foe])
	var hits: Array = _hits(guarded, 2)
	var on_ward: Array = hits.filter(func(e: Dictionary) -> bool: return e["dst"] == 0)
	var on_back: Array = hits.filter(func(e: Dictionary) -> bool: return e["dst"] == 1)
	assert_eq(int(on_ward[0]["dmg"]), 100, "방패막 드래곤 자신은 그대로 맞는다")
	assert_eq(int(on_back[0]["dmg"]), 100, "방패막 드래곤이 쓰러진 뒤에는 그대로 맞는다")
	var alive: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 150, 1, 1000)], [_able("ward", 100000, 1, 1000)]), [foe])
	var front_hits: Array = _hits(alive, 2).filter(func(e: Dictionary) -> bool: return e["dst"] == 0)
	assert_eq([int(front_hits[0]["dmg"]), front_hits[0].get("ward", false)], [80, true], "같은 줄의 다른 드래곤은 20% 덜 맞는다")


func test_ward_does_not_reach_other_lanes() -> void:
	var foe: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 1, 400)
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("ward", 100000, 1, 1000), B._solo("fire", 100000, 1, 1000)]), [foe])
	var hit: Dictionary = _hits(result, 2).filter(func(e: Dictionary) -> bool: return e["dst"] == 1)[0]
	assert_eq([int(hit["dmg"]), hit.has("ward")], [100, false])


func test_duel_hits_harder_only_in_its_own_lane() -> void:
	var dmg: Array = []
	for lane: int in range(3):
		var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("duel", 100000, 100)]),
			[B._enemy("minion", "fire", 100000, 1, 1000, lane, 400)])
		dmg.append(int(_hits(result, 0)[0]["dmg"]))
	assert_eq(dmg, [125, 70, 50])


func test_ultimates_carry_no_form_ability() -> void:
	## 궁극기는 두 번째 공격(20틱)에 나간다: 꿰뚫기 · 연속 공격 · 맞대결 없이 한 번, 200%.
	var cfg: Dictionary = _cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 2}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 470)]
	for ability: String in ["pierce", "twin", "duel"]:
		var result: Dictionary = Battle.simulate_battle(cfg, B._slots([_able(ability, 100000, 100)]), enemies)
		var second: Array = _at_tick(_hits(result, 0), 20)
		assert_eq(second.size(), 1, ability)
		if not second.is_empty():
			assert_eq([second[0].get("ult", false), int(second[0]["dmg"])], [true, 200], ability)


func test_species_get_their_ability_from_the_form_name() -> void:
	var want: Dictionary = {
		"fire_raptor": "pierce", "ice_lancer": "pierce", "storm_meteor": "pierce",
		"fire_wyvern": "twin", "storm_twinhead": "twin", "abyss_skylord": "twin",
		"poison_fairy": "mend", "steel_sage": "mend", "fire_elder": "mend",
		"ice_tortoise": "ward", "fire_armored": "ward", "poison_guardian": "ward",
		"steel_horned": "duel", "abyss_brawler": "duel",
		"fire_drake": "vanguard", "ice_lindworm": "vanguard", "storm_whelp": "vanguard",
		"poison_amphiptere": "ambush", "steel_gecko": "ambush",
		"abyss_serpent": "rally", "fire_wyrm": "rally", "ice_dancer": "rally",
		"beowulf_firedrake": "mythic", "north_black_dragon": "mythic", "zhulong": "mythic", "kuraokami": "mythic", "fire_god": "",
	}
	for id: String in want:
		assert_true(_data["dragons"].has(id), id)
		assert_eq(Battle.ability_of(_data, id), want[id], id)
	assert_eq(Battle.to_unit(_data, {"speciesId": "fire_raptor", "traits": [], "bonusPct": 0})["ability"], "pierce")
	assert_true(not Battle.to_unit(_data, {"speciesId": "fire_god", "traits": [], "bonusPct": 0}).has("ability"))


func test_every_ability_form_exists_for_all_six_elements_and_has_copy() -> void:
	var prefixes: Array = ["fire", "ice", "storm", "poison", "steel", "abyss"]
	for id: String in _data["battle"]["abilities"]:
		var spec: Dictionary = _data["battle"]["abilities"][id]
		assert_true(not str(spec.get("nameKo", "")).is_empty() and not str(spec.get("descKo", "")).is_empty(), id)
		assert_true(int(spec["pct"]) > 0, id)
		for form: String in spec["forms"]:
			for prefix: String in prefixes:
				assert_true(_data["dragons"].has(prefix + "_" + form), prefix + "_" + form)


func test_enemy_leaders_carry_their_ability() -> void:
	var seen: bool = false
	for seed: int in range(1, 30):
		for enemy: Dictionary in Waves.generate_enemies(_data, 14, Rng.new(seed), seed):
			if enemy["kind"] == "dragon":
				assert_eq(enemy.get("ability", ""), Battle.ability_of(_data, enemy["id"]))
				seen = seen or not str(enemy.get("ability", "")).is_empty()
	assert_true(seen, "능력이 있는 적 우두머리가 나온다")


func test_pierce_does_not_reach_beyond_the_dragons_range() -> void:
	## 사거리 260: x 400의 적은 닿고 x 900의 적은 안 닿는다.
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 900)]
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("pierce", 100000, 100)]), enemies)
	assert_eq(_at_tick(_hits(result, 0), 10).size(), 1)


func test_ward_does_not_weaken_ultimates() -> void:
	var cfg: Dictionary = _cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 2}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	## 적 쪽에 방패막 우두머리와 다른 우두머리가 같은 줄에 있다.
	var warder: Dictionary = B._enemy("dragon", "fire", 100000, 1, 1000, 0, 480)
	warder["ability"] = "ward"
	var other: Dictionary = B._enemy("dragon", "fire", 100000, 1, 1000, 0, 400)
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 100)]), [warder, other])
	var hits: Array = _hits(result, 0)
	assert_eq([int(hits[0]["dmg"]), hits[0].get("ward", false)], [80, true], "보통 공격은 20% 덜 들어간다")
	assert_eq([int(hits[1]["dmg"]), hits[1].get("ult", false), hits[1].has("ward")], [200, true, false], "궁극기는 그대로")


func test_ability_lookup_follows_the_data_as_it_is_now() -> void:
	var data: Dictionary = GameData.load_all()
	assert_eq(Battle.ability_of(data, "fire_raptor"), "pierce")
	data["battle"]["abilities"]["pierce"]["forms"].erase("raptor")
	data["battle"]["abilities"]["twin"]["forms"].append("raptor")
	assert_eq(Battle.ability_of(data, "fire_raptor"), "twin")
	assert_eq(Battle.ability_of(data, "fire_god"), "")


func test_every_base_form_has_an_ability() -> void:
	for spec: Dictionary in _data["dragons"].values():
		if spec["tier"] == "base":
			assert_true(not Battle.ability_of(_data, spec["id"]).is_empty(), spec["id"])


func test_vanguard_takes_less_damage_only_in_the_front_row() -> void:
	var foe: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)
	var front: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("vanguard", 100000, 1, 1000)]), [foe])
	var back: Dictionary = Battle.simulate_battle(_cfg(), B._slots([], [_able("vanguard", 100000, 1, 1000)]), [foe])
	assert_eq(int(_hits(front, 1)[0]["dmg"]), 88)
	assert_eq(int(_hits(back, 1)[0]["dmg"]), 100)


func test_ambush_hits_harder_only_from_the_back_row() -> void:
	var foe: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)]
	var front: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("ambush", 100000, 100)]), foe)
	var back: Dictionary = Battle.simulate_battle(_cfg(), B._slots([], [_able("ambush", 100000, 100)]), foe)
	assert_eq(int(_hits(front, 0)[0]["dmg"]), 100)
	assert_eq(int(_hits(back, 0)[0]["dmg"]), 115)


func test_rally_speeds_up_the_other_dragon_in_its_lane_but_not_itself() -> void:
	var foe: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)]
	## 앞줄 함성(쿨다운 100) + 같은 줄 뒷줄 드래곤(쿨다운 100): 뒷줄 드래곤만 88틱에 친다.
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("rally", 100000, 1, 100)], [B._solo("fire", 100000, 1, 100)]), foe)
	assert_eq(int(_hits(result, 0)[0]["tick"]), 100, "함성 드래곤 자신은 그대로")
	assert_eq(int(_hits(result, 1)[0]["tick"]), 88, "같은 줄의 다른 드래곤은 12% 빨라진다")
	var apart: Dictionary = Battle.simulate_battle(_cfg(), B._slots([_able("rally", 100000, 1, 100), B._solo("fire", 100000, 1, 100)]), foe)
	assert_eq(int(_hits(apart, 1)[0]["tick"]), 100, "다른 줄에는 닿지 않는다")


func test_enemy_leaders_use_stance_abilities_without_a_row() -> void:
	var tough: Dictionary = B._enemy("dragon", "fire", 100000, 1, 1000, 0, 400)
	tough["ability"] = "vanguard"
	var hit: Dictionary = _hits(Battle.simulate_battle(_cfg(), B._slots([B._solo("fire", 100000, 100)]), [tough]), 0)[0]
	assert_eq(int(hit["dmg"]), 88)
	var sniper: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)
	sniper["ability"] = "ambush"
	var shot: Dictionary = _hits(Battle.simulate_battle(_cfg(), B._slots([B._solo("fire", 100000, 1, 1000)]), [sniper]), 1)[0]
	assert_eq(int(shot["dmg"]), 115)


func test_rally_does_not_come_from_a_group_that_has_not_appeared() -> void:
	## 0단계 적 드래곤과, 같은 줄의 2단계 함성 드래곤: 함성 드래곤이 나오기 전에는 빨라지지 않는다.
	var cfg: Dictionary = _cfg()
	var first: Dictionary = B._enemy("dragon", "fire", 100000, 1, 100, 0, 400)
	var later: Dictionary = B._enemy("dragon", "fire", 100000, 1, 100, 0, 450)
	later["ability"] = "rally"
	later["stage"] = 2
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 1, 1000)]), [first, later])
	assert_eq(int(_hits(result, 1)[0]["tick"]), 100)


func test_mythic_dragons_hit_one_more_enemy_with_their_ultimate() -> void:
	var cfg: Dictionary = _cfg()
	cfg["abilities"]["mythic"] = {"pct": 1}
	cfg["ultimate"] = {"chargeHits": {"none": 2}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 0, 470)]
	var plain: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 100)]), enemies)
	var mythic: Dictionary = Battle.simulate_battle(cfg, B._slots([_able("mythic", 100000, 100)]), enemies)
	assert_eq(_at_tick(_hits(plain, 0), 20).size(), 1)
	var burst: Array = _at_tick(_hits(mythic, 0), 20)
	assert_eq(burst.size(), 2)
	assert_true(burst[0].get("ult", false) and burst[1].get("ult", false))
	assert_eq(_at_tick(_hits(mythic, 0), 10).size(), 1, "보통 공격은 그대로 한 마리")


func test_every_named_mythic_dragon_of_the_middle_tiers_has_the_mythic_ability() -> void:
	var listed: Array = _data["battle"]["abilities"]["mythic"]["species"]
	assert_eq(listed.size(), 30)
	for id: String in listed:
		assert_true(_data["dragons"].has(id), id)
		assert_true(_data["dragons"][id]["tier"] in ["t2", "t1"], id)
	for spec: Dictionary in _data["dragons"].values():
		if spec["tier"] in ["t2", "t1"] and spec["elements"].size() == 1:
			assert_true(not Battle.ability_of(_data, spec["id"]).is_empty(), spec["id"])
