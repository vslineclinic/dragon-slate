extends TestCase

const HintRules = preload("res://godot/core/hints.gd")
const RunRules = preload("res://godot/core/run.gd")
const F: String = "fire"
const I: String = "ice"
const L: String = "lightning"
const G: String = "gold"

var _data: Dictionary = GameData.load_all()


func test_best_nudge_completes_a_line() -> void:
	var grid: Dictionary = _grid([[L, F, I], [F, I, F], [L, G, I]])
	grid["reels"][1][0] = _cell(L)
	assert_eq(HintRules.best_nudge(grid, 1), {"col": 1, "dir": -1, "lines": 1})
	assert_eq(grid["offsets"], [0, 0, 0])


func test_best_nudge_needs_an_improvement_and_a_charge() -> void:
	assert_eq(HintRules.best_nudge(_grid([[F, I, L], [I, L, F], [L, F, I]]), 1), null)
	var grid: Dictionary = _grid([[L, F, I], [F, I, F], [L, G, I]])
	grid["reels"][1][0] = _cell(L)
	assert_eq(HintRules.best_nudge(grid, 0), null)


func test_recommend_offer_prefers_a_recipe() -> void:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state["phase"] = "pick"
	state["bench"][0] = _inst(1, "fire_drake")
	state["grid"] = _grid([[I, L, I], [I, F, L], [L, I, F]])
	state["grid"]["reels"][1][2] = _cell(F, "fire_drake")
	assert_eq(HintRules.recommend_offer(_data, state), {
		"index": 1, "reason": "recipe", "result": "beowulf_firedrake",
	})


func test_recommend_offer_falls_back_to_nest_element() -> void:
	# TypeScript 테스트와 같은 미니 레시피로 원소 추천을 검증한다.
	var mini: Dictionary = load_json("res://data/fixtures/mini.json")
	var data: Dictionary = _data.duplicate()
	data["recipes"] = mini["recipes"]
	var state: Dictionary = RunRules.create_run(data, 1)["state"]
	assert_eq(HintRules.recommend_offer(data, state), null)
	state["phase"] = "pick"
	state["nest"][0] = _inst(1, "storm_wyvern")
	state["grid"] = _grid([[I, L, I], [I, L, G], [L, I, F]])
	state["grid"]["reels"][0][2] = _cell(I, "ice_drake")
	state["grid"]["reels"][1][2] = _cell(L, "storm_drake")
	assert_eq(HintRules.recommend_offer(data, state), {"index": 1, "reason": "element", "result": null})
	state["nest"][0] = null
	assert_eq(HintRules.recommend_offer(data, state), null)


func test_line_rewards_summarizes_picking() -> void:
	assert_eq(HintRules.line_rewards(_data, _grid([[F, F, F], [I, G, L], [L, I, I]])), {
		"lines": 1, "eggs": [{"element": F, "tier": "base"}], "mana": 3,
	})
	var two_lines: Dictionary = HintRules.line_rewards(_data, _grid([[F, F, F], [F, L, I], [F, I, L]]))
	assert_eq(two_lines["eggs"], [{"element": F, "tier": "t2"}])
	assert_eq(HintRules.line_rewards(_data, _grid([[F, I, L], [I, L, F], [F, F, I]])), {
		"lines": 0, "eggs": [], "mana": 0,
	})


func test_evolvable_pairs_crosses_nest_and_bench() -> void:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state["nest"][0] = _inst(1, "fire_drake")
	state["bench"][0] = _inst(2, "fire_drake")
	state["bench"][1] = _inst(3, "ice_drake")
	assert_eq(HintRules.evolvable_pairs(_data, state), [], "레벨이 모자라면 추천하지 않아요")
	state["nest"][0]["level"] = Fusion.evolve_level(_data, "beowulf_firedrake")
	assert_eq(HintRules.evolvable_pairs(_data, state), [{
		"a": {"zone": "nest", "index": 0},
		"b": {"zone": "bench", "index": 0},
		"result": "beowulf_firedrake",
	}])


static func _inst(uid: int, species_id: String) -> Dictionary:
	return {"uid": uid, "speciesId": species_id, "traits": [], "bonusPct": 0}


static func _grid(rows: Array) -> Dictionary:
	var reels: Array = []
	for col: int in range(3):
		var reel: Array = [_cell(G)]
		for row: int in range(3):
			var symbol: String = rows[row][col]
			reel.append(_cell(symbol, null if symbol == G else symbol + "_x"))
		reel.append(_cell(G))
		reels.append(reel)
	return {"reels": reels, "offsets": [0, 0, 0]}


