extends TestCase
## 원소 시너지 4마리 단계의 규칙 효과: 폭발 · 얼림 · 연쇄 · 중독 · 방벽 · 흡수(설계 2026-11-26-synergy-rules).

const Fixture = preload("res://godot/tests/test_slot.gd")
const B = preload("res://godot/tests/test_battle.gd")

const ALL: Dictionary = {
	"burst": {"pct": 20, "radius": 150},
	"chill": {"ticks": 6},
	"chain": {"pct": 50},
	"venom": {"pct": 40, "everyTicks": 10},
	"bulwark": {"pct": 25},
	"siphon": {"charge": 1},
}


func _cfg() -> Dictionary:
	return Fixture.mini_data()["battle"].duplicate(true)


static func _rules(keys: Array) -> Dictionary:
	var synergy: Dictionary = {}
	for key: String in keys:
		synergy[key] = ALL[key]
	return {"synergy": synergy}


static func _via(result: Dictionary, via: String) -> Array:
	return result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e.get("via", "") == via)


static func _first_hit_on(result: Dictionary, dst: int) -> Variant:
	for e: Dictionary in result["events"]:
		if e["kind"] == "attack" and e["dst"] == dst:
			return e
	return null


func _burst_battle(element: String, rules: Dictionary) -> Dictionary:
	## 0 = 우리 드래곤, 1 = 한 방에 쓰러질 적, 2 = 같은 줄 옆의 적, 3 = 다른 줄 적.
	var enemies: Array = [B._enemy("minion", "steel", 100, 1, 1000, 0, 400), B._enemy("minion", "steel", 100000, 1, 1000, 0, 450),
		B._enemy("minion", "steel", 100000, 1, 1000, 1, 400)]
	return Battle.simulate_battle(_cfg(), B._slots([B._solo(element, 100000, 100)]), enemies, rules)


func test_fire_kill_bursts_onto_nearby_enemies_in_the_same_lane() -> void:
	var bursts: Array = _via(_burst_battle("fire", _rules(["burst"])), "burst")
	assert_eq(bursts.size(), 1)
	if bursts.is_empty():
		return
	assert_eq([bursts[0]["tick"], bursts[0]["src"], bursts[0]["dst"], bursts[0]["dmg"]], [10, 0, 2, 20])


func test_burst_needs_the_rule_and_a_fire_dragon() -> void:
	assert_eq(_via(_burst_battle("fire", {}), "burst").size(), 0)
	assert_eq(_via(_burst_battle("ice", _rules(["burst"])), "burst").size(), 0)


func test_a_burst_kill_does_not_burst_again() -> void:
	## 1이 쓰러지면 2가 폭발로 쓰러지지만, 2의 죽음은 3을 터뜨리지 않는다.
	var enemies: Array = [B._enemy("minion", "steel", 100, 1, 1000, 0, 400), B._enemy("minion", "steel", 10, 1, 1000, 0, 450),
		B._enemy("minion", "steel", 100000, 1, 1000, 0, 500)]
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([B._solo("fire", 100000, 100)]), enemies, _rules(["burst"]))
	var first: Array = _via(result, "burst").filter(func(e: Dictionary) -> bool: return e["tick"] == 10)
	assert_eq(first.map(func(e: Dictionary) -> int: return e["dst"]), [2, 3], "1의 폭발이 2 · 3을 치고, 2의 죽음은 다시 터지지 않는다")


func _enemy_first_attack(element: String, rules: Dictionary) -> int:
	var foe: Dictionary = B._enemy("dragon", "steel", 100000, 1, 30, 0, 400)
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([B._solo(element, 100000, 1)]), [foe], rules)
	for e: Dictionary in result["events"]:
		if e["kind"] == "attack" and e["src"] == 1:
			return e["tick"]
	return -1


func test_ice_hits_delay_the_enemy_attack_once_per_cycle() -> void:
	assert_eq(_enemy_first_attack("ice", {}), 30)
	## 10 · 20틱에 맞아도 한 번만 6틱 늦어진다.
	assert_eq(_enemy_first_attack("ice", _rules(["chill"])), 36)
	assert_eq(_enemy_first_attack("fire", _rules(["chill"])), 30)


func test_chill_right_after_the_enemy_attacked_still_delays_fully() -> void:
	## 적은 10틱마다 친다. 얼음 드래곤이 11틱(적이 막 친 다음)에 때려도 다음 공격이 20틱에서 26틱으로(얼림 6틱) 밀린다.
	var foe: Dictionary = B._enemy("dragon", "steel", 100000, 1, 10, 0, 400)
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([B._solo("ice", 100000, 1, 11)]), [foe], _rules(["chill"]))
	var ticks: Array = result["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["src"] == 1).map(func(e: Dictionary) -> int: return e["tick"])
	assert_eq(ticks.slice(0, 2), [10, 26])


func test_lightning_chains_to_the_nearest_enemy_in_a_next_lane() -> void:
	var enemies: Array = [B._enemy("minion", "steel", 100000, 1, 1000, 0, 400), B._enemy("minion", "steel", 100000, 1, 1000, 1, 470),
		B._enemy("minion", "steel", 100000, 1, 1000, 1, 430), B._enemy("minion", "steel", 100000, 1, 1000, 2, 400)]
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([B._solo("lightning", 100000, 100)]), enemies, _rules(["chain"]))
	var chains: Array = _via(result, "chain").filter(func(e: Dictionary) -> bool: return e["tick"] == 10)
	assert_eq(chains.size(), 1)
	if chains.is_empty():
		return
	assert_eq([chains[0]["src"], chains[0]["dst"], chains[0]["dmg"]], [0, 3, 50])


