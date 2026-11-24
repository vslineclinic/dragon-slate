class_name Hints
extends RefCounted
## 추천을 계산하며 입력 상태를 바꾸지 않는다.


static func best_nudge(grid: Dictionary, nudges_left: int) -> Variant:
	if nudges_left <= 0:
		return null
	var best_count: int = _line_count(grid)
	var best: Variant = null
	var offsets: Array = grid["offsets"]
	for col: int in range(3):
		var offset: int = 0
		if col < offsets.size() and offsets[col] != null:
			offset = offsets[col]
		for dir: int in [-1, 1]:
			if offset + dir < -1 or offset + dir > 1:
				continue
			var count: int = _line_count(Slot.nudge(grid, col, dir))
			if count > best_count:
				best_count = count
				best = {"col": col, "dir": dir, "lines": count}
	return best


static func recommend_offer(data: Dictionary, state: Dictionary) -> Variant:
	if state["grid"] == null:
		return null
	var offers: Array = Slot.offers_from(data, state["grid"])
	var owned: Array = _owned(state)
	for i: int in range(offers.size()):
		var offer: Dictionary = offers[i]
		if offer["kind"] != "egg":
			continue
		for entry: Dictionary in owned:
			var result: Variant = Fusion.find_recipe(data, offer["speciesId"], entry["inst"]["speciesId"])
			if result != null:
				return {"index": i, "reason": "recipe", "result": result}

	var nest_elements: Array = []
	for inst: Variant in state["nest"]:
		if inst != null:
			var element: Variant = _primary_element(data, inst["speciesId"])
			if element != null:
				nest_elements.append(element)
	for i: int in range(offers.size()):
		var offer: Dictionary = offers[i]
		if offer["kind"] != "egg":
			continue
		var element: Variant = _primary_element(data, offer["speciesId"])
		if (element if element != null else "fire") in nest_elements:
			return {"index": i, "reason": "element", "result": null}
	return null


static func evolvable_pairs(data: Dictionary, state: Dictionary) -> Array:
	var owned: Array = _owned(state)
	var pairs: Array = []
	for i: int in range(owned.size()):
		for j: int in range(i + 1, owned.size()):
			var a: Dictionary = owned[i]
			var b: Dictionary = owned[j]
			var preview: Dictionary = Fusion.merge_preview(data, a["inst"], b["inst"])
			if preview["kind"] == "evolve":
				pairs.append({"a": a["ref"], "b": b["ref"], "result": preview["result"]})
	return pairs


## crown = 유물 "여의주 왕관"을 가졌는지(여의주 줄에 2티어 알이 더 온다).
static func line_rewards(data: Dictionary, grid: Dictionary, crown: bool = false) -> Dictionary:
	var lines: int = 0
	var mana: int = 0
	var eggs: Array = []
	for group: Dictionary in Slot.evaluate_lines(grid):
		var count: int = group["lines"].size()
		lines += count
		match group["element"]:
			"gold":
				mana += data["slot"]["goldLineMana"]
			"wild":
				mana += data["slot"]["wildLineMana"]
				if crown:
					eggs.append({"element": "wild", "tier": "t2"})
			_:
				eggs.append({"element": group["element"], "tier": "t2" if count >= 2 else "base"})
				mana += data["slot"]["lineMana"]
	for col: int in range(3):
		for row: int in range(3):
			if Slot.visible(grid, col, row).get("symbol") == "gold":
				mana += data["slot"]["goldMana"]
	return {"lines": lines, "eggs": eggs, "mana": mana}


static func _line_count(grid: Dictionary) -> int:
	var count: int = 0
	for group: Dictionary in Slot.evaluate_lines(grid):
		count += group["lines"].size()
	return count


static func _owned(state: Dictionary) -> Array:
	var owned: Array = []
	for zone: String in ["nest", "bench"]:
		var slots: Array = state[zone]
		for index: int in range(slots.size()):
			if slots[index] != null:
				owned.append({"ref": {"zone": zone, "index": index}, "inst": slots[index]})
	return owned


static func _primary_element(data: Dictionary, species_id: String) -> Variant:
	var spec: Dictionary = data["dragons"].get(species_id, {})
	var elements: Array = spec.get("elements", [])
	return null if elements.is_empty() else elements[0]


## 진 전투를 되짚어 가장 큰 이유 하나를 고른다: {"kind": 이유, "pct": 비율(해당할 때)}.
## weakElement = 우리 용의 공격 절반 이상이 약한 상성 / offLane = 넷 중 하나 이상이 다른 줄을 쳐서 약해짐 /
## timeout = 시간이 다 됨 / leaders = 우두머리만 남음 / swarm = 졸병에게 밀림.
static func defeat_reason(cfg: Dictionary, result: Dictionary) -> Dictionary:
	var kind_of: Dictionary = {}
	var side_of: Dictionary = {}
	var stage_of: Dictionary = {}
	## 전장에 나와 있는 유닛만 센다(뒤 무리는 stage 사건이 올 때 나온다).
	var alive: Dictionary = {}
	for unit: Dictionary in result["units"]:
		kind_of[unit["id"]] = unit["kind"]
		side_of[unit["id"]] = unit["side"]
		stage_of[unit["id"]] = int(unit.get("stage", 0))
		alive[unit["id"]] = int(unit.get("stage", 0)) == 0
	var hits: int = 0
	var weak: int = 0
	var off_lane: int = 0
	for event: Dictionary in result["events"]:
		if event["kind"] == "death":
			alive[event["id"]] = false
		elif event["kind"] == "stage":
			for id: Variant in stage_of:
				if stage_of[id] == int(event["stage"]):
					alive[id] = true
		elif event["kind"] == "attack" and side_of.get(event["src"]) == "ally" and kind_of.get(event["src"]) == "dragon":
			hits += 1
			if int(event["mult"]) < 100:
				weak += 1
			if event.has("lane"):
				off_lane += 1
	if hits > 0 and weak * 2 >= hits:
		return {"kind": "weakElement", "pct": Rng.fdiv(weak * 100, hits)}
	if hits > 0 and off_lane * 4 >= hits:
		return {"kind": "offLane", "pct": Rng.fdiv(off_lane * 100, hits)}
	var leaders: int = 0
	var minions: int = 0
	var allies_left: int = 0
	for id: Variant in alive:
		if alive[id] and side_of[id] == "ally":
			allies_left += 1
	## 시간이 다 됐다는 것은 우리 편이 남아 있는데 못 끝낸 경우다.
	if int(result["ticks"]) >= int(cfg["maxTicks"]) and allies_left > 0:
		return {"kind": "timeout"}
	for id: Variant in alive:
		if alive[id] and side_of[id] == "enemy":
			if kind_of[id] == "dragon":
				leaders += 1
			else:
				minions += 1
	return {"kind": "leaders" if leaders > 0 and minions <= leaders else "swarm"}