static func _cell(symbol: String, species_id: Variant = null) -> Dictionary:
	return {"symbol": symbol, "speciesId": species_id}


## ── 패배 이유 ──

static func _fight(units: Array, events: Array, ticks: int = 100) -> Dictionary:
	return {"winner": "enemy", "ticks": ticks, "units": units, "events": events}


static func _u(id: int, side: String, kind: String) -> Dictionary:
	return {"id": id, "side": side, "kind": kind}


static func _hit(src: int, dst: int, mult: int = 100, lane: int = 100) -> Dictionary:
	var event: Dictionary = {"tick": 1, "kind": "attack", "src": src, "dst": dst, "dmg": 1, "mult": mult, "heal": 0}
	if lane != 100:
		event["lane"] = lane
	return event


func test_defeat_reason_names_a_weak_element_first() -> void:
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "enemy", "dragon")]
	var events: Array = [_hit(0, 1, 75), _hit(0, 1, 75, 75), _hit(0, 1, 100), _hit(1, 0, 135)]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, events)), {"kind": "weakElement", "pct": 66})


func test_defeat_reason_names_off_lane_hits() -> void:
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "enemy", "minion")]
	var events: Array = [_hit(0, 1, 100, 75), _hit(0, 1), _hit(0, 1), _hit(0, 1, 100, 50)]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, events)), {"kind": "offLane", "pct": 50})


func test_defeat_reason_tells_timeout_leaders_and_swarm_apart() -> void:
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "enemy", "dragon"), _u(2, "enemy", "minion"), _u(3, "enemy", "minion")]
	var plain: Array = [_hit(0, 2), _hit(0, 2), _hit(0, 2), _hit(0, 2), _hit(0, 2)]
	assert_eq(HintRules.defeat_reason({"maxTicks": 100}, _fight(units, plain, 100))["kind"], "timeout")
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, plain))["kind"], "swarm")
	var cleared: Array = plain + [{"tick": 2, "kind": "death", "id": 2, "cause": "hit"}, {"tick": 2, "kind": "death", "id": 3, "cause": "hit"}]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, cleared))["kind"], "leaders")


func test_defeat_reason_ignores_escorts_and_enemy_hits() -> void:
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "ally", "escort"), _u(2, "enemy", "minion")]
	var events: Array = [_hit(1, 2, 75), _hit(1, 2, 75), _hit(2, 0, 75), _hit(0, 2)]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, events))["kind"], "swarm")


func test_defeat_reason_does_not_count_groups_that_never_appeared() -> void:
	## 첫 무리의 졸병 하나에게 졌고, 둘째 무리의 우두머리는 나오지도 않았다.
	var leader: Dictionary = _u(2, "enemy", "dragon")
	leader["stage"] = 1
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "enemy", "minion"), leader]
	var events: Array = [_hit(0, 1), {"tick": 5, "kind": "death", "id": 0, "cause": "hit"}]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, events))["kind"], "swarm")
	var shown: Array = events + [{"tick": 6, "kind": "stage", "stage": 1, "total": 2}]
	assert_eq(HintRules.defeat_reason({"maxTicks": 3600}, _fight(units, shown))["kind"], "leaders")


func test_being_wiped_on_the_last_tick_is_not_a_timeout() -> void:
	var units: Array = [_u(0, "ally", "dragon"), _u(1, "enemy", "minion"), _u(2, "enemy", "minion")]
	var events: Array = [_hit(0, 1), {"tick": 100, "kind": "death", "id": 0, "cause": "hit"}]
	assert_eq(HintRules.defeat_reason({"maxTicks": 100}, _fight(units, events, 100))["kind"], "swarm")


func test_line_rewards_show_the_crown_egg() -> void:
	var wild: Dictionary = {"symbol": "wild", "speciesId": "fire_drake"}
	var gold: Dictionary = {"symbol": "gold", "speciesId": null}
	var reels: Array = []
	for col: int in range(3):
		reels.append([gold, gold, wild, gold, gold])
	var grid: Dictionary = {"reels": reels, "offsets": [0, 0, 0]}
	assert_eq(HintRules.line_rewards(_data, grid)["eggs"], [])
	assert_eq(HintRules.line_rewards(_data, grid, true)["eggs"], [{"element": "wild", "tier": "t2"}])
