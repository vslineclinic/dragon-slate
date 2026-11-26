extends SceneTree
## 화면 확인용 캡처(테스트 아님): 장면을 띄우고 몇 프레임 뒤 PNG로 저장하고 종료.
## godot --path . --position -4000,-4000 --script res://godot/tests/capture.gd -- <장면> <저장경로> [모드] [폭]
## 모드: (없음) | spin | spinmid | manage | battle | battle-late

func _init() -> void:
	## 사용자가 하던 판의 자동 저장을 건드리지 않는다.
	load("res://godot/ui/store.gd").set("autosave_off", true)
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
		if mode == "offer":
			## 추천이 붙은 알 카드를 보려고, 나온 알과 같은 종을 대기칸에 미리 둔다(합치면 진화 → 추천).
			ctl.busy = false
			for offer in Slot.offers_from(ctl.data, ctl.state["grid"]):
				if offer["kind"] == "egg":
					ctl.state["bench"][0] = {"uid": 950, "speciesId": offer["speciesId"], "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 5, "xp": 0}
					break
			## 대기칸이 찬 모습도 함께 본다.
			for slot in range(1, 4):
				ctl.state["bench"][slot] = {"uid": 951 + slot, "speciesId": ["ice_wyvern", "poison_horned", "abyss_sage"][slot - 1], "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 1, "level": 2, "xp": 0}
			scene.call("_render", [], ctl.state)
			for i in 20:
				await process_frame
		if mode in ["nudgebuy", "nudgepoor"]:
			## 무료 밀기를 다 쓴 뒤: 밀기 단추에 값이 보인다. nudgepoor는 마력이 모자라 눌리지 않는 모습.
			ctl.busy = false
			ctl.state["nudgesLeft"] = 0
			ctl.state["nudgesBought"] = 1
			ctl.state["mana"] = 9 if mode == "nudgebuy" else 1
			scene.call("_render", [], ctl.state)
			for i in 20:
				await process_frame
		if mode in ["manage", "battle", "battle-late", "crit", "ult", "reward", "skills", "transmute", "lineage", "slab", "erase", "live", "wave7", "synergy", "synergy4", "burst", "dex", "dexpick", "dexmixed", "relic", "levels", "fork", "result", "stageclear", "shop", "shoppoor", "shopslab", "reroll", "rerollpoor", "rerollused"]:
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
		if mode == "wave7":
			## 졸병 종류가 섞이는 웨이브의 줄 미리보기.
			ctl.state["wave"] = 7
			scene.call("_render", [], ctl.state)
			for i in 20:
				await process_frame
		if mode == "live":
			## 수동 궁극기 전투: 설정을 잠깐 수동으로 바꿨다가 되돌린다.
			var keep_auto: bool = scene.get("store").ult_auto
			scene.get("store").ult_auto = false
			for tier in ctl.data["battle"]["ultimate"]["chargeHits"]:
				ctl.data["battle"]["ultimate"]["chargeHits"][tier] = 2
			scene.call("_begin_battle")
			scene.get("store").ult_auto = keep_auto
			for i in (int(args[4]) if args.size() > 4 else 150):
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
		if mode in ["synergy4", "burst"]:
			## 불 드래곤 넷: 4마리 규칙 효과(폭발)가 켜진 칩, burst는 그 전투.
			var fours: Array = ["fire_drake", "fire_wyvern", "fire_serpent", "fire_drake"]
			ctl.state["nestOpen"] = maxi(4, int(ctl.state["nestOpen"]))
			for slot in range(4):
				ctl.state["nest"][slot] = {"uid": 950 + slot, "speciesId": fours[slot], "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 6, "xp": 0}
			scene.call("_render", [], ctl.state)
			for i in 10:
				await process_frame
			if mode == "burst":
				ctl.dispatch({"type": "startBattle"})
				for i in (int(args[4]) if args.size() > 4 else 130):
					await process_frame
		if mode in ["dex", "dexpick", "dexmixed", "relic", "levels", "fork", "result", "stageclear"]:
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
			if mode in ["result", "stageclear"]:
				ctl.state["discovered"] = ["fafnir", "zhulong", "fire_whelp"]
				ctl.state["phase"] = "victory"
				if mode == "stageclear":
					## 지역을 깬 화면: 별과 데려갈 드래곤 고르기.
					scene.set("run_length", "stage:0")
					ctl.state["livesLost"] = 1
					ctl.state["bench"][0] = {"uid": 990, "speciesId": "ice_wyvern", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 6, "xp": 0}
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
		if mode in ["shop", "shoppoor", "shopslab"]:
			## 상점: 갈림길의 상인으로 실제 진열을 연 뒤, 글이 가장 긴 유물로 바꿔 꽉 찬 모습을 본다.
			ctl.state["phase"] = "fork"
			ctl.state["forkChoices"] = ["elite", "rest", "merchant"]
			ctl.state["mana"] = 40 if mode != "shoppoor" else 5
			ctl.state["lives"] = 3 if mode != "shoppoor" else int(ctl.data["waves"]["startLives"])
			if mode == "shoppoor":
				ctl.state["slab"] = ctl.state["slab"].slice(0, int(ctl.data["slot"]["slab"]["minSize"]))
			ctl.dispatch({"type": "chooseFork", "option": "merchant"})
			for item in ctl.state["shop"]["items"]:
				if item["kind"] == "relic":
					item["detail"] = "hawkeye"
				if item["kind"] == "rune":
					item["detail"] = "lightning"
			if mode == "shop":
				## 하나 산 뒤의 모습(산 물건은 흐리게, 아래에 한 줄).
				for i in range(ctl.state["shop"]["items"].size()):
					if ctl.state["shop"]["items"][i]["kind"] == "transmute":
						ctl.dispatch({"type": "buy", "index": i})
			elif mode == "shopslab":
				for i in range(ctl.state["shop"]["items"].size()):
					if ctl.state["shop"]["items"][i]["kind"] == "rune":
						ctl.dispatch({"type": "buy", "index": i})
			else:
				scene.call("_render", [], ctl.state)
			for i in 50:
				await process_frame
		if mode in ["reroll", "rerollpoor", "rerollused"]:
			## 보상 화면의 다시 뽑기 단추: 글이 긴 보상 석 장으로.
			var picks: Array = []
			for kind in ["t2egg", "transmute", "rune"]:
				for reward in ctl.data["rewards"]:
					if reward["kind"] == kind:
						picks.append({"reward": reward, "detail": {"t2egg": "fafnir", "rune": "lightning"}.get(kind)})
			ctl.state["phase"] = "reward"
			ctl.state["rewardChoices"] = picks
			ctl.state["mana"] = 1 if mode == "rerollpoor" else 9
			ctl.state["rewardRerolls"] = 1 if mode == "rerollused" else 0
			scene.call("_render", [], ctl.state)
			for i in 50:
				await process_frame
		if mode in ["slab", "erase"]:
			ctl.state["phase"] = "slab"
			ctl.state["runePending"] = "fire" if mode == "slab" else "erase"
			ctl.state["slab"][2] = "fire"
			scene.call("_render", [], ctl.state)
			for i in 40:
				await process_frame
		if mode == "lineage":
			ctl.state["nest"][0] = {"uid": 901, "speciesId": "fire_drake", "traits": ["tr_fire_wyvern"], "bonusPct": 0, "skills": {"fang": 2}, "skillPoints": 0, "level": 6, "xp": 1}
			ctl.state["bench"][0] = {"uid": 902, "speciesId": "fire_wyvern", "traits": [], "bonusPct": 0, "skills": {}, "skillPoints": 0, "level": 2, "xp": 0}
			scene.call("_render", [], ctl.state)
			scene.call("_show_lineage", {"type": "merge", "main": {"zone": "nest", "index": 0}, "material": {"zone": "bench", "index": 0}})
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
