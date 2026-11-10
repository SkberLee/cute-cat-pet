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
	var bubble: Node = main.get_node("%SpeechBubble")
	assert(bubble != null, "SpeechBubble missing")
	assert(bubble.has_method("show_line"))
	var label: Label = main.get_node("%FeedbackLabel")
	assert(label != null)
	var cat: Node = main.get_node("%Cat")
	assert(cat.has_method("get_mouth_point"))
	var mouth = cat.get_mouth_point()
	# 2D y-down: the mouth sits above the paws. 3D y-up is also accepted.
	if mouth is Vector2:
		assert(mouth.y < cat.global_position.y, "mouth should sit above the paws")
	else:
		assert(mouth.y > cat.global_position.y)
	bubble.show_line("测试说话框～", true)
	assert(label.text.find("测试") >= 0)
	assert(bubble.visible == true)
	# Replace line cleanly
	bubble.show_line("呼噜～再摸摸", true)
	assert(label.text.find("呼噜") >= 0)
	print("smoke_speech ok mouth=", mouth, " text=", label.text, " visible=", bubble.visible)
	quit(0)
