class_name GameData
extends RefCounted

const ELEMENTS: Array = ["fire", "ice", "lightning", "poison", "steel", "abyss"]
const _FILES: Array = [
	"dragons", "traits", "recipes", "slot", "waves", "battle", "rewards", "bosses", "calamity", "minions", "skills", "synergies", "relics",
]


static func load_all() -> Dictionary:
	var raw: Dictionary = {}
	for key: String in _FILES:
		var path: String = "res://data/" + key + ".json"
		if not FileAccess.file_exists(path):
			raw[key] = []
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("파일을 열 수 없음: " + path)
			return {}
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) != OK:
			push_error("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
			return {}
		raw[key] = json.data
	return _from_raw(raw)


## 기본종이 있는 원소만 계약의 원소 순서대로 반환한다.
static func active_elements(data: Dictionary) -> Array:
	var used: Dictionary = {}
	for spec: Dictionary in data["dragons"].values():
		if spec["tier"] == "base" and not spec["elements"].is_empty():
			used[spec["elements"][0]] = true
	var active: Array = []
	for element: String in ELEMENTS:
		if used.has(element):
			active.append(element)
	return active


static func _from_raw(raw: Dictionary) -> Dictionary:
	var data: Dictionary = {}
	for key: String in _FILES:
		data[key] = _normalize_numbers(raw.get(key, []))

	var dragons: Dictionary = {}
	var traits: Dictionary = {}
	for spec: Dictionary in data["dragons"]:
		dragons[spec["id"]] = spec
	for trait_spec: Dictionary in data["traits"]:
		traits[trait_spec["id"]] = trait_spec

	for spec: Dictionary in data["dragons"]:
		if not traits.has(spec["traitId"]):
			push_error("dragon %s: unknown traitId %s" % [spec["id"], spec["traitId"]])
			return {}
	for recipe: Dictionary in data["recipes"]:
		for id: String in [recipe["a"], recipe["b"], recipe["result"]]:
			if not dragons.has(id):
				push_error("recipe %s+%s: unknown dragon id %s" % [recipe["a"], recipe["b"], id])
				return {}

	var minions: Dictionary = {}
	for spec: Variant in data["minions"]:
		minions[spec["id"]] = spec
	data["dragons"] = dragons
	data["traits"] = traits
	var skills: Dictionary = {}
	for spec: Variant in data["skills"]:
		skills[spec["id"]] = spec
	data["minions"] = minions
	data["skills"] = skills
	return data


## JSON 파서는 정수도 float로 읽으므로 규칙에 넘기기 전에 정수로 바꾼다.
static func _normalize_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var integer: int = int(value)
			if value == integer:
				return integer
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_normalize_numbers(item))
			return items
		TYPE_DICTIONARY:
			var fields: Dictionary = {}
			for key: Variant in value:
				fields[key] = _normalize_numbers(value[key])
			return fields
	return value