func test_poison_stores_venom_and_releases_it_on_the_beat() -> void:
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([B._solo("poison", 100000, 100)]),
		[B._enemy("minion", "poison", 100000, 1, 1000, 0, 400)], _rules(["venom"]))
	var venom: Array = _via(result, "venom")
	assert_true(venom.size() >= 2)
	if venom.size() < 2:
		return
	## 10틱의 공격(100)이 40을 남기고, 20틱 박자에 터진다. 20틱의 공격분은 30틱에.
	assert_eq([venom[0]["tick"], venom[0]["src"], venom[0]["dst"], venom[0]["dmg"]], [20, 0, 1, 40])
	assert_eq([venom[1]["tick"], venom[1]["dmg"]], [30, 40])


func _dragon_hit(rules: Dictionary, tier: String) -> int:
	## 적 드래곤이 우리 드래곤 뒤쪽(200)에 서서 1틱에 바로 친다. 호위(300 · 312)는 아직 멀다.
	var me: Dictionary = B._ally("steel", 100000, 1, 1000, 0, tier)
	var result: Dictionary = Battle.simulate_battle(_cfg(), B._slots([me]), [B._enemy("dragon", "steel", 100000, 100, 1, 0, 200)], rules)
	var hit: Variant = _first_hit_on(result, 0)
	return -1 if hit == null else int(hit["dmg"])


func test_bulwark_cuts_damage_while_an_escort_lives() -> void:
	assert_eq(_dragon_hit({}, "base"), 100)
	assert_eq(_dragon_hit(_rules(["bulwark"]), "base"), 75)
	assert_eq(_dragon_hit(_rules(["bulwark"]), "none"), 100, "호위가 없으면 방벽도 없다")


func _siphon_battle(element: String, rules: Dictionary) -> Dictionary:
	var cfg: Dictionary = _cfg()
	cfg["ultimate"] = {"chargeHits": {"none": 5}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	var enemies: Array = [B._enemy("minion", "steel", 50, 1, 1000, 0, 400), B._enemy("minion", "steel", 100000, 1, 1000, 0, 450)]
	return Battle.simulate_battle(cfg, B._slots([B._solo(element, 100000, 100)]), enemies, rules)


func test_abyss_dragons_charge_their_ultimate_when_an_enemy_falls() -> void:
	var charged: Array = _siphon_battle("abyss", _rules(["siphon"]))["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "charge")
	assert_eq(charged.size(), 1)
	if charged.is_empty():
		return
	assert_eq([charged[0]["tick"], charged[0]["id"], charged[0]["charge"]], [10, 0, 2])
	assert_eq(_siphon_battle("abyss", {})["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "charge").size(), 0)
	assert_eq(_siphon_battle("fire", _rules(["siphon"]))["events"].filter(func(e: Dictionary) -> bool: return e["kind"] == "charge").size(), 0)


func test_stepping_with_every_synergy_rule_matches_simulating_at_once() -> void:
	var cfg: Dictionary = _cfg()
	cfg["ultimate"] = {"chargeHits": {"base": 4}, "powerPct": {"base": 200}, "targets": {"base": 2}}
	var allies: Array = B._slots([B._ally("fire", 400, 30), B._ally("ice", 300, 20), B._ally("lightning", 300, 25)],
		[B._ally("poison", 250, 20), B._ally("steel", 300, 15), B._ally("abyss", 250, 22)])
	var enemies: Array = [B._enemy("dragon", "ice", 900, 25, 15, 0, 860), B._enemy("minion", "fire", 80, 5, 14, 1, 700, 5),
		B._enemy("minion", "fire", 80, 5, 14, 1, 760, 5), B._enemy("minion", "steel", 120, 6, 12, 2, 720, 5)]
	var rules: Dictionary = _rules(ALL.keys())
	rules["critSeed"] = 3
	var whole: Dictionary = Battle.simulate_battle(cfg, allies, enemies, rules)
	var sim: Dictionary = Battle.begin_battle(cfg, allies, enemies, rules)
	var guard: int = 0
	while not Battle.battle_over(sim) and guard < 10000:
		guard += 1
		Battle.step_battle(sim)
	assert_eq(Battle.battle_result(sim)["events"], whole["events"])
	assert_true(not _via(whole, "venom").is_empty() and not _via(whole, "chain").is_empty(), "효과가 실제로 일어난다")


func test_synergy_rules_turn_on_at_four_dragons_of_an_element() -> void:
	var data: Dictionary = GameData.load_all()
	var three: Array = [B._inst("fire_drake"), B._inst("fire_wyvern"), B._inst("fire_serpent")]
	assert_eq(Battle.synergy_rules(data, three), {})
	var four: Array = three + [B._inst("fire_drake")]
	var rules: Dictionary = Battle.synergy_rules(data, four)
	assert_eq(rules.keys(), ["burst"])
	for row: Dictionary in data["synergies"]:
		assert_true(row["levels"][1].has("rule"), "%s 4마리 단계에 규칙 효과가 있다" % row["element"])


func test_battle_setup_carries_the_synergy_rules() -> void:
	var data: Dictionary = GameData.load_all()
	var state: Dictionary = Run.create_run(data, 5)["state"]
	for slot: int in range(4):
		state["nest"][slot] = {"uid": 900 + slot, "speciesId": "fire_drake", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}
	state["nestOpen"] = maxi(4, int(state["nestOpen"]))
	state["phase"] = "manage"
	var setup: Dictionary = Run.battle_setup(data, state)
	assert_true(setup["rules"].get("synergy", {}).has("burst"))
