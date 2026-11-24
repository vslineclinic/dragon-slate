class_name Run
extends RefCounted

const NEST_SIZE: int = 6
const BENCH_SIZE: int = 4
const START_NEST_OPEN: int = 3
const ARRANGE_PHASES: Array[String] = ["manage", "pick", "spin"]
const REWARD_CHOICES: int = 3


## 시작 묶음: 한 원소에 힘을 실은 룬 묶음. 그 원소 룬이 focus.own장, 그 원소가 이기는 원소는 focus.beaten장, 나머지는 기본 그대로.
static func start_bundle(data: Dictionary, element: String) -> Array:
	var cfg: Dictionary = data["slot"].get("slab", {})
	var focus: Dictionary = cfg.get("focus", {})
	var beaten: Array = data["battle"]["beats"].get(element, [])
	var runes: Array = []
	var placed: Dictionary = {}
	for symbol: String in cfg.get("start", []):
		var limit: int = -1
		if symbol == element:
			limit = int(focus.get("own", 2))
		elif symbol in beaten:
			limit = int(focus.get("beaten", 2))
		if limit >= 0:
			if int(placed.get(symbol, 0)) >= limit:
				continue
			placed[symbol] = int(placed.get(symbol, 0)) + 1
		runes.append(symbol)
	## 모자란 주력 룬을 주력 원소 자리 바로 뒤에 채워 넣는다(같은 무늬가 모여 있게).
	var at: int = runes.rfind(element) + 1
	while runes.count(element) < int(focus.get("own", 2)):
		runes.insert(at, element)
	return runes


## 판을 시작할 때 고를 수 있는 묶음(판 씨앗으로 정해진다): {"id": 원소, "runes": 묶음, "speciesId": 함께 오는 용}.
static func start_options(data: Dictionary, seed: int) -> Array:
	var cfg: Dictionary = data["slot"].get("slab", {})
	var elements: Array = GameData.active_elements(data).duplicate()
	var rng: Rng = Rng.new(((seed & Rng.M32) ^ 0x5bd1e995) & Rng.M32)
	var options: Array = []
	while options.size() < int(cfg.get("choices", 0)) and not elements.is_empty():
		var element: String = elements[rng.next_int(elements.size())]
		elements.erase(element)
		var pool: Array = Slot.base_pool(data, element)
		options.append({
			"id": element, "runes": start_bundle(data, element),
			"speciesId": "" if pool.is_empty() else Slot.pick_species(data, rng, pool),
		})
	return options


## start = 시작 묶음의 원소. 이번 판에 내놓은 묶음이 아니면(빈 글 포함) 기본 묶음으로, 용 없이 시작한다.
## carry = 앞 지역에서 데려온 용({"speciesId", "traits"}). 레벨 1로 대기칸에 들어온다.
static func create_run(data: Dictionary, seed: int, calamity: int = 0, start: String = "", carry: Dictionary = {}) -> Dictionary:
	var mods: Dictionary = Calamity.mods(data, calamity)
	var chosen: Dictionary = {}
	for option: Dictionary in start_options(data, seed):
		if option["id"] == start:
			chosen = option
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
		"rewardRerolls": 0,
		"nudgesBought": 0,
		"shopPending": false,
		"shop": null,
		"shopVisits": 0,
		"relics": [],
		"relicChoices": [],
		"relicPending": false,
		"forkPending": false,
		"forkChoices": [],
		"waveMod": {},
		"extraRewards": 0,
		"rewardBoss": false,
		"discovered": [],
		"items": {},
		"transmuteFails": 0,
		"slab": data["slot"].get("slab", {}).get("start", []).duplicate(),
		"runePending": null,
		"start": "",
		"carry": "",
		"cursePct": 0,
		"livesLost": 0,
		"log": [],
	}
	var events: Array = []
	if data["dragons"].has(carry.get("speciesId", "")):
		var kept: Array = []
		for trait_id: Variant in carry.get("traits", []):
			if data["traits"].has(trait_id) and kept.size() < int(data["battle"]["maxTraits"]) and trait_id not in kept:
				kept.append(trait_id)
		if _add_to_bench(state, carry["speciesId"], "carry", events):
			state["bench"][0]["traits"] = kept
			state["carry"] = carry["speciesId"]
	if not chosen.is_empty():
		state["slab"] = chosen["runes"].duplicate()
		state["start"] = chosen["id"]
		if not chosen["speciesId"].is_empty():
			_add_to_bench(state, chosen["speciesId"], "start", events)
	events.append(_wave_start(data, state))
	return {"state": state, "events": events}


