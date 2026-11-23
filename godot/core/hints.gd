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


static func line_rewards(data: Dictionary, grid: Dictionary) -> Dictionary:
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
