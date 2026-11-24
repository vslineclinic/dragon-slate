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


## ── 시작 묶음 ──

const Bot = preload("res://godot/tools/bot.gd")


func test_start_options_offer_three_different_elements_fixed_by_the_seed() -> void:
	var seen: Dictionary = {}
	for seed: int in range(1, 30):
		var options: Array = RunRules.start_options(_data, seed)
		assert_eq(options, RunRules.start_options(_data, seed))
		assert_eq(options.size(), int(_data["slot"]["slab"]["choices"]))
		var ids: Dictionary = {}
		for option: Dictionary in options:
			ids[option["id"]] = true
			assert_true(option["id"] in GameData.active_elements(_data))
			seen[option["id"]] = true
		assert_eq(ids.size(), options.size())
	assert_eq(seen.size(), 6, "판마다 다른 묶음이 나온다")


func test_focus_bundle_has_four_of_its_element_and_one_of_each_it_beats() -> void:
	var slab_cfg: Dictionary = _data["slot"]["slab"]
	for element: String in GameData.active_elements(_data):
		var runes: Array = RunRules.start_bundle(_data, element)
		assert_eq(runes.size(), slab_cfg["start"].size(), element)
		assert_eq(runes.count(element), int(slab_cfg["focus"]["own"]))
		for weak: String in _data["battle"]["beats"][element]:
			assert_eq(runes.count(weak), int(slab_cfg["focus"]["beaten"]), element + " → " + weak)
		assert_eq(runes.count("gold"), slab_cfg["start"].count("gold"))
		assert_eq(runes.count("wild"), slab_cfg["start"].count("wild"))


func test_run_started_with_a_bundle_gets_its_slab_and_a_dragon_of_that_element() -> void:
	var option: Dictionary = RunRules.start_options(_data, 31)[1]
	var state: Dictionary = RunRules.create_run(_data, 31, 0, option["id"])["state"]
	assert_eq(state["slab"], option["runes"])
	assert_eq(state["start"], option["id"])
	assert_eq(state["phase"], "spin")
	var hatchling: Variant = state["bench"][0]
	assert_true(hatchling != null)
	if hatchling != null:
		assert_eq(hatchling["speciesId"], option["speciesId"])
		var spec: Dictionary = _data["dragons"][hatchling["speciesId"]]
		assert_eq([spec["tier"], spec["elements"][0]], ["base", option["id"]])
		assert_eq(int(state["nextUid"]), int(hatchling["uid"]) + 1)


func test_run_without_a_bundle_or_with_an_unknown_one_starts_balanced_and_empty() -> void:
	for start: String in ["", "water"]:
		var state: Dictionary = RunRules.create_run(_data, 31, 0, start)["state"]
		assert_eq(state["slab"], _data["slot"]["slab"]["start"])
		assert_eq(state["bench"], [null, null, null, null])
		assert_eq(state["start"], "")


func test_same_seed_grows_a_different_roost_depending_on_the_bundle() -> void:
	## 같은 씨앗에서 내놓은 묶음 둘(A, B)로 5웨이브까지: 고른 원소의 알이 더 많이 들어온다.
	var own: int = 0
	var other: int = 0
	for seed: int in [11, 12, 13, 14, 15, 16]:
		var options: Array = RunRules.start_options(_data, seed)
		var pair: Array = [options[0]["id"], options[1]["id"]]
		for mine: int in range(2):
			var state: Dictionary = RunRules.create_run(_data, seed, 0, pair[mine])["state"]
			assert_eq(state["start"], pair[mine])
			for step: int in range(600):
				if int(state["wave"]) > 5 or state["phase"] in ["gameOver", "victory"]:
					break
				var result: Dictionary = RunRules.apply_command(_data, state, Bot.choose(_data, state))
				state = result["state"]
				for event: Dictionary in result["events"]:
					if event["t"] != "gained":
						continue
					var element: String = _data["dragons"][event["inst"]["speciesId"]]["elements"][0]
					if element == pair[mine]:
						own += 1
					elif element == pair[1 - mine]:
						other += 1
	assert_true(own > other * 2, "고른 원소 %d마리, 고르지 않은 원소 %d마리" % [own, other])


## ── 룬 지우기 ──

func _erase_state(seed: int = 4) -> Dictionary:
	var state: Dictionary = _reward_state("fire", seed)
	for row: Dictionary in _data["rewards"]:
		if row["kind"] == "erase":
			state["rewardChoices"] = [{"reward": row, "detail": null}]
	return state


func test_erase_reward_removes_the_chosen_rune() -> void:
	var state: Dictionary = _erase_state()
	assert_eq(state["rewardChoices"][0]["reward"]["kind"], "erase")
	var chosen: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseReward", "index": 0})["state"]
	assert_eq([chosen["phase"], chosen["runePending"]], ["slab", "erase"])
	var gone: String = chosen["slab"][5]
	var done: Dictionary = RunRules.apply_command(_data, chosen, {"type": "replaceRune", "index": 5})
	assert_eq(done["state"]["slab"].size(), state["slab"].size() - 1)
	assert_eq(done["state"]["slab"].count(gone), state["slab"].count(gone) - 1)
	assert_eq([done["state"]["phase"], done["state"]["runePending"]], ["spin", null])
	assert_true(done["events"].any(func(event: Dictionary) -> bool: return event["t"] == "runeErased" and event["from"] == gone))


func test_erase_can_be_skipped() -> void:
	var chosen: Dictionary = RunRules.apply_command(_data, _erase_state(), {"type": "chooseReward", "index": 0})["state"]
	var done: Dictionary = RunRules.apply_command(_data, chosen, {"type": "skipRune"})["state"]
	assert_eq(done["slab"].size(), _data["slot"]["slab"]["start"].size())
	assert_eq(done["phase"], "spin")


func test_slab_never_shrinks_below_the_minimum() -> void:
	var state: Dictionary = _erase_state()
	var least: int = int(_data["slot"]["slab"]["minSize"])
	state["slab"] = state["slab"].slice(0, least)
	var chosen: Dictionary = RunRules.apply_command(_data, state, {"type": "chooseReward", "index": 0})
	assert_eq(chosen["state"]["phase"], "spin", "더 못 줄이면 마력으로 바뀐다")
	assert_eq(chosen["state"]["slab"].size(), least)
	assert_eq(int(chosen["state"]["mana"]), int(state["mana"]) + 3)


func test_old_save_without_a_slab_is_never_offered_an_erase() -> void:
	for seed: int in range(1, 80):
		for choice: Dictionary in RunRules._roll_reward_choices(_data, Rng.new(seed), true, false):
			assert_true(choice["reward"]["kind"] not in ["rune", "erase"])


func test_erase_rechecks_the_minimum_when_the_rune_is_chosen() -> void:
	var chosen: Dictionary = RunRules.apply_command(_data, _erase_state(), {"type": "chooseReward", "index": 0})["state"]
	var least: int = int(_data["slot"]["slab"]["minSize"])
	chosen["slab"] = chosen["slab"].slice(0, least)
	var done: Dictionary = RunRules.apply_command(_data, chosen, {"type": "replaceRune", "index": 0})["state"]
	assert_eq(done["slab"].size(), least)
	assert_eq(int(done["mana"]), int(chosen["mana"]) + 3)
	assert_eq([done["phase"], done["runePending"]], ["spin", null])
