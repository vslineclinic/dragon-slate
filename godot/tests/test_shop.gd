extends TestCase
## 마력을 쓸 곳: 보스 뒤의 상점, 밀기 추가 구매, 보상 다시 뽑기.

const RunRules = preload("res://godot/core/run.gd")
const Store = preload("res://godot/ui/store.gd")
const Bot = preload("res://godot/tools/bot.gd")

var _data: Dictionary = GameData.load_all()


static func _inst(uid: int, species_id: String, bonus_pct: int = 0) -> Dictionary:
	return {"uid": uid, "speciesId": species_id, "traits": [], "bonusPct": bonus_pct, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}


func _apply(state: Dictionary, cmd: Dictionary) -> Dictionary:
	return RunRules.apply_command(_data, state, cmd)


func _assert_rejected(state: Dictionary, cmd: Dictionary, reason: String) -> void:
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = _apply(state, cmd)
	assert_eq(result["events"], [{"t": "rejected", "reason": reason}], str(cmd))
	assert_eq(state, before, "거절하면 상태가 그대로여야 함")
	assert_eq(result["state"], before, "거절하면 돌려주는 상태도 그대로여야 함")


## 상점이 열린 상태(갈림길의 상인 길로 연다). mana = 가진 마력.
func _shop(mana: int = 99, seed: int = 4, overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state.merge({"phase": "fork", "forkChoices": ["elite", "rest", "merchant"], "wave": 4, "mana": mana,
		"nest": [_inst(1, "fire_drake"), null, null, null, null, null]}, true)
	state.merge(overrides, true)
	return _apply(state, {"type": "chooseFork", "option": "merchant"})["state"]


func _item(state: Dictionary, kind: String) -> int:
	var items: Array = state["shop"]["items"]
	for i: int in range(items.size()):
		if items[i]["kind"] == kind:
			return i
	return -1


func _cost(kind: String) -> int:
	for item: Dictionary in _data["waves"]["shop"]["stock"]:
		if item["kind"] == kind:
			return int(item["cost"])
	return -1


## 보스(5웨이브)를 이기고 보상 · 유물을 고른 뒤의 상태.
func _after_boss(seed: int = 3) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state.merge({"wave": 5, "phase": "manage", "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var won: Dictionary = _apply(state, {"type": "startBattle"})["state"]
	var picked: Dictionary = _apply(won, {"type": "chooseReward", "index": 0})["state"]
	if picked["phase"] == "slab":
		picked = _apply(picked, {"type": "skipRune"})["state"]
	assert_eq(picked["phase"], "relic")
	return _apply(picked, {"type": "chooseRelic", "index": 0})["state"]


# ---------- 상점 ----------

func test_shop_values_live_in_data() -> void:
	var kinds: Array = _data["waves"]["shop"]["stock"].map(func(item: Dictionary) -> String: return item["kind"])
	assert_eq(kinds, ["rune", "erase", "transmute", "life", "relic"])
	for item: Dictionary in _data["waves"]["shop"]["stock"]:
		assert_true(int(item["cost"]) > 0 and not str(item["nameKo"]).is_empty(), str(item))
	assert_true(int(_data["slot"]["nudgeBuy"]["cost"]) > 0 and int(_data["slot"]["nudgeBuy"]["perWave"]) > 0)
	assert_true(int(_data["waves"]["rewardReroll"]["cost"]) > 0)


func test_shop_opens_after_a_boss_win_and_leaving_goes_on() -> void:
	var state: Dictionary = _after_boss()
	assert_eq(state["phase"], "shop")
	assert_eq(int(state["wave"]), 6)
	assert_eq(state["shop"]["items"].size(), 5)
	for item: Dictionary in state["shop"]["items"]:
		assert_eq(item["sold"], false)
	var rune: Dictionary = state["shop"]["items"][_item(state, "rune")]
	assert_true(rune["detail"] in _data["slot"]["slab"]["offer"], "어떤 룬인지 미리 정해져 있다")
	var relic: Dictionary = state["shop"]["items"][_item(state, "relic")]
	assert_true(relic["detail"] not in state["relics"], "아직 없는 유물")
	var left: Dictionary = _apply(state, {"type": "leaveShop"})
	assert_eq(left["state"]["phase"], "spin")
	assert_eq(left["state"]["shop"], null)
	assert_true(left["events"].any(func(event: Dictionary) -> bool: return event["t"] == "waveStart" and event["wave"] == 6))


func test_no_shop_after_an_ordinary_win_or_a_lost_boss() -> void:
	var state: Dictionary = RunRules.create_run(_data, 3)["state"]
	state.merge({"wave": 2, "phase": "manage", "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var won: Dictionary = _apply(state, {"type": "startBattle"})["state"]
	var picked: Dictionary = _apply(won, {"type": "chooseReward", "index": 0})["state"]
	if picked["phase"] == "slab":
		picked = _apply(picked, {"type": "skipRune"})["state"]
	assert_eq(picked["phase"], "spin")
	var weak: Dictionary = RunRules.create_run(_data, 3)["state"]
	weak.merge({"wave": 5, "phase": "manage", "nest": [_inst(1, "fire_drake", -90), null, null, null, null, null]}, true)
	var lost: Dictionary = _apply(weak, {"type": "startBattle"})["state"]
	assert_eq(lost["phase"], "spin")


func test_shop_stock_does_not_touch_the_run_rng() -> void:
	var state: Dictionary = RunRules.create_run(_data, 4)["state"]
	state.merge({"phase": "fork", "forkChoices": ["elite", "rest", "merchant"], "wave": 4, "mana": 50,
		"nest": [_inst(1, "fire_drake"), null, null, null, null, null]}, true)
	var opened: Dictionary = _apply(state, {"type": "chooseFork", "option": "merchant"})["state"]
	assert_eq(opened["rngState"], state["rngState"], "진열을 뽑아도 판의 난수는 그대로")
	var bought: Dictionary = _apply(opened, {"type": "buy", "index": _item(opened, "transmute")})["state"]
	bought = _apply(bought, {"type": "buy", "index": _item(bought, "relic")})["state"]
	var left: Dictionary = _apply(bought, {"type": "leaveShop"})["state"]
	assert_eq(left["rngState"], state["rngState"], "사고 나가도 판의 난수는 그대로")
	## 같은 판 · 같은 때의 진열은 늘 같다.
	assert_eq(_apply(state, {"type": "chooseFork", "option": "merchant"})["state"]["shop"], opened["shop"])


func test_buying_pays_mana_and_each_thing_sells_once() -> void:
	var state: Dictionary = _shop(30)
	var index: int = _item(state, "transmute")
	var result: Dictionary = _apply(state, {"type": "buy", "index": index})
	var after: Dictionary = result["state"]
	assert_eq(int(after["mana"]), 30 - _cost("transmute"))
	assert_eq(int(after["items"]["transmute"]), 1)
	assert_eq(after["phase"], "shop")
	assert_eq(after["shop"]["items"][index]["sold"], true)
	assert_true({"t": "mana", "delta": -_cost("transmute"), "reason": "shop"} in result["events"])
	assert_true(result["events"].any(func(event: Dictionary) -> bool: return event["t"] == "bought" and event["index"] == index))
	_assert_rejected(after, {"type": "buy", "index": index}, "soldOut")
	_assert_rejected(after, {"type": "buy", "index": 99}, "emptySlot")
	_assert_rejected(after, {"type": "buy", "index": -1}, "emptySlot")


func test_cannot_buy_without_enough_mana() -> void:
	var state: Dictionary = _shop(_cost("transmute") - 1)
	_assert_rejected(state, {"type": "buy", "index": _item(state, "transmute")}, "notEnoughMana")
	assert_eq(RunRules.shop_rejection(_data, state, _item(state, "transmute")), "notEnoughMana")


func test_buy_and_leave_only_work_in_the_shop() -> void:
	var state: Dictionary = RunRules.create_run(_data, 4)["state"]
	_assert_rejected(state, {"type": "buy", "index": 0}, "wrongPhase")
	_assert_rejected(state, {"type": "leaveShop"}, "wrongPhase")


func test_life_sells_only_when_lives_are_missing() -> void:
	var full: Dictionary = _shop(30)
	_assert_rejected(full, {"type": "buy", "index": _item(full, "life")}, "livesFull")
	var hurt: Dictionary = _shop(30, 4, {"lives": 3})
	var after: Dictionary = _apply(hurt, {"type": "buy", "index": _item(hurt, "life")})["state"]
	assert_eq(int(after["lives"]), 4)
	assert_eq(int(after["mana"]), 30 - _cost("life"))


func test_bought_relic_is_owned_and_applies_at_once() -> void:
	var state: Dictionary = _shop(30)
	var index: int = _item(state, "relic")
	var id: String = state["shop"]["items"][index]["detail"]
	var result: Dictionary = _apply(state, {"type": "buy", "index": index})
	assert_true(id in result["state"]["relics"])
	assert_eq(int(result["state"]["mana"]), 30 - _cost("relic"))
	assert_true({"t": "relic", "id": id} in result["events"])
	assert_eq(result["state"]["phase"], "shop")


func test_bought_rune_goes_to_the_slab_and_comes_back_to_the_shop() -> void:
	var state: Dictionary = _shop(30)
	var index: int = _item(state, "rune")
	var rune: String = state["shop"]["items"][index]["detail"]
	var buying: Dictionary = _apply(state, {"type": "buy", "index": index})["state"]
	assert_eq(buying["phase"], "slab")
	assert_eq(buying["runePending"], rune)
	var at: int = 0
	while buying["slab"][at] == rune:
		at += 1
	var placed: Dictionary = _apply(buying, {"type": "replaceRune", "index": at})["state"]
	assert_eq(placed["phase"], "shop")
	assert_eq(placed["slab"][at], rune)
	assert_eq(placed["runePending"], null)
	assert_eq(int(placed["mana"]), 30 - _cost("rune"))
	assert_eq(placed["shop"]["items"][index]["sold"], true)


func test_backing_out_of_a_bought_rune_gives_the_mana_back() -> void:
	var state: Dictionary = _shop(30)
	var index: int = _item(state, "rune")
	var buying: Dictionary = _apply(state, {"type": "buy", "index": index})["state"]
	var result: Dictionary = _apply(buying, {"type": "skipRune"})
	var back: Dictionary = result["state"]
	assert_eq(back["phase"], "shop")
	assert_eq(int(back["mana"]), 30)
	assert_eq(back["shop"]["items"][index]["sold"], false)
	assert_eq(back["slab"], state["slab"])
	assert_true(result["events"].any(func(event: Dictionary) -> bool: return event["t"] == "refunded"))


func test_erase_sells_until_the_slab_is_at_its_smallest() -> void:
	var state: Dictionary = _shop(30)
	var index: int = _item(state, "erase")
	var size: int = state["slab"].size()
	var buying: Dictionary = _apply(state, {"type": "buy", "index": index})["state"]
	assert_eq(buying["phase"], "slab")
	var erased: Dictionary = _apply(buying, {"type": "replaceRune", "index": 0})["state"]
	assert_eq(erased["phase"], "shop")
	assert_eq(erased["slab"].size(), size - 1)
	var least: int = int(_data["slot"]["slab"]["minSize"])
	var small: Dictionary = _shop(30, 4, {"slab": state["slab"].slice(0, least)})
	_assert_rejected(small, {"type": "buy", "index": _item(small, "erase")}, "slabMin")


func test_twin_chisel_lets_a_bought_rune_replace_two_and_then_no_refund() -> void:
	var state: Dictionary = _shop(30, 4, {"relics": ["chisel"]})
	var index: int = _item(state, "rune")
	var rune: String = state["shop"]["items"][index]["detail"]
	var buying: Dictionary = _apply(state, {"type": "buy", "index": index})["state"]
	var spots: Array = []
	for i: int in range(buying["slab"].size()):
		if buying["slab"][i] != rune and spots.size() < 2:
			spots.append(i)
	var once: Dictionary = _apply(buying, {"type": "replaceRune", "index": spots[0]})["state"]
	assert_eq(once["phase"], "slab", "한 장 더 바꿀 수 있다")
	var stopped: Dictionary = _apply(once, {"type": "skipRune"})["state"]
	assert_eq(stopped["phase"], "shop")
	assert_eq(int(stopped["mana"]), 30 - _cost("rune"), "이미 한 장 바꿨으면 돌려받지 않는다")
	assert_eq(stopped["shop"]["items"][index]["sold"], true)


func test_merchant_fork_opens_the_shop_for_free() -> void:
	var state: Dictionary = RunRules.create_run(_data, 4)["state"]
	state.merge({"phase": "fork", "forkChoices": ["elite", "rest", "merchant"], "wave": 4, "mana": 0,
		"nest": [_inst(1, "fire_drake"), null, null, null, null, null]}, true)
	var result: Dictionary = _apply(state, {"type": "chooseFork", "option": "merchant"})
	assert_eq(result["state"]["phase"], "shop")
	assert_eq(int(result["state"]["mana"]), 0)
	assert_eq(result["state"]["forkChoices"], [])
	assert_eq(_apply(result["state"], {"type": "leaveShop"})["state"]["phase"], "spin")


func test_shop_without_a_slab_sells_no_runes_and_owned_relics_are_not_restocked() -> void:
	var all_but_one: Array = _data["relics"].map(func(relic: Dictionary) -> String: return relic["id"])
	var last: String = all_but_one.pop_back()
	var state: Dictionary = _shop(30, 4, {"slab": [], "relics": all_but_one})
	assert_eq(_item(state, "rune"), -1)
	assert_eq(_item(state, "erase"), -1)
	assert_eq(state["shop"]["items"][_item(state, "relic")]["detail"], last)
	var every: Dictionary = _shop(30, 4, {"relics": all_but_one + [last]})
	assert_eq(_item(every, "relic"), -1)


func test_shop_survives_a_save_and_plays_on() -> void:
	var state: Dictionary = _shop(30)
	var loaded: Dictionary = Store.unpack_run(Store.pack_run(state, "standard", false), _data, false)
	assert_eq(RunRules.state_hash(loaded["state"]), RunRules.state_hash(state))
	var bought: Dictionary = _apply(loaded["state"], {"type": "buy", "index": _item(state, "transmute")})["state"]
	assert_eq(int(bought["mana"]), 30 - _cost("transmute"))
	assert_eq(_apply(bought, {"type": "leaveShop"})["state"]["phase"], "spin")
	## 상점에서 룬을 사서 석판을 고치는 중에 저장해도 이어진다.
	var buying: Dictionary = _apply(state, {"type": "buy", "index": _item(state, "rune")})["state"]
	var mid: Dictionary = Store.unpack_run(Store.pack_run(buying, "standard", false), _data, false)["state"]
	var back: Dictionary = _apply(mid, {"type": "skipRune"})["state"]
	assert_eq(back["phase"], "shop")
	assert_eq(int(back["mana"]), 30, "이어 한 뒤에 물러도 값을 돌려받는다")
	assert_eq(back["shop"]["items"][_item(back, "rune")]["sold"], false)
	## 진열이 빈 상점 저장은 이어 할 수 없다.
	var broken: Dictionary = state.duplicate(true)
	broken["shop"] = {"items": []}
	assert_eq(Store.unpack_run(Store.pack_run(broken, "standard", false), _data, false), {})
	broken["shop"] = null
	assert_eq(Store.unpack_run(Store.pack_run(broken, "standard", false), _data, false), {})


func test_erase_and_half_used_chisel_purchases_survive_a_save() -> void:
	## 룬 지우기를 사서 고르는 중에 저장: 이어 한 뒤 물러도 값을 돌려받는다.
	var state: Dictionary = _shop(30)
	var erasing: Dictionary = _apply(state, {"type": "buy", "index": _item(state, "erase")})["state"]
	var loaded: Dictionary = Store.unpack_run(Store.pack_run(erasing, "standard", false), _data, false)["state"]
	var back: Dictionary = _apply(loaded, {"type": "skipRune"})["state"]
	assert_eq([back["phase"], int(back["mana"]), back["shop"]["items"][_item(back, "erase")]["sold"]], ["shop", 30, false])
	## 쌍둥이 끌로 한 장 바꾼 뒤에 저장: 이어 해서 그만둬도 값은 돌려받지 않는다.
	var chisel: Dictionary = _shop(30, 4, {"relics": ["chisel"]})
	var index: int = _item(chisel, "rune")
	var rune: String = chisel["shop"]["items"][index]["detail"]
	var buying: Dictionary = _apply(chisel, {"type": "buy", "index": index})["state"]
	var at: int = 0
	while buying["slab"][at] == rune:
		at += 1
	var once: Dictionary = _apply(buying, {"type": "replaceRune", "index": at})["state"]
	assert_eq(once["phase"], "slab")
	var again: Dictionary = Store.unpack_run(Store.pack_run(once, "standard", false), _data, false)["state"]
	var stopped: Dictionary = _apply(again, {"type": "skipRune"})["state"]
	assert_eq([stopped["phase"], int(stopped["mana"]), stopped["shop"]["items"][index]["sold"]], ["shop", 30 - _cost("rune"), true])


func _loads(state: Dictionary) -> bool:
	return not Store.unpack_run(Store.pack_run(state, "standard", false), _data, false).is_empty()


func test_tampered_shop_saves_are_rejected() -> void:
	var state: Dictionary = _shop(30)
	var buying: Dictionary = _apply(state, {"type": "buy", "index": _item(state, "rune")})["state"]
	assert_true(_loads(state) and _loads(buying), "온전한 저장은 열린다")
	## 무를 물건 번호를 다른 물건(유물)으로 바꾼 저장: 4를 내고 12를 돌려받지 못하게.
	var swapped: Dictionary = buying.duplicate(true)
	swapped["shop"]["refund"] = _item(state, "relic")
	assert_true(not _loads(swapped), "무를 물건이 고치는 룬과 다르다")
	var loose: Dictionary = state.duplicate(true)
	loose["shop"]["refund"] = _item(state, "rune")
	assert_true(not _loads(loose), "상점 차례인데 무를 물건이 있다")
	var out_of_range: Dictionary = buying.duplicate(true)
	out_of_range["shop"]["refund"] = 99
	assert_true(not _loads(out_of_range))
	## 값이 음수이거나 이름이 없는 물건, 모르는 종류, 없는 유물.
	for change: Array in [["cost", -6], ["cost", 2.5], ["nameKo", null], ["kind", "gift"], ["sold", "no"]]:
		var bad: Dictionary = state.duplicate(true)
		bad["shop"]["items"][_item(state, "transmute")][change[0]] = change[1]
		assert_true(not _loads(bad), str(change))
	var ghost: Dictionary = state.duplicate(true)
	ghost["shop"]["items"][_item(state, "relic")]["detail"] = "no_such_relic"
	assert_true(not _loads(ghost))
	## 상점이 닫혀 있어야 할 차례에 상점이 남아 있는 저장.
	var stale: Dictionary = state.duplicate(true)
	stale["phase"] = "spin"
	assert_true(not _loads(stale))


func test_bot_gets_through_the_shop() -> void:
	var state: Dictionary = _shop(40, 4, {"lives": 2})
	var steps: int = 0
	var bought: Array = []
	while state["phase"] in ["shop", "slab"] and steps < 30:
		var command: Dictionary = Bot.choose(_data, state)
		if command["type"] == "buy":
			bought.append(state["shop"]["items"][int(command["index"])]["kind"])
		var result: Dictionary = _apply(state, command)
		assert_true(result["events"].all(func(event: Dictionary) -> bool: return event["t"] != "rejected"), str(command))
		state = result["state"]
		steps += 1
	assert_eq(state["phase"], "spin", "봇이 상점을 나와 다음 웨이브로 간다")
	assert_true("life" in bought and "relic" in bought, "생명과 유물을 산다: %s" % str(bought))
	var poor: Dictionary = _shop(0)
	assert_eq(Bot.choose(_data, poor), {"type": "leaveShop"})


func test_bot_visits_the_shop_after_a_boss_and_moves_on() -> void:
	var state: Dictionary = RunRules.create_run(_data, 3)["state"]
	state.merge({"wave": 5, "phase": "manage", "mana": 30, "lives": 3, "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var shops: int = 0
	var buys: int = 0
	var steps: int = 0
	while int(state["wave"]) < 7 and state["phase"] not in ["gameOver", "victory"] and steps < 400:
		var command: Dictionary = Bot.choose(_data, state)
		var result: Dictionary = _apply(state, command)
		assert_true(result["events"].all(func(event: Dictionary) -> bool: return event["t"] != "rejected"), "수 %d %s" % [steps, str(command)])
		shops += 1 if result["events"].any(func(event: Dictionary) -> bool: return event["t"] == "shop") else 0
		buys += 1 if command["type"] == "buy" else 0
		state = result["state"]
		steps += 1
	assert_eq(int(state["wave"]), 7, "보스 뒤 상점을 지나 7웨이브까지 간다")
	assert_eq(shops, 1)
	assert_true(buys >= 1, "마력이 넉넉하고 생명이 모자라니 무언가 산다")


func test_bot_plays_whole_runs_with_the_new_turns() -> void:
	for seed: int in [31, 32]:
		var state: Dictionary = RunRules.create_run(_data, seed, 0, RunRules.start_options(_data, seed)[0]["id"])["state"]
		var steps: int = 0
		while state["phase"] not in ["gameOver", "victory"] and steps < 4000 and int(state["wave"]) <= 9:
			var result: Dictionary = _apply(state, Bot.choose(_data, state))
			assert_true(result["events"].all(func(event: Dictionary) -> bool: return event["t"] != "rejected"), "판 %d 수 %d" % [seed, steps])
			state = result["state"]
			steps += 1
		assert_true(steps < 4000, "봇이 제자리에서 돌지 않는다")


# ---------- 밀기 추가 구매 ----------

func _picking(mana: int) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, 1)["state"]
	state["mana"] = mana
	return _apply(state, {"type": "spin"})["state"]


func test_free_nudge_first_then_paid_nudges_up_to_the_limit() -> void:
	var cost: int = int(_data["slot"]["nudgeBuy"]["cost"])
	var limit: int = int(_data["slot"]["nudgeBuy"]["perWave"])
	var state: Dictionary = _picking(cost * limit + 5)
	var mana: int = int(state["mana"])
	assert_eq(RunRules.nudge_cost(_data, state), 0)
	var dirs: Array = [1, -1, -1, 1, 1, -1, -1, 1]
	state = _apply(state, {"type": "nudge", "col": 0, "dir": dirs[0]})["state"]
	assert_eq(int(state["mana"]), mana, "첫 밀기는 무료")
	for i: int in range(limit):
		assert_eq(RunRules.nudge_cost(_data, state), cost)
		var result: Dictionary = _apply(state, {"type": "nudge", "col": 0, "dir": dirs[i + 1]})
		assert_true({"t": "mana", "delta": -cost, "reason": "nudge"} in result["events"], "산 밀기 %d" % i)
		state = result["state"]
		assert_eq(int(state["mana"]), mana - cost * (i + 1))
		assert_eq(int(state["nudgesBought"]), i + 1)
	assert_eq(RunRules.nudge_cost(_data, state), -1)
	_assert_rejected(state, {"type": "nudge", "col": 0, "dir": dirs[limit + 1]}, "noNudgeLeft")


func test_a_nudge_that_cannot_move_costs_nothing() -> void:
	var state: Dictionary = _picking(20)
	state = _apply(state, {"type": "nudge", "col": 0, "dir": 1})["state"]
	## 끝까지 밀린 열을 같은 쪽으로 또 밀면 거절: 마력도, 산 횟수도 그대로.
	_assert_rejected(state, {"type": "nudge", "col": 0, "dir": 1}, "cannotNudge")
	_assert_rejected(state, {"type": "nudge", "col": 5, "dir": 1}, "cannotNudge")
	_assert_rejected(state, {"type": "nudge", "col": 0, "dir": 2}, "cannotNudge")
	## 마력이 없거나 횟수를 다 썼어도 까닭은 같다.
	state["mana"] = 0
	_assert_rejected(state, {"type": "nudge", "col": 0, "dir": 1}, "cannotNudge")


func test_replacing_a_rune_with_the_same_rune_is_refused_and_keeps_the_refund() -> void:
	var state: Dictionary = _shop(30, 4, {"relics": ["chisel"]})
	var index: int = _item(state, "rune")
	var rune: String = state["shop"]["items"][index]["detail"]
	var buying: Dictionary = _apply(state, {"type": "buy", "index": index})["state"]
	_assert_rejected(buying, {"type": "replaceRune", "index": buying["slab"].find(rune)}, "sameRune")
	assert_eq(int(_apply(buying, {"type": "skipRune"})["state"]["mana"]), 30)


func test_reward_reroll_is_off_when_three_new_cards_cannot_be_drawn() -> void:
	var data: Dictionary = _data.duplicate(true)
	data["rewards"] = data["rewards"].slice(0, 5)
	var state: Dictionary = RunRules.create_run(data, 3)["state"]
	state.merge({"wave": 2, "phase": "manage", "mana": 20, "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var won: Dictionary = RunRules.apply_command(data, state, {"type": "startBattle"})["state"]
	assert_eq(won["rewardChoices"].size(), 3)
	assert_eq(RunRules.reward_reroll_cost(data, won), -1, "남은 보상이 둘뿐이면 다시 뽑지 않는다")
	assert_eq(RunRules.apply_command(data, won, {"type": "rerollRewards"})["events"], [{"t": "rejected", "reason": "noRerollLeft"}])


func test_paid_nudge_needs_mana() -> void:
	var cost: int = int(_data["slot"]["nudgeBuy"]["cost"])
	var state: Dictionary = _picking(cost - 1)
	state = _apply(state, {"type": "nudge", "col": 1, "dir": 1})["state"]
	_assert_rejected(state, {"type": "nudge", "col": 1, "dir": -1}, "notEnoughMana")


func test_bought_nudges_reset_with_the_next_wave() -> void:
	var state: Dictionary = RunRules.create_run(_data, 3)["state"]
	state.merge({"wave": 2, "phase": "manage", "nudgesBought": 3, "nudgesLeft": 0,
		"nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var after: Dictionary = _apply(state, {"type": "startBattle"})["state"]
	assert_eq(int(after["nudgesBought"]), 0)
	assert_eq(int(after["nudgesLeft"]), int(_data["slot"]["nudgesPerWave"]))


# ---------- 보상 다시 뽑기 ----------

func _rewarding(mana: int, seed: int = 3) -> Dictionary:
	var state: Dictionary = RunRules.create_run(_data, seed)["state"]
	state.merge({"wave": 2, "phase": "manage", "mana": mana, "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var won: Dictionary = _apply(state, {"type": "startBattle"})["state"]
	assert_eq(won["phase"], "reward")
	return won


func test_reward_reroll_costs_mana_and_shows_three_new_cards() -> void:
	var cost: int = int(_data["waves"]["rewardReroll"]["cost"])
	var state: Dictionary = _rewarding(20)
	var mana: int = int(state["mana"])
	assert_eq(RunRules.reward_reroll_cost(_data, state), cost)
	var before: Array = state["rewardChoices"].map(func(choice: Dictionary) -> String: return choice["reward"]["id"])
	var result: Dictionary = _apply(state, {"type": "rerollRewards"})
	var after: Dictionary = result["state"]
	assert_eq(after["phase"], "reward")
	assert_eq(int(after["mana"]), mana - cost)
	assert_eq(after["rewardChoices"].size(), 3)
	for choice: Dictionary in after["rewardChoices"]:
		assert_true(choice["reward"]["id"] not in before, "방금 본 보상은 다시 나오지 않는다: " + choice["reward"]["id"])
	assert_true({"t": "mana", "delta": -cost, "reason": "rewardReroll"} in result["events"])
	assert_true(result["events"].any(func(event: Dictionary) -> bool: return event["t"] == "rewardChoices"))
	## 한 보상 화면에서 한 번만.
	assert_eq(RunRules.reward_reroll_cost(_data, after), -1)
	_assert_rejected(after, {"type": "rerollRewards"}, "noRerollLeft")
	assert_eq(_apply(after, {"type": "chooseReward", "index": 0})["state"]["phase"] in ["spin", "slab"], true)


func test_reward_reroll_needs_mana_and_the_reward_turn() -> void:
	var state: Dictionary = _rewarding(0)
	state["mana"] = int(_data["waves"]["rewardReroll"]["cost"]) - 1
	_assert_rejected(state, {"type": "rerollRewards"}, "notEnoughMana")
	_assert_rejected(RunRules.create_run(_data, 3)["state"], {"type": "rerollRewards"}, "wrongPhase")


func test_each_reward_screen_gets_its_own_reroll() -> void:
	var state: Dictionary = _rewarding(20)
	state["extraRewards"] = 1
	var rerolled: Dictionary = _apply(state, {"type": "rerollRewards"})["state"]
	var next: Dictionary = _apply(rerolled, {"type": "chooseReward", "index": 0})["state"]
	if next["phase"] == "slab":
		next = _apply(next, {"type": "skipRune"})["state"]
	assert_eq(next["phase"], "reward", "정예 사냥의 둘째 보상")
	assert_eq(RunRules.reward_reroll_cost(_data, next), int(_data["waves"]["rewardReroll"]["cost"]))


func test_runs_that_never_use_the_new_things_keep_their_rng() -> void:
	## 상점이 없는 자료로 같은 명령을 보낸 판과 견준다: 상점을 열고 그냥 나가면 다음 석판까지 똑같다.
	var plain_data: Dictionary = _data.duplicate(true)
	plain_data["waves"].erase("shop")
	var commands: Array = [{"type": "startBattle"}, {"type": "chooseReward", "index": 0}, {"type": "chooseRelic", "index": 0}]
	var plain: Dictionary = RunRules.create_run(plain_data, 3)["state"]
	plain.merge({"wave": 5, "phase": "manage", "nest": [_inst(1, "tiamat", 5000), null, null, null, null, null]}, true)
	var mine: Dictionary = plain.duplicate(true)
	for command: Dictionary in commands:
		plain = RunRules.apply_command(plain_data, plain, command)["state"]
		mine = _apply(mine, command)["state"]
		if plain["phase"] == "slab":
			plain = RunRules.apply_command(plain_data, plain, {"type": "skipRune"})["state"]
			mine = _apply(mine, {"type": "skipRune"})["state"]
	assert_eq(plain["phase"], "spin")
	assert_eq(mine["phase"], "shop")
	mine = _apply(mine, {"type": "leaveShop"})["state"]
	assert_eq(mine["rngState"], plain["rngState"])
	var spun_plain: Dictionary = RunRules.apply_command(plain_data, plain, {"type": "spin"})["state"]
	assert_eq(_apply(mine, {"type": "spin"})["state"]["grid"], spun_plain["grid"])
