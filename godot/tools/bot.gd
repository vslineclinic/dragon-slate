extends RefCounted
## 밸런스 시뮬레이터용 자동 플레이어. 웹판 tools/sim/bot.ts의 판단 규칙을 옮겼다.

const COLUMNS: Array = [0, 1, 2]
const DIRECTIONS: Array = [-1, 1]
const FRONT_SLOTS: Array = [0, 1, 2, 3, 4, 5]
const BACK_SLOTS: Array = [3, 4, 5, 0, 1, 2]


static func choose(data: Dictionary, state: Dictionary) -> Dictionary:
	match state["phase"]:
		"spin":
			return {"type": "spin"}
		"pick":
			return _choose_pick(data, state, state["grid"])
		"manage":
			var spend: Dictionary = _choose_skill(data, state)
			return spend if not spend.is_empty() else _choose_manage(data, state)
		"reward":
			return _choose_reward(data, state)
		"relic":
			return _choose_relic(state)
		"slab":
			return _choose_rune(data, state)
		"fork":
			var cost: int = int(data["waves"].get("fork", {}).get("merchantCost", 0))
			if int(state["lives"]) < int(data["waves"]["startLives"]) - 1:
				return {"type": "chooseFork", "option": "rest"}
			if int(state["mana"]) >= cost + 4:
				return {"type": "chooseFork", "option": "merchant"}
			return {"type": "chooseFork", "option": "rest"}
	push_error("no bot command for phase " + str(state["phase"]))
	return {}


const REWARD_ORDER: Array = ["t2egg", "trait", "egg", "life", "mana", "freeSpin", "nudge"]
const RELIC_ORDER: Array = ["sword", "shell", "horn", "banner", "feather", "fang", "seal", "tome", "scale", "dice", "phoenix", "kiln"]
const SKILL_ORDER: Array = ["fang", "scale", "pack", "alpha", "frenzy", "leech"]


static func _choose_reward(data: Dictionary, state: Dictionary) -> Dictionary:
	var choices: Array = state["rewardChoices"]
	var bench_full: bool = not state["bench"].has(null)
	var best: int = 0
	var best_rank: int = 99
	for i: int in range(choices.size()):
		var kind: String = choices[i]["reward"]["kind"]
		var rank: int = REWARD_ORDER.find(kind)
		## 룬 한 장은 내가 가장 많이 가진 원소일 때만 알 다음으로 친다.
		if kind == "rune" and choices[i]["detail"] == _favoured(data, state):
			rank = 3
		## 봇이 쓸 줄 모르는 보상(전환의 룬 등)은 맨 뒤로.
		if rank < 0:
			rank = 50
		if kind in ["egg", "t2egg"] and bench_full:
			rank += 10
		if kind == "life" and state["lives"] >= data["waves"]["startLives"]:
			rank += 10
		if rank < best_rank:
			best_rank = rank
			best = i
	return {"type": "chooseReward", "index": best}


