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
	var body: Node3D = main.get_node("%CatBody")
	var anim: AnimationPlayer = main.get_node("%CatAnim")
	assert(body != null)
	assert(body.find_child("TabbyModel", true, false) != null or body.get_child_count() > 0)
	assert(anim != null)
	# Wait one more frame so Cat._ready built the animation library.
	await process_frame
	assert(anim.has_animation("idle"))
	assert(anim.has_animation("pet"))
	assert(anim.has_animation("feed"))
	assert(anim.has_animation("play"))

	var mood0: float = stats.mood
	cat.do_pet()
	assert(stats.mood > mood0)
	assert(label.text.find("呼噜") >= 0)
	assert(anim.current_animation == "pet" or anim.current_animation == "idle")

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

	print("smoke_main ok feedback=", label.text, " mood=", stats.mood, " hunger=", stats.hunger, " bond=", stats.bond, " anim=", anim.current_animation)
	quit(0)
