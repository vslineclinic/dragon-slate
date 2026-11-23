class_name Run
extends RefCounted

const NEST_SIZE: int = 6
const BENCH_SIZE: int = 4
const START_NEST_OPEN: int = 3
const ARRANGE_PHASES: Array[String] = ["manage", "pick", "spin"]
const REWARD_CHOICES: int = 3


static func create_run(data: Dictionary, seed: int, calamity: int = 0) -> Dictionary:
	var mods: Dictionary = Calamity.mods(data, calamity)
	var nest: Array = []
	nest.resize(NEST_SIZE)
	var bench: Array = []
	bench.resize(BENCH_SIZE)
	var state: Dictionary = {
		"seed": seed & Rng.M32,
		"rngState": seed & Rng.M32,
		"calamity": calamity,
		"wave": 1,
		"phase": "spin",
		"lives": maxi(1, int(data["waves"]["startLives"]) + int(mods["startLivesAdd"])),
		"mana": data["waves"]["startMana"],
		"nest": nest,
		"nestOpen": START_NEST_OPEN,
		"bench": bench,
		"grid": null,
		"spinsThisWave": 0,
		"nudgesLeft": data["slot"]["nudgesPerWave"],
		"pity": 0,
		"nextUid": 1,
		"bonusNudges": 0,
		"freeSpins": 0,
		"rewardChoices": [],
		"discovered": [],
		"log": [],
	}
	return {"state": state, "events": [_wave_start(data, state)]}


