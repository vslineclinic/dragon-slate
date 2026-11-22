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
