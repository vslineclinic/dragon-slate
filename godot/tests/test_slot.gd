extends TestCase

const F: String = "fire"
const I: String = "ice"
const L: String = "lightning"
const G: String = "gold"
const W: String = "wild"


static func mini_data() -> Dictionary:
	var raw: Dictionary = TestCase.load_json("res://data/fixtures/mini.json")
	for extra: Array in [
		["ice_drake", I, "front"],
		["ice_wyvern", I, "back"],
		["storm_drake", L, "front"],
		["storm_wyvern", L, "back"],
	]:
		var id: String = extra[0]
		raw["dragons"].append({
			"id": id, "nameKo": id, "tier": "base", "elements": [extra[1]],
			"role": extra[2], "stats": {"hp": 100, "atk": 10, "cooldownTicks": 20},
			"traitId": "tr_ember",
		})
	return GameData._from_raw(raw)


static func _grid_from(rows: Array) -> Dictionary:
	var reels: Array = []
	for col: int in range(3):
		var reel: Array = [{"symbol": G, "speciesId": null}]
		for row: int in range(3):
			var symbol: String = rows[row][col]
			var species_id: Variant = symbol + "_x"
			if symbol == G:
				species_id = null
			elif symbol == W:
				species_id = "fire_drake"
			reel.append({"symbol": symbol, "speciesId": species_id})
		reel.append({"symbol": G, "speciesId": null})
		reels.append(reel)
	return {"reels": reels, "offsets": [0, 0, 0]}


func test_detects_horizontal_line_with_wild_substitute() -> void:
	var grid: Dictionary = _grid_from([[G, I, L], [F, W, F], [I, G, L]])
	assert_eq(Slot.evaluate_lines(grid), [{"lines": [1], "element": F}])


func test_detects_two_lines_sharing_a_cell() -> void:
	var grid: Dictionary = _grid_from([[I, I, I], [I, F, L], [I, L, F]])
	assert_eq(Slot.evaluate_lines(grid), [{"lines": [0, 3], "element": I}])


func test_gold_breaks_element_line() -> void:
	var grid: Dictionary = _grid_from([[F, G, F], [I, L, I], [L, I, L]])
	assert_eq(Slot.evaluate_lines(grid), [])


func test_three_gold_is_gold_line() -> void:
	var grid: Dictionary = _grid_from([[G, G, G], [I, L, F], [L, F, I]])
	assert_eq(Slot.evaluate_lines(grid), [{"lines": [0], "element": G}])


func test_three_wild_is_wild_line() -> void:
	var grid: Dictionary = _grid_from([[I, L, F], [W, W, W], [L, I, L]])
	assert_eq(Slot.evaluate_lines(grid), [{"lines": [1], "element": W}])


func test_nudge_shifts_visible_window_and_clamps() -> void:
	var grid: Dictionary = _grid_from([[F, I, L], [I, L, F], [L, F, I]])
	var up: Dictionary = Slot.nudge(grid, 0, -1)
	assert_eq(up["offsets"], [-1, 0, 0])
	assert_eq(Slot.visible(up, 0, 0)["symbol"], G)
	assert_eq(Slot.visible(up, 0, 1)["symbol"], F)
	assert_eq(Slot.nudge(up, 0, -1)["offsets"], [-1, 0, 0])
	assert_eq(grid["offsets"], [0, 0, 0])


func test_force_line_guarantees_a_line() -> void:
	var data: Dictionary = mini_data()
	for run_seed: int in range(1, 1001):
		var grid: Dictionary = Slot.spin_grid(data, Rng.new(run_seed), true)
		assert_true(Slot.evaluate_lines(grid).size() >= 1, "seed %d" % run_seed)


func test_offers_come_from_visible_center_row_after_nudge() -> void:
	var data: Dictionary = mini_data()
	var grid: Dictionary = _grid_from([[F, I, L], [I, G, F], [L, F, I]])
	assert_eq(Slot.offers_from(data, grid), [
		{"kind": "egg", "speciesId": "ice_x"},
		{"kind": "mana", "amount": 3},
		{"kind": "egg", "speciesId": "fire_x"},
	])
	assert_eq(Slot.offers_from(data, Slot.nudge(grid, 0, 1))[0], {
		"kind": "egg", "speciesId": "lightning_x",
	})


func test_spun_cells_carry_species_of_their_element() -> void:
	var data: Dictionary = mini_data()
	var grid: Dictionary = Slot.spin_grid(data, Rng.new(3), false)
	for reel: Array in grid["reels"]:
		assert_eq(reel.size(), 5)
		for cell: Dictionary in reel:
			var symbol: String = cell["symbol"]
			var species: Dictionary = data["dragons"].get(cell["speciesId"], {})
			if symbol == G:
				assert_eq(cell["speciesId"], null)
			elif symbol == W:
				assert_eq(species.get("tier"), "base")
			else:
				var elements: Array = species.get("elements", [])
				assert_eq(elements.front() if not elements.is_empty() else null, symbol)


func test_hit_rate_is_sane() -> void:
	var data: Dictionary = mini_data()
	var rng: Rng = Rng.new(11)
	var hits: int = 0
	for i: int in range(10000):
		if not Slot.evaluate_lines(Slot.spin_grid(data, rng, false)).is_empty():
			hits += 1
	assert_true(hits > 2500, "hit count %d" % hits)
	assert_true(hits < 7500, "hit count %d" % hits)


func test_species_odds_follow_weights() -> void:
	var data: Dictionary = GameData.load_all()
	var common: int = Slot.species_odds(data, "fire_drake")
	var rare: int = Slot.species_odds(data, "fire_whelp")
	assert_true(common > rare * 3)
	var total: int = 0
	for spec: Dictionary in data["dragons"].values():
		total += Slot.species_odds(data, spec["id"])
	## 금빛 칸을 뺀 나머지(88%)가 알이다. 정수 나눗셈 오차만 허용.
	assert_true(total > 8700 and total <= 8800, str(total))
	assert_eq(Slot.species_odds(data, "zhulong"), 0)


func test_weighted_pool_prefers_heavier_species() -> void:
	var data: Dictionary = GameData.load_all()
	var pool: Array = Slot.base_pool(data, "fire")
	assert_eq(pool.size(), 4)
	var counts: Dictionary = {}
	var rng: Rng = Rng.new(7)
	for i: int in range(2000):
		var id: String = Slot.pick_species(data, rng, pool)
		counts[id] = int(counts.get(id, 0)) + 1
	assert_true(counts["fire_drake"] > counts["fire_whelp"] * 2)
