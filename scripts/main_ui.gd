# scripts/main_ui.gd
extends CanvasLayer

## Landscape-first mobile UI (1280×720). Soft bars + large touch targets.

@onready var cat: Node3D = %Cat
@onready var stats: PetStats = %PetStats
@onready var mood_bar: ProgressBar = %MoodBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_bar: ProgressBar = %BondBar
@onready var btn_pet: Button = %BtnPet
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay

func _ready() -> void:
	_style_ui()
	btn_pet.pressed.connect(_on_pet)
	btn_feed.pressed.connect(_on_feed)
	btn_play.pressed.connect(_on_play)
	if cat:
		if cat.has_signal("interaction_started"):
			cat.interaction_started.connect(_on_busy)
		if cat.has_signal("interaction_ready"):
			cat.interaction_ready.connect(_on_ready_again)
	if stats:
		stats.stats_changed.connect(_refresh)
		_refresh()

func _style_ui() -> void:
	var card := get_node_or_null("Root/SafeMargin/Layout/StatsCard")
	if card is PanelContainer:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(1, 0.96, 0.94, 0.78)
		panel.corner_radius_top_left = 18
		panel.corner_radius_top_right = 18
		panel.corner_radius_bottom_left = 18
		panel.corner_radius_bottom_right = 18
		panel.content_margin_left = 16
		panel.content_margin_right = 16
		panel.content_margin_top = 12
		panel.content_margin_bottom = 14
		(card as PanelContainer).add_theme_stylebox_override("panel", panel)
	_style_bar(mood_bar, Color(0.95, 0.62, 0.72))
	_style_bar(hunger_bar, Color(0.98, 0.78, 0.45))
	_style_bar(bond_bar, Color(0.72, 0.7, 0.95))
	for b in [btn_pet, btn_feed, btn_play]:
		_style_button(b)

func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.28)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.corner_radius_top_left = 8
	fg.corner_radius_top_right = 8
	fg.corner_radius_bottom_left = 8
	fg.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 0.92, 0.9, 0.92)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 0.86, 0.84, 0.98)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.95, 0.78, 0.76, 1)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.9, 0.88, 0.86, 0.55)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(0.28, 0.18, 0.22))
	btn.add_theme_color_override("font_pressed_color", Color(0.22, 0.14, 0.16))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.45, 0.7))

func _set_buttons_enabled(enabled: bool) -> void:
	btn_pet.disabled = not enabled
	btn_feed.disabled = not enabled
	btn_play.disabled = not enabled

func _on_busy(_action: String) -> void:
	_set_buttons_enabled(false)

func _on_ready_again() -> void:
	_set_buttons_enabled(true)

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