## 가진 용의 원소별 수(이중 원소는 첫 원소만).
static func _owned_elements(data: Dictionary, state: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for inst: Variant in state["nest"] + state["bench"]:
		if inst == null:
			continue
		var elements: Array = data["dragons"][inst["speciesId"]]["elements"]
		if not elements.is_empty():
			counts[elements[0]] = int(counts.get(elements[0], 0)) + 1
	return counts


## 가장 많이 가진 원소(같으면 원소 순서). 없으면 "".
static func _favoured(data: Dictionary, state: Dictionary) -> String:
	var counts: Dictionary = _owned_elements(data, state)
	var best: String = ""
	for element: String in GameData.active_elements(data):
		if int(counts.get(element, 0)) > int(counts.get(best, 0)):
			best = element
	return best


## 내 석판: 받은 룬이 주력 원소면, 한 마리도 없는 원소의 룬과 바꾼다. 아니면 넘긴다.
static func _choose_rune(data: Dictionary, state: Dictionary) -> Dictionary:
	var rune: Variant = state.get("runePending")
	if rune != null and rune == _favoured(data, state):
		var counts: Dictionary = _owned_elements(data, state)
		var slab: Array = state.get("slab", [])
		var worst: int = -1
		for i: int in range(slab.size()):
			var symbol: String = slab[i]
			if symbol in ["gold", "wild"] or symbol == rune:
				continue
			if worst < 0 or int(counts.get(symbol, 0)) < int(counts.get(slab[worst], 0)):
				worst = i
		if worst >= 0 and int(counts.get(slab[worst], 0)) == 0:
			return {"type": "replaceRune", "index": worst}
	return {"type": "skipRune"}


static func _choose_relic(state: Dictionary) -> Dictionary:
	var choices: Array = state["relicChoices"]
	var best: int = 0
	for i: int in range(choices.size()):
		if RELIC_ORDER.find(choices[i]) < RELIC_ORDER.find(choices[best]):
			best = i
	return {"type": "chooseRelic", "index": best}


## 둥지의 드래곤부터, 찍을 수 있는 스킬 중 단계가 가장 낮은 것을 고른다.
static func _choose_skill(data: Dictionary, state: Dictionary) -> Dictionary:
	for slot: Dictionary in _occupied(state, "nest") + _occupied(state, "bench"):
		var inst: Dictionary = slot["inst"]
		if int(inst.get("skillPoints", 0)) <= 0:
			continue
		var pick: String = ""
		var lowest: int = 99
		for node: String in SKILL_ORDER:
			if Fusion.skill_rejection(data, inst, node).is_empty():
				var level: int = int(inst.get("skills", {}).get(node, 0))
				if level < lowest:
					lowest = level
					pick = node
		if not pick.is_empty():
			return {"type": "skill", "at": slot["ref"], "node": pick}
	return {}


static func _occupied(state: Dictionary, zone: String) -> Array:
	var slots: Array = state["nest"].slice(0, state["nestOpen"]) if zone == "nest" else state["bench"]
	var out: Array = []
	for i: int in range(slots.size()):
		if slots[i] != null:
			out.append({"inst": slots[i], "ref": {"zone": zone, "index": i}})
	return out


static func _line_count(groups: Array) -> int:
	var count: int = 0
	for group: Dictionary in groups:
		count += group["lines"].size()
	return count


static func _can_recruit(has_egg: bool, groups: Array) -> bool:
	if has_egg:
		return true
	for group: Dictionary in groups:
		if group["element"] != "gold" and group["element"] != "wild":
			return true
	return false


static func _has_egg(offers: Array) -> bool:
	for offer: Variant in offers:
		if offer != null and offer["kind"] == "egg":
			return true
	return false


static func strength(data: Dictionary, inst: Dictionary) -> int:
	var unit: Dictionary = Battle.to_unit(data, inst)
	return Rng.fdiv(int(unit["hp"]), 4) + Rng.fdiv(int(unit["atk"]) * 20, int(unit["cooldownTicks"]))


static func _ranked(data: Dictionary, slots: Array, strongest_first: bool) -> Array:
	var out: Array = []
	for slot: Dictionary in slots:
		var copy: Dictionary = slot.duplicate()
		copy["strength"] = strength(data, slot["inst"])
		out.append(copy)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["strength"] > b["strength"] if strongest_first else a["strength"] < b["strength"])
	return out


static func _choose_pick(data: Dictionary, state: Dictionary, grid: Dictionary) -> Dictionary:
	var lines: Array = Slot.evaluate_lines(grid)
	var offers: Array = Slot.offers_from(data, grid)
	var nest: Array = _occupied(state, "nest")
	var owned: Array = nest + _occupied(state, "bench")
	var bench_has_space: bool = state["bench"].has(null)
	var needs_dragon: bool = owned.is_empty()

	var best_nudge: Variant = null
	var recruiting_nudge: Variant = null
	var best_count: int = _line_count(lines)
	if state["nudgesLeft"] > 0:
		for col: int in COLUMNS:
			for dir: int in DIRECTIONS:
				var shifted: Dictionary = Slot.nudge(grid, col, dir)
				var shifted_lines: Array = Slot.evaluate_lines(shifted)
				var command: Dictionary = {"type": "nudge", "col": col, "dir": dir}
				var count: int = _line_count(shifted_lines)
				if needs_dragon:
					if not _can_recruit(_has_egg(Slot.offers_from(data, shifted)), shifted_lines):
						continue
					if recruiting_nudge == null:
						recruiting_nudge = command
				if count > best_count:
					best_count = count
					best_nudge = command
	if best_nudge != null:
		return best_nudge

	var cost: int = Run.spin_cost(data, state)
	if state["mana"] >= maxi(8, cost) and state["spinsThisWave"] == 1 and lines.is_empty():
		return {"type": "spin"}
	if needs_dragon and not _can_recruit(_has_egg(offers), lines):
		if recruiting_nudge != null:
			return recruiting_nudge
		if state["mana"] >= cost:
			return {"type": "spin"}

	var nest_elements: Dictionary = {}
	for slot: Dictionary in nest:
		for element: String in data["dragons"][slot["inst"]["speciesId"]]["elements"]:
			nest_elements[element] = true
	var best_index: int = -1
	var best_priority: int = -1
	for index: int in COLUMNS:
		if index >= offers.size():
			continue
		var offer: Variant = offers[index]
		if offer == null or (offer["kind"] == "egg" and not bench_has_space):
			continue
		var priority: int = 0
		if offer["kind"] == "egg":
			var matches_recipe: bool = false
			for slot: Dictionary in owned:
				if Fusion.find_recipe(data, slot["inst"]["speciesId"], offer["speciesId"]) != null:
					matches_recipe = true
			var matches_element: bool = false
			for element: String in data["dragons"][offer["speciesId"]]["elements"]:
				if nest_elements.has(element):
					matches_element = true
			priority = 3 if matches_recipe else (2 if matches_element else 1)
		if priority > best_priority:
			best_priority = priority
			best_index = index
	if best_index < 0:
		var bench_slots: Array = _ranked(data, _occupied(state, "bench"), false)
		var nest_slots: Array = _ranked(data, _occupied(state, "nest"), true)
		if not bench_slots.is_empty() and not nest_slots.is_empty():
			return {"type": "merge", "main": nest_slots[0]["ref"], "material": bench_slots[0]["ref"]}
		if bench_slots.size() > 1:
			return {"type": "release", "from": bench_slots[0]["ref"]}
		return {"type": "pick", "index": 0}
	return {"type": "pick", "index": best_index}


