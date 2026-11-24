extends RefCounted

const MAX_WAVE: int = 10
const MAX_CALAMITY: int = 1
const FINAL_BOSS_PCT: int = 105


static func load_data() -> Dictionary:
	return apply(GameData.load_all(), OS.has_feature("demo"))


## 데모판: 첫 지역(잊힌 평원)의 처음 10웨이브. 지역 자료가 없으면 원래 자료의 처음 10웨이브.
static func apply(data: Dictionary, demo: bool) -> Dictionary:
	if not demo:
		return data
	var result: Dictionary = for_stage(data, 0).duplicate(true) if not data.get("stages", []).is_empty() else data.duplicate(true)
	result["waves"]["maxWave"] = MAX_WAVE
	result["waves"]["bossPct"][str(MAX_WAVE)] = FINAL_BOSS_PCT
	var levels: Array = []
	for calamity: Dictionary in result["calamity"]:
		if calamity["level"] <= MAX_CALAMITY:
			levels.append(calamity)
	result["calamity"] = levels
	return result


## 원정 길이. "standard" = 기본 원정(waves.standard의 값으로 덮어쓴 20웨이브), 그 밖은 긴 원정(자료 그대로 40웨이브).
## waves.standard: {"waves": {...}, "squad": {...}, "level": {...}} — 적힌 키만 바꾼다.
static func for_length(data: Dictionary, length: String) -> Dictionary:
	## 긴 원정: waves.long이 있으면 그 값으로 덮어쓴다(성장 속도 등). 없으면 자료 그대로.
	if length == "long" and not data["waves"].get("long", {}).is_empty():
		var long_run: Dictionary = data.duplicate(true)
		var extra: Dictionary = long_run["waves"]["long"]
		long_run["waves"].erase("long")
		long_run["waves"].erase("standard")
		for key: String in extra.get("waves", {}):
			long_run["waves"][key] = extra["waves"][key]
		for key: String in extra.get("squad", {}):
			long_run["waves"]["squad"][key] = extra["squad"][key]
		for key: String in extra.get("level", {}):
			long_run["battle"]["level"][key] = extra["level"][key]
		return long_run
	if length != "standard" or data["waves"].get("standard", {}).is_empty():
		return data
	var result: Dictionary = data.duplicate(true)
	## 깊은 복사본에서 꺼낸다: 돌려준 자료를 고쳐도 원래 자료의 standard가 바뀌지 않는다.
	var standard: Dictionary = result["waves"]["standard"]
	result["waves"].erase("standard")
	result["waves"].erase("long")
	for key: String in standard.get("waves", {}):
		result["waves"][key] = standard["waves"][key]
	for key: String in standard.get("squad", {}):
		result["waves"]["squad"][key] = standard["squad"][key]
	for key: String in standard.get("level", {}):
		result["battle"]["level"][key] = standard["level"][key]
	return result


## 지역(스테이지) index번째의 자료: 기본 원정(20웨이브)에 그 지역의 배경 · 규칙 · 보스 · 수치를 덮어쓴다.
## 없는 번호면 기본 원정 그대로.
static func for_stage(data: Dictionary, index: int) -> Dictionary:
	var base: Dictionary = for_length(data, "standard")
	var stages: Array = data.get("stages", [])
	if index < 0 or index >= stages.size():
		return base
	var result: Dictionary = base.duplicate(true)
	var stage: Dictionary = result["stages"][index]
	var waves: Dictionary = result["waves"]
	waves["stage"] = index
	waves["stageName"] = stage.get("nameKo", "")
	waves["stageRule"] = stage.get("ruleKo", "")
	waves["scene"] = stage.get("scene", "")
	waves["ambience"] = stage.get("ambience", "")
	waves["battleRules"] = stage.get("battleRules", {})
	for key: String in stage.get("waves", {}):
		waves[key] = stage["waves"][key]
	for key: String in stage.get("squad", {}):
		waves["squad"][key] = stage["squad"][key]
	## 보스: 그 지역이 고른 보스 넷을 5 · 10 · 15 · 20웨이브에 세운다.
	var picked: Array = []
	var from: Array = stage.get("bosses", [])
	for k: int in range(from.size()):
		for boss: Dictionary in result["bosses"]:
			if int(boss["wave"]) == int(from[k]):
				var copy: Dictionary = boss.duplicate(true)
				copy["wave"] = 5 * (k + 1)
				picked.append(copy)
				break
	if not picked.is_empty():
		result["bosses"] = picked
	return result


## 저장 글에 적는 원정 이름("stage:2" · "long" · "standard")에 맞는 자료.
static func for_mode(data: Dictionary, mode: String) -> Dictionary:
	if mode.begins_with("stage:"):
		return for_stage(data, int(mode.substr(6)))
	return for_length(data, mode)


static func max_calamity(data: Dictionary) -> int:
	var highest: int = 0
	for calamity: Dictionary in data["calamity"]:
		highest = maxi(highest, calamity["level"])
	return highest
