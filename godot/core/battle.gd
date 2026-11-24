class_name Battle
extends RefCounted
## 부대 전투(설계 2026-11-23-squad-battlefield 4장). 정수 좌표 x(0~1000), 줄 0~2.
## 드래곤은 움직이지 않고 어디든 쏘며, 호위·졸병은 걸어가 같은 줄에서 근접 공격한다.

const LANES: int = 3


static func element_mult(cfg: Dictionary, atk: Variant, def: Variant) -> int:
	var beats: Dictionary = cfg["beats"]
	if def in beats.get(atk, []):
		return int(cfg["strongPct"])
	if atk in beats.get(def, []):
		return int(cfg["weakPct"])
	return 100


## 종 고유 특성과 계승 특성을 모두 적용한다.
static func to_unit(data: Dictionary, inst: Dictionary, team_bonus: Dictionary = {}) -> Dictionary:
	var species_id: String = inst["speciesId"]
	var spec: Variant = data["dragons"].get(species_id)
	if spec == null:
		push_error("unknown species " + species_id)
		return {}
	var hp_pct: int = 0
	var atk_pct: int = 0
	var haste_pct: int = 0
	var lifesteal_pct: int = 0
	for id: String in [spec["traitId"]] + inst["traits"]:
		var trait_spec: Variant = data["traits"].get(id)
		if trait_spec == null:
			continue
		var value: int = int(trait_spec["value"])
		match trait_spec["kind"]:
			"hpPct":
				hp_pct += value
			"atkPct":
				atk_pct += value
			"hastePct":
				haste_pct += value
			_:
				lifesteal_pct += value

	var escort_bonus: int = 0
	var escort_pct: int = 0
	## 스킬로만 붙는 값: 치명타 확률, 궁극기 피해, 받는 피해 감소, 궁극기 충전 줄이기.
	var extra: Dictionary = {}
	var learned: Dictionary = inst.get("skills", {})
	for skill_id: String in learned:
		var skill: Variant = data.get("skills", {}).get(skill_id)
		if skill == null:
			continue
		var amount: int = int(skill["value"]) * int(learned[skill_id])
		match skill["kind"]:
			"hpPct":
				hp_pct += amount
			"atkPct":
				atk_pct += amount
			"hastePct":
				haste_pct += amount
			"lifestealPct":
				lifesteal_pct += amount
			"escortCount":
				escort_bonus += amount
			"escortPct":
				escort_pct += amount
			"critPct", "ultPowerPct", "guardPct", "ultCharge":
				extra[skill["kind"]] = int(extra.get(skill["kind"], 0)) + amount

	hp_pct += int(team_bonus.get("hpPct", 0))
	atk_pct += int(team_bonus.get("atkPct", 0))
	haste_pct += int(team_bonus.get("hastePct", 0))
	lifesteal_pct += int(team_bonus.get("lifestealPct", 0))
	escort_bonus += int(team_bonus.get("escortCount", 0))
	escort_pct += int(team_bonus.get("escortPct", 0))

	var stats: Dictionary = spec["stats"]
	var level_pct: int = int(data["battle"].get("level", {}).get("statPct", 0)) * (maxi(1, int(inst.get("level", 1))) - 1)
	var bonus_pct: int = int(inst.get("bonusPct", 0)) + level_pct
	var unit: Dictionary = {
		"speciesId": spec["id"],
		"tier": spec["tier"],
		"elements": spec["elements"].duplicate(),
		"hp": Rng.fdiv(int(stats["hp"]) * (100 + bonus_pct + hp_pct), 100),
		"atk": Rng.fdiv(int(stats["atk"]) * (100 + bonus_pct + atk_pct), 100),
		"cooldownTicks": maxi(5, Rng.fdiv(int(stats["cooldownTicks"]) * (100 - haste_pct), 100)),
		"lifestealPct": lifesteal_pct,
		"escortBonus": escort_bonus,
		"escortPct": escort_pct,
	}
	## 배운 것만 싣는다(안 배웠으면 키가 없다).
	for kind: String in extra:
		unit[kind] = extra[kind]
	return unit


