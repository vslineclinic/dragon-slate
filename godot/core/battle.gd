class_name Battle
extends RefCounted
## 부대 전투(설계 2026-11-23-squad-battlefield 4장). 정수 좌표 x(0~1000), 줄 0~2.
## 드래곤은 제 줄을 지키며 사거리까지 걸어가 쏜다(다른 줄을 치면 약해진다). 호위·졸병은 걸어가 같은 줄에서 근접 공격한다.
## field에 dragonSpeed·frontRange·backRange·leaderRange·crossLanePct가 없으면 예전처럼 서서 어디든 쏜다.

const LANES: int = 3


static func element_mult(cfg: Dictionary, atk: Variant, def: Variant) -> int:
	var beats: Dictionary = cfg["beats"]
	if def in beats.get(atk, []):
		return int(cfg["strongPct"])
	if atk in beats.get(def, []):
		return int(cfg["weakPct"])
	return 100


## 형태별 능력: 종 id에서 원소 머리말을 뗀 형태 이름(lancer · sage …)으로 찾는다. 없으면 "".
static func ability_of(data: Dictionary, species_id: String) -> String:
	var cut: int = species_id.find("_")
	## 이름에 밑줄이 없는 종(신화 이름 드래곤)은 species 목록으로만 찾는다.
	var form: String = "" if cut < 0 else species_id.substr(cut + 1)
	var abilities: Dictionary = data["battle"].get("abilities", {})
	for id: String in abilities:
		if form in abilities[id].get("forms", []) or species_id in abilities[id].get("species", []):
			return id
	return ""


## 단련 단계의 끝(값과 확률이 둘 다 있는 단계까지).
static func temper_max(data: Dictionary) -> int:
	var cfg: Dictionary = data["battle"].get("temper", {})
	return mini(cfg.get("cost", []).size(), cfg.get("chancePct", []).size())


## 그 드래곤의 단련 단계. 저장이 깨져 범위를 벗어난 값은 0~끝으로 자른다.
static func temper_step(data: Dictionary, inst: Dictionary) -> int:
	return clampi(int(inst.get("temper", 0)), 0, temper_max(data))


## 단련 단계가 형태 능력을 얼마나 키우는가(%). 넘긴 문턱 가운데 가장 높은 값.
static func temper_boost(data: Dictionary, inst: Dictionary) -> int:
	var table: Dictionary = data["battle"].get("temper", {}).get("abilityPct", {})
	var step: int = temper_step(data, inst)
	var best: int = 0
	for key: String in table:
		if step >= int(key):
			best = maxi(best, int(table[key]))
	return best


