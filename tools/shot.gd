extends SceneTree
## Dev tool: godot --path . -s res://tools/shot.gd --resolution 540x1200 -- out.png [scenario]
## scenarios: idle | bubble | walk | zoom | free | pet | pickfeed | pickplay | feed (food=id) | toy (toy=id)
## extra k=v args (any scenario): cam=x,y,z look=x,y,z fov=deg clip=name t=sec nofloor=1 (hide Room) nohud=1 (hide UI)
## clip= plays an animation on the cat and freezes it after t seconds (default 0.4).

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
	var opts := {}
	for i in range(2, args.size()):
		var kv: PackedStringArray = args[i].split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
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
		"pet":
			cat._cooldown = 0.0
			main.get_node("UI")._on_pet()
			wait = float(opts.get("t", "0.75"))
		"zoompet":
			main.get_node("UI")._enter_zoom()
			for i in 40:
				await process_frame
			cat._cooldown = 0.0
			main.get_node("UI")._on_pet()
			wait = float(opts.get("t", "0.9"))
		"pickfeed":
			main.get_node("UI")._on_feed()
			wait = 0.3
		"pickplay":
			main.get_node("UI")._on_play()
			wait = 0.3
		"feed":
			cat._cooldown = 0.0
			cat.do_feed(opts.get("food", "fish"))
			var guard := 0.0
			while cat.action_phase != "eat" and guard < 15.0:
				await process_frame
				guard += 0.016
			wait = float(opts.get("t", "0.7"))
		"mouseshow":   # static toy mouse placed in front of the cat (use cam=/look= with rel=1)
			cat.set_autonomy_paused(true)
			var mo: Node3D = load("res://scripts/cat_props.gd").make_toy("mouse")
			main.add_child(mo)
			mo.global_position = cat.global_position + Vector3(0.0, 0.0, 0.0) + Vector3(float(opts.get("mx", "1.0")), 0.0, 0.0)
			mo.rotation.y = float(opts.get("my", "0.5"))
			wait = 0.3
		"toy":
			cat._cooldown = 0.0
			cat.do_play(opts.get("toy", "wand"))
			wait = float(opts.get("t", "2.0"))
	var t0 := Time.get_ticks_msec()
	var said := false
	while (Time.get_ticks_msec() - t0) / 1000.0 < wait:
		await process_frame
		if scenario == "bubble" and not said and (Time.get_ticks_msec() - t0) / 1000.0 > wait - 0.5:
			said = true
			main.get_node("%SpeechBubble").show_line("走走停停…我在这里玩呀", false)
	await process_frame
	if opts.has("clip"):
		cat.set_autonomy_paused(true)
		cat.anim.play(opts["clip"])
		var tt := float(opts.get("t", "0.4"))
		var t1 := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t1) / 1000.0 < tt:
			await process_frame
		cat.anim.pause()
	if opts.has("cam"):
		var ui = main.get_node("UI")
		ui._cam_follow = false
		var cam: Camera3D = main.get_node("Camera3D")
		var p := _v3(opts["cam"])
		var lk := _v3(opts.get("look", "0,0.1,0.4"))
		if opts.has("rel"):   # cam/look are offsets from the cat (or from the first prop with rel=prop)
			var o: Vector3 = cat.global_position
			p += o
			lk += o
		cam.global_position = p
		cam.look_at(lk, Vector3.UP)
		if opts.has("fov"):
			cam.fov = float(opts["fov"])
	if opts.has("nofloor"):
		main.get_node("Room").visible = false
	if opts.has("nohud"):
		main.get_node("UI").visible = false
	for i in 3:
		await process_frame
	print("DBG props=", cat._props.map(func(n): return n.global_position), " yaw=", cat.rotation.y)
	print("DBG cat=", cat.global_position, " cam=", main.get_node("Camera3D").global_position)
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " win=", root.size, " visible=", root.get_visible_rect().size, " scale=", root.content_scale_factor)
	quit(0)

func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