static func _choose_manage(data: Dictionary, state: Dictionary) -> Dictionary:
	var nest: Array = _occupied(state, "nest")
	var bench: Array = _occupied(state, "bench")
	var owned: Array = nest + bench
	for i: int in range(owned.size()):
		for j: int in range(i + 1, owned.size()):
			if Fusion.merge_preview(data, owned[i]["inst"], owned[j]["inst"])["kind"] == "evolve":
				return {"type": "merge", "main": owned[i]["ref"], "material": owned[j]["ref"]}

	var ranked_nest: Array = _ranked(data, nest, true)
	var ranked_bench: Array = _ranked(data, bench, true)
	if not state["bench"].has(null) and not ranked_bench.is_empty():
		var weakest: Dictionary = ranked_bench[-1]
		if not ranked_nest.is_empty():
			return {"type": "merge", "main": ranked_nest[0]["ref"], "material": weakest["ref"]}
		return {"type": "release", "from": weakest["ref"]}

	if not ranked_bench.is_empty():
		var strongest: Dictionary = ranked_bench[0]
		var role: String = data["dragons"][strongest["inst"]["speciesId"]].get("role", "front")
		var order: Array = BACK_SLOTS if role == "back" else FRONT_SLOTS
		for index: int in order:
			if index < state["nestOpen"] and state["nest"][index] == null:
				return {"type": "move", "from": strongest["ref"], "to": {"zone": "nest", "index": index}}
		if not ranked_nest.is_empty() and strongest["strength"] > ranked_nest[-1]["strength"]:
			return {"type": "move", "from": strongest["ref"], "to": ranked_nest[-1]["ref"]}
	var lane_move: Dictionary = _lane_move(data, state)
	if not lane_move.is_empty():
		return lane_move
	return {"type": "startBattle"}


## 줄 미리보기를 읽고, 같은 열(전열·후열) 안에서 센 용을 적이 많이 몰리는 줄에 세운다. 다 맞으면 빈 사전.
static func _lane_move(data: Dictionary, state: Dictionary) -> Dictionary:
	var preview: Array = Waves.lane_preview(data, state["seed"], state["wave"])
	var lanes: Array = [0, 1, 2]
	lanes.sort_custom(func(a: int, b: int) -> bool:
		var ta: int = int(preview[a]["minions"]) + 3 * int(preview[a]["leaders"])
		var tb: int = int(preview[b]["minions"]) + 3 * int(preview[b]["leaders"])
		return ta > tb if ta != tb else a < b)
	for row: int in range(2):
		var here: Array = []
		for lane: int in range(3):
			var index: int = row * 3 + lane
			if index < int(state["nestOpen"]) and state["nest"][index] != null:
				here.append({"index": index, "strength": strength(data, state["nest"][index]), "uid": int(state["nest"][index]["uid"])})
		here.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["strength"] > b["strength"] if a["strength"] != b["strength"] else a["uid"] < b["uid"])
		var rank: int = 0
		for lane: int in lanes:
			var want: int = row * 3 + lane
			if want >= int(state["nestOpen"]) or rank >= here.size():
				continue
			var dragon: Dictionary = here[rank]
			rank += 1
			if int(dragon["index"]) == want:
				continue
			var there: Variant = state["nest"][want]
			if there != null and strength(data, there) == int(dragon["strength"]):
				continue
			return {"type": "move", "from": {"zone": "nest", "index": int(dragon["index"])}, "to": {"zone": "nest", "index": want}}
	return {}
