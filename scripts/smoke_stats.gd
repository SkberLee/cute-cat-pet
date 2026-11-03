extends SceneTree

func _init() -> void:
	var s = load("res://scripts/pet_stats.gd").new()
	var mood0 = s.mood
	s.pet()
	assert(s.mood > mood0)
	assert(s.mood <= 100.0)
	s.feed()
	assert(s.hunger < 30.0)
	s.play()
	s.tick(1.0)
	assert(s.hunger >= 0.0 and s.hunger <= 100.0)
	print("smoke_stats ok mood=", s.mood, " hunger=", s.hunger, " bond=", s.bond)
	quit()