## 형태 능력의 수치. 단련한 드래곤은 boost만큼 세다.
static func _apct(abilities: Dictionary, unit: Dictionary) -> int:
	var base: int = int(abilities.get(unit["ability"], {}).get("pct", 0))
	return Rng.fdiv(base * (100 + int(unit.get("boost", 0))), 100)


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
	var temper_pct: int = int(data["battle"].get("temper", {}).get("statPct", 0)) * temper_step(data, inst)
	var bonus_pct: int = int(inst.get("bonusPct", 0)) + level_pct + temper_pct
	var unit: Dictionary = {
		"speciesId": spec["id"],
		"tier": spec["tier"],
		"role": spec.get("role", ""),
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
	var ability: String = ability_of(data, species_id)
	if not ability.is_empty():
		unit["ability"] = ability
	var boost: int = temper_boost(data, inst)
	if boost > 0:
		unit["abilityBoost"] = boost
	return unit


## 그 드래곤이 데리고 나오는 호위 수: 등급 기본값 + 스킬 · 유물 · 시너지, escort.max를 넘지 않는다.
static func escort_count(cfg: Dictionary, unit: Dictionary) -> int:
	var escort: Dictionary = cfg["escort"]
	var count: int = int(escort["count"].get(unit.get("tier", "base"), 0)) + int(unit.get("escortBonus", 0))
	return count if not escort.has("max") else mini(count, int(escort["max"]))


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
		var entry: Dictionary = {
			"element": row["element"], "nameKo": row["nameKo"], "kind": row["kind"], "descKo": row.get("descKo", ""),
			"count": count, "level": level, "value": value, "nextCount": next_count,
		}
		## 규칙 효과(4마리 단계): 켜졌으면 rule, 아직이면 다음에 켜질 nextRule.
		for i: int in range(row["levels"].size()):
			var rule: Variant = row["levels"][i].get("rule")
			if rule is Dictionary:
				entry["rule" if level > i else "nextRule"] = rule
				entry["ruleCount"] = int(row["levels"][i]["count"])
				break
		found.append(entry)
	return found


## 발동한 시너지의 규칙 효과: {규칙 id: 수치}. 전투에는 rules.synergy로 들어간다.
static func synergy_rules(data: Dictionary, insts: Array) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in synergies(data, insts):
		if row.has("rule"):
			var params: Dictionary = row["rule"].duplicate()
			var id: String = params["id"]
			for key: String in ["id", "nameKo", "descKo"]:
				params.erase(key)
			out[id] = params
	return out


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
## rules.ultAt = {틱: [드래곤 id, ...]}: 수동 궁극기(rules.manualUlt)를 그 틱에 쏘라고 한 기록. 같은 기록이면 결과가 같다.
static func simulate_battle(
	cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {},
) -> Dictionary:
	var sim: Dictionary = begin_battle(cfg, allies, enemies, rules)
	var ult_at: Dictionary = rules.get("ultAt", {})
	while not battle_over(sim):
		var next_tick: int = int(sim["tick"]) + 1
		## 저장 글(JSON)을 거친 기록은 틱이 글자 열쇠다: 둘 다 찾아본다.
		var arm: Variant = [] if ult_at.is_empty() else ult_at.get(next_tick, ult_at.get(str(next_tick), []))
		step_battle(sim, arm if arm is Array else [])
	return battle_result(sim)


## 전투를 한 틱씩 돌릴 수 있는 상태를 만든다(화면이 직접 돌리며 수동 궁극기를 끼워 넣을 때 쓴다).
static func begin_battle(cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {}) -> Dictionary:
	var units: Array = _spawn(cfg, allies, enemies, rules)
	var spawn_info: Array = []
	for unit: Dictionary in units:
		spawn_info.append({
			"id": unit["id"], "side": unit["side"], "kind": unit["kind"], "ref": unit["ref"],
			"elements": unit["elements"].duplicate(), "slot": unit["slot"], "owner": unit["owner"],
			"lane": unit["lane"], "x": unit["x"], "hp": unit["hp"], "stage": unit["stage"],
			"ultNeed": unit["ultNeed"], "elite": unit["elite"], "type": unit["type"],
		})
	var last_stage: int = 0
	for unit: Dictionary in units:
		last_stage = maxi(last_stage, int(unit["stage"]))
	return {
		"cfg": cfg, "rules": rules, "units": units, "spawnInfo": spawn_info, "lastStage": last_stage,
		"stage": 0, "stageStart": 0, "events": [], "tick": 0, "winner": "", "blastFront": true, "enraged": false,
		"dirty": {}, "flushed": false, "critRng": Rng.new(int(rules.get("critSeed", 0))),
	}


static func battle_over(sim: Dictionary) -> bool:
	return not str(sim["winner"]).is_empty() or int(sim["tick"]) >= int(sim["cfg"]["maxTicks"])


## 끝난 전투의 결과. left = 전장에 나와 살아남은 적(우두머리 · 졸병 수).
static func battle_result(sim: Dictionary) -> Dictionary:
	var left: Dictionary = {"leaders": 0, "minions": 0}
	for unit: Dictionary in sim["units"]:
		if unit["side"] == "enemy" and unit["hp"] > 0 and unit["active"]:
			left["leaders" if unit["kind"] == "dragon" else "minions"] += 1
	var winner: String = sim["winner"]
	return {
		"winner": "enemy" if winner.is_empty() else winner,
		"ticks": sim["tick"], "events": sim["events"], "units": sim["spawnInfo"], "left": left,
	}


## 수동 모드에서 지금 궁극기를 쏠 수 있는(게이지가 가득 찬) 우리 드래곤의 id들.
static func ready_ults(sim: Dictionary) -> Array:
	var ready: Array = []
	for unit: Dictionary in sim["units"]:
		if unit["side"] == "ally" and unit["kind"] == "dragon" and unit["hp"] > 0 and int(unit["ultNeed"]) > 0 \
				and int(unit["charge"]) >= int(unit["ultNeed"]) and not unit["armed"]:
			ready.append(unit["id"])
	return ready


## 한 틱 진행하고 이 틱에 생긴 사건들을 돌려준다. arm = 이번 틱에 궁극기를 쏘라고 한 드래곤의 id들(수동 모드에서만 듣는다).
static func step_battle(sim: Dictionary, arm: Array = []) -> Array:
	if battle_over(sim):
		return []
	var cfg: Dictionary = sim["cfg"]
	var rules: Dictionary = sim["rules"]
	var field: Dictionary = cfg["field"]
	var units: Array = sim["units"]
	var events: Array = sim["events"]
	var first_event: int = events.size()
	var last_stage: int = sim["lastStage"]
	var stage: int = sim["stage"]
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
	var crit_rng: Rng = sim["critRng"]
	var abilities: Dictionary = cfg.get("abilities", {})
	## 유물 "매의 눈": 후열에 선 우리 드래곤은 줄 감쇠를 받지 않는다.
	var keen_back: bool = bool(rules.get("backRowNoLane", false))
	var manual: bool = bool(rules.get("manualUlt", false))
	## 원소 시너지 규칙 효과(우리 편만): 폭발 · 얼림 · 연쇄 · 중독 · 방벽 · 흡수.
	var syn: Dictionary = rules.get("synergy", {})
	var enraged: bool = sim["enraged"]
	var dirty: Dictionary = sim["dirty"]
	var winner: String = ""
	sim["tick"] = int(sim["tick"]) + 1
	var tick: int = sim["tick"]
	## 수동 궁극기: 게이지가 가득 찬 우리 드래곤을 장전한다. 바로 다음 공격이 궁극기가 되고, 기다리지 않게 공격 차례를 당긴다.
	if manual:
		for id: Variant in arm:
			## 숫자가 아닌 값이나 범위를 벗어난 id는 무시한다.
			if not (id is int or (id is float and floorf(id) == id)) or int(id) < 0 or int(id) >= units.size():
				continue
			var shooter: Dictionary = units[int(id)]
			if shooter["side"] == "ally" and shooter["kind"] == "dragon" and shooter["hp"] > 0 \
					and int(shooter["ultNeed"]) > 0 and int(shooter["charge"]) >= int(shooter["ultNeed"]):
				shooter["armed"] = true
				shooter["timer"] = maxi(int(shooter["timer"]), int(shooter["cd"]) - 1)
	if stage < last_stage:
		var cleared: bool = true
		for unit: Dictionary in units:
			if unit["side"] == "enemy" and unit["active"] and unit["hp"] > 0:
				cleared = false
				break
		if cleared or (stage_ticks > 0 and tick - int(sim["stageStart"]) >= stage_ticks):
			stage += 1
			sim["stage"] = stage
			sim["stageStart"] = tick
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
		var front: bool = sim["blastFront"]
		sim["blastFront"] = not front
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
		sim["enraged"] = true
		events.append({"tick": tick, "kind": "enrage"})
	if syn.has("venom") and _hazard_due(syn["venom"], tick):
		for unit: Dictionary in units:
			if unit["side"] == "enemy" and unit["hp"] > 0 and int(unit["venom"]) > 0:
				var venom: int = int(unit["venom"])
				unit["venom"] = 0
				unit["hp"] -= venom
				events.append({"tick": tick, "kind": "attack", "src": unit["venomSrc"], "dst": unit["id"], "dmg": venom, "mult": 100, "heal": 0, "via": "venom"})
				if unit["hp"] <= 0:
					_kill(units, unit, tick, "hit", events)
	if not _any_alive(units, "ally"):
		winner = "enemy"
	if winner.is_empty():

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
				var target: Variant = _strike_target(field, units, unit)
				if target == null:
					continue
				if not _can_hit(field, unit, target):
					unit["timer"] = unit["cd"]
					continue
				unit["timer"] = 0
				unit["chilled"] = false
				## 궁극기: 아군 드래곤은 공격할 때마다 게이지가 차고, 다 차면 가까운 적 여럿을 세게 친다.
				var victims: Array = [target]
				var power_pct: int = 100
				var is_ult: bool = false
				var need: int = int(unit["ultNeed"])
				if need > 0:
					## 수동 모드의 우리 드래곤: 게이지는 가득 찬 채로 기다리다가, 쏘라고 한 뒤의 공격이 궁극기가 된다.
					var fire: bool = false
					if manual and side == "ally":
						fire = bool(unit["armed"]) and int(unit["charge"]) >= need
						if not fire:
							unit["charge"] = mini(need, int(unit["charge"]) + 1)
					else:
						unit["charge"] += 1
						fire = int(unit["charge"]) >= need
					if fire:
						unit["charge"] = 0
						unit["armed"] = false
						is_ult = true
						power_pct = int(ultimate["powerPct"].get(unit["tier"], 100)) + int(unit["ultPower"])
						## 신화의 숨결: 궁극기가 한 마리를 더 친다.
						var extra_targets: int = _apct(abilities, unit) if unit["ability"] == "mythic" else 0
						victims = _nearest_many(field, units, unit, int(ultimate["targets"].get(unit["tier"], 1)) + extra_targets)
						events.append({"tick": tick, "kind": "ult", "src": unit["id"]})
				## 형태별 능력(보통 공격에만): 꿰뚫기는 같은 줄의 다음 적도, 연속 공격은 같은 적을 한 번 더.
				var strikes: Array = []
				for victim: Dictionary in victims:
					strikes.append([victim, 100, ""])
				var ability: String = unit["ability"]
				var ability_pct: int = 0 if ability.is_empty() or is_ult else _apct(abilities, unit)
				if ability_pct > 0 and ability == "pierce":
					var behind: Variant = _next_in_lane(field, units, unit, target)
					if behind != null:
						strikes.append([behind, ability_pct, "pierce"])
				elif ability_pct > 0 and ability == "twin":
					strikes.append([target, ability_pct, "twin"])
				for strike: Array in strikes:
					var victim: Dictionary = strike[0]
					var via: String = strike[2]
					if not via.is_empty() and victim["hp"] <= 0:
						continue
					var mult: int = element_mult(cfg, _primary(unit), _primary(victim))
					if side == "ally" and mult > 100:
						mult += strong_add
					var dmg: int = maxi(1, Rng.fdiv(int(unit["atk"]) * mult * power_pct * int(strike[1]), 1000000))
					var crit_chance: int = crit_pct + int(unit["critBonus"])
					var is_crit: bool = crit_chance > 0 and not is_ult and via.is_empty() and unit["kind"] == "dragon" and crit_rng.next_int(100) < crit_chance
					if is_crit:
						dmg = Rng.fdiv(dmg * int(crit["dmgPct"]), 100)
					if side == "enemy" and enraged:
						dmg = Rng.fdiv(dmg * int(enrage["atkPct"]), 100)
					## 줄 감쇠: 드래곤이 제 줄 밖을 치면 줄 거리만큼 약해진다(궁극기는 그대로).
					var lane_pct: int = 100
					if unit["kind"] == "dragon" and not is_ult and not (keen_back and side == "ally" and int(unit["slot"]) >= 3):
						lane_pct = _lane_pct(field, unit, victim)
						if lane_pct != 100:
							dmg = maxi(1, Rng.fdiv(dmg * lane_pct, 100))
					## 저격: 후열에 선 드래곤의 보통 공격이 더 세다.
					if int(unit["edge"]) > 0 and not is_ult:
						dmg = Rng.fdiv(dmg * (100 + int(unit["edge"])), 100)
					## 맞대결: 제 줄의 적을 칠 때 더 세다.
					if ability_pct > 0 and ability == "duel" and unit["lane"] == victim["lane"]:
						dmg = Rng.fdiv(dmg * (100 + ability_pct), 100)
					## 방패막: 같은 줄에 방패막 드래곤이 살아 있으면 다른 드래곤이 보통 공격을 덜 맞는다(궁극기는 그대로).
					var ward_pct: int = _warded(abilities, units, victim) if not is_ult and victim["kind"] == "dragon" else 0
					if ward_pct > 0:
						dmg = maxi(1, Rng.fdiv(dmg * (100 - mini(90, ward_pct)), 100))
					if int(victim["guard"]) > 0:
						dmg = maxi(1, Rng.fdiv(dmg * (100 - int(victim["guard"])), 100))
					## 방벽(강철 시너지): 호위가 살아 있는 우리 드래곤은 덜 맞는다.
					if side == "enemy" and syn.has("bulwark") and victim["kind"] == "dragon" and _has_escort(units, victim):
						dmg = maxi(1, Rng.fdiv(dmg * (100 - int(syn["bulwark"]["pct"])), 100))
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
					if lane_pct != 100:
						hit["lane"] = lane_pct
					if not via.is_empty():
						hit["via"] = via
					if ward_pct > 0:
						hit["ward"] = true
					events.append(hit)
					if victim["hp"] <= 0:
						_kill(units, victim, tick, "hit", events)
					## 시너지 규칙 효과는 우리 드래곤의 보통 공격(추가타 · 궁극기 제외)에서만 일어난다.
					if side == "ally" and not syn.is_empty() and unit["kind"] == "dragon" and via.is_empty() and not is_ult:
						_synergy_on_hit(syn, units, unit, victim, dmg, tick, events)
				if side == "ally" and syn.has("chain") and unit["kind"] == "dragon" and not is_ult and "lightning" in unit["elements"]:
					_chain(cfg, syn["chain"], units, unit, target, tick, events)
				## 돌봄: 공격할 때마다 제 줄·옆줄에서 가장 다친 아군 드래곤을 고친다.
				if ability_pct > 0 and ability == "mend":
					var patient: Variant = _most_hurt(units, unit)
					if patient != null:
						var mend: int = Rng.fdiv(int(unit["atk"]) * ability_pct, 100)
						if side == "ally" and heal_cut_pct != 0 and tick >= heal_cut_from:
							mend = Rng.fdiv(mend * (100 - heal_cut_pct), 100)
						mend = mini(mend, int(patient["maxHp"]) - int(patient["hp"]))
						if mend > 0:
							patient["hp"] += mend
							events.append({"tick": tick, "kind": "heal", "src": unit["id"], "dst": patient["id"], "amount": mend})

		if syn.has("siphon"):
			_siphon(syn["siphon"], units, events, first_event, tick)
		if pos_every > 0 and tick % pos_every == 0 and not dirty.is_empty():
			_record_pos(units, dirty, tick, events)
			dirty.clear()
		if not _any_alive(units, "enemy"):
			winner = "ally"
		elif not _any_alive(units, "ally"):
			winner = "enemy"

	sim["winner"] = winner
	if battle_over(sim) and not sim["flushed"]:
		sim["flushed"] = true
		if not dirty.is_empty():
			_record_pos(units, dirty, tick, events)
			dirty.clear()
	return events.slice(first_event)


static func _spawn(cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {}) -> Array:
	var slow_pct: int = int(rules.get("allySlowPct", 0))
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
			Rng.fdiv(int(unit["hp"]) * hp_scale, 100), int(unit["atk"]), _slowed(int(unit["cooldownTicks"]), slow_pct),
			int(field.get("dragonSpeed", 0)),
			slot % LANES, int(field["frontX"]) if slot < 3 else int(field["backX"]))
		dragon["slot"] = slot
		dragon["role"] = unit.get("role", "")
		dragon["ability"] = unit.get("ability", "")
		dragon["boost"] = int(unit.get("abilityBoost", 0))
		## 선봉은 전열에서, 저격은 후열에서 힘을 낸다.
		var stance_pct: int = _apct(cfg.get("abilities", {}), dragon)
		if dragon["ability"] == "ambush" and slot >= 3:
			dragon["edge"] = stance_pct
		dragon["range"] = _role_range(field, int(field.get("frontRange" if slot < 3 else "backRange", 0)), dragon["role"])
		dragon["lifesteal"] = int(unit["lifestealPct"])
		dragon["tier"] = unit.get("tier", "")
		dragon["ultNeed"] = int(cfg.get("ultimate", {}).get("chargeHits", {}).get(dragon["tier"], 0))
		if dragon["ultNeed"] > 0:
			dragon["ultNeed"] = maxi(2, int(dragon["ultNeed"]) - int(unit.get("ultCharge", 0)))
		dragon["ultPower"] = int(unit.get("ultPowerPct", 0))
		dragon["critBonus"] = int(unit.get("critPct", 0))
		dragon["guard"] = mini(60, int(unit.get("guardPct", 0)) + (stance_pct if dragon["ability"] == "vanguard" and slot < 3 else 0))
		units.append(dragon)
		var count: int = escort_count(cfg, unit)
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
		var foe_speed: int = int(item.get("speed", 0))
		if item["kind"] == "dragon":
			foe_speed = maxi(foe_speed, int(field.get("dragonSpeed", 0)))
		var foe: Dictionary = _make(units.size(), "enemy", item["kind"], item["id"], item["elements"],
			maxi(1, Rng.fdiv(int(item["hp"]) * hp_scale, 100)), int(item["atk"]), int(item["cooldownTicks"]), foe_speed,
			int(item["lane"]), int(item["x"]))
		if item["kind"] == "dragon":
			foe["role"] = item.get("role", "")
			foe["ability"] = item.get("ability", "")
			foe["tier"] = item.get("tier", "")
			## 지역 규칙 "적 우두머리도 궁극기를 쓴다".
			if bool(rules.get("enemyUlt", false)):
				foe["ultNeed"] = int(cfg.get("ultimate", {}).get("chargeHits", {}).get(foe["tier"], 0))
			var foe_pct: int = int(cfg.get("abilities", {}).get(foe["ability"], {}).get("pct", 0))
			if foe["ability"] == "vanguard":
				foe["guard"] = foe_pct
			elif foe["ability"] == "ambush":
				foe["edge"] = foe_pct
			foe["range"] = _role_range(field, int(field.get("leaderRange", 0)), foe["role"])
		foe["stage"] = int(item.get("stage", 0))
		foe["type"] = str(item.get("type", ""))
		foe["reach"] = int(item.get("reach", 0))
		foe["elite"] = bool(item.get("elite", false))
		foe["active"] = foe["stage"] == 0
		units.append(foe)
	## 함성: 같은 편·같은 줄에 함성 드래곤이 있으면 다른 드래곤의 공격이 빨라진다(겹치지 않는다).
	var rally_pct: int = int(cfg.get("abilities", {}).get("rally", {}).get("pct", 0))
	if rally_pct > 0:
		for unit: Dictionary in units:
			if unit["kind"] != "dragon" or not unit["active"]:
				continue
			## 함성 드래곤이 여럿이면 가장 센 함성 하나만 듣는다.
			var heard: int = 0
			for other: Dictionary in units:
				## 아직 나오지 않은 무리의 드래곤은 함성을 주지도 받지도 않는다.
				if other["ability"] == "rally" and other["active"] and other["kind"] == "dragon" and other["side"] == unit["side"] \
						and other["lane"] == unit["lane"] and other["id"] != unit["id"]:
					heard = maxi(heard, _apct(cfg.get("abilities", {}), other))
			if heard > 0:
				unit["cd"] = maxi(5, Rng.fdiv(int(unit["cd"]) * (100 - mini(90, heard)), 100))
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
		"ultPower": 0, "critBonus": 0, "guard": 0, "range": 0, "role": "", "ability": "", "edge": 0, "armed": false, "type": "", "reach": 0,
		"chilled": false, "venom": 0, "venomSrc": -1, "boost": 0,
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


