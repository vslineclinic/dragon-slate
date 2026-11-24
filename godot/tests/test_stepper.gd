extends TestCase
## 전투를 한 틱씩 돌리기, 수동 궁극기, 살아남은 적 세기, 멀리서 치는 졸병.

const Fixture = preload("res://godot/tests/test_slot.gd")
const B = preload("res://godot/tests/test_battle.gd")


func _cfg() -> Dictionary:
	var cfg: Dictionary = Fixture.mini_data()["battle"].duplicate(true)
	cfg["field"]["dragonSpeed"] = 3
	cfg["field"]["frontRange"] = 260
	cfg["field"]["backRange"] = 420
	cfg["field"]["leaderRange"] = 300
	cfg["field"]["crossLanePct"] = [100, 70, 50]
	cfg["ultimate"] = {"chargeHits": {"none": 3}, "powerPct": {"none": 200}, "targets": {"none": 1}}
	return cfg


static func _hits(events: Array, src: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["kind"] == "attack" and e["src"] == src)


func test_stepping_tick_by_tick_gives_the_same_battle_as_simulating_at_once() -> void:
	var cfg: Dictionary = _cfg()
	var allies: Array = B._slots([B._solo("fire", 400, 30), B._solo("ice", 300, 20)])
	var enemies: Array = [B._enemy("dragon", "ice", 600, 25, 15, 0, 860), B._enemy("minion", "fire", 80, 5, 14, 1, 700, 5)]
	var whole: Dictionary = Battle.simulate_battle(cfg, allies, enemies, {"critSeed": 7})
	var sim: Dictionary = Battle.begin_battle(cfg, allies, enemies, {"critSeed": 7})
	var seen: Array = []
	var guard: int = 0
	while not Battle.battle_over(sim) and guard < 10000:
		guard += 1
		seen.append_array(Battle.step_battle(sim))
	var stepped: Dictionary = Battle.battle_result(sim)
	assert_eq(stepped["winner"], whole["winner"])
	assert_eq(stepped["ticks"], whole["ticks"])
	assert_eq(stepped["events"], whole["events"])
	assert_eq(seen, whole["events"], "틱마다 돌려준 사건을 이으면 전체 사건과 같다")
	assert_eq(Battle.step_battle(sim), [], "끝난 전투는 더 나아가지 않는다")


func test_manual_mode_holds_the_ultimate_until_it_is_armed() -> void:
	var cfg: Dictionary = _cfg()
	var allies: Array = B._slots([B._solo("fire", 100000, 100)])
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)]
	var sim: Dictionary = Battle.begin_battle(cfg, allies, enemies, {"manualUlt": true})
	for i: int in range(65):
		Battle.step_battle(sim)
	var before: Array = _hits(sim["events"], 0)
	assert_eq(before.size(), 6)
	assert_true(before.all(func(e: Dictionary) -> bool: return not e.get("ult", false)), "쏘라고 하기 전에는 궁극기가 나가지 않는다")
	assert_eq(int(before[5]["charge"]), 3, "게이지는 가득 찬 채로 기다린다")
	assert_eq(Battle.ready_ults(sim), [0])
	var fired: Array = Battle.step_battle(sim, [0])
	var burst: Array = _hits(fired, 0)
	assert_eq(burst.size(), 1, "쏘라고 한 그 틱에 바로 나간다")
	assert_eq([burst[0].get("ult", false), int(burst[0]["dmg"]), int(burst[0]["charge"])], [true, 200, 0])
	assert_eq(Battle.ready_ults(sim), [])


func test_arming_does_nothing_before_the_gauge_is_full_or_in_auto_mode() -> void:
	var cfg: Dictionary = _cfg()
	var allies: Array = B._slots([B._solo("fire", 100000, 100)])
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)]
	var sim: Dictionary = Battle.begin_battle(cfg, allies, enemies, {"manualUlt": true})
	for i: int in range(12):
		Battle.step_battle(sim, [0])
	assert_true(_hits(sim["events"], 0).all(func(e: Dictionary) -> bool: return not e.get("ult", false)))
	var auto: Dictionary = Battle.begin_battle(cfg, allies, enemies)
	for i: int in range(35):
		Battle.step_battle(auto, [0])
	var hits: Array = _hits(auto["events"], 0)
	assert_eq(hits.map(func(e: Dictionary) -> bool: return e.get("ult", false)), [false, false, true], "자동 모드는 세 번째 공격이 궁극기")


func test_replaying_the_recorded_ultimate_ticks_gives_the_same_battle() -> void:
	var cfg: Dictionary = _cfg()
	var allies: Array = B._slots([B._solo("fire", 100000, 100)])
	var enemies: Array = [B._enemy("minion", "fire", 3000, 1, 1000, 0, 400)]
	var sim: Dictionary = Battle.begin_battle(cfg, allies, enemies, {"manualUlt": true, "critSeed": 3})
	var record: Dictionary = {}
	var guard: int = 0
	while not Battle.battle_over(sim) and guard < 10000:
		guard += 1
		var arm: Array = Battle.ready_ults(sim) if int(sim["tick"]) % 47 == 0 else []
		if not arm.is_empty():
			record[int(sim["tick"]) + 1] = arm
		Battle.step_battle(sim, arm)
	var played: Dictionary = Battle.battle_result(sim)
	assert_true(not record.is_empty())
	var replay: Dictionary = Battle.simulate_battle(cfg, allies, enemies, {"manualUlt": true, "critSeed": 3, "ultAt": record})
	assert_eq(replay["events"], played["events"])
	assert_eq([replay["winner"], replay["ticks"]], [played["winner"], played["ticks"]])


