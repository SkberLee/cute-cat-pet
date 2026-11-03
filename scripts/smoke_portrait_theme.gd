extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	SaveManager.clear()
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null)
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cosmetics: Node = main.get_node("%RoomCosmetics")
	assert(cosmetics != null)
	assert(main.get_node("%Curtain") != null)
	assert(main.get_node("%Rug") != null)
	assert(main.get_node("%BtnTheme") != null)
	var stats: PetStats = main.get_node("%PetStats")
	stats.bond = 80.0
	stats._check_milestones()
	var ids = cosmetics.unlocked_ids(stats.bond)
	assert(ids.size() >= 3)
	var before = cosmetics.current_theme
	var nxt = cosmetics.cycle_next(stats.bond)
	assert(nxt != "" and (nxt != before or ids.size() == 1))
	# save roundtrip via UI helper
	var ui = main.get_node("UI")
	assert(ui.has_method("_save_game"))
	ui._save_game()
	var data = SaveManager.load_dict()
	assert(data.has("room_theme"))
	assert(data.has("stats"))
	SaveManager.clear()
	print("smoke_portrait_theme ok theme=", nxt, " unlocked=", ids)
	quit(0)
