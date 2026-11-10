extends SceneTree
## Dev tool: godot --path . -s res://tools/shot.gd --resolution 540x1200 -- out.png [scenario]
## scenarios: idle | bubble | walk | walkdir (dir=down|up|left|right|diag) | zoom | free | pet | pickfeed | pickplay | feed (food=id) | toy (toy=id)
## extra k=v args (any scenario): cam=x,y zoom=n clip=name t=sec nofloor=1 (hide Room) nohud=1 (hide UI)
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
			cat._start_wander(Vector2(64, 170))
			wait = 1.4
		"walk":
			cat._cooldown = 0.0
			cat._start_wander(Vector2(250, 120))
			wait = 2.5
		"walkdir":
			cat.set_autonomy_paused(true)
			cat._cooldown = 0.0
			var dname := str(opts.get("dir", "down"))
			var start := Vector2(168, 148)
			var dest := Vector2(168, 148)
			match dname:
				"up":
					start = Vector2(168, 188)
					dest = Vector2(168, 104)
				"left":
					start = Vector2(240, 156)
					dest = Vector2(50, 156)
				"right":
					start = Vector2(60, 156)
					dest = Vector2(270, 156)
				"diag":
					start = Vector2(80, 118)
					dest = Vector2(240, 188)
				_:
					start = Vector2(168, 110)
					dest = Vector2(168, 192)
			cat.position = start
			cat._start_wander(dest)
			cat._wander_speed = cat.WALK_SPEED
			cat._face_dir(dest - start)
			cat._play_locomotion(false)
			if cat.speech_bubble:
				cat.speech_bubble.visible = false
			wait = float(opts.get("t", "1.13"))
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
		"mouseshow":
			cat.set_autonomy_paused(true)
			var mo: Node2D = load("res://scripts/cat_props.gd").make_food_2d("fish") if false else CatProps.make_toy_2d("mouse")
			var holder = main.get_node_or_null("World/PropsHolder")
			(holder if holder else main.get_node("World")).add_child(mo)
			mo.global_position = cat.global_position + Vector2(float(opts.get("mx", "28")), 0.0)
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
		var cam: Camera2D = main.get_node_or_null("World/Camera2D")
		if cam:
			var p := _v2(opts["cam"])
			if opts.has("rel"):
				p += cat.global_position
			cam.position = p
			if opts.has("zoom"):
				var z := float(opts["zoom"])
				cam.zoom = Vector2(z, z)
	if opts.has("nofloor"):
		var room = main.get_node_or_null("World/Room")
		if room:
			room.visible = false
	if opts.has("nohud"):
		main.get_node("UI").visible = false
	for i in 3:
		await process_frame
	var cam_node = main.get_node_or_null("World/Camera2D")
	print("DBG props=", cat._props.map(func(n): return n.global_position))
	print("DBG cat=", cat.global_position, " cam=", cam_node.position if cam_node else "?", " anim=", cat.anim.animation if cat.anim else "?", " facing=", cat._facing, " flip=", cat.anim.flip_h if cat.anim else "?")
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", out, " win=", root.size, " visible=", root.get_visible_rect().size, " scale=", root.content_scale_factor)
	quit(0)

func _v2(s: String) -> Vector2:
	var p := s.split(",")
	if p.size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return Vector2.ZERO