## 누구에게 다가갈지. 사거리가 있는 드래곤은 제 줄의 적을 먼저 보고(가까운 순, 같으면 id),
## 제 줄이 비면 가로로 가장 가까운 적(같으면 가까운 줄, 그다음 id).
static func _target(field: Dictionary, units: Array, me: Dictionary) -> Variant:
	if me["kind"] != "dragon" or int(me["range"]) <= 0:
		return _nearest(field, units, me)
	var best: Variant = null
	var best_key: int = 0
	for other: Dictionary in units:
		if other["side"] == me["side"] or other["hp"] <= 0 or not other["active"]:
			continue
		var gap: int = absi(int(me["lane"]) - int(other["lane"]))
		## 제 줄이 늘 먼저, 그다음 가로 거리, 그다음 줄 거리.
		var key: int = (0 if gap == 0 else 1000000) + absi(int(me["x"]) - int(other["x"])) * 10 + gap
		if best == null or key < best_key:
			best = other
			best_key = key
	return best


## 지금 누구를 칠지. 사거리가 있는 드래곤은 닿는 적 가운데 제 줄 → 가까운 줄 → 가까운 순으로 고른다.
## 닿는 적이 없으면 다가가는 대상을 돌려준다(아직 못 친다).
static func _strike_target(field: Dictionary, units: Array, me: Dictionary) -> Variant:
	if me["kind"] != "dragon" or int(me["range"]) <= 0:
		return _nearest(field, units, me)
	var best: Variant = null
	var best_key: int = 0
	for other: Dictionary in units:
		if other["side"] == me["side"] or other["hp"] <= 0 or not other["active"]:
			continue
		var dx: int = absi(int(me["x"]) - int(other["x"]))
		if dx > int(me["range"]):
			continue
		var key: int = absi(int(me["lane"]) - int(other["lane"])) * 100000 + dx
		if best == null or key < best_key:
			best = other
			best_key = key
	return best if best != null else _target(field, units, me)


