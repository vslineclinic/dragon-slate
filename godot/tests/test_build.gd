extends TestCase

const Build = preload("res://godot/ui/build.gd")


func test_demo_overrides() -> void:
	var data: Dictionary = GameData.load_all()
	var original: Dictionary = data.duplicate(true)
	var demo: Dictionary = Build.apply(data, true)
	assert_eq(demo["waves"]["maxWave"], 10)
	assert_eq(demo["waves"]["bossPct"]["10"], 520)
	assert_eq(demo["waves"]["bossPct"]["5"], original["waves"]["bossPct"]["5"])
	assert_eq(Build.max_calamity(demo), 1)
	assert_eq(demo["calamity"].size(), 1)
	assert_eq(data, original)
	assert_eq(Build.apply(data, false), original)
