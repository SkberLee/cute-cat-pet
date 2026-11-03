extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "main.tscn failed to load")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cat: Node = main.get_node("%Cat")
	var stats: Node = main.get_node("%PetStats")
	var label: Label = main.get_node("%FeedbackLabel")

	var mood0: float = stats.mood
	cat.do_pet()
	assert(stats.mood > mood0)
	assert(label.text.find("呼噜") >= 0)

	await create_timer(1.0).timeout
	var hunger0: float = stats.hunger
	cat.do_feed()
	assert(stats.hunger < hunger0)
	assert(label.text.find("好吃") >= 0)

	await create_timer(1.0).timeout
	var bond0: float = stats.bond
	cat.do_play()
	assert(stats.bond > bond0)
	assert(label.text.find("逗") >= 0)

	print("smoke_main ok feedback=", label.text, " mood=", stats.mood, " hunger=", stats.hunger, " bond=", stats.bond)
	quit(0)