## 원소 시너지: 전장에 놓인 드래곤을 원소별로 세어 단계와 효과를 돌려준다(이중 원소는 양쪽에 센다).
## 결과는 자료 순서대로, 한 마리 이상 있는 원소만. level 0이면 아직 발동 전.
static func synergies(data: Dictionary, insts: Array) -> Array:
	var counts: Dictionary = {}
	for inst: Variant in insts:
		if inst == null:
			continue
		var spec: Variant = data["dragons"].get(inst["speciesId"])
		if spec == null:
			continue
		for element: String in spec["elements"]:
			counts[element] = int(counts.get(element, 0)) + 1
	var found: Array = []
	for row: Dictionary in data.get("synergies", []):
		var count: int = int(counts.get(row["element"], 0))
		if count == 0:
			continue
		var level: int = 0
		var value: int = 0
		var next_count: int = 0
		for step: Dictionary in row["levels"]:
			if count >= int(step["count"]):
				level += 1
				value = int(step["value"])
			elif next_count == 0:
				next_count = int(step["count"])
		found.append({
			"element": row["element"], "nameKo": row["nameKo"], "kind": row["kind"], "descKo": row.get("descKo", ""),
			"count": count, "level": level, "value": value, "nextCount": next_count,
		})
	return found


## 열린 둥지 칸의 드래곤(빈칸 null).
static func fielded(nest: Array, open: int) -> Array:
	var out: Array = []
	for i: int in range(nest.size()):
		out.append(nest[i] if i < open else null)
	return out


## 발동한 시너지를 종류별 합으로.
static func team_bonus(data: Dictionary, insts: Array) -> Dictionary:
	var bonus: Dictionary = {}
	for row: Dictionary in synergies(data, insts):
		if row["level"] > 0:
			bonus[row["kind"]] = int(bonus.get(row["kind"], 0)) + int(row["value"])
	return bonus


## 둥지 6칸을 전투 유닛으로(시너지 적용, 빈칸·잠긴 칸은 null).
static func team(data: Dictionary, nest: Array, open: int, extra: Dictionary = {}) -> Array:
	var insts: Array = fielded(nest, open)
	var bonus: Dictionary = team_bonus(data, insts)
	for kind: String in extra:
		bonus[kind] = int(bonus.get(kind, 0)) + int(extra[kind])
	var out: Array = []
	for inst: Variant in insts:
		out.append(null if inst == null else to_unit(data, inst, bonus))
	return out


