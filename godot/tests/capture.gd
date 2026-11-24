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
	## 타이틀은 첫 실행 때 창을 화면 가운데로 옮기므로 다시 화면 밖으로 보낸다.
	await process_frame
	DisplayServer.window_set_size(Vector2i(int(args[3]) if args.size() > 3 else 1280, 720))
	DisplayServer.window_set_position(Vector2i(-4000, -4000))
	for i in 30:
		await process_frame
	if mode != "" and scene.get("controller") != null:
		var tut = scene.get("_tutorial")
		if tut != null and tut.has_method("finish"):
			tut.call("finish")
		var ctl = scene.get("controller")
		## 시작 묶음 화면은 "start" 모드에서만 본다. 다른 모드는 기본 묶음으로 바로 시작.
		scene.set("_start_open", false)
		ctl.restart(12, 0)
		ctl.busy = false
		for i in 10:
			await process_frame
		if mode == "start":
			scene.set("_start_open", true)
			scene.call("_render", [], ctl.state)
			for i in 50:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png(out)
			print("saved ", out)
			quit()
			return
		ctl.dispatch({"type": "spin"})
		for i in (12 if mode == "spinmid" else 90):
			await process_frame
		if mode in ["manage", "battle", "battle-late", "crit", "ult", "reward", "skills", "transmute", "slab", "erase", "synergy", "dex", "dexpick", "dexmixed", "relic", "levels", "fork", "result"]:
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
		if mode in ["battle", "battle-late", "crit", "ult", "reward"]:
			if mode == "crit":
				ctl.data["battle"]["crit"]["pct"] = 100
			if mode == "ult":
				for tier in ctl.data["battle"]["ultimate"]["chargeHits"]:
					ctl.data["battle"]["ultimate"]["chargeHits"][tier] = 1
			ctl.dispatch({"type": "startBattle"})
			for i in (50 if mode == "battle" else (int(args[4]) if args.size() > 4 else 160)):
				await process_frame
		if mode == "reward":
			scene.get("_battle").call("_skip_playback")
			for i in 120:
				await process_frame
		if mode == "synergy":
			var ids: Array = ["fire_drake", "fire_wyvern", "ice_drake"]
			for slot in range(3):
				ctl.state["nest"][slot] = {"uid": 900 + slot, "speciesId": ids[slot], "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0}
			scene.call("_render", [], ctl.state)
			for i in 10:
				await process_frame
		if mode in ["dex", "dexpick", "dexmixed", "relic", "levels", "fork", "result"]:
			var team: Array = [["fafnir", 7, 3], ["fire_whelp", 4, 1], ["zhulong", 11, 0]]
			for slot in range(3):
				ctl.state["nest"][slot] = {"uid": 900 + slot, "speciesId": team[slot][0], "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": team[slot][2], "level": team[slot][1], "xp": 3}
			ctl.state["relics"] = ["sword", "dice"]
			if mode == "relic":
				ctl.state["phase"] = "relic"
				ctl.state["relicChoices"] = ["shell", "horn", "tome"]
			if mode == "fork":
				ctl.state["phase"] = "fork"
				ctl.state["forkChoices"] = ["elite", "rest", "merchant"]
			scene.call("_render", [], ctl.state)
			if mode == "result":
				ctl.state["discovered"] = ["fafnir", "zhulong", "fire_whelp"]
				ctl.state["phase"] = "victory"
				scene.call("_show_result", ctl.state)
			if mode in ["dex", "dexpick", "dexmixed"]:
				scene.call("_open_dex")
				var dex: Node = scene.get_child(scene.get_child_count() - 1)
				if mode == "dexpick":
					dex.call("_show_detail", ctl.data["dragons"]["zhulong"])
				if mode == "dexmixed":
					dex.call("_show_page", "mixed")
			for i in 30:
				await process_frame
		if mode in ["slab", "erase"]:
			ctl.state["phase"] = "slab"
			ctl.state["runePending"] = "fire" if mode == "slab" else "erase"
			ctl.state["slab"][2] = "fire"
			scene.call("_render", [], ctl.state)
			for i in 40:
				await process_frame
		if mode == "transmute":
			ctl.state["items"] = {"transmute": 2}
			for slot in range(3):
				if ctl.state["nest"][slot] != null:
					scene.call("_render", [], ctl.state)
					scene.call("_open_skills", {"zone": "nest", "index": slot})
					var overlay = scene.get_child(scene.get_child_count() - 1)
					if args.size() > 4:
						overlay.call("_toggle_transmute")
					break
			for i in 20:
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
