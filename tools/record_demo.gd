extends SceneTree
## v0.3 portrait demo — same flow as the user's playtest:
## idle → pet → feed (can) → play (wand) → dress-up ×2 → walk all facings → idle.
## No teleports after the start. Writes /tmp/record/demo_done before quitting.

const W := 540
const H := 1200

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(W, H))
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 16:
		await process_frame
	var cat = main.get_node("%Cat")
	var ui = main.get_node("UI")
	var stats = cat.stats
	cat.set_autonomy_paused(true)
	# Enough bond for the dress-up themes to unlock (shown on the HUD bars too).
	stats.bond = 80.0
	stats.hunger = 30.0
	stats.stats_changed.emit()
	ui._update_theme_button()
	cat.position = Vector2(150, 150)
	cat._facing = "down"
	cat._play_idle()
	await _wait(2.0)
	# pet
	cat._cooldown = 0.0
	ui._on_pet()
	await _wait(2.2)
	# feed: open picker, pick can
	cat._cooldown = 0.0
	ui._on_feed()
	await _wait(0.9)
	ui._on_food_picked("can")
	await _until(func(): return cat.action_phase == "", 12.0)
	await _wait(0.8)
	# play: wand
	cat._cooldown = 0.0
	ui._on_play()
	await _wait(0.9)
	ui._on_toy_picked("wand")
	await _until(func(): return cat.action_phase == "", 14.0)
	await _wait(0.8)
	# dress-up twice
	ui._on_theme()
	await _wait(1.6)
	ui._on_theme()
	await _wait(1.8)
	# walks in every facing
	await _walk(cat, Vector2(250, 150))
	await _walk(cat, Vector2(250, 190))
	await _walk(cat, Vector2(90, 190))
	await _walk(cat, Vector2(90, 108))
	await _walk(cat, Vector2(160, 160))
	cat._face_dir(Vector2(0, 1))
	cat._play_idle()
	await _wait(2.4)
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
	await _wait(0.25)


func _until(cond: Callable, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and (Time.get_ticks_msec() - t0) / 1000.0 < limit:
		await process_frame


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await process_frame