## allies: 둥지 6칸(빈칸 null, to_unit 결과). enemies: Waves.generate_enemies 결과.
static func simulate_battle(
	cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {},
) -> Dictionary:
	var field: Dictionary = cfg["field"]
	var units: Array = _spawn(cfg, allies, enemies, int(rules.get("allySlowPct", 0)))
	var spawn_info: Array = []
	for unit: Dictionary in units:
		spawn_info.append({
			"id": unit["id"], "side": unit["side"], "kind": unit["kind"], "ref": unit["ref"],
			"elements": unit["elements"].duplicate(), "slot": unit["slot"], "owner": unit["owner"],
			"lane": unit["lane"], "x": unit["x"], "hp": unit["hp"], "stage": unit["stage"],
			"ultNeed": unit["ultNeed"], "elite": unit["elite"],
		})
	var last_stage: int = 0
	for unit: Dictionary in units:
		last_stage = maxi(last_stage, int(unit["stage"]))
	var stage: int = 0
	var stage_start: int = 0
	var stage_ticks: int = int(field.get("stageTicks", 0))

	var burn: Variant = rules.get("burn")
	var row_blast: Variant = rules.get("rowBlast")
	var pulse: Variant = rules.get("pulse")
	var enrage: Variant = rules.get("enrage")
	var heal_cut_pct: int = int(rules.get("healCutPct", 0))
	var heal_cut_from: int = int(rules.get("healCutFromTick", 0))
	var pos_every: int = int(field["posEveryTicks"])
	var strong_add: int = int(rules.get("strongAddPct", 0))
	var ultimate: Dictionary = cfg.get("ultimate", {})
	## 치명타: 드래곤(아군·적 우두머리)의 보통 공격이 가끔 세게 들어간다. 전투마다 받은 씨앗으로만 굴린다.
	var crit: Dictionary = cfg.get("crit", {})
	var crit_pct: int = int(crit.get("pct", 0))
	var crit_rng: Rng = Rng.new(int(rules.get("critSeed", 0)))

	var events: Array = []
	var tick: int = 0
	var winner: String = ""
	var blast_front: bool = true
	var enraged: bool = false
	var dirty: Dictionary = {}
	while winner.is_empty() and tick < cfg["maxTicks"]:
		tick += 1
		if stage < last_stage:
			var cleared: bool = true
			for unit: Dictionary in units:
				if unit["side"] == "enemy" and unit["active"] and unit["hp"] > 0:
					cleared = false
					break
			if cleared or (stage_ticks > 0 and tick - stage_start >= stage_ticks):
				stage += 1
				stage_start = tick
				for unit: Dictionary in units:
					if unit["stage"] == stage:
						unit["active"] = true
				events.append({"tick": tick, "kind": "stage", "stage": stage, "total": last_stage + 1})
		if _hazard_due(burn, tick):
			var lowest: Variant = null
			for unit: Dictionary in units:
				if unit["side"] == "ally" and unit["kind"] == "dragon" and unit["hp"] > 0:
					if lowest == null or unit["hp"] < lowest["hp"]:
						lowest = unit
			if lowest != null:
				_hurt(units, lowest, tick, "burn", int(burn["pct"]), events)
		if _hazard_due(row_blast, tick):
			var front: bool = blast_front
			blast_front = not blast_front
			for unit: Dictionary in units:
				if unit["side"] != "ally" or unit["hp"] <= 0:
					continue
				var slot: int = unit["slot"]
				if (slot < 3) == front:
					_hurt(units, unit, tick, "rowBlast", int(row_blast["pct"]), events)
		if _hazard_due(pulse, tick):
			for unit: Dictionary in units:
				if unit["side"] == "ally" and unit["hp"] > 0:
					_hurt(units, unit, tick, "pulse", int(pulse["pct"]), events)
		if enrage != null and not enraged and tick >= enrage["atTick"]:
			enraged = true
			events.append({"tick": tick, "kind": "enrage"})
		if not _any_alive(units, "ally"):
			winner = "enemy"
			break

		for unit: Dictionary in units:
			if unit["active"] and unit["hp"] > 0 and unit["speed"] > 0:
				if _step(field, units, unit):
					dirty[unit["id"]] = true

		for side: String in ["ally", "enemy"]:
			for unit: Dictionary in units:
				if unit["side"] != side or unit["hp"] <= 0 or not unit["active"]:
					continue
				unit["timer"] += 1
				if unit["timer"] < unit["cd"]:
					continue
				var target: Variant = _nearest(field, units, unit)
				if target == null:
					continue
				if not _can_hit(field, unit, target):
					unit["timer"] = unit["cd"]
					continue
				unit["timer"] = 0
				## 궁극기: 아군 드래곤은 공격할 때마다 게이지가 차고, 다 차면 가까운 적 여럿을 세게 친다.
				var victims: Array = [target]
				var power_pct: int = 100
				var is_ult: bool = false
				var need: int = int(unit["ultNeed"])
				if need > 0:
					unit["charge"] += 1
					if unit["charge"] >= need:
						unit["charge"] = 0
						is_ult = true
						power_pct = int(ultimate["powerPct"].get(unit["tier"], 100)) + int(unit["ultPower"])
						victims = _nearest_many(field, units, unit, int(ultimate["targets"].get(unit["tier"], 1)))
						events.append({"tick": tick, "kind": "ult", "src": unit["id"]})
				for victim: Dictionary in victims:
					var mult: int = element_mult(cfg, _primary(unit), _primary(victim))
					if side == "ally" and mult > 100:
						mult += strong_add
					var dmg: int = maxi(1, Rng.fdiv(int(unit["atk"]) * mult * power_pct, 10000))
					var crit_chance: int = crit_pct + int(unit["critBonus"])
					var is_crit: bool = crit_chance > 0 and not is_ult and unit["kind"] == "dragon" and crit_rng.next_int(100) < crit_chance
					if is_crit:
						dmg = Rng.fdiv(dmg * int(crit["dmgPct"]), 100)
					if side == "enemy" and enraged:
						dmg = Rng.fdiv(dmg * int(enrage["atkPct"]), 100)
					if int(victim["guard"]) > 0:
						dmg = maxi(1, Rng.fdiv(dmg * (100 - int(victim["guard"])), 100))
					victim["hp"] -= dmg
					var raw_heal: int = Rng.fdiv(dmg * int(unit["lifesteal"]), 100)
					if side == "ally" and heal_cut_pct != 0 and tick >= heal_cut_from:
						raw_heal = Rng.fdiv(raw_heal * (100 - heal_cut_pct), 100)
					var heal: int = maxi(0, mini(raw_heal, int(unit["maxHp"]) - int(unit["hp"])))
					unit["hp"] += heal
					var hit: Dictionary = {
						"tick": tick, "kind": "attack", "src": unit["id"], "dst": victim["id"],
						"dmg": dmg, "mult": mult, "heal": heal,
					}
					if need > 0:
						hit["charge"] = unit["charge"]
					if is_ult:
						hit["ult"] = true
					if is_crit:
						hit["crit"] = true
					events.append(hit)
					if victim["hp"] <= 0:
						_kill(units, victim, tick, "hit", events)

		if pos_every > 0 and tick % pos_every == 0 and not dirty.is_empty():
			_record_pos(units, dirty, tick, events)
			dirty = {}
		if not _any_alive(units, "enemy"):
			winner = "ally"
		elif not _any_alive(units, "ally"):
			winner = "enemy"

	if not dirty.is_empty():
		_record_pos(units, dirty, tick, events)
	return {
		"winner": "enemy" if winner.is_empty() else winner,
		"ticks": tick, "events": events, "units": spawn_info,
	}