## 사거리에 역할 보너스를 더한다(사수는 더 멀리 쏜다). 사거리 규칙이 꺼져 있으면(0) 그대로 0.
static func _role_range(field: Dictionary, base: int, role: String) -> int:
	return base if base <= 0 else base + int(field.get("roleRangeAdd", {}).get(role, 0))


## 줄 거리(0·1·2)에 따른 피해 비율. 역할마다 표가 다를 수 있다(roleLanePct). 자료가 없으면 100.
static func _lane_pct(field: Dictionary, unit: Dictionary, target: Dictionary) -> int:
	var table: Array = field.get("roleLanePct", {}).get(unit["role"], field.get("crossLanePct", []))
	var gap: int = absi(int(unit["lane"]) - int(target["lane"]))
	return 100 if gap >= table.size() else int(table[gap])


## 꿰뚫기: target과 같은 줄에서 target 다음으로 가까운(가로 거리) 살아 있는 적. 내 사거리 안이어야 한다. 없으면 null.
static func _next_in_lane(field: Dictionary, units: Array, me: Dictionary, target: Dictionary) -> Variant:
	var best: Variant = null
	var best_d: int = 0
	for other: Dictionary in units:
		if other["side"] == me["side"] or other["hp"] <= 0 or not other["active"] or other["lane"] != target["lane"] or other["id"] == target["id"]:
			continue
		if not _can_hit(field, me, other):
			continue
		var d: int = absi(int(other["x"]) - int(target["x"]))
		if best == null or d < best_d:
			best = other
			best_d = d
	return best


