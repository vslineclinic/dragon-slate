extends RefCounted

const MAX_WAVE: int = 10
const MAX_CALAMITY: int = 1
const FINAL_BOSS_PCT: int = 105


static func load_data() -> Dictionary:
	return apply(GameData.load_all(), OS.has_feature("demo"))


static func apply(data: Dictionary, demo: bool) -> Dictionary:
	if not demo:
		return data
	var result: Dictionary = data.duplicate(true)
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
	if length != "standard" or data["waves"].get("standard", {}).is_empty():
		return data
	var result: Dictionary = data.duplicate(true)
	## 깊은 복사본에서 꺼낸다: 돌려준 자료를 고쳐도 원래 자료의 standard가 바뀌지 않는다.
	var standard: Dictionary = result["waves"]["standard"]
	result["waves"].erase("standard")
	for key: String in standard.get("waves", {}):
		result["waves"][key] = standard["waves"][key]
	for key: String in standard.get("squad", {}):
		result["waves"]["squad"][key] = standard["squad"][key]
	for key: String in standard.get("level", {}):
		result["battle"]["level"][key] = standard["level"][key]
	return result


static func max_calamity(data: Dictionary) -> int:
	var highest: int = 0
	for calamity: Dictionary in data["calamity"]:
		highest = maxi(highest, calamity["level"])
	return highest