static func _spawn(cfg: Dictionary, allies: Array, enemies: Array, slow_pct: int) -> Array:
	var field: Dictionary = cfg["field"]
	var escort: Dictionary = cfg["escort"]
	## 양쪽 체력을 같은 비율로 키워 전투 길이만 조절한다.
	var hp_scale: int = int(cfg.get("hpScalePct", 100))
	var units: Array = []
	for slot: int in range(allies.size()):
		var item: Variant = allies[slot]
		if item == null:
			continue
		var unit: Dictionary = item
		var dragon: Dictionary = _make(units.size(), "ally", "dragon", unit["speciesId"], unit["elements"],
			Rng.fdiv(int(unit["hp"]) * hp_scale, 100), int(unit["atk"]), _slowed(int(unit["cooldownTicks"]), slow_pct), 0,
			slot % LANES, int(field["frontX"]) if slot < 3 else int(field["backX"]))
		dragon["slot"] = slot
		dragon["lifesteal"] = int(unit["lifestealPct"])
		dragon["tier"] = unit.get("tier", "")
		dragon["ultNeed"] = int(cfg.get("ultimate", {}).get("chargeHits", {}).get(dragon["tier"], 0))
		if dragon["ultNeed"] > 0:
			dragon["ultNeed"] = maxi(2, int(dragon["ultNeed"]) - int(unit.get("ultCharge", 0)))
		dragon["ultPower"] = int(unit.get("ultPowerPct", 0))
		dragon["critBonus"] = int(unit.get("critPct", 0))
		dragon["guard"] = mini(60, int(unit.get("guardPct", 0)))
		units.append(dragon)
		var count: int = int(escort["count"].get(unit.get("tier", "base"), 0)) + int(unit.get("escortBonus", 0))
		var escort_scale: int = 100 + int(unit.get("escortPct", 0))
		var first: Array = [] if unit["elements"].is_empty() else [unit["elements"][0]]
		for k: int in range(count):
			var guard: Dictionary = _make(units.size(), "ally", "escort", unit["speciesId"], first,
				maxi(1, Rng.fdiv(Rng.fdiv(int(unit["hp"]) * int(escort["hpPct"]) * escort_scale, 10000) * hp_scale, 100)),
				maxi(1, Rng.fdiv(int(unit["atk"]) * int(escort["atkPct"]) * escort_scale, 10000)),
				_slowed(int(escort["cooldownTicks"]), slow_pct), int(escort["speed"]),
				dragon["lane"], dragon["x"] + int(escort["offsetX"]) + k * int(escort["spacingX"]))
			guard["slot"] = slot
			guard["owner"] = dragon["id"]
			units.append(guard)
	for item: Dictionary in enemies:
		var foe: Dictionary = _make(units.size(), "enemy", item["kind"], item["id"], item["elements"],
			maxi(1, Rng.fdiv(int(item["hp"]) * hp_scale, 100)), int(item["atk"]), int(item["cooldownTicks"]), int(item.get("speed", 0)),
			int(item["lane"]), int(item["x"]))
		foe["stage"] = int(item.get("stage", 0))
		foe["elite"] = bool(item.get("elite", false))
		foe["active"] = foe["stage"] == 0
		units.append(foe)
	return units


static func _make(
	id: int, side: String, kind: String, ref: String, elements: Array,
	hp: int, atk: int, cd: int, speed: int, lane: int, x: int,
) -> Dictionary:
	return {
		"id": id, "side": side, "kind": kind, "ref": ref, "elements": elements.duplicate(),
		"hp": hp, "maxHp": hp, "atk": atk, "cd": cd, "timer": 0, "speed": speed,
		"lane": lane, "x": x, "laneTimer": 0, "slot": -1, "owner": -1, "lifesteal": 0,
		"stage": 0, "active": true, "tier": "", "ultNeed": 0, "charge": 0, "elite": false,
		"ultPower": 0, "critBonus": 0, "guard": 0,
	}


static func _slowed(cd: int, slow_pct: int) -> int:
	return cd if slow_pct == 0 else Rng.fdiv(cd * (100 + slow_pct), 100)


