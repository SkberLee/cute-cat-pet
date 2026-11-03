extends SceneTree

## v0.2.4 interactions: pet hand, food picker + eating, toy picker + play.

var _finished: Array = []
var _label_log: Array = []

func _init() -> void:
	call_deferred("_run")

func _wait_finish(cat: Node, kind: String, max_frames: int) -> bool:
	var n := 0
	while n < max_frames:
		await process_frame
		n += 1
		if _finished.has(kind):
			return true
	return false

func _settle(cat: Node) -> void:
	var n := 0
	while cat.is_busy_action() and n < 4000:
		await process_frame
		n += 1
	await process_frame
	cat._cooldown = 0.0

func _run() -> void:
	Engine.time_scale = 6.0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cat: Node = main.get_node("%Cat")
	var stats: Node = main.get_node("%PetStats")
	var ui: Node = main.get_node("UI")
	var label: Label = main.get_node("%FeedbackLabel")
	cat.action_finished.connect(func(k: String) -> void: _finished.append(k))
	cat.set_autonomy_paused(true)

	# --- pickers exist and have 4 options each
	assert(ui.food_picker != null and ui.toy_picker != null and ui.pet_hand != null)
	assert(ui.food_picker.option_count() == 4, "food picker needs 4 options")
	assert(ui.toy_picker.option_count() == 4, "toy picker needs 4 options")
	assert(not ui.food_picker.visible and not ui.toy_picker.visible)
	ui._on_feed()
	assert(ui.food_picker.visible and not ui.toy_picker.visible)
	ui._on_play()
	assert(ui.toy_picker.visible and not ui.food_picker.visible)
	ui._on_play()
	assert(not ui.toy_picker.visible)

	# --- pet hand
	cat._cooldown = 0.0
	assert(not ui.pet_hand.is_playing())
	ui._on_pet()
	await process_frame
	assert(ui.pet_hand.is_playing(), "pet hand must show while petting")
	var n := 0
	while ui.pet_hand.is_playing() and n < 3000:
		await process_frame
		n += 1
	assert(not ui.pet_hand.is_playing(), "pet hand must hide afterwards")

	# --- foods
	var start_lines := {}
	for fid in CatProps.FOOD_ORDER:
		await _settle(cat)
		stats.hunger = 80.0
		var h0: float = stats.hunger
		_finished.clear()
		ui._on_feed()
		assert(ui.food_picker.visible)
		ui.food_picker.press_option(fid)
		await process_frame
		assert(not ui.food_picker.visible, "picker closes after picking")
		assert(cat.is_busy_action(), "feed sequence runs " + fid)
		assert(cat._props.size() >= 1, "food prop spawned " + fid)
		var seen_eat := false
		var k := 0
		while not _finished.has("feed") and k < 4000:
			await process_frame
			k += 1
			if cat.action_phase == "eat":
				seen_eat = true
		assert(_finished.has("feed"), "feed finished " + fid)
		assert(seen_eat, "cat reached eat phase " + fid)
		assert(stats.hunger < h0, "hunger drops " + fid)
		assert(cat._props.is_empty(), "food cleaned up " + fid)
		start_lines[fid] = true
	assert(CatProps.FOOD_ORDER.size() == 4)
	var line_sets := {}
	for fid in CatProps.FOOD_ORDER:
		line_sets[str(cat.FOOD_LINES[fid]["start"])] = true
	assert(line_sets.size() == 4, "each food has its own lines")

	# --- toys
	for tid in CatProps.TOY_ORDER:
		await _settle(cat)
		stats.hunger = 60.0
		var m0: float = stats.mood
		stats.mood = 40.0
		m0 = stats.mood
		_finished.clear()
		ui._on_play()
		ui.toy_picker.press_option(tid)
		await process_frame
		assert(cat.is_busy_action(), "play sequence runs " + tid)
		assert(cat._props.size() >= 1, "toy prop spawned " + tid)
		var ok := await _wait_finish(cat, "play", 4000)
		assert(ok, "play finished " + tid)
		assert(stats.mood > m0, "mood rises " + tid)
		assert(cat._props.is_empty(), "toy cleaned up " + tid)
	assert(cat.TOY_LINES.size() == 4)

	# --- interaction_ready fires again after an action
	var ready := [false]
	cat.interaction_ready.connect(func() -> void: ready[0] = true)
	await _settle(cat)
	_finished.clear()
	cat.do_play("wand")
	await _wait_finish(cat, "play", 4000)
	var j := 0
	while not ready[0] and j < 600:
		await process_frame
		j += 1
	assert(ready[0], "interaction_ready fires after action")
	assert(cat.can_interact())

	# --- portrait + landscape picker layout stays inside the viewport
	for sz in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		root.size = sz
		await process_frame
		await process_frame
		ui._on_feed()
		await process_frame
		var r: Rect2 = ui.food_picker.get_global_rect()
		assert(r.position.x >= -1.0 and r.end.x <= float(sz.x) + 1.0, "picker within width %s" % str(sz))
		assert(r.position.y >= 0.0 and r.end.y <= float(sz.y) + 1.0, "picker within height %s" % str(sz))
		ui._close_pickers()

	Engine.time_scale = 1.0
	print("smoke_interactions ok")
	quit(0)
