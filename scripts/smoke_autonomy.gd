extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null)
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cat = main.get_node("%Cat")
	assert(cat.has_method("_choose_autonomy"))
	assert(cat.has_method("_start_wander"))
	var pos0: Vector3 = cat.position
	cat._cooldown = 0.0
	cat._auto_busy = false
	cat._wandering = false
	cat._start_wander()
	assert(cat._wandering == true)
	# Manually step wander a few frames
	for i in 20:
		cat._update_wander(0.05)
	var moved: bool = cat.position.distance_to(pos0) > 0.02
	assert(moved, "cat should wander")
	# User interaction cancels autonomy
	cat._cooldown = 0.0
	cat.do_pet()
	assert(cat._wandering == false)
	assert(cat._auto_busy == false)
	print("smoke_autonomy ok moved=", moved, " anim=", cat.anim.current_animation, " pos=", cat.position)
	quit(0)
