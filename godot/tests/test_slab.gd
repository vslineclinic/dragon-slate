extends TestCase
## 내 석판: 석판의 칸은 내가 가진 룬 묶음에서 뽑힌다. 보상으로 받은 룬 한 장으로 묶음의 룬 하나를 바꾼다.

const RunRules = preload("res://godot/core/run.gd")

var _data: Dictionary = GameData.load_all()


func _counts(slab: Array, spins: int, seed: int) -> Dictionary:
	var rng: Rng = Rng.new(seed)
	var counts: Dictionary = {}
	for i: int in range(spins):
		var grid: Dictionary = Slot.spin_grid(_data, rng, false, slab)
		for reel: Array in grid["reels"]:
			for cell: Dictionary in reel:
				counts[cell["symbol"]] = int(counts.get(cell["symbol"], 0)) + 1
	return counts


func _reward_state(rune: String, seed: int = 4) -> Dictionary:
	var reward: Dictionary = {}
	for row: Dictionary in _data["rewards"]:
		if row["kind"] == "rune":
			reward = row
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state["phase"] = "reward"
	state["nest"][0] = {"uid": 1, "speciesId": "fire_drake", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}
	state["rewardChoices"] = [{"reward": reward, "detail": rune}]
	return state


func test_a_new_run_starts_with_the_starting_slab() -> void:
	var start: Array = _data["slot"]["slab"]["start"]
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	assert_eq(state["slab"], start)
	assert_true(start.size() >= 12)
	for element: String in GameData.active_elements(_data):
		assert_true(element in start, element)


func test_cells_come_only_from_the_slab() -> void:
	var counts: Dictionary = _counts(["fire", "fire", "ice", "gold"], 200, 7)
	var keys: Array = counts.keys()
	keys.sort()
	assert_eq(keys, ["fire", "gold", "ice"])


func test_adding_a_third_fire_rune_raises_fire_from_two_to_three_twelfths() -> void:
	var base: Array = ["fire", "fire", "ice", "ice", "lightning", "lightning", "poison", "poison", "steel", "steel", "gold", "wild"]
	var more: Array = base.duplicate()
	more[2] = "fire"
	var cells: int = 4000 * 15
	var before: int = int(_counts(base, 4000, 11).get("fire", 0))
	var after: int = int(_counts(more, 4000, 11).get("fire", 0))
	assert_true(absi(before - cells * 2 / 12) < cells / 100, "2/12 근처: %d" % before)
	assert_true(absi(after - cells * 3 / 12) < cells / 100, "3/12 근처: %d" % after)


func test_egg_cells_carry_a_base_species_of_their_rune() -> void:
	var grid: Dictionary = Slot.spin_grid(_data, Rng.new(5), false, ["ice", "ice", "wild"])
	for reel: Array in grid["reels"]:
		for cell: Dictionary in reel:
			var spec: Dictionary = _data["dragons"][cell["speciesId"]]
			assert_eq(spec["tier"], "base")
			if cell["symbol"] == "ice":
				assert_eq(spec["elements"][0], "ice")


func test_forced_line_uses_an_element_that_is_on_the_slab() -> void:
	for seed: int in range(1, 40):
		var grid: Dictionary = Slot.spin_grid(_data, Rng.new(seed), true, ["steel", "gold", "gold", "wild"])
		for col: int in range(3):
			assert_eq(Slot.visible(grid, col, 1)["symbol"], "steel")


func test_empty_slab_falls_back_to_the_old_weights() -> void:
	var a: Dictionary = Slot.spin_grid(_data, Rng.new(9), false)
	var b: Dictionary = Slot.spin_grid(_data, Rng.new(9), false, [])
	assert_eq(a, b)


func test_run_spins_from_the_slab_in_the_state() -> void:
	var state: Dictionary = RunRules.create_run(_data, 21)["state"]
	state["slab"] = ["abyss", "abyss", "abyss"]
	var result: Dictionary = RunRules.apply_command(_data, state, {"type": "spin"})
	for reel: Array in result["state"]["grid"]["reels"]:
		for cell: Dictionary in reel:
			assert_eq(cell["symbol"], "abyss")


