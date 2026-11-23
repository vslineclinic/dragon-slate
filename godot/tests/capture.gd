extends SceneTree
## 화면 확인용 캡처(테스트 아님): 장면을 띄우고 몇 프레임 뒤 PNG로 저장하고 종료.
## godot --path . --position -4000,-4000 --script res://godot/tests/capture.gd -- <장면> <저장경로> [모드] [폭]
## 모드: (없음) | spin | spinmid | manage | battle | battle-late

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://godot/scenes/main.tscn"
	var out: String = args[1] if args.size() > 1 else "user://capture.png"
	var mode: String = args[2] if args.size() > 2 else ""
	if args.size() > 3:
		DisplayServer.window_set_size(Vector2i(int(args[3]), 720))
		await process_frame
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 30:
		await process_frame
	if mode != "" and scene.get("controller") != null:
		var tut = scene.get("_tutorial")
		if tut != null and tut.has_method("finish"):
			tut.call("finish")
		var ctl = scene.get("controller")
		ctl.restart(12, 0)
		for i in 10:
			await process_frame
		ctl.dispatch({"type": "spin"})
		for i in (12 if mode == "spinmid" else 90):
			await process_frame
		if mode in ["manage", "battle", "battle-late", "reward", "skills"]:
			ctl.busy = false
			var offers: Array = Slot.offers_from(ctl.data, ctl.state["grid"])
			var pick: int = 0
			for i in range(offers.size()):
				if offers[i]["kind"] == "egg":
					pick = i
					break
			ctl.dispatch({"type": "pick", "index": pick})
			for i in 10:
				await process_frame
			for b in range(4):
				if ctl.state["bench"][b] != null:
					ctl.dispatch({"type": "move", "from": {"zone": "bench", "index": b}, "to": {"zone": "nest", "index": b % 3}})
			for i in 20:
				await process_frame
		if mode in ["battle", "battle-late", "reward"]:
			ctl.dispatch({"type": "startBattle"})
			for i in (50 if mode == "battle" else 160):
				await process_frame
		if mode == "reward":
			scene.get("_battle").call("_skip_playback")
			for i in 120:
				await process_frame
		if mode == "skills":
			for slot in range(3):
				if ctl.state["nest"][slot] != null:
					ctl.state["nest"][slot]["skillPoints"] = 3
					ctl.state["nest"][slot]["skills"] = {"fang": 2}
					scene.call("_render", [], ctl.state)
					scene.call("_open_skills", {"zone": "nest", "index": slot})
					break
			for i in 20:
				await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
