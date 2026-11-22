extends SceneTree
## 화면 확인용 캡처(테스트 아님): 장면을 띄우고 몇 프레임 뒤 PNG로 저장하고 종료.
## godot --path . --position -4000,-4000 --script res://godot/tests/capture.gd -- <장면경로> <저장경로> [spin]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://godot/scenes/main.tscn"
	var out: String = args[1] if args.size() > 1 else "user://capture.png"
	var spin := args.size() > 2 and args[2] == "spin"
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 30:
		await process_frame
	if spin and scene.get("controller") != null:
		var tut = scene.get("_tutorial")
		if tut != null and tut.has_method("finish"):
			tut.call("finish")
		var ctl = scene.get("controller")
		ctl.restart(12, 0)
		for i in 10:
			await process_frame
		ctl.dispatch({"type": "spin"})
		for i in 90:
			await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
