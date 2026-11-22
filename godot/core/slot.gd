class_name Slot
extends RefCounted

## 각 좌표는 [col, row]. row는 보이는 칸의 0~2.
const LINES: Array = [
	[[0, 0], [1, 0], [2, 0]],
	[[0, 1], [1, 1], [2, 1]],
	[[0, 2], [1, 2], [2, 2]],
	[[0, 0], [0, 1], [0, 2]],
	[[1, 0], [1, 1], [1, 2]],
	[[2, 0], [2, 1], [2, 2]],
	[[0, 0], [1, 1], [2, 2]],
	[[0, 2], [1, 1], [2, 0]],
]


static func spin_grid(data: Dictionary, rng: Rng, force_line: bool) -> Dictionary:
	var elements: Array = GameData.active_elements(data)
	var symbols: Array = elements + ["gold", "wild"]
	var weights: Array = []
	var total_weight: int = 0
	for symbol: String in symbols:
		var weight: int = data["slot"]["weights"].get(symbol, 0)
		weights.append(weight)
		total_weight += weight

	var reels: Array = []
	for col: int in range(3):
		var reel: Array = []
		for i: int in range(5):
			var symbol: String
			if total_weight == 0:
				# TypeScript의 가중치 합 0 처리와 같은 난수 소비 및 마지막 항목 선택.
				rng.next_u32()
				symbol = symbols.back()
			else:
				symbol = rng.pick_weighted(symbols, weights)
			reel.append(_roll_cell(data, rng, symbol))
		reels.append(reel)
	if force_line:
		var index: int = rng.next_int(maxi(1, elements.size()))
		var element: Variant = null if elements.is_empty() else elements[index]
		for col: int in range(3):
			reels[col][2] = _roll_cell(data, rng, element)
	return {"reels": reels, "offsets": [0, 0, 0]}


static func visible(grid: Dictionary, col: int, row: int) -> Dictionary:
	return grid["reels"][col][1 + _offset(grid["offsets"], col) + row]


static func evaluate_lines(grid: Dictionary) -> Array:
	var groups: Dictionary = {}
	for i: int in range(LINES.size()):
		var symbol: Variant = _line_symbol(grid, LINES[i])
		if symbol == null:
			continue
		if not groups.has(symbol):
			groups[symbol] = {"lines": [], "element": symbol}
		groups[symbol]["lines"].append(i)
	return groups.values()


static func nudge(grid: Dictionary, col: int, dir: int) -> Dictionary:
	var offsets: Array = grid["offsets"].duplicate()
	if col >= offsets.size():
		offsets.resize(col + 1)
	offsets[col] = clampi(_offset(offsets, col) + dir, -1, 1)
	return {"reels": grid["reels"], "offsets": offsets}


static func offers_from(data: Dictionary, grid: Dictionary) -> Array:
	var offers: Array = []
	for col: int in range(3):
		var cell: Dictionary = visible(grid, col, 1)
		if cell["symbol"] == "gold" or cell["speciesId"] == null:
			offers.append({"kind": "mana", "amount": data["slot"]["goldOfferMana"]})
		else:
			offers.append({"kind": "egg", "speciesId": cell["speciesId"]})
	return offers


static func _offset(offsets: Array, col: int) -> int:
	if col >= offsets.size() or offsets[col] == null:
		return 0
	return offsets[col]


static func _roll_cell(data: Dictionary, rng: Rng, symbol: Variant) -> Dictionary:
	var cell: Dictionary = {"symbol": symbol, "speciesId": null}
	if symbol == "gold":
		return cell

	var pool: Array = []
	for spec: Dictionary in data["dragons"].values():
		if spec["tier"] != "base":
			continue
		var elements: Array = spec["elements"]
		var primary: Variant = null if elements.is_empty() else elements[0]
		if symbol == "wild" or primary == symbol:
			pool.append(spec["id"])
	pool.sort()
	var index: int = rng.next_int(maxi(1, pool.size()))
	if not pool.is_empty():
		cell["speciesId"] = pool[index]
	if symbol == null:
		cell.erase("symbol")
	return cell


static func _line_symbol(grid: Dictionary, line: Array) -> Variant:
	var symbols: Array = []
	for pos: Array in line:
		symbols.append(visible(grid, pos[0], pos[1]).get("symbol"))
	if "gold" in symbols:
		return "gold" if symbols.count("gold") == 3 else null

	var non_wild: Array = symbols.filter(func(symbol: Variant) -> bool: return symbol != "wild")
	if non_wild.is_empty():
		return "wild"
	var first: Variant = non_wild[0]
	return first if non_wild.count(first) == non_wild.size() else null