func test_result_counts_the_enemies_left_on_the_field() -> void:
	var cfg: Dictionary = _cfg()
	var enemies: Array = [B._enemy("dragon", "fire", 100000, 500, 5, 0, 400), B._enemy("minion", "fire", 100000, 1, 1000, 1, 400), B._enemy("minion", "fire", 100000, 1, 1000, 2, 400)]
	var later: Dictionary = B._enemy("minion", "fire", 100000, 1, 1000, 0, 900)
	later["stage"] = 3
	var lost: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 50, 1)]), enemies + [later])
	assert_eq(lost["winner"], "enemy")
	assert_eq(lost["left"], {"leaders": 1, "minions": 2}, "아직 나오지 않은 무리는 세지 않는다")
	var won: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 100000)]), [B._enemy("minion", "fire", 10, 1, 1000, 0, 400)])
	assert_eq(won["left"], {"leaders": 0, "minions": 0})


func test_a_minion_with_reach_stops_at_a_distance_and_shoots() -> void:
	var cfg: Dictionary = _cfg()
	var archer: Dictionary = B._enemy("minion", "fire", 100000, 7, 10, 0, 900, 5)
	archer["reach"] = 220
	archer["type"] = "archer"
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 1, 1000)]), [archer])
	var last_x: int = 900
	var ally_x: int = int(cfg["field"]["frontX"])
	for event: Dictionary in result["events"]:
		if event["kind"] == "pos":
			if event["xs"].has(1):
				last_x = int(event["xs"][1])
			if event["xs"].has(0):
				ally_x = int(event["xs"][0])
	assert_true(last_x - ally_x > int(cfg["field"]["meleeRange"]), "근접 거리까지 붙지 않는다")
	assert_true(last_x - ally_x <= 220)
	assert_true(not _hits(result["events"], 1).is_empty())
	assert_eq(result["units"][1]["type"], "archer")


func test_enemy_leaders_use_ultimates_only_under_the_region_rule() -> void:
	var cfg: Dictionary = _cfg()
	cfg["ultimate"]["chargeHits"]["t2"] = 2
	cfg["ultimate"]["powerPct"]["t2"] = 300
	cfg["ultimate"]["targets"]["t2"] = 1
	var leader: Dictionary = B._enemy("dragon", "fire", 100000, 100, 10, 0, 400)
	leader["tier"] = "t2"
	var allies: Array = B._slots([B._solo("fire", 100000, 1, 1000)])
	var calm: Dictionary = Battle.simulate_battle(cfg, allies, [leader])
	assert_true(_hits(calm["events"], 1).slice(0, 4).all(func(e: Dictionary) -> bool: return not e.get("ult", false)))
	var wild: Dictionary = Battle.simulate_battle(cfg, allies, [leader], {"enemyUlt": true})
	var hits: Array = _hits(wild["events"], 1)
	assert_eq([hits[1].get("ult", false), int(hits[1]["dmg"])], [true, 300])


func test_a_ranged_minion_walks_into_lane_change_range_for_a_target_in_another_lane() -> void:
	## 궁병의 유일한 표적이 옆줄, 가로 거리 200(사거리 220 안): 멈춰 서지 않고 다가가 줄을 바꿔 친다.
	var cfg: Dictionary = _cfg()
	var archer: Dictionary = B._enemy("minion", "fire", 100000, 7, 10, 1, 450, 5)
	archer["reach"] = 220
	var result: Dictionary = Battle.simulate_battle(cfg, B._slots([B._solo("fire", 100000, 1, 100000)]), [archer])
	assert_true(not _hits(result["events"], 1).is_empty(), "다른 줄의 표적도 결국 친다")


func test_recorded_ultimates_work_with_text_keys_and_ignore_garbage() -> void:
	var cfg: Dictionary = _cfg()
	var allies: Array = B._slots([B._solo("fire", 100000, 100)])
	var enemies: Array = [B._enemy("minion", "fire", 100000, 1, 1000, 0, 400)]
	var by_int: Dictionary = Battle.simulate_battle(cfg, allies, enemies, {"manualUlt": true, "ultAt": {66: [0]}})
	var by_text: Dictionary = Battle.simulate_battle(cfg, allies, enemies, {"manualUlt": true, "ultAt": {"66": [0.0]}})
	assert_true(_hits(by_int["events"], 0).any(func(e: Dictionary) -> bool: return e.get("ult", false)))
	assert_eq(by_text["events"], by_int["events"])
	var junk: Dictionary = Battle.simulate_battle(cfg, allies, enemies, {"manualUlt": true, "ultAt": {66: ["bogus", -3, 99, 0.5]}})
	assert_true(_hits(junk["events"], 0).all(func(e: Dictionary) -> bool: return not e.get("ult", false)), "잘못된 id는 아무도 장전하지 않는다")