## 방패막: victim과 같은 편·같은 줄에 살아 있는 다른 방패막 드래곤이 막아 주는 비율(%). 없으면 0, 여럿이면 가장 센 것.
static func _warded(abilities: Dictionary, units: Array, victim: Dictionary) -> int:
	var best: int = 0
	for other: Dictionary in units:
		if other["ability"] == "ward" and other["side"] == victim["side"] and other["lane"] == victim["lane"] \
				and other["id"] != victim["id"] and other["hp"] > 0 and other["active"] and other["kind"] == "dragon":
			best = maxi(best, _apct(abilities, other))
	return best


## 돌봄: 제 줄과 옆줄의 같은 편 드래곤 가운데 체력 비율이 가장 낮은(다친) 드래곤. 다친 드래곤이 없으면 null.
static func _most_hurt(units: Array, me: Dictionary) -> Variant:
	var best: Variant = null
	for other: Dictionary in units:
		if other["side"] != me["side"] or other["kind"] != "dragon" or other["hp"] <= 0 or not other["active"]:
			continue
		if int(other["hp"]) >= int(other["maxHp"]) or absi(int(other["lane"]) - int(me["lane"])) > 1:
			continue
		## hp/maxHp를 나눗셈 없이 견준다.
		if best == null or int(other["hp"]) * int(best["maxHp"]) < int(best["hp"]) * int(other["maxHp"]):
			best = other
	return best


