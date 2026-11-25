extends TestCase
## 판 자동 저장: 상태를 글(JSON)로 싸고 풀어도 같은 판이 이어진다. 못 읽는 저장은 버린다.

const Store = preload("res://godot/ui/store.gd")
const Bot = preload("res://godot/tools/bot.gd")
const PATH: String = "user://test_run_save.json"

var _data: Dictionary = GameData.load_all()


## 봇으로 몇 수 둔 판(드래곤 · 석판 · 유물이 조금 쌓인 상태).
func _played(seed: int, steps: int) -> Dictionary:
	var state: Dictionary = Run.create_run(_data, seed, 0, Run.start_options(_data, seed)[0]["id"])["state"]
	## 판이 끝나기 직전에서 멈춘다(끝난 판은 저장하지 않으므로).
	for step: int in range(steps):
		var next: Dictionary = Run.apply_command(_data, state, Bot.choose(_data, state))["state"]
		if next["phase"] in ["gameOver", "victory"]:
			break
		state = next
	return state


func test_packed_run_unpacks_to_the_same_state() -> void:
	var state: Dictionary = _played(21, 60)
	var text: String = Store.pack_run(state, "standard", false)
	var loaded: Dictionary = Store.unpack_run(text, _data, false)
	assert_eq(loaded.get("length"), "standard")
	assert_eq(Run.state_hash(loaded["state"]), Run.state_hash(state))
	assert_eq(loaded["state"]["log"], [], "명령 기록은 저장하지 않는다")


func test_a_loaded_run_plays_on_exactly_like_the_original() -> void:
	var state: Dictionary = _played(22, 40)
	var loaded: Dictionary = Store.unpack_run(Store.pack_run(state, "long", false), _data, false)["state"]
	for step: int in range(80):
		if state["phase"] in ["gameOver", "victory"]:
			break
		var command: Dictionary = Bot.choose(_data, state)
		assert_eq(Bot.choose(_data, loaded), command, "수 %d" % step)
		state = Run.apply_command(_data, state, command)["state"]
		loaded = Run.apply_command(_data, loaded, command)["state"]
	assert_eq(Run.state_hash(loaded), Run.state_hash(state))


func test_broken_or_foreign_saves_are_rejected() -> void:
	var state: Dictionary = _played(23, 20)
	var good: String = Store.pack_run(state, "standard", false)
	assert_eq(Store.unpack_run("", _data, false), {})
	assert_eq(Store.unpack_run("not json", _data, false), {})
	assert_eq(Store.unpack_run("[1, 2]", _data, false), {})
	assert_eq(Store.unpack_run(good, _data, true), {}, "정식판 저장은 데모판에서 열지 않는다")
	assert_eq(Store.unpack_run(good.replace("\"version\":%d" % Store.RUN_VERSION, "\"version\":0"), _data, false), {}, "옛 판 저장")
	var unknown: Dictionary = state.duplicate(true)
	unknown["bench"][0] = {"uid": 99, "speciesId": "no_such_dragon", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}
	assert_eq(Store.unpack_run(Store.pack_run(unknown, "standard", false), _data, false), {}, "모르는 종이 든 저장")
	var over: Dictionary = state.duplicate(true)
	over["phase"] = "gameOver"
	assert_eq(Store.unpack_run(Store.pack_run(over, "standard", false), _data, false), {}, "끝난 판은 이어 하지 않는다")


func test_store_writes_reads_and_clears_the_run_file() -> void:
	var store: Store = Store.new()
	store.clear_run(PATH)
	assert_eq(store.load_run(_data, PATH), {})
	var state: Dictionary = _played(24, 30)
	store.save_run(state, "long", PATH)
	var loaded: Dictionary = store.load_run(_data, PATH)
	assert_eq(loaded.get("length"), "long")
	assert_eq(Run.state_hash(loaded["state"]), Run.state_hash(state))
	store.clear_run(PATH)
	assert_eq(store.load_run(_data, PATH), {})
	assert_true(not FileAccess.file_exists(PATH))


func test_tools_can_switch_the_real_autosave_off() -> void:
	var store: Store = Store.new()
	var before: bool = FileAccess.file_exists(Store.RUN_PATH)
	var kept: String = FileAccess.get_file_as_string(Store.RUN_PATH) if before else ""
	Store.autosave_off = true
	store.save_run(_played(25, 10), "standard")
	store.clear_run()
	Store.autosave_off = false
	assert_eq(FileAccess.file_exists(Store.RUN_PATH), before, "실제 저장 파일은 그대로")
	if before:
		assert_eq(FileAccess.get_file_as_string(Store.RUN_PATH), kept)


func test_saves_that_could_not_go_on_are_rejected() -> void:
	var state: Dictionary = _played(26, 20)
	var late: Dictionary = state.duplicate(true)
	late["wave"] = int(_data["waves"]["maxWave"]) + 1
	assert_eq(Store.unpack_run(Store.pack_run(late, "long", false), _data, false), {}, "마지막 웨이브를 넘은 저장")
	var cases: Dictionary = {
		"reward": {"rewardChoices": []}, "relic": {"relicChoices": []}, "fork": {"forkChoices": []},
		"slab": {"runePending": null}, "pick": {"grid": null},
	}
	for phase: String in cases:
		var broken: Dictionary = state.duplicate(true)
		broken["phase"] = phase
		broken.merge(cases[phase], true)
		assert_eq(Store.unpack_run(Store.pack_run(broken, "long", false), _data, false), {}, phase)


func test_demo_and_full_game_keep_separate_save_files() -> void:
	assert_true(Store.RUN_PATH != Store.DEMO_RUN_PATH)
	assert_eq(Store.run_path(), Store.DEMO_RUN_PATH if OS.has_feature("demo") else Store.RUN_PATH)


func test_saving_leaves_no_draft_file_behind() -> void:
	var store: Store = Store.new()
	store.save_run(_played(27, 10), "standard", PATH)
	assert_true(FileAccess.file_exists(PATH))
	assert_true(not FileAccess.file_exists(PATH + ".tmp"))
	store.save_run(_played(27, 20), "standard", PATH)
	assert_true(not store.load_run(_data, PATH).is_empty(), "덮어써도 읽힌다")
	store.clear_run(PATH)


func test_stars_follow_the_lives_lost() -> void:
	assert_eq(Store.stars_for({"phase": "gameOver", "livesLost": 0}), 0)
	assert_eq(Store.stars_for({"phase": "victory", "livesLost": 0}), 3)
	assert_eq(Store.stars_for({"phase": "victory", "livesLost": 1}), 2)
	assert_eq(Store.stars_for({"phase": "victory", "livesLost": 4}), 1)