static func apply_command(data: Dictionary, state: Dictionary, cmd: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var rng: Rng = Rng.new(next["seed"], next["rngState"])
	var events: Array = []
	var reason: String = ""
	match cmd["type"]:
		"spin":
			reason = _do_spin(data, next, rng, events)
		"nudge":
			reason = _do_nudge(data, next, cmd["col"], cmd["dir"], events)
		"pick":
			reason = _do_pick(data, next, cmd["index"], rng, events)
		"merge":
			reason = _do_merge(data, next, cmd["main"], cmd["material"], events, cmd.get("choice", 0))
		"move":
			reason = _do_move(next, cmd["from"], cmd["to"])
		"release":
			reason = _do_release(data, next, cmd["from"], events)
		"startBattle":
			reason = _do_battle(data, next, rng, events, cmd)
		"chooseReward":
			reason = _do_choose_reward(data, next, cmd["index"], rng, events)
		"skill":
			reason = _do_skill(data, next, cmd["at"], cmd["node"], events)
		"chooseRelic":
			reason = _do_choose_relic(data, next, cmd["index"], rng, events)
		"chooseFork":
			reason = _do_choose_fork(data, next, cmd["option"], rng, events)
		"transmute":
			reason = _do_transmute(data, next, cmd["at"], cmd["element"], rng, events)
		"replaceRune":
			reason = _do_rune(data, next, cmd["index"], rng, events)
		"skipRune":
			reason = _do_rune(data, next, null, rng, events)
		"rerollRewards":
			reason = _do_reroll_rewards(data, next, rng, events)
		"buy":
			reason = _do_buy(data, next, cmd.get("index"), events)
		"leaveShop":
			reason = _do_leave_shop(data, next, rng, events)
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
	if ref.get("zone") not in ["nest", "bench"]:
		return "emptySlot"
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
		"level": 1, "xp": 0,
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
	if costs.is_empty():
		return 0
	## 용이 한 마리도 없을 때: 고를 알이 없으면 무료로 다시 돌린다(막히지 않게).
	## 알이 나와 있으면 그 알을 고르거나 값을 내야 한다(좋은 첫 알이 뜰 때까지 공짜로 돌리지 못하게).
	if _dragon_count(state) == 0:
		var egg_offered: bool = false
		if state.get("grid") != null:
			for offer: Dictionary in Slot.offers_from(data, state["grid"]):
				egg_offered = egg_offered or offer["kind"] == "egg"
		if not egg_offered:
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
	var grid: Dictionary = Slot.spin_grid(data, rng, state["pity"] >= data["slot"]["pityThreshold"], state.get("slab", []))
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


## 지금 한 번 미는 값: 0 = 무료 밀기가 남았다, 양수 = 마력을 내고 민다, -1 = 이번 웨이브에는 더 밀 수 없다.
static func nudge_cost(data: Dictionary, state: Dictionary) -> int:
	if int(state["nudgesLeft"]) > 0:
		return 0
	var buy: Dictionary = data["slot"].get("nudgeBuy", {})
	if int(state.get("nudgesBought", 0)) >= int(buy.get("perWave", 0)):
		return -1
	return maxi(0, int(buy.get("cost", 0)))


static func _do_nudge(data: Dictionary, state: Dictionary, col: int, dir: int, events: Array) -> String:
	if state["phase"] != "pick" or state["grid"] == null:
		return "wrongPhase"
	var cost: int = nudge_cost(data, state)
	if cost < 0:
		return "noNudgeLeft"
	if int(state["mana"]) < cost:
		return "notEnoughMana"
	if col < 0 or col > 2 or dir not in [-1, 1]:
		return "cannotNudge"
	var grid: Dictionary = Slot.nudge(state["grid"], col, dir)
	## 끝까지 밀린 열은 더 움직이지 않는다: 밀기도 마력도 쓰지 않고 거절한다.
	if grid["offsets"] == state["grid"]["offsets"]:
		return "cannotNudge"
	state["grid"] = grid
	if int(state["nudgesLeft"]) > 0:
		state["nudgesLeft"] -= 1
	else:
		## 무료 밀기를 다 쓴 뒤: 마력을 내고 민다(웨이브마다 slot.nudgeBuy.perWave번까지).
		state["nudgesBought"] = int(state.get("nudgesBought", 0)) + 1
	events.append({"t": "nudged", "grid": grid, "cost": cost})
	_add_mana(state, -cost, "nudge", events)
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
				## 유물 "여의주 왕관": 여의주 줄을 맞추면 2티어 알도 받는다(대기칸이 꽉 찼으면 마력).
				if relic_bonus(data, state).has("wildLineEgg"):
					var crowned: Array = _species_of_tier(data, "t2")
					if not crowned.is_empty() and not _add_to_bench(state, Slot.pick_species(data, rng, crowned), "bonus", events):
						converted += 2
			_:
				var tier: String = "t2" if group["lines"].size() >= 2 else "base"
				var pool: Array = _species_of_tier(data, tier, group["element"])
				var bonus_species: String = "" if pool.is_empty() else Slot.pick_species(data, rng, pool)
				if pool.is_empty():
					rng.next_int(1)
				if not pool.is_empty() and not _add_to_bench(state, bonus_species, "bonus", events):
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


static func _do_merge(data: Dictionary, state: Dictionary, main: Dictionary, material: Dictionary, events: Array, choice: Variant = 0) -> String:
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
	## 계보 선택: 진화할 때만 본다. 없는 갈래를 고르면 거절한다.
	var preview: Dictionary = Fusion.merge_preview(data, a, b)
	if preview["kind"] == "evolve" and not _valid_index(choice, preview["options"].size()):
		return "emptySlot"
	var result: Dictionary = Fusion.merge(data, a, b, state["nextUid"], int(choice) if preview["kind"] == "evolve" else 0)
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
		events.append({"t": "absorbed", "inst": inst, "at": main.duplicate(true), "trait": result["trait"], "levels": result["levels"]})
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
	var release_mana: int = int(data["waves"]["releaseMana"].get(spec.get("tier", "base"), 0))
	_add_mana(state, Rng.fdiv(release_mana * (100 + int(relic_bonus(data, state).get("releasePct", 0))), 100), "release", events)
	return ""


## 보상 후보 3개를 겹치지 않게 뽑는다. 알은 어떤 종인지 미리 정해 카드에 보여 준다.
## with_rune = 내 석판이 있는 판인지. 석판이 없는 옛 저장에는 "룬 한 장"을 내놓지 않는다.
## skip = 내놓지 않을 보상 id(다시 뽑을 때 방금 본 것).
static func _roll_reward_choices(data: Dictionary, rng: Rng, boss: bool, with_rune: bool = true, skip: Array = []) -> Array:
	var pool: Array = []
	var weights: Array = []
	var weight_key: String = "bossWeight" if boss else "weight"
	for candidate: Dictionary in data["rewards"]:
		var weight: int = candidate[weight_key]
		if candidate["kind"] in ["rune", "erase"] and not with_rune:
			continue
		if candidate["id"] in skip:
			continue
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
			if species.is_empty():
				rng.next_int(1)
			else:
				detail = Slot.pick_species(data, rng, species)
		elif reward["kind"] == "rune":
			## 어떤 룬인지 미리 정해 카드에 보여 준다.
			var runes: Array = data["slot"].get("slab", {}).get("offer", [])
			detail = null if runes.is_empty() else runes[rng.next_int(runes.size())]
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
	if state.get("runePending") != null:
		## 룬 한 장: 석판의 어느 룬과 바꿀지 고를 때까지 멈춘다.
		state["phase"] = "slab"
		events.append({"t": "runeOffer", "rune": state["runePending"]})
		return ""
	_after_reward(data, state, rng, events)
	return ""


## 보상 다시 뽑기의 값: 양수(또는 0) = 마력, -1 = 이 보상 화면에서는 더 뽑을 수 없다.
static func reward_reroll_cost(data: Dictionary, state: Dictionary) -> int:
	var cfg: Dictionary = data["waves"].get("rewardReroll", {})
	if int(state.get("rewardRerolls", 0)) >= int(cfg.get("perScreen", 0)):
		return -1
	## 방금 본 것을 빼고도 석 장을 채울 수 있어야 한다(값을 내고 같은 카드를 다시 보지 않게).
	var seen: Array = []
	for choice: Dictionary in state.get("rewardChoices", []):
		seen.append(choice["reward"]["id"])
	var weight_key: String = "bossWeight" if state.get("rewardBoss", false) else "weight"
	var with_rune: bool = not state.get("slab", []).is_empty()
	var fresh: int = 0
	for candidate: Dictionary in data["rewards"]:
		if int(candidate[weight_key]) > 0 and candidate["id"] not in seen and (with_rune or candidate["kind"] not in ["rune", "erase"]):
			fresh += 1
	if fresh < REWARD_CHOICES:
		return -1
	return maxi(0, int(cfg.get("cost", 0)))


## 보상 다시 뽑기: 마력을 내고 세 장을 새로 뽑는다(방금 본 보상은 빼고). 한 보상 화면에서 perScreen번까지.
static func _do_reroll_rewards(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> String:
	if state["phase"] != "reward" or state.get("rewardChoices", []).is_empty():
		return "wrongPhase"
	var cost: int = reward_reroll_cost(data, state)
	if cost < 0:
		return "noRerollLeft"
	if int(state["mana"]) < cost:
		return "notEnoughMana"
	var seen: Array = []
	for choice: Dictionary in state["rewardChoices"]:
		seen.append(choice["reward"]["id"])
	var choices: Array = _roll_reward_choices(data, rng, state.get("rewardBoss", false), not state.get("slab", []).is_empty(), seen)
	if choices.is_empty():
		return "noRerollLeft"
	_add_mana(state, -cost, "rewardReroll", events)
	state["rewardRerolls"] = int(state.get("rewardRerolls", 0)) + 1
	state["rewardChoices"] = choices
	events.append({"t": "rewardChoices", "choices": choices, "rerolled": true})
	return ""


## 보상을 받은 뒤: 보상을 한 번 더 고르거나(정예 사냥) 다음 차례로.
static func _after_reward(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> void:
	if int(state.get("extraRewards", 0)) > 0:
		state["extraRewards"] = int(state["extraRewards"]) - 1
		state["rewardRerolls"] = 0
		state["rewardChoices"] = _roll_reward_choices(data, rng, state.get("rewardBoss", false), not state.get("slab", []).is_empty())
		if not state["rewardChoices"].is_empty():
			state["phase"] = "reward"
			events.append({"t": "rewardChoices", "choices": state["rewardChoices"]})
			return
	_proceed(data, state, rng, events)


## 내 석판 고치기: index 칸의 룬을 받은 룬으로 바꾼다. index가 null이면 넘긴다.
static func _do_rune(data: Dictionary, state: Dictionary, index: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] != "slab" or state.get("runePending") == null:
		return "wrongPhase"
	var rune: String = state["runePending"]
	## 상점에서 산 룬이면 끝난 뒤 상점으로 돌아간다. refund = 아직 쓰지 않아서 무를 수 있는 물건의 번호(없으면 -1).
	var shop: Variant = state.get("shop")
	var refund: int = int(shop.get("refund", -1)) if shop is Dictionary else -1
	if index != null:
		var slab: Array = state.get("slab", [])
		if not _valid_index(index, slab.size()):
			return "emptySlot"
		## 이미 그 룬인 칸은 바꿀 것이 없다: 룬도, 무를 기회도 쓰지 않고 거절한다.
		if rune != "erase" and slab[int(index)] == rune:
			return "sameRune"
		if rune == "erase" and slab.size() <= int(data["slot"].get("slab", {}).get("minSize", 0)):
			## 그사이 묶음이 가장 적은 장수가 됐으면 빼지 않고 마력으로 준다(상점에서 샀으면 값을 돌려준다).
			if refund < 0:
				_add_mana(state, 3, "reward", events)
		elif rune == "erase":
			refund = -1
			## 룬 지우기: 그 룬을 묶음에서 뺀다.
			events.append({"t": "runeErased", "index": int(index), "from": slab[int(index)]})
			slab.remove_at(int(index))
		else:
			events.append({"t": "runeReplaced", "index": int(index), "from": slab[int(index)], "to": rune})
			slab[int(index)] = rune
			state["runeUses"] = int(state.get("runeUses", 1)) - 1
			refund = -1
			if int(state["runeUses"]) > 0:
				## 아직 더 바꿀 수 있다: 석판 차례에 머문다(한 장이라도 바꿨으니 이제 무를 수 없다).
				if shop is Dictionary:
					shop["refund"] = -1
				return ""
	else:
		events.append({"t": "runeSkipped", "rune": rune})
	state["runePending"] = null
	state["runeUses"] = 0
	if shop is Dictionary:
		## 상점에서 산 룬을 쓰지 않고 돌아왔다: 값을 돌려주고 물건을 다시 진열한다.
		var items: Array = shop.get("items", [])
		if refund >= 0 and refund < items.size():
			items[refund]["sold"] = false
			_add_mana(state, int(items[refund]["cost"]), "refund", events)
			events.append({"t": "refunded", "index": refund, "item": items[refund].duplicate(true)})
		shop["refund"] = -1
		state["phase"] = "shop"
		return ""
	_after_reward(data, state, rng, events)
	return ""


## 보상 뒤의 차례: 유물 → 상점 → 갈림길 → 다음 웨이브.
static func _proceed(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> void:
	if _offer_relics(data, state, rng, events):
		return
	if _open_shop(data, state, events):
		return
	if state.get("forkPending", false):
		state["forkPending"] = false
		state["forkChoices"] = ["elite", "rest", "merchant"] + (["pact"] if int(data["waves"].get("fork", {}).get("pactPowerPct", 0)) > 0 else [])
		state["phase"] = "fork"
		events.append({"t": "forkChoices", "choices": state["forkChoices"]})
		return
	state["phase"] = "spin"
	events.append(_wave_start(data, state))


## 갈림길: 정예 사냥(다음 적이 강해지고 보상을 한 번 더) · 쉼터(생명과 경험치) · 상인(상점을 한 번 더 연다) · 저주의 계약.
static func _do_choose_fork(data: Dictionary, state: Dictionary, option: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] != "fork":
		return "wrongPhase"
	if option not in state.get("forkChoices", []):
		return "emptySlot"
	var fork: Dictionary = data["waves"].get("fork", {})
	match option:
		"elite":
			state["waveMod"] = {"powerPct": int(fork.get("elitePowerPct", 0)), "extraRewards": 1}
		"rest":
			var max_lives: int = maxi(int(state["lives"]), int(data["waves"]["startLives"]))
			state["lives"] = mini(max_lives, int(state["lives"]) + int(fork.get("restLives", 0)))
			events.append({"t": "lives", "lives": state["lives"]})
			for zone: String in ["nest", "bench"]:
				for i: int in range(state[zone].size()):
					var inst: Variant = state[zone][i]
					if inst != null and Fusion.add_xp(data, inst, int(fork.get("restXp", 0))) > 0:
						events.append({"t": "leveled", "at": {"zone": zone, "index": i}, "level": inst["level"]})
		"merchant":
			## 떠돌이 상인: 들어가는 값은 없다. 상점이 한 번 더 열린다.
			state["shopPending"] = true
		"pact":
			## 저주: 판이 끝날 때까지 적이 세지는 대신 유물을 바로 하나 고른다.
			state["cursePct"] = int(state.get("cursePct", 0)) + int(fork.get("pactPowerPct", 0))
			state["relicPending"] = true
	state["forkChoices"] = []
	events.append({"t": "fork", "option": option})
	_proceed(data, state, rng, events)
	return ""


## 가진 유물의 효과를 종류별 합으로.
static func relic_bonus(data: Dictionary, state: Dictionary) -> Dictionary:
	var bonus: Dictionary = {}
	for relic: Dictionary in data.get("relics", []):
		if relic["id"] in state.get("relics", []):
			bonus[relic["kind"]] = int(bonus.get(relic["kind"], 0)) + int(relic["value"])
	return bonus


## 보스를 이긴 뒤: 아직 없는 유물 셋을 내놓는다. 내놓았으면 true.
static func _offer_relics(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> bool:
	if not state.get("relicPending", false):
		return false
	state["relicPending"] = false
	var pool: Array = []
	for relic: Dictionary in data.get("relics", []):
		if relic["id"] not in state["relics"]:
			pool.append(relic["id"])
	var choices: Array = []
	while choices.size() < REWARD_CHOICES and not pool.is_empty():
		var at: int = rng.next_int(pool.size())
		choices.append(pool[at])
		pool.remove_at(at)
	if choices.is_empty():
		return false
	state["relicChoices"] = choices
	state["phase"] = "relic"
	events.append({"t": "relicChoices", "choices": choices})
	return true


static func _do_choose_relic(data: Dictionary, state: Dictionary, index: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] != "relic":
		return "wrongPhase"
	var choices: Array = state.get("relicChoices", [])
	if not _valid_index(index, choices.size()):
		return "emptySlot"
	state["relicChoices"] = []
	_grant_relic(data, state, choices[int(index)], events)
	_proceed(data, state, rng, events)
	return ""


## 유물 하나를 갖는다(받는 즉시 드는 효과 포함).
static func _grant_relic(data: Dictionary, state: Dictionary, id: String, events: Array) -> void:
	state["relics"].append(id)
	for relic: Dictionary in data.get("relics", []):
		if relic["id"] != id:
			continue
		if relic["kind"] == "life":
			state["lives"] = int(state["lives"]) + int(relic["value"])
			events.append({"t": "lives", "lives": state["lives"]})
		elif relic["kind"] == "nudge":
			state["nudgesLeft"] += int(relic["value"])
		elif relic["kind"] == "transmuteSure":
			## 현자의 돌: 전환의 룬 하나와 함께 온다.
			_add_item(state, "transmute", int(relic["value"]), events)
	events.append({"t": "relic", "id": id})


## 상점을 연다(심판 보스를 이긴 뒤 · 갈림길의 상인). 열었으면 true.
## 진열(어떤 룬 · 어떤 유물)은 판 씨앗 · 웨이브 · 들른 횟수로 정한다: 판의 난수 흐름을 건드리지 않는다.
static func _open_shop(data: Dictionary, state: Dictionary, events: Array) -> bool:
	if not state.get("shopPending", false):
		return false
	state["shopPending"] = false
	var visits: int = int(state.get("shopVisits", 0))
	var rng: Rng = Rng.new(((int(state["seed"]) ^ 0x2545f491) + int(state["wave"]) * 0x9e3779b1 + visits * 0x85ebca6b) & Rng.M32)
	var runes: Array = data["slot"].get("slab", {}).get("offer", [])
	var has_slab: bool = not state.get("slab", []).is_empty()
	var unowned: Array = []
	for relic: Dictionary in data.get("relics", []):
		if relic["id"] not in state["relics"]:
			unowned.append(relic["id"])
	var items: Array = []
	for spec: Dictionary in data["waves"].get("shop", {}).get("stock", []):
		var item: Dictionary = spec.duplicate(true)
		item["detail"] = null
		item["sold"] = false
		match spec["kind"]:
			"rune":
				if not has_slab or runes.is_empty():
					continue
				item["detail"] = runes[rng.next_int(runes.size())]
			"erase":
				if not has_slab:
					continue
			"relic":
				if unowned.is_empty():
					continue
				item["detail"] = unowned[rng.next_int(unowned.size())]
		items.append(item)
	if items.is_empty():
		return false
	state["shopVisits"] = visits + 1
	state["shop"] = {"items": items, "refund": -1}
	state["phase"] = "shop"
	events.append({"t": "shop", "items": items.duplicate(true)})
	return true


## 상점의 index번째 물건을 지금 살 수 없는 까닭. 살 수 있으면 "".
static func shop_rejection(data: Dictionary, state: Dictionary, index: Variant) -> String:
	var shop: Variant = state.get("shop")
	if state["phase"] != "shop" or not shop is Dictionary:
		return "wrongPhase"
	var items: Array = shop.get("items", [])
	if not _valid_index(index, items.size()):
		return "emptySlot"
	var item: Dictionary = items[int(index)]
	if item.get("sold", false):
		return "soldOut"
	match item["kind"]:
		"life":
			if int(state["lives"]) >= int(data["waves"]["startLives"]):
				return "livesFull"
		"erase":
			if state.get("slab", []).size() <= int(data["slot"].get("slab", {}).get("minSize", 0)):
				return "slabMin"
		"rune":
			if state.get("slab", []).is_empty() or not item.get("detail") is String:
				return "emptySlot"
		"relic":
			if not item.get("detail") is String or item["detail"] in state["relics"]:
				return "soldOut"
	if int(state["mana"]) < int(item["cost"]):
		return "notEnoughMana"
	return ""


## 상점에서 사기: 한 물건은 한 번만. 룬 한 장 · 룬 지우기는 석판 차례로 갔다가 상점으로 돌아온다.
static func _do_buy(data: Dictionary, state: Dictionary, index: Variant, events: Array) -> String:
	var reason: String = shop_rejection(data, state, index)
	if not reason.is_empty():
		return reason
	var at: int = int(index)
	var item: Dictionary = state["shop"]["items"][at]
	_add_mana(state, -int(item["cost"]), "shop", events)
	item["sold"] = true
	events.append({"t": "bought", "index": at, "item": item.duplicate(true)})
	match item["kind"]:
		"rune":
			state["runePending"] = item["detail"]
			state["runeUses"] = int(item.get("amount", 1)) + int(relic_bonus(data, state).get("runeEdits", 0))
			state["shop"]["refund"] = at
			state["phase"] = "slab"
			events.append({"t": "runeOffer", "rune": item["detail"]})
		"erase":
			state["runePending"] = "erase"
			state["shop"]["refund"] = at
			state["phase"] = "slab"
			events.append({"t": "runeOffer", "rune": "erase"})
		"transmute":
			_add_item(state, "transmute", int(item.get("amount", 1)), events)
		"life":
			state["lives"] = mini(int(data["waves"]["startLives"]), int(state["lives"]) + int(item.get("amount", 1)))
			events.append({"t": "lives", "lives": state["lives"]})
		"relic":
			_grant_relic(data, state, item["detail"], events)
	return ""


static func _do_leave_shop(data: Dictionary, state: Dictionary, rng: Rng, events: Array) -> String:
	if state["phase"] != "shop":
		return "wrongPhase"
	state["shop"] = null
	events.append({"t": "shopClosed"})
	_proceed(data, state, rng, events)
	return ""


## 전환의 룬: 이 용이 그 원소로 바뀌면 어떤 종이 되는지. 같은 등급에서 자료 순서가 같은 종(역할·능력치가 같다).
## 바꿀 수 없으면 "" (이중·비밀 원소, 같은 원소, 모르는 원소).
static func transmute_target(data: Dictionary, species_id: String, element: String) -> String:
	var spec: Variant = data["dragons"].get(species_id)
	if spec == null or spec["tier"] in ["dual", "secret"] or spec["elements"].size() != 1 or spec["elements"][0] == element:
		return ""
	var mine: Array = []
	var theirs: Array = []
	for other: Dictionary in data["dragons"].values():
		if other["tier"] != spec["tier"] or other["elements"].size() != 1:
			continue
		if other["elements"][0] == spec["elements"][0]:
			mine.append(other["id"])
		elif other["elements"][0] == element:
			theirs.append(other["id"])
	var at: int = mine.find(species_id)
	return theirs[at] if at >= 0 and at < theirs.size() else ""


## 지금 전환이 성공할 확률(%). 직전에 실패했으면 afterFailPct.
static func transmute_chance(data: Dictionary, state: Dictionary) -> int:
	var cfg: Dictionary = data["waves"].get("transmute", {})
	if relic_bonus(data, state).has("transmuteSure"):
		return 100
	return int(cfg.get("afterFailPct", 100)) if int(state.get("transmuteFails", 0)) > 0 else int(cfg.get("successPct", 100))


static func _add_item(state: Dictionary, id: String, amount: int, events: Array) -> void:
	if amount == 0:
		return
	if not state.has("items"):
		state["items"] = {}
	state["items"][id] = int(state["items"].get(id, 0)) + amount
	events.append({"t": "item", "id": id, "delta": amount, "count": state["items"][id]})


static func _do_transmute(data: Dictionary, state: Dictionary, at: Dictionary, element: Variant, rng: Rng, events: Array) -> String:
	if state["phase"] not in ARRANGE_PHASES:
		return "wrongPhase"
	if int(state.get("items", {}).get("transmute", 0)) <= 0:
		return "noItem"
	var reason: String = _valid_ref(state, at)
	if not reason.is_empty():
		return reason
	var inst: Variant = _zone_of(state, at)[int(at["index"])]
	if inst == null:
		return "emptySlot"
	var spec: Dictionary = data["dragons"].get(inst["speciesId"], {})
	if element is String and not spec.get("elements", []).is_empty() and spec["elements"][0] == element:
		return "sameElement"
	var target: String = transmute_target(data, inst["speciesId"], element) if element is String else ""
	if target.is_empty():
		return "cannotTransmute"
	var chance: int = transmute_chance(data, state)
	var ok: bool = rng.next_int(100) < chance
	_add_item(state, "transmute", -1, events)
	var from: String = inst["speciesId"]
	if ok:
		inst["speciesId"] = target
		state["transmuteFails"] = 0
		if target not in state["discovered"]:
			state["discovered"].append(target)
	else:
		state["transmuteFails"] = int(state.get("transmuteFails", 0)) + 1
	events.append({"t": "transmuted", "at": at.duplicate(true), "ok": ok, "from": from, "to": target, "chance": chance, "inst": inst})
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
		"transmute":
			_add_item(state, "transmute", int(reward["amount"]), events)
		"rune":
			if detail != null and not state.get("slab", []).is_empty():
				state["runePending"] = detail
				## 유물 "쌍둥이 끌": 룬 한 장으로 두 장까지 바꾼다.
				state["runeUses"] = 1 + int(relic_bonus(data, state).get("runeEdits", 0))
			else:
				_add_mana(state, 3, "reward", events)
		"erase":
			if state.get("slab", []).size() > int(data["slot"].get("slab", {}).get("minSize", 0)):
				state["runePending"] = "erase"
			else:
				_add_mana(state, 3, "reward", events)
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


## 다음 전투의 편성과 규칙을 미리 만든다(상태를 바꾸지 않는다). 화면이 수동 궁극기 전투를 직접 돌릴 때 쓴다.
## 같은 상태에서 startBattle을 보내면 core가 똑같은 편성으로 다시 계산한다. 둥지가 비었으면 {}.
static func battle_setup(data: Dictionary, state: Dictionary, manual: bool = false) -> Dictionary:
	var probe: Dictionary = state.duplicate(true)
	var setup: Dictionary = _battle_setup(data, probe, Rng.new(probe["seed"], probe["rngState"]))
	if not setup.is_empty() and manual:
		setup["rules"]["manualUlt"] = true
	return setup


## 편성과 규칙. rng를 실제 전투와 같은 순서로 쓴다(적 뽑기 → 치명타 씨앗).
static func _battle_setup(data: Dictionary, state: Dictionary, rng: Rng) -> Dictionary:
	var relics: Dictionary = relic_bonus(data, state)
	var allies: Array = Battle.team(data, state["nest"], state["nestOpen"], relics)
	if allies.all(func(unit: Variant) -> bool: return unit == null):
		return {}
	var wave: int = state["wave"]
	var waves: Dictionary = data["waves"]
	var mods: Dictionary = Calamity.mods(data, state["calamity"]).duplicate()
	var wave_mod: Dictionary = state.get("waveMod", {})
	## 정예 사냥(이번 웨이브만)과 저주(판이 끝날 때까지)가 적을 더 세게 한다.
	mods["enemyPowerPct"] = int(mods["enemyPowerPct"]) + int(wave_mod.get("powerPct", 0)) + int(state.get("cursePct", 0))
	var enemies: Array = Waves.generate_enemies(data, wave, rng, state["seed"], mods)
	var is_boss: bool = Waves.is_boss(waves, wave)
	var boss: Variant = _boss_spec(data, wave) if is_boss else null
	## 지역 규칙(waves.battleRules)이 바탕이고, 보스의 규칙이 그 위에 덮인다.
	var rules: Dictionary = waves.get("battleRules", {}).duplicate(true)
	if boss != null:
		rules.merge(boss.get("rules", {}).duplicate(true), true)
	if relics.has("strongAddPct"):
		rules["strongAddPct"] = relics["strongAddPct"]
	if relics.has("backRowNoLane"):
		rules["backRowNoLane"] = true
	rules["critSeed"] = rng.next_int(1000000007)
	return {
		"allies": allies, "enemies": enemies, "rules": rules, "relics": relics, "mods": mods, "waveMod": wave_mod,
		"boss": is_boss, "strong": is_boss or Waves.is_elite(waves, wave),
	}


## 졌을 때 잃는 생명: 전장에 살아남은 적이 많을수록 더 잃는다(waves.leak). 자료가 없으면 예전처럼 고정값.
static func leak_lives(waves: Dictionary, left: Dictionary, is_boss: bool) -> int:
	var floor_loss: int = int(waves["bossLossLife"]) if is_boss else int(waves["lossLife"])
	var leak: Dictionary = waves.get("leak", {})
	if leak.is_empty():
		return floor_loss
	var points: int = int(left.get("minions", 0)) * int(leak.get("minion", 1)) + int(left.get("leaders", 0)) * int(leak.get("leader", 1))
	var per_life: int = maxi(1, int(leak.get("perLife", 1)))
	return clampi(Rng.fdiv(points + per_life - 1, per_life), floor_loss, maxi(floor_loss, int(leak.get("max", floor_loss))))


static func _do_battle(data: Dictionary, state: Dictionary, rng: Rng, events: Array, cmd: Dictionary = {}) -> String:
	if state["phase"] != "manage":
		return "wrongPhase"
	var setup: Dictionary = _battle_setup(data, state, rng)
	if setup.is_empty():
		return "nestEmpty"
	var relics: Dictionary = setup["relics"]
	var allies: Array = setup["allies"]
	var enemies: Array = setup["enemies"]
	var rules: Dictionary = setup["rules"]
	var mods: Dictionary = setup["mods"]
	var wave_mod: Dictionary = setup["waveMod"]
	var is_boss: bool = setup["boss"]
	var strong_wave: bool = setup["strong"]
	var wave: int = state["wave"]
	var waves: Dictionary = data["waves"]
	state["waveMod"] = {}
	## 수동 궁극기: 화면이 직접 돌린 전투에서 궁극기를 쏜 틱의 기록을 받아 똑같이 다시 계산한다.
	if bool(cmd.get("manual", false)):
		rules["manualUlt"] = true
		var ult_at: Dictionary = {}
		var given: Variant = cmd.get("ults", {})
		if given is Dictionary:
			for key: Variant in given:
				## 틱은 정수(또는 정수를 적은 글자), id는 정수만 받는다. 그 밖의 값은 버린다.
				var tick_ok: bool = key is int or (key is float and floorf(key) == key) or (key is String and key.is_valid_int())
				if not tick_ok or not given[key] is Array:
					continue
				var ids: Array = []
				for id: Variant in given[key]:
					if id is int or (id is float and floorf(id) == id):
						ids.append(int(id))
				ult_at[int(key)] = ids
		rules["ultAt"] = ult_at
	var result: Dictionary = Battle.simulate_battle(data["battle"], allies, enemies, rules)
	events.append({"t": "battle", "result": result})
	var won: bool = result["winner"] == "ally"
	var level_cfg: Dictionary = data["battle"].get("level", {})
	var battle_xp: int = Rng.fdiv(int(level_cfg.get("winXp" if won else "lossXp", 0)) * (100 + int(relics.get("xpPct", 0))), 100)
	for i: int in range(state["nestOpen"]):
		var fighter: Variant = state["nest"][i]
		if fighter != null and battle_xp > 0 and Fusion.add_xp(data, fighter, battle_xp) > 0:
			events.append({"t": "leveled", "at": {"zone": "nest", "index": i}, "level": fighter["level"]})
	if won:
		_add_mana(state, Rng.fdiv(int(waves["winMana"]) * (100 + int(mods["winManaPct"])), 100) + int(relics.get("winMana", 0)), "win", events)
		if wave in waves.get("transmute", {}).get("grantAfterWaves", []):
			_add_item(state, "transmute", 1, events)
	else:
		## 남은 생명보다 더 잃을 수는 없다.
		var loss: int = mini(leak_lives(waves, result.get("left", {}), is_boss), int(state["lives"]))
		state["lives"] = maxi(0, int(state["lives"]) - loss)
		state["livesLost"] = int(state.get("livesLost", 0)) + loss
		events.append({"t": "lives", "lives": state["lives"], "lost": loss, "left": result.get("left", {})})
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
	state["nudgesLeft"] = int(data["slot"]["nudgesPerWave"]) + int(state["bonusNudges"]) + int(relics.get("nudge", 0))
	state["bonusNudges"] = 0
	state["nudgesBought"] = 0
	state["rewardRerolls"] = 0
	state["relicPending"] = won and is_boss
	## 심판 보스를 이기면 유물 다음에 상점이 열린다.
	state["shopPending"] = won and is_boss
	state["forkPending"] = wave in waves.get("fork", {}).get("after", []) and int(state["wave"]) > wave
	state["extraRewards"] = int(wave_mod.get("extraRewards", 0)) if won else 0
	state["rewardBoss"] = strong_wave
	if won:
		state["rewardChoices"] = _roll_reward_choices(data, rng, strong_wave, not state.get("slab", []).is_empty())
	if won and not state["rewardChoices"].is_empty():
		state["phase"] = "reward"
		events.append({"t": "rewardChoices", "choices": state["rewardChoices"]})
		return ""
	_proceed(data, state, rng, events)
	return ""
