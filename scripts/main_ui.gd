# scripts/main_ui.gd
extends CanvasLayer

@onready var cat: Node3D = %Cat
@onready var stats: PetStats = %PetStats
@onready var mood_bar: ProgressBar = %MoodBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_bar: ProgressBar = %BondBar
@onready var btn_pet: Button = %BtnPet
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay

func _ready() -> void:
	btn_pet.pressed.connect(_on_pet)
	btn_feed.pressed.connect(_on_feed)
	btn_play.pressed.connect(_on_play)
	if stats:
		stats.stats_changed.connect(_refresh)
		_refresh()

func _on_pet() -> void:
	if cat and cat.has_method("do_pet"):
		cat.do_pet()

func _on_feed() -> void:
	if cat and cat.has_method("do_feed"):
		cat.do_feed()

func _on_play() -> void:
	if cat and cat.has_method("do_play"):
		cat.do_play()

func _refresh() -> void:
	if stats == null:
		return
	mood_bar.value = stats.mood
	hunger_bar.value = stats.hunger
	bond_bar.value = stats.bond
