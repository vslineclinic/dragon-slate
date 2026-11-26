extends TestCase

const Build = preload("res://godot/ui/build.gd")


func test_demo_overrides() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var demo: Dictionary = Build.apply(data, true)
	assert_eq(demo["waves"]["maxWave"], 10)
	## 데모판은 1지역(10웨이브)과 같은 난이도.
	assert_eq(demo["waves"]["bossPct"], Build.for_stage(original, 0)["waves"]["bossPct"])
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


func test_long_run_is_forty_waves_with_its_own_growth() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var long_run: Dictionary = Build.for_length(data, "long")
	assert_eq(long_run["waves"]["maxWave"], 40)
	assert_true(not long_run["waves"].has("long") and not long_run["waves"].has("standard"))
	assert_eq(long_run["waves"]["nestUnlockAfter"], original["waves"]["long"]["waves"]["nestUnlockAfter"])
	assert_eq(long_run["battle"]["level"]["evolveLevel"], original["waves"]["long"]["level"]["evolveLevel"])
	assert_true(Waves.is_boss(long_run["waves"], 40))
	assert_eq(data, original)


func test_demo_is_the_first_ten_waves_of_the_first_region() -> void:
	var data: Dictionary = GameData.load_all()
	var demo: Dictionary = Build.apply(data, true)
	var first: Dictionary = Build.for_stage(data, 0)
	assert_eq(demo["waves"]["maxWave"], 10)
	assert_eq(demo["waves"]["stageName"], first["waves"]["stageName"])
	assert_eq(demo["waves"]["nestUnlockAfter"], first["waves"]["nestUnlockAfter"])
	assert_eq(demo["battle"]["level"]["evolveLevel"], first["battle"]["level"]["evolveLevel"])
	assert_eq(first["waves"]["maxWave"], 10, "1지역은 익히는 곳이라 10웨이브")
	assert_eq(demo["waves"]["bossPct"], first["waves"]["bossPct"], "데모판은 1지역과 같은 난이도")
	assert_eq(first["bosses"].map(func(b: Dictionary) -> int: return int(b["wave"])), [5, 10])


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


func test_there_are_four_regions_and_each_has_its_own_bosses() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	assert_eq(data["stages"].size(), 4)
	var boss_sets: Dictionary = {}
	for index: int in range(4):
		var stage: Dictionary = Build.for_stage(data, index)
		var waves: Dictionary = stage["waves"]
		## 1지역은 익히는 곳이라 10웨이브, 나머지는 20웨이브.
		var last: int = 10 if index == 0 else 20
		assert_eq([waves["maxWave"], waves["stage"]], [last, index])
		assert_true(not str(waves["stageName"]).is_empty() and not str(waves["stageRule"]).is_empty())
		assert_true(ResourceLoader.exists("res://assets/backgrounds/%s.png" % waves["scene"]), str(waves["scene"]))
		var names: Array = []
		for wave: int in range(5, last + 1, 5):
			var boss: Variant = Run._boss_spec(stage, wave)
			assert_true(boss != null, "지역 %d의 %d웨이브 보스" % [index, wave])
			if boss != null:
				names.append(boss["id"] if boss.has("id") else boss["nameKo"])
		assert_eq(stage["bosses"].size(), last / 5)
		boss_sets[str(names)] = true
	assert_eq(boss_sets.size(), 4, "지역마다 보스 구성이 다르다")
	assert_true(Build.for_stage(data, 3)["waves"]["battleRules"].get("enemyUlt", false))
	assert_eq(int(Build.for_stage(data, 1)["waves"].get("fogLanes", 0)), 1)
	assert_eq(data, original, "원래 자료는 그대로")
	assert_eq(Build.for_stage(data, 9)["waves"]["maxWave"], 20, "없는 지역이면 기본 원정")
	assert_eq(Build.for_mode(data, "stage:2")["waves"]["stage"], 2)
	assert_eq(Build.for_mode(data, "long")["waves"]["maxWave"], 40)


func test_region_rules_reach_the_battle() -> void:
	var data: Dictionary = Build.for_stage(GameData.load_all(), 3)
	var state: Dictionary = Run.create_run(data, 4)["state"]
	state["phase"] = "manage"
	state["nest"][0] = {"uid": 1, "speciesId": "fire_drake", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 1, "xp": 0}
	assert_true(Run.battle_setup(data, state)["rules"].get("enemyUlt", false))
	var volcano: Dictionary = Build.for_stage(GameData.load_all(), 2)
	assert_true(Run.battle_setup(volcano, state)["rules"].has("rowBlast"))


func test_every_region_can_be_played_to_the_end_by_the_bot_with_a_carried_dragon() -> void:
	var Bot: GDScript = load("res://godot/tools/bot.gd")
	for index: int in range(4):
		var data: Dictionary = Build.for_stage(GameData.load_all(), index)
		var carry: Dictionary = {} if index == 0 else {"speciesId": "fire_god", "traits": []}
		var state: Dictionary = Run.create_run(data, 90 + index, 0, Run.start_options(data, 90 + index)[0]["id"], carry)["state"]
		for step: int in range(3000):
			if state["phase"] in ["gameOver", "victory"]:
				break
			var result: Dictionary = Run.apply_command(data, state, Bot.choose(data, state))
			assert_true(result["events"].is_empty() or result["events"][0]["t"] != "rejected", "지역 %d 거절된 명령: %s" % [index, str(result["events"])])
			state = result["state"]
			state["log"].clear()
		assert_true(state["phase"] in ["gameOver", "victory"], "지역 %d" % index)