## 방벽: 그 드래곤의 호위가 하나라도 살아 있는가.
static func _has_escort(units: Array, dragon: Dictionary) -> bool:
	for other: Dictionary in units:
		if other["owner"] == dragon["id"] and other["hp"] > 0:
			return true
	return false


## 얼림 · 중독 · 폭발: 우리 드래곤의 보통 공격 한 번이 맞은 뒤.
static func _synergy_on_hit(syn: Dictionary, units: Array, unit: Dictionary, victim: Dictionary, dmg: int, tick: int, events: Array) -> void:
	var elements: Array = unit["elements"]
	if syn.has("chill") and "ice" in elements and victim["hp"] > 0 and not victim["chilled"]:
		## 맞은 적의 다음 공격이 늦어진다. 그 적이 한 번 공격할 때까지 한 번만.
		## 막 공격해 타이머가 0이어도 온전히 늦도록 0 아래로 내려갈 수 있다.
		victim["timer"] = int(victim["timer"]) - int(syn["chill"]["ticks"])
		victim["chilled"] = true
	if syn.has("venom") and "poison" in elements and victim["hp"] > 0:
		victim["venom"] = int(victim["venom"]) + Rng.fdiv(dmg * int(syn["venom"]["pct"]), 100)
		victim["venomSrc"] = unit["id"]
	if syn.has("burst") and "fire" in elements and victim["hp"] <= 0:
		## 쓰러진 적이 터진다. 폭발로 쓰러진 적은 다시 터지지 않는다.
		var blast: int = maxi(1, Rng.fdiv(int(victim["maxHp"]) * int(syn["burst"]["pct"]), 100))
		for other: Dictionary in units:
			if other["side"] != victim["side"] or other["hp"] <= 0 or not other["active"] or other["lane"] != victim["lane"]:
				continue
			if absi(int(other["x"]) - int(victim["x"])) > int(syn["burst"]["radius"]):
				continue
			other["hp"] -= blast
			events.append({"tick": tick, "kind": "attack", "src": unit["id"], "dst": other["id"], "dmg": blast, "mult": 100, "heal": 0, "via": "burst"})
			if other["hp"] <= 0:
				_kill(units, other, tick, "hit", events)