func test_rune_reward_opens_the_slab_and_replacing_swaps_one_rune() -> void:
	var state: Dictionary = _reward_state("fire")
	var first: String = state["slab"][2]
	var chosen: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseReward", "index": 0})
	assert_eq(chosen["state"]["phase"], "slab")
	assert_eq(chosen["state"]["runePending"], "fire")
	var done: Dictionary = RunRules.apply_command(_data, chosen["state"], {"type": "replaceRune", "index": 2})
	assert_eq(done["state"]["slab"][2], "fire")
	assert_eq(done["state"]["slab"].size(), state["slab"].size())
	assert_eq(done["state"]["runePending"], null)
	assert_eq(done["state"]["phase"], "spin")
	var swapped: bool = false
	for event: Dictionary in done["events"]:
		swapped = swapped or (event["t"] == "runeReplaced" and event["from"] == first and event["to"] == "fire" and event["index"] == 2)
	assert_true(swapped)


func test_skipping_keeps_the_slab() -> void:
	var chosen: Dictionary = RunRules.apply_command(_data, _reward_state("ice"), {"type": "chooseReward", "index": 0})
	var done: Dictionary = RunRules.apply_command(_data, chosen["state"], {"type": "skipRune"})
	assert_eq(done["state"]["slab"], _data["slot"]["slab"]["start"])
	assert_eq(done["state"]["runePending"], null)
	assert_eq(done["state"]["phase"], "spin")


func test_slab_commands_are_rejected_outside_the_slab_phase_and_for_bad_cells() -> void:
	var fresh: Dictionary = RunRules.create_run(_data, 2)["state"]
	assert_eq(RunRules.apply_command(_data, fresh, {"type": "replaceRune", "index": 0})["events"][0].get("reason"), "wrongPhase")
	assert_eq(RunRules.apply_command(_data, fresh, {"type": "skipRune"})["events"][0].get("reason"), "wrongPhase")
	var chosen: Dictionary = RunRules.apply_command(_data, _reward_state("ice"), {"type": "chooseReward", "index": 0})["state"]
	assert_eq(RunRules.apply_command(_data, chosen, {"type": "replaceRune", "index": 99})["events"][0].get("reason"), "emptySlot")
	assert_eq(RunRules.apply_command(_data, chosen, {"type": "spin"})["events"][0].get("reason"), "wrongPhase")


func test_rune_reward_rolls_a_rune_the_player_can_see_before_choosing() -> void:
	var seen: Dictionary = {}
	for seed: int in range(1, 60):
		for choice: Dictionary in RunRules._roll_reward_choices(_data, Rng.new(seed), false):
			if choice["reward"]["kind"] == "rune":
				assert_true(choice["detail"] in _data["slot"]["slab"]["offer"], str(choice["detail"]))
				seen[choice["detail"]] = true
	assert_true(seen.size() >= 4, "여러 가지 룬이 나온다")


func test_species_odds_follow_the_slab() -> void:
	var none: int = Slot.species_odds(_data, "fire_drake", ["ice", "ice", "gold"])
	var some: int = Slot.species_odds(_data, "fire_drake", ["fire", "ice", "gold"])
	var more: int = Slot.species_odds(_data, "fire_drake", ["fire", "fire", "gold"])
	assert_eq(none, 0)
	assert_true(some > 0 and more > some)


func test_old_save_without_a_slab_still_spins() -> void:
	var state: Dictionary = RunRules.create_run(_data, 8)["state"]
	state.erase("slab")
	var result: Dictionary = RunRules.apply_command(_data, state, {"type": "spin"})
	assert_eq(result["state"]["phase"], "pick")


func test_forced_line_never_brings_back_an_element_the_player_removed() -> void:
	for seed: int in range(1, 40):
		var grid: Dictionary = Slot.spin_grid(_data, Rng.new(seed), true, ["gold", "gold", "wild"])
		for col: int in range(3):
			assert_true(Slot.visible(grid, col, 1)["symbol"] in ["gold", "wild"])


func test_old_save_without_a_slab_is_never_offered_a_rune() -> void:
	for seed: int in range(1, 80):
		for choice: Dictionary in RunRules._roll_reward_choices(_data, Rng.new(seed), false, false):
			assert_true(choice["reward"]["kind"] != "rune")
