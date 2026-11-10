extends SceneTree
## Portrait demo of smooth 4-dir walks, a diagonal, then a natural stop. No teleports.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(540, 960))
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 16:
		await process_frame
	var cat = main.get_node("%Cat")
	cat.set_autonomy_paused(true)
	if cat.speech_bubble:
		cat.speech_bubble.visible = false
	# Place once at the start, then only walk — never teleport mid-demo.
	# Extra time on side (right/left) and front/down walks, plus a back walk.
	cat.position = Vector2(60, 110)
	cat._facing = "right"
	cat._apply_flip()
	cat._play_idle()
	await _wait(0.55)
	await _walk(cat, Vector2(250, 110))
	await _walk(cat, Vector2(250, 200))
	await _walk(cat, Vector2(70, 200))
	await _walk(cat, Vector2(70, 110))
	await _walk(cat, Vector2(70, 200))
	await _walk(cat, Vector2(230, 140))
	await _wait(1.1)
	# Tell the shell recorder to stop ffmpeg before this window closes.
	var f := FileAccess.open("/tmp/record/demo_done", FileAccess.WRITE)
	if f:
		f.store_string("ok")
		f.close()
	await _wait(0.2)
	quit(0)


func _walk(cat, dest: Vector2) -> void:
	cat._cooldown = 0.0
	cat._start_wander(dest)
	cat._wander_speed = cat.WALK_SPEED
	var t0 := Time.get_ticks_msec()
	while (cat._wandering or cat._settling) and (Time.get_ticks_msec() - t0) / 1000.0 < 6.0:
		await process_frame
	await _wait(0.16)


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await process_frame
