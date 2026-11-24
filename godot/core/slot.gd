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


## slab = 내 석판의 룬 묶음(무늬 이름 배열). 비어 있지 않으면 칸마다 그 묶음에서 고르게 하나를 뽑는다.
## 비어 있으면 예전처럼 slot.weights로 뽑는다(옛 저장 · 기준 자료 시험).
static func spin_grid(data: Dictionary, rng: Rng, force_line: bool, slab: Array = []) -> Dictionary:
	if not slab.is_empty():
		return _spin_from_slab(data, rng, force_line, slab)
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


static func _spin_from_slab(data: Dictionary, rng: Rng, force_line: bool, slab: Array) -> Dictionary:
	var reels: Array = []
	for col: int in range(3):
		var reel: Array = []
		for i: int in range(5):
			reel.append(_roll_cell(data, rng, slab[rng.next_int(slab.size())]))
		reels.append(reel)
	if force_line:
		## 줄 보정: 석판에 있는 원소 룬 가운데 하나로 가운데 줄을 맞춘다(많이 넣은 원소일수록 잘 나온다).
		var elements: Array = slab.filter(func(symbol: Variant) -> bool: return symbol != "gold" and symbol != "wild")
		## 원소 룬을 모두 뺐으면 묶음에 남은 무늬(금·여의주)로 맞춘다. 뺀 원소가 되살아나지 않는다.
		if elements.is_empty():
			elements = slab
		var element: Variant = elements[rng.next_int(elements.size())]
		for col: int in range(3):
			reels[col][2] = _roll_cell(data, rng, element)
	return {"reels": reels, "offsets": [0, 0, 0]}


## 석판 묶음에서 그 무늬가 차지하는 칸 수.
static func slab_count(slab: Array, symbol: String) -> int:
	return slab.count(symbol)


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


## 그 무늬에서 나올 수 있는 기본종(id 순). wild는 전부.
static func base_pool(data: Dictionary, symbol: Variant) -> Array:
	var pool: Array = []
	for spec: Dictionary in data["dragons"].values():
		if spec["tier"] != "base":
			continue
		var elements: Array = spec["elements"]
		var primary: Variant = null if elements.is_empty() else elements[0]
		if symbol == "wild" or primary == symbol:
			pool.append(spec["id"])
	pool.sort()
	return pool


static func species_weight(data: Dictionary, id: String) -> int:
	return maxi(1, int(data["dragons"][id].get("weight", 1)))


## 종마다 weight가 있으면 그 비율로, 없으면 고르게 뽑는다.
static func pick_species(data: Dictionary, rng: Rng, pool: Array) -> String:
	var weights: Array = []
	var weighted: bool = false
	for id: String in pool:
		weights.append(species_weight(data, id))
		if data["dragons"][id].has("weight"):
			weighted = true
	if not weighted:
		return pool[rng.next_int(maxi(1, pool.size()))]
	return rng.pick_weighted(pool, weights)


## 석판 한 칸에 그 종의 알이 나올 확률(만분율). slab을 주면 내 석판 기준.
static func species_odds(data: Dictionary, id: String, slab: Array = []) -> int:
	var spec: Dictionary = data["dragons"][id]
	if spec["tier"] != "base" or spec["elements"].is_empty():
		return 0
	var weights: Dictionary = data["slot"]["weights"]
	if not slab.is_empty():
		weights = {}
		for symbol: Variant in slab:
			weights[symbol] = int(weights.get(symbol, 0)) + 1
	var total: int = 0
	for key: String in weights:
		total += int(weights[key])
	var odds: int = 0
	for symbol: String in [spec["elements"][0], "wild"]:
		var pool: Array = base_pool(data, symbol)
		var pool_weight: int = 0
		for other: String in pool:
			pool_weight += species_weight(data, other)
		if total > 0 and pool_weight > 0:
			odds += Rng.fdiv(int(weights.get(symbol, 0)) * species_weight(data, id) * 10000, total * pool_weight)
	return odds


static func _offset(offsets: Array, col: int) -> int:
	if col >= offsets.size() or offsets[col] == null:
		return 0
	return offsets[col]


static func _roll_cell(data: Dictionary, rng: Rng, symbol: Variant) -> Dictionary:
	var cell: Dictionary = {"symbol": symbol, "speciesId": null}
	if symbol == "gold":
		return cell

	var pool: Array = base_pool(data, symbol)
	if not pool.is_empty():
		cell["speciesId"] = pick_species(data, rng, pool)
	else:
		rng.next_int(1)
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
