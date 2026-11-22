extends TestCase
## Rng 가 TypeScript판(fixtures/rng.json)과 같은 수열을 내는지


func test_matches_typescript_sequences() -> void:
	var cases: Array = TestCase.load_json("res://godot/tests/fixtures/rng.json")
	for c in cases:
		var r := Rng.new(int(c["seed"]))
		var u32: Array = []
		for i in 20:
			u32.append(r.next_u32())
		assert_eq(u32, c["u32"], "next_u32 seed %d" % int(c["seed"]))
		var ints: Array = []
		for i in 20:
			ints.append(r.next_int(6))
		assert_eq(ints, c["ints"], "next_int seed %d" % int(c["seed"]))
		var picks: Array = []
		for i in 20:
			picks.append(r.pick_weighted(["a", "b", "c"], [1, 3, 6]))
		assert_eq(picks, c["picks"], "pick_weighted seed %d" % int(c["seed"]))
		assert_eq(r.state(), c["state"], "state seed %d" % int(c["seed"]))


func test_state_restore() -> void:
	var a := Rng.new(42)
	for i in 100:
		a.next_u32()
	var b := Rng.new(42, a.state())
	assert_eq(b.next_u32(), a.next_u32(), "복원한 상태에서 같은 다음 값")


func test_fdiv_matches_math_floor() -> void:
	assert_eq(Rng.fdiv(7, 2), 3)
	assert_eq(Rng.fdiv(-7, 2), -4)
	assert_eq(Rng.fdiv(-8, 2), -4)
	assert_eq(Rng.fdiv(400 * 80, 100), 320)