## 연쇄(번개 시너지): 맞은 적의 옆줄에서 가로로 가장 가까운 적에게 튄다(같으면 줄 번호, 그다음 id).
static func _chain(cfg: Dictionary, chain: Dictionary, units: Array, unit: Dictionary, target: Dictionary, tick: int, events: Array) -> void:
	var best: Variant = null
	var best_key: int = 0
	for other: Dictionary in units:
		if other["side"] == unit["side"] or other["hp"] <= 0 or not other["active"]:
			continue
		if absi(int(other["lane"]) - int(target["lane"])) != 1:
			continue
		var key: int = absi(int(other["x"]) - int(target["x"])) * 10 + int(other["lane"])
		if best == null or key < best_key:
			best = other
			best_key = key
	if best == null:
		return
	var victim: Dictionary = best
	var mult: int = element_mult(cfg, _primary(unit), _primary(victim))
	var dmg: int = maxi(1, Rng.fdiv(int(unit["atk"]) * mult * int(chain["pct"]), 10000))
	if int(victim["guard"]) > 0:
		dmg = maxi(1, Rng.fdiv(dmg * (100 - int(victim["guard"])), 100))
	victim["hp"] -= dmg
	events.append({"tick": tick, "kind": "attack", "src": unit["id"], "dst": victim["id"], "dmg": dmg, "mult": mult, "heal": 0, "via": "chain"})
	if victim["hp"] <= 0:
		_kill(units, victim, tick, "hit", events)


