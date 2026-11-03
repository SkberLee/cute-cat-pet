extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	SaveManager.clear()
	var s = PetStats.new()
	s.mood = 88.0
	s.hunger = 12.0
	s.bond = 42.0
	s.unlocked_milestones = [25]
	assert(SaveManager.save_dict({"stats": s.to_save(), "room_theme": "mint"}))
	var data := SaveManager.load_dict()
	assert(not data.is_empty())
	var s2 = PetStats.new()
	s2.from_save(data["stats"])
	assert(abs(s2.mood - 88.0) < 0.01)
	assert(abs(s2.hunger - 12.0) < 0.01)
	assert(abs(s2.bond - 42.0) < 0.01)
	assert(25 in s2.unlocked_milestones)
	assert(str(data.get("room_theme", "")) == "mint")
	# milestone unlock emits
	var got := {"th": 0}
	s2.milestone_unlocked.connect(func(th, _title): got["th"] = th)
	s2.bond = 49.0
	s2.play()  # +5 -> 54, should unlock 50
	assert(50 in s2.unlocked_milestones)
	assert(got["th"] == 50)
	SaveManager.clear()
	print("smoke_save ok")
	quit(0)
