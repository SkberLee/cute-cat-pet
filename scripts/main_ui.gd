# scripts/main_ui.gd
extends CanvasLayer

## Dual-orientation mobile UI. Soft bars + large touch targets.

@onready var cat: Node3D = %Cat
@onready var stats: PetStats = %PetStats
@onready var mood_bar: ProgressBar = %MoodBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_bar: ProgressBar = %BondBar
@onready var btn_pet: Button = %BtnPet
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay
@onready var btn_theme: Button = %BtnTheme
@onready var stats_card: PanelContainer = $Root/SafeMargin/Layout/StatsCard
@onready var buttons: HBoxContainer = $Root/SafeMargin/Layout/Buttons
@onready var feedback_label: Label = %FeedbackLabel
@onready var camera: Camera3D = $"../Camera3D"
@onready var room_cosmetics: RoomCosmetics = %RoomCosmetics

var _sfx_ui: AudioStream
var _ui_player: AudioStreamPlayer
var _portrait := false

func _ready() -> void:
	_style_ui()
	_setup_ui_audio()
	_load_game()
	btn_pet.pressed.connect(_on_pet)
	btn_feed.pressed.connect(_on_feed)
	btn_play.pressed.connect(_on_play)
	if btn_theme:
		btn_theme.pressed.connect(_on_theme)
	if cat:
		if cat.has_signal("interaction_started"):
			cat.interaction_started.connect(_on_busy)
		if cat.has_signal("interaction_ready"):
			cat.interaction_ready.connect(_on_ready_again)
		if cat.has_signal("save_requested"):
			cat.save_requested.connect(_save_game)
	if stats:
		stats.stats_changed.connect(_refresh)
		if stats.has_signal("milestone_unlocked"):
			stats.milestone_unlocked.connect(_on_milestone_ui)
		_refresh()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_update_theme_button()

func _setup_ui_audio() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiSfx"
	_ui_player.volume_db = -8.0
	add_child(_ui_player)
	_sfx_ui = load("res://assets/sfx/ui_soft.wav")

func _play_ui() -> void:
	if _ui_player and _sfx_ui:
		_ui_player.stream = _sfx_ui
		_ui_player.play()

func _style_ui() -> void:
	if stats_card:
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
		stats_card.add_theme_stylebox_override("panel", panel)
	_style_bar(mood_bar, Color(0.95, 0.62, 0.72))
	_style_bar(hunger_bar, Color(0.98, 0.78, 0.45))
	_style_bar(bond_bar, Color(0.72, 0.7, 0.95))
	for b in [btn_pet, btn_feed, btn_play, btn_theme]:
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

func _on_viewport_resized() -> void:
	var size := get_viewport().get_visible_rect().size
	_portrait = size.y > size.x
	_apply_layout()

func _apply_layout() -> void:
	if stats_card == null or buttons == null:
		return
	if _portrait:
		# Top full-width card, taller feedback, bottom buttons with theme
		stats_card.set_anchors_preset(Control.PRESET_TOP_WIDE)
		stats_card.anchor_left = 0.0
		stats_card.anchor_right = 1.0
		stats_card.offset_left = 0.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 168.0
		if feedback_label:
			feedback_label.offset_top = 176.0
			feedback_label.offset_bottom = 230.0
			feedback_label.add_theme_font_size_override("font_size", 22)
		buttons.offset_left = -160.0 if get_viewport().get_visible_rect().size.x < 500 else -280.0
		buttons.offset_right = -buttons.offset_left
		buttons.offset_top = -160.0
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("separation", 12)
		for b in [btn_pet, btn_feed, btn_play]:
			if b:
				b.custom_minimum_size = Vector2(96, 64)
				b.add_theme_font_size_override("font_size", 20)
		if btn_theme:
			btn_theme.visible = true
			btn_theme.custom_minimum_size = Vector2(96, 56)
		if camera:
			camera.fov = 55.0
			camera.position = Vector3(0, 1.55, 3.15)
	else:
		stats_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		stats_card.anchor_left = 1.0
		stats_card.anchor_right = 1.0
		stats_card.offset_left = -280.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 148.0
		if feedback_label:
			feedback_label.offset_top = 8.0
			feedback_label.offset_bottom = 56.0
			feedback_label.add_theme_font_size_override("font_size", 26)
		buttons.offset_left = -340.0
		buttons.offset_right = 340.0
		buttons.offset_top = -84.0
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("separation", 18)
		for b in [btn_pet, btn_feed, btn_play]:
			if b:
				b.custom_minimum_size = Vector2(140, 68)
				b.add_theme_font_size_override("font_size", 24)
		if btn_theme:
			btn_theme.visible = true
			btn_theme.custom_minimum_size = Vector2(120, 68)
		if camera:
			camera.fov = 48.0
			camera.position = Vector3(0, 1.48, 2.85)

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

func _on_theme() -> void:
	if room_cosmetics == null or stats == null:
		return
	var id := room_cosmetics.cycle_next(stats.bond)
	_play_ui()
	_update_theme_button()
	if feedback_label:
		feedback_label.text = "房间换成「%s」啦" % room_cosmetics.theme_display_name(id)
	_save_game()

func _on_milestone_ui(threshold: int, title: String) -> void:
	_update_theme_button()
	if feedback_label and threshold >= 25:
		# Cat controller already says a line; keep title soft in theme button tip.
		pass
	_save_game()

func _update_theme_button() -> void:
	if btn_theme == null or room_cosmetics == null or stats == null:
		return
	var name := room_cosmetics.theme_display_name(room_cosmetics.current_theme)
	var unlocked := room_cosmetics.unlocked_ids(stats.bond)
	btn_theme.text = "换装·%s" % name
	btn_theme.disabled = unlocked.size() <= 1 and stats.bond < 25.0
	if stats.bond < 25.0:
		btn_theme.text = "换装·锁定"
		btn_theme.disabled = true

func _refresh() -> void:
	if stats == null:
		return
	mood_bar.value = stats.mood
	hunger_bar.value = stats.hunger
	bond_bar.value = stats.bond
	_update_theme_button()

func _load_game() -> void:
	var data := SaveManager.load_dict()
	if data.is_empty():
		return
	if stats and data.has("stats"):
		stats.from_save(data["stats"])
	elif stats:
		# backward: flat fields
		stats.from_save(data)
	if room_cosmetics and data.has("room_theme"):
		var theme_id := str(data["room_theme"])
		var bond_v := stats.bond if stats else 0.0
		if theme_id in room_cosmetics.unlocked_ids(bond_v) or theme_id == "blush":
			room_cosmetics.apply_theme(theme_id, false)
	if cat and cat.has_method("_apply_cosmetics_for_bond") and stats:
		cat._apply_cosmetics_for_bond(stats.bond)

func _save_game() -> void:
	if stats == null:
		return
	var data := {
		"stats": stats.to_save(),
		"room_theme": room_cosmetics.current_theme if room_cosmetics else "blush",
	}
	SaveManager.save_dict(data)