## 흡수(심연 시너지): 이번 틱에 쓰러진 적 수만큼 우리 심연 드래곤의 궁극기 게이지가 찬다(가득 찬 채로 멈춘다).
static func _siphon(siphon: Dictionary, units: Array, events: Array, first_event: int, tick: int) -> void:
	var fallen: int = 0
	for i: int in range(first_event, events.size()):
		var event: Dictionary = events[i]
		if event["kind"] == "death" and units[int(event["id"])]["side"] == "enemy":
			fallen += 1
	if fallen == 0:
		return
	for unit: Dictionary in units:
		if unit["side"] != "ally" or unit["kind"] != "dragon" or unit["hp"] <= 0 or int(unit["ultNeed"]) <= 0 or "abyss" not in unit["elements"]:
			continue
		var before: int = unit["charge"]
		unit["charge"] = mini(int(unit["ultNeed"]), before + fallen * int(siphon["charge"]))
		if unit["charge"] != before:
			events.append({"tick": tick, "kind": "charge", "id": unit["id"], "charge": unit["charge"]})


## 걷는 유닛이 닿는 가로 거리: 궁병처럼 reach가 있으면 그 값, 없으면 근접 거리.
static func _reach(field: Dictionary, unit: Dictionary) -> int:
	return int(unit["reach"]) if int(unit["reach"]) > 0 else int(field["meleeRange"])


static func _can_hit(field: Dictionary, unit: Dictionary, target: Dictionary) -> bool:
	if unit["kind"] == "dragon":
		return int(unit["range"]) <= 0 or absi(int(unit["x"]) - int(target["x"])) <= int(unit["range"])
	return unit["lane"] == target["lane"] and absi(int(unit["x"]) - int(target["x"])) <= _reach(field, unit)


## 걷는 유닛 한 틱 이동. 움직였으면 true.
static func _step(field: Dictionary, units: Array, unit: Dictionary) -> bool:
	var target: Variant = _target(field, units, unit)
	if target == null or _can_hit(field, unit, target):
		unit["laneTimer"] = 0
		return false
	if unit["kind"] == "dragon":
		## 드래곤은 줄을 바꾸지 않는다. 사거리에 닿을 만큼만 다가간다.
		var gap: int = int(target["x"]) - int(unit["x"])
		unit["x"] += signi(gap) * mini(int(unit["speed"]), absi(gap) - int(unit["range"]))
		return true
	var moved: bool = false
	var dx: int = int(target["x"]) - int(unit["x"])
	## 다른 줄의 표적에게는 줄을 바꿀 수 있는 거리까지 다가간다. 멀리서 치는 졸병이 사거리 안이라고 멈추면 영영 못 친다.
	var melee: int = _reach(field, unit)
	if target["lane"] != unit["lane"]:
		melee = mini(melee, int(field["laneChangeRange"]))
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