static func apply_command(data: Dictionary, state: Dictionary, cmd: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var rng: Rng = Rng.new(next["seed"], next["rngState"])
	var events: Array = []
	var reason: String = ""
	match cmd["type"]:
		"spin":
			reason = _do_spin(data, next, rng, events)
		"nudge":
			reason = _do_nudge(next, cmd["col"], cmd["dir"], events)
		"pick":
			reason = _do_pick(data, next, cmd["index"], rng, events)
		"merge":
			reason = _do_merge(data, next, cmd["main"], cmd["material"], events)
		"move":
			reason = _do_move(next, cmd["from"], cmd["to"])
		"release":
			reason = _do_release(data, next, cmd["from"], events)
		"startBattle":
			reason = _do_battle(data, next, rng, events)
		"chooseReward":
			reason = _do_choose_reward(data, next, cmd["index"], rng, events)
		"skill":
			reason = _do_skill(data, next, cmd["at"], cmd["node"], events)
	if not reason.is_empty():
		return {"state": state, "events": [{"t": "rejected", "reason": reason}]}
	next["rngState"] = rng.state()
	next["log"].append(cmd.duplicate(true))
	return {"state": next, "events": events}


static func spin_cost(data: Dictionary, state: Dictionary) -> int:
	var paid: int = _paid_spin_cost(data, state)
	return 0 if paid > 0 and state["freeSpins"] > 0 else paid


static func state_hash(state: Dictionary) -> String:
	var snapshot: Dictionary = state.duplicate()
	snapshot.erase("log")
	return JSON.stringify(snapshot, "", false)


static func _boss_spec(data: Dictionary, wave: int) -> Variant:
	for boss: Dictionary in data["bosses"]:
		if boss["wave"] == wave:
			return boss
	return null


static func _wave_start(data: Dictionary, state: Dictionary) -> Dictionary:
	var wave: int = state["wave"]
	var preview: Variant = null
	var boss: Variant = null
	if (wave - 1) % 5 == 0:
		boss = _boss_spec(data, wave + 4)
		if Waves.is_boss(data["waves"], wave + 4):
			preview = Waves.boss_element(state["seed"], wave + 4, GameData.active_elements(data))
	return {"t": "waveStart", "wave": wave, "bossPreview": preview, "boss": boss}


static func _zone_of(state: Dictionary, ref: Dictionary) -> Array:
	return state["nest"] if ref["zone"] == "nest" else state["bench"]


static func _valid_index(index: Variant, size: int) -> bool:
	if index is int:
		return index >= 0 and index < size
	# JSON 명령의 정수도 float로 읽힌다.
	return index is float and index >= 0 and index < size and floorf(index) == index


static func _valid_ref(state: Dictionary, ref: Dictionary) -> String:
	var nest: bool = ref["zone"] == "nest"
	var index: Variant = ref["index"]
	if not _valid_index(index, NEST_SIZE if nest else BENCH_SIZE):
		return "emptySlot"
	if nest and index >= state["nestOpen"]:
		return "slotLocked"
	return ""


static func _dragon_count(state: Dictionary) -> int:
	var nest: Array = state["nest"]
	var bench: Array = state["bench"]
	return nest.size() - nest.count(null) + bench.size() - bench.count(null)


static func _arrange_rejection(state: Dictionary, a: Dictionary, b: Dictionary) -> String:
	if state["phase"] not in ARRANGE_PHASES:
		return "wrongPhase"
	if a["zone"] == b["zone"] and a["index"] == b["index"]:
		return "sameSlot"
	var reason: String = _valid_ref(state, a)
	return _valid_ref(state, b) if reason.is_empty() else reason


static func _species_of_tier(data: Dictionary, tier: String, element: String = "") -> Array:
	var pool: Array = []
	for spec: Dictionary in data["dragons"].values():
		var elements: Array = spec["elements"]
		if spec["tier"] == tier and (element.is_empty() or (not elements.is_empty() and elements[0] == element)):
			pool.append(spec["id"])
	pool.sort()
	return pool


static func _add_to_bench(state: Dictionary, species: String, via: String, events: Array) -> bool:
	var index: int = state["bench"].find(null)
	if index < 0:
		return false
	var inst: Dictionary = {
		"uid": state["nextUid"], "speciesId": species, "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0,
	}
	state["nextUid"] += 1
	state["bench"][index] = inst
	events.append({"t": "gained", "inst": inst, "to": {"zone": "bench", "index": index}, "via": via})
	return true


static func _add_mana(state: Dictionary, delta: int, reason: String, events: Array) -> void:
	if delta != 0:
		state["mana"] += delta
		events.append({"t": "mana", "delta": delta, "reason": reason})


static func _paid_spin_cost(data: Dictionary, state: Dictionary) -> int:
	var costs: Array = data["slot"]["rerollCosts"]
	if costs.is_empty() or _dragon_count(state) == 0:
		return 0
	var base: int = costs[mini(state["spinsThisWave"], costs.size() - 1)]
	return base + int(Calamity.mods(data, state["calamity"])["rerollCostAdd"]) if base > 0 else 0


static func _append_line_hits(groups: Array, events: Array) -> void:
	for group: Dictionary in groups:
		events.append({"t": "lineHit", "lines": group["lines"], "element": group["element"]})


static func _do_spin(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> String:
	if state["phase"] != "spin" and state["phase"] != "pick":
		return "wrongPhase"
	var cost: int = spin_cost(data, state)
	if cost == 0 and _paid_spin_cost(data, state) > 0:
		state["freeSpins"] -= 1
	if state["mana"] < cost:
		return "notEnoughMana"
	state["mana"] -= cost
	var grid: Dictionary = Slot.spin_grid(data, rng, state["pity"] >= data["slot"]["pityThreshold"])
	var groups: Array = Slot.evaluate_lines(grid)
	state["pity"] = state["pity"] + 1 if groups.is_empty() else 0
	state["spinsThisWave"] += 1
	state["grid"] = grid
	state["phase"] = "pick"
	events.append({"t": "spun", "grid": grid, "cost": cost})
	if cost > 0:
		events.append({"t": "mana", "delta": -cost, "reason": "reroll"})
	_append_line_hits(groups, events)
	return ""


static func _do_nudge(state: Dictionary, col: int, dir: int, events: Array) -> String:
	if state["phase"] != "pick" or state["grid"] == null:
		return "wrongPhase"
	if state["nudgesLeft"] <= 0:
		return "noNudgeLeft"
	var grid: Dictionary = Slot.nudge(state["grid"], col, dir)
	state["grid"] = grid
	state["nudgesLeft"] -= 1
	events.append({"t": "nudged", "grid": grid})
	_append_line_hits(Slot.evaluate_lines(grid), events)
	return ""


static func _do_pick(data: Dictionary, state: Dictionary, index: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] != "pick" or state["grid"] == null:
		return "wrongPhase"
	var grid: Dictionary = state["grid"]
	var offers: Array = Slot.offers_from(data, grid)
	if not _valid_index(index, offers.size()):
		return "emptySlot"
	var offer: Dictionary = offers[int(index)]
	if offer["kind"] == "egg":
		if not _add_to_bench(state, offer["speciesId"], "pick", events):
			return "benchFull"
	else:
		_add_mana(state, offer["amount"], "goldOffer", events)

	var converted: int = 0
	for group: Dictionary in Slot.evaluate_lines(grid):
		match group["element"]:
			"gold":
				_add_mana(state, data["slot"]["goldLineMana"], "goldLine", events)
			"wild":
				_add_mana(state, data["slot"]["wildLineMana"], "wildLine", events)
			_:
				var tier: String = "t2" if group["lines"].size() >= 2 else "base"
				var pool: Array = _species_of_tier(data, tier, group["element"])
				var roll: int = rng.next_int(maxi(1, pool.size()))
				if not pool.is_empty() and not _add_to_bench(state, pool[roll], "bonus", events):
					converted += 1
				_add_mana(state, data["slot"]["lineMana"], "line", events)
	_add_mana(state, converted, "benchFull", events)
	var gold: int = 0
	for col: int in range(3):
		for row: int in range(3):
			if Slot.visible(grid, col, row).get("symbol") == "gold":
				gold += 1
	_add_mana(state, gold * int(data["slot"]["goldMana"]), "goldCells", events)

	if _dragon_count(state) == 0:
		return "needDragon"
	state["grid"] = null
	state["phase"] = "manage"
	return ""


static func _do_merge(data: Dictionary, state: Dictionary, main: Dictionary, material: Dictionary, events: Array) -> String:
	var reason: String = _arrange_rejection(state, main, material)
	if not reason.is_empty():
		return reason
	var main_zone: Array = _zone_of(state, main)
	var material_zone: Array = _zone_of(state, material)
	var main_index: int = int(main["index"])
	var material_index: int = int(material["index"])
	var a: Variant = main_zone[main_index]
	var b: Variant = material_zone[material_index]
	if a == null or b == null:
		return "emptySlot"
	var result: Dictionary = Fusion.merge(data, a, b, state["nextUid"])
	var inst: Dictionary = result["inst"]
	main_zone[main_index] = inst
	material_zone[material_index] = null
	if result["kind"] == "evolve":
		state["nextUid"] += 1
		var first_time: bool = inst["speciesId"] not in state["discovered"]
		if first_time:
			state["discovered"].append(inst["speciesId"])
		events.append({"t": "evolved", "inst": inst, "at": main.duplicate(true), "firstTime": first_time})
	else:
		events.append({"t": "absorbed", "inst": inst, "at": main.duplicate(true), "trait": result["trait"]})
	return ""


static func _do_move(state: Dictionary, from: Dictionary, to: Dictionary) -> String:
	var reason: String = _arrange_rejection(state, from, to)
	if not reason.is_empty():
		return reason
	var from_zone: Array = _zone_of(state, from)
	var to_zone: Array = _zone_of(state, to)
	var from_index: int = int(from["index"])
	var to_index: int = int(to["index"])
	var inst: Variant = from_zone[from_index]
	if inst == null:
		return "emptySlot"
	from_zone[from_index] = to_zone[to_index]
	to_zone[to_index] = inst
	return ""


static func _do_release(data: Dictionary, state: Dictionary, from: Dictionary, events: Array) -> String:
	if state["phase"] not in ARRANGE_PHASES:
		return "wrongPhase"
	var reason: String = _valid_ref(state, from)
	if not reason.is_empty():
		return reason
	var zone: Array = _zone_of(state, from)
	var index: int = int(from["index"])
	var inst: Variant = zone[index]
	if inst == null:
		return "emptySlot"
	if _dragon_count(state) <= 1:
		return "needDragon"
	zone[index] = null
	var spec: Dictionary = data["dragons"].get(inst["speciesId"], {})
	_add_mana(state, data["waves"]["releaseMana"].get(spec.get("tier", "base"), 0), "release", events)
	return ""


## 보상 후보 3개를 겹치지 않게 뽑는다. 알은 어떤 종인지 미리 정해 카드에 보여 준다.
static func _roll_reward_choices(data: Dictionary, rng: Rng, boss: bool) -> Array:
	var pool: Array = []
	var weights: Array = []
	var weight_key: String = "bossWeight" if boss else "weight"
	for candidate: Dictionary in data["rewards"]:
		var weight: int = candidate[weight_key]
		if weight > 0:
			pool.append(candidate)
			weights.append(weight)
	var choices: Array = []
	while choices.size() < REWARD_CHOICES and not pool.is_empty():
		var reward: Dictionary = rng.pick_weighted(pool, weights)
		var at: int = pool.find(reward)
		pool.remove_at(at)
		weights.remove_at(at)
		var detail: Variant = null
		if reward["kind"] in ["egg", "t2egg"]:
			var species: Array = _species_of_tier(data, "base" if reward["kind"] == "egg" else "t2")
			var roll: int = rng.next_int(maxi(1, species.size()))
			if not species.is_empty():
				detail = species[roll]
		choices.append({"reward": reward, "detail": detail})
	return choices


static func _do_choose_reward(data: Dictionary, state: Dictionary, index: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] != "reward":
		return "wrongPhase"
	var choices: Array = state.get("rewardChoices", [])
	if not _valid_index(index, choices.size()):
		return "emptySlot"
	var choice: Dictionary = choices[int(index)]
	_apply_reward(data, state, rng, choice["reward"], choice["detail"], events)
	state["rewardChoices"] = []
	state["nudgesLeft"] += int(state["bonusNudges"])
	state["bonusNudges"] = 0
	state["phase"] = "spin"
	events.append(_wave_start(data, state))
	return ""


static func _do_skill(data: Dictionary, state: Dictionary, at: Dictionary, node: String, events: Array) -> String:
	if state["phase"] not in ARRANGE_PHASES:
		return "wrongPhase"
	var reason: String = _valid_ref(state, at)
	if not reason.is_empty():
		return reason
	var zone: Array = _zone_of(state, at)
	var inst: Variant = zone[int(at["index"])]
	if inst == null:
		return "emptySlot"
	reason = Fusion.skill_rejection(data, inst, node)
	if not reason.is_empty():
		return reason
	if not inst.has("skills"):
		inst["skills"] = {}
	inst["skills"][node] = int(inst["skills"].get(node, 0)) + 1
	inst["skillPoints"] = int(inst.get("skillPoints", 0)) - 1
	events.append({"t": "skilled", "at": at.duplicate(true), "node": node, "level": inst["skills"][node]})
	return ""


static func _apply_reward(data: Dictionary, state: Dictionary, rng: Rng, reward: Dictionary, detail: Variant, events: Array) -> void:
	match reward["kind"]:
		"mana":
			_add_mana(state, reward["amount"], "reward", events)
		"egg", "t2egg":
			var tier: String = "base" if reward["kind"] == "egg" else "t2"
			if detail != null:
				if not _add_to_bench(state, detail, "reward", events):
					_add_mana(state, 1 if tier == "base" else 2, "benchFull", events)
		"trait":
			detail = _reward_trait(data, state, rng)
			if detail == null:
				_add_mana(state, 3, "reward", events)
		"nudge":
			state["bonusNudges"] += reward["amount"]
		"freeSpin":
			state["freeSpins"] += reward["amount"]
		"life":
			var max_lives: int = data["waves"]["startLives"]
			if state["lives"] < max_lives:
				state["lives"] = mini(max_lives, int(state["lives"]) + int(reward["amount"]))
			else:
				_add_mana(state, 3, "reward", events)
	events.append({"t": "reward", "reward": reward, "detail": detail})


static func _reward_trait(data: Dictionary, state: Dictionary, rng: Rng) -> Variant:
	var targets: Array = []
	var max_traits: int = data["battle"]["maxTraits"]
	for inst: Variant in state["nest"] + state["bench"]:
		if inst != null and inst["traits"].size() < max_traits:
			targets.append(inst)
	var target_index: int = rng.next_int(maxi(1, targets.size()))
	var target: Variant = null if targets.is_empty() else targets[target_index]
	var choices: Array = []
	if target != null:
		var spec: Dictionary = data["dragons"].get(target["speciesId"], {})
		var own: Variant = spec.get("traitId")
		for trait_id: String in data["traits"]:
			if trait_id != own and trait_id not in target["traits"]:
				choices.append(trait_id)
		choices.sort()
	var trait_index: int = rng.next_int(maxi(1, choices.size()))
	if choices.is_empty():
		return null
	var trait_id: String = choices[trait_index]
	target["traits"].append(trait_id)
	return trait_id


static func _do_battle(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> String:
	if state["phase"] != "manage":
		return "wrongPhase"
	var allies: Array = []
	var has_ally: bool = false
	for i: int in range(state["nest"].size()):
		var inst: Variant = state["nest"][i]
		if inst != null and i < state["nestOpen"]:
			has_ally = true
			allies.append(Battle.to_unit(data, inst))
		else:
			allies.append(null)
	if not has_ally:
		return "nestEmpty"
	var wave: int = state["wave"]
	var waves: Dictionary = data["waves"]
	var mods: Dictionary = Calamity.mods(data, state["calamity"])
	var enemies: Array = Waves.generate_enemies(data, wave, rng, state["seed"], mods)
	var is_boss: bool = Waves.is_boss(waves, wave)
	var boss: Variant = _boss_spec(data, wave) if is_boss else null
	var rules: Dictionary = {} if boss == null else boss.get("rules", {})
	var result: Dictionary = Battle.simulate_battle(data["battle"], allies, enemies, rules)
	events.append({"t": "battle", "result": result})
	var won: bool = result["winner"] == "ally"
	if won:
		_add_mana(state, Rng.fdiv(int(waves["winMana"]) * (100 + int(mods["winManaPct"])), 100), "win", events)
	else:
		var loss: int = waves["bossLossLife"] if is_boss else waves["lossLife"]
		state["lives"] = maxi(0, int(state["lives"]) - loss)
		events.append({"t": "lives", "lives": state["lives"]})
		_add_mana(state, waves["lossMana"], "loss", events)
	if wave in waves["nestUnlockAfter"] and state["nestOpen"] < NEST_SIZE:
		state["nestOpen"] += 1
		events.append({"t": "nestUnlocked", "open": state["nestOpen"]})
	if state["lives"] <= 0:
		state["phase"] = "gameOver"
		events.append({"t": "gameOver"})
		return ""
	if wave < waves["maxWave"]:
		state["wave"] += 1
	elif won:
		state["phase"] = "victory"
		events.append({"t": "victory"})
		return ""
	state["spinsThisWave"] = 0
	state["nudgesLeft"] = int(data["slot"]["nudgesPerWave"]) + int(state["bonusNudges"])
	state["bonusNudges"] = 0
	if won:
		state["rewardChoices"] = _roll_reward_choices(data, rng, is_boss)
	if won and not state["rewardChoices"].is_empty():
		state["phase"] = "reward"
		events.append({"t": "rewardChoices", "choices": state["rewardChoices"]})
		return ""
	state["phase"] = "spin"
	events.append(_wave_start(data, state))
	return ""
