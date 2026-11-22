extends TestCase


func test_spin_pick_move_battle() -> void:
	var script: GDScript = load("res://godot/ui/controller.gd")
	if script == null:
		assert_true(false, "게임 컨트롤러를 불러올 수 있어야 해요")
		return
	var ctl: RefCounted = script.new(GameData.load_all(), 42)
	var from: Dictionary = {"zone": "bench", "index": 0}
	var to: Dictionary = {"zone": "nest", "index": 0}
	assert_eq(ctl.dispatch({"type": "startBattle"}), [{"t": "rejected", "reason": "wrongPhase"}])
	ctl.dispatch({"type": "spin"})
	assert_eq(ctl.state["phase"], "pick")
	assert_eq(ctl.dispatch({"type": "pick", "index": 0}), [{"t": "rejected", "reason": "needDragon"}])
	var offers: Array = Slot.offers_from(ctl.data, ctl.state["grid"])
	var egg: int = offers.find_custom(func(offer: Dictionary) -> bool: return offer["kind"] == "egg")
	assert_true(egg >= 0, "시드 42의 첫 석판에 알이 있어야 해요")
	if egg < 0:
		return
	ctl.dispatch({"type": "pick", "index": egg})
	assert_eq(ctl.state["phase"], "manage")
	assert_eq(ctl.dispatch({"type": "startBattle"}), [{"t": "rejected", "reason": "nestEmpty"}])
	var locked: Dictionary = {"zone": "nest", "index": 5}
	assert_eq(
		ctl.dispatch({"type": "move", "from": from, "to": locked}),
		[{"t": "rejected", "reason": "slotLocked"}],
	)
	var dragon: Variant = ctl.state["bench"][0]
	assert_true(dragon != null, "고른 알이 대기칸에 들어와야 해요")
	ctl.dispatch({"type": "move", "from": from, "to": to})
	assert_eq(ctl.state["nest"][0], dragon)
	var events: Array = ctl.dispatch({"type": "startBattle"})
	assert_true(events.any(func(event: Dictionary) -> bool: return event["t"] == "battle"))


func test_busy_and_restart() -> void:
	var script: GDScript = load("res://godot/ui/controller.gd")
	if script == null:
		assert_true(false, "게임 컨트롤러를 불러올 수 있어야 해요")
		return
	var ctl: RefCounted = script.new(GameData.load_all(), 42)
	var changes: Array = []
	ctl.changed.connect(func(events: Array, state: Dictionary) -> void: changes.append([events, state]))
	ctl.busy = true
	assert_eq(ctl.dispatch({"type": "spin"}), [])
	assert_eq(changes.size(), 0)
	ctl.restart(7, 1)
	assert_eq(ctl.busy, false)
	assert_eq(ctl.state["seed"], 7)
	assert_eq(ctl.state["calamity"], 1)
	assert_eq(changes.size(), 1)
	if not changes.is_empty():
		assert_true(changes[0][0].any(func(event: Dictionary) -> bool: return event["t"] == "waveStart"))
		assert_eq(changes[0][1], ctl.state)
	ctl.restart(8)
	assert_eq(ctl.state["calamity"], 1)
