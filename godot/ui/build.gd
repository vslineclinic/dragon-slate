extends RefCounted

const MAX_WAVE: int = 10
const MAX_CALAMITY: int = 1
const FINAL_BOSS_PCT: int = 520


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


static func max_calamity(data: Dictionary) -> int:
	var highest: int = 0
	for calamity: Dictionary in data["calamity"]:
		highest = maxi(highest, calamity["level"])
	return highest