static func _distance(field: Dictionary, a: Dictionary, b: Dictionary) -> int:
	return absi(int(a["x"]) - int(b["x"])) + absi(int(a["lane"]) - int(b["lane"])) * int(field["laneGap"])


## 가장 가까운 살아 있는 적. 동률이면 줄 번호, 그다음 id가 작은 쪽.
static func _nearest(field: Dictionary, units: Array, me: Dictionary) -> Variant:
	var best: Variant = null
	var best_d: int = 0
	for other: Dictionary in units:
		if other["side"] == me["side"] or other["hp"] <= 0 or not other["active"]:
			continue
		var d: int = _distance(field, me, other)
		if best == null or d < best_d or (d == best_d and int(other["lane"]) < int(best["lane"])):
			best = other
			best_d = d
	return best


## 가까운 순으로 살아 있는 적 count마리.
static func _nearest_many(field: Dictionary, units: Array, me: Dictionary, count: int) -> Array:
	var found: Array = []
	for other: Dictionary in units:
		if other["side"] != me["side"] and other["hp"] > 0 and other["active"]:
			found.append(other)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = _distance(field, me, a)
		var db: int = _distance(field, me, b)
		if da != db:
			return da < db
		if a["lane"] != b["lane"]:
			return int(a["lane"]) < int(b["lane"])
		return int(a["id"]) < int(b["id"]))
	return found.slice(0, maxi(1, count))


static func _can_hit(field: Dictionary, unit: Dictionary, target: Dictionary) -> bool:
	if unit["kind"] == "dragon":
		return true
	return unit["lane"] == target["lane"] and absi(int(unit["x"]) - int(target["x"])) <= int(field["meleeRange"])


## 걷는 유닛 한 틱 이동. 움직였으면 true.
static func _step(field: Dictionary, units: Array, unit: Dictionary) -> bool:
	var target: Variant = _nearest(field, units, unit)
	if target == null or _can_hit(field, unit, target):
		unit["laneTimer"] = 0
		return false
	var moved: bool = false
	var dx: int = int(target["x"]) - int(unit["x"])
	var melee: int = int(field["meleeRange"])
	if target["lane"] != unit["lane"] and absi(dx) <= int(field["laneChangeRange"]):
		unit["laneTimer"] += 1
		if unit["laneTimer"] >= int(field["laneChangeTicks"]):
			unit["laneTimer"] = 0
			unit["lane"] += signi(int(target["lane"]) - int(unit["lane"]))
			moved = true
	else:
		unit["laneTimer"] = 0
	if absi(dx) > melee:
		unit["x"] += signi(dx) * mini(int(unit["speed"]), absi(dx) - melee)
		moved = true
	return moved


static func _kill(units: Array, target: Dictionary, tick: int, cause: String, events: Array) -> void:
	events.append({"tick": tick, "kind": "death", "id": target["id"], "cause": cause})
	if target["kind"] != "dragon":
		return
	for unit: Dictionary in units:
		if unit["owner"] == target["id"] and unit["hp"] > 0:
			unit["hp"] = 0
			events.append({"tick": tick, "kind": "death", "id": unit["id"], "cause": "owner"})


static func _record_pos(units: Array, dirty: Dictionary, tick: int, events: Array) -> void:
	var xs: Dictionary = {}
	var lanes: Dictionary = {}
	for unit: Dictionary in units:
		if dirty.has(unit["id"]):
			xs[unit["id"]] = unit["x"]
			lanes[unit["id"]] = unit["lane"]
	events.append({"tick": tick, "kind": "pos", "xs": xs, "lanes": lanes})


static func _any_alive(units: Array, side: String) -> bool:
	for unit: Dictionary in units:
		if unit["side"] == side and unit["hp"] > 0:
			return true
	return false


static func _primary(unit: Dictionary) -> Variant:
	var elements: Array = unit["elements"]
	return null if elements.is_empty() else elements[0]


static func _hazard_due(hazard: Variant, tick: int) -> bool:
	if hazard == null:
		return false
	var interval: int = int(hazard["everyTicks"])
	return interval != 0 and tick % interval == 0


static func _hurt(units: Array, unit: Dictionary, tick: int, hazard_name: String, pct: int, events: Array) -> void:
	if unit["hp"] <= 0:
		return
	var dmg: int = maxi(1, Rng.fdiv(int(unit["maxHp"]) * pct, 100))
	unit["hp"] -= dmg
	events.append({"tick": tick, "kind": "hazard", "name": hazard_name, "id": unit["id"], "dmg": dmg})
	if unit["hp"] <= 0:
		_kill(units, unit, tick, "hazard", events)
