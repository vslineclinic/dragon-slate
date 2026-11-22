class_name Calamity
extends RefCounted

const NONE: Dictionary = {
	"enemyPowerPct": 0,
	"bossPowerPct": 0,
	"winManaPct": 0,
	"rerollCostAdd": 0,
	"startLivesAdd": 0,
}


## 선택한 단계까지의 수정치를 누적한다.
static func mods(data: Dictionary, level: int) -> Dictionary:
	var result: Dictionary = NONE.duplicate()
	for entry: Dictionary in data["calamity"]:
		if entry["level"] > level:
			continue
		for key: String in NONE:
			var value: Variant = entry.get(key)
			if value != null:
				result[key] += int(value)
	return result
