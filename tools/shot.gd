extends SceneTree
## Dev tool: godot --path . -s res://tools/shot.gd --resolution 540x1200 -- out.png [scenario]
## scenarios: idle | bubble | walk | zoom

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/shot.png"
	var scenario := args[1] if args.size() > 1 else "idle"
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var cat = main.get_node("%Cat")
	var wait := 0.6
	if scenario == "idle" or scenario == "zoom":
		cat.set_autonomy_paused(true)
	match scenario:
		"bubble":
			cat._cooldown = 0.0
			cat._start_wander(Vector3(-1.8, 0, 1.2))
			wait = 1.4
		"walk":
			cat._cooldown = 0.0
			cat._start_wander(Vector3(1.8, 0, -1.2))
			wait = 2.5
		"zoom":
			main.get_node("UI")._enter_zoom()
			wait = 1.0
	var t0 := Time.get_ticks_msec()
	var said := false
	while (Time.get_ticks_msec() - t0) / 1000.0 < wait:
		await process_frame
		if scenario == "bubble" and not said and (Time.get_ticks_msec() - t0) / 1000.0 > wait - 0.5:
			said = true
			main.get_node("%SpeechBubble").show_line("走走停停…我在这里玩呀", false)
	await process_frame
	print("DBG cat=", cat.global_position, " cam=", main.get_node("Camera3D").global_position)
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " win=", root.size, " visible=", root.get_visible_rect().size, " scale=", root.content_scale_factor)
	quit(0)
