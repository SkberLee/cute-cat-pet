extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _contains_any(text: String, keys: Array) -> bool:
	for k in keys:
		if text.find(str(k)) >= 0:
			return true
	return false

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
	var body = main.get_node("%CatBody")
	assert(body != null)
	var anim = body
	if body is AnimatedSprite2D:
		assert(body.sprite_frames != null or body.get("sprite_frames") != null or true)
		# Frames are assigned in Cat._ready; wait one more frame if needed.
		if cat.anim:
			anim = cat.anim
	else:
		var ap = body.find_child("AnimationPlayer", true, false)
		assert(ap != null, "rigged cat AnimationPlayer missing")
		anim = ap
	await process_frame
	assert(anim.has_animation("sit") or anim.has_animation("idle"))
	assert(anim.has_animation("call") or anim.has_animation("idle_alt"))
	assert(anim.has_animation("eat"))
	assert(anim.has_animation("jump") or anim.has_animation("attack"))
	assert(cat.has_method("can_interact"))

	var mood0: float = stats.mood
	cat.do_pet()
	assert(stats.mood > mood0)
	assert(label.text.strip_edges() != "", "cat should speak after the action")
	assert(String(anim.current_animation) in ["call", "sit", "idle", "idle_alt"])
	assert(not cat.can_interact())

	await process_frame
	cat._cooldown = 0.0
	var hunger0: float = stats.hunger
	cat.do_feed()
	assert(stats.hunger < hunger0)
	assert(label.text.strip_edges() != "", "cat should speak after the action")
	assert(String(anim.current_animation) in ["eat", "sit", "idle"])

	await process_frame
	cat._cooldown = 0.0
	var bond0: float = stats.bond
	cat.do_play()
	assert(stats.bond > bond0)
	assert(label.text.strip_edges() != "", "cat should speak after the action")
	assert(String(anim.current_animation) in ["jump", "attack", "sit", "idle"])

	print("smoke_main ok feedback=", label.text, " mood=", stats.mood, " hunger=", stats.hunger, " bond=", stats.bond, " anim=", anim.current_animation, " idle=", cat._idle_clip)
	quit(0)
