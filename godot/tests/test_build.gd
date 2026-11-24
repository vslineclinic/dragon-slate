extends TestCase

const Build = preload("res://godot/ui/build.gd")


func test_demo_overrides() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var demo: Dictionary = Build.apply(data, true)
	assert_eq(demo["waves"]["maxWave"], 10)
	assert_eq(demo["waves"]["bossPct"]["10"], 105)
	assert_eq(demo["waves"]["bossPct"]["5"], original["waves"]["bossPct"]["5"])
	assert_eq(Build.max_calamity(demo), 1)
	assert_eq(demo["calamity"].size(), 1)
	assert_eq(data, original)
	assert_eq(Build.apply(data, false), original)


func test_standard_run_is_twenty_waves_and_ends_on_a_boss() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var standard: Dictionary = Build.for_length(data, "standard")
	var waves: Dictionary = standard["waves"]
	assert_eq(waves["maxWave"], 20)
	assert_true(Waves.is_boss(waves, 20), "마지막 웨이브는 심판 보스")
	assert_true(not waves.has("standard"))
	for wave: int in waves["nestUnlockAfter"]:
		assert_true(wave < 20)
	assert_eq(waves["nestUnlockAfter"].size(), original["waves"]["nestUnlockAfter"].size(), "둥지는 끝까지 다 열린다")
	for key: String in waves["bossPct"]:
		assert_true(int(key) <= 20)
	for key: String in waves["elitePct"]:
		assert_true(int(key) <= 20 and not Waves.is_boss(waves, int(key)))
	assert_true(int(standard["battle"]["level"]["winXp"]) > int(original["battle"]["level"]["winXp"]), "짧은 판은 더 빨리 자란다")
	assert_eq(waves["basePower"], original["waves"]["basePower"])
	assert_eq(data, original, "원래 자료는 그대로")


func test_long_run_keeps_the_data_as_it_is() -> void:
	var data: Dictionary = GameData.load_all()
	assert_eq(Build.for_length(data, "long")["waves"]["maxWave"], 40)
	assert_true(Build.for_length(data, "long") == data)


func test_standard_run_can_be_played_to_the_end_by_the_bot() -> void:
	var Bot: GDScript = load("res://godot/tools/bot.gd")
	var data: Dictionary = Build.for_length(GameData.load_all(), "standard")
	var state: Dictionary = Run.create_run(data, 77, 0, Run.start_options(data, 77)[0]["id"])["state"]
	for step: int in range(3000):
		if state["phase"] in ["gameOver", "victory"]:
			break
		var result: Dictionary = Run.apply_command(data, state, Bot.choose(data, state))
		assert_true(result["events"].is_empty() or result["events"][0]["t"] != "rejected", "거절된 명령: %s" % str(result["events"]))
		state = result["state"]
		state["log"].clear()
	assert_true(state["phase"] in ["gameOver", "victory"])
	assert_true(int(state["wave"]) <= 20)


func test_changing_the_standard_run_does_not_leak_into_the_original() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var standard: Dictionary = Build.for_length(data, "standard")
	standard["waves"]["bossPct"]["5"] = 999
	standard["waves"]["nestUnlockAfter"].append(99)
	assert_eq(data, original)
