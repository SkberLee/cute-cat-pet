# scripts/main_ui.gd
extends CanvasLayer

## Dual-orientation mobile UI over a 2D pixel room.
## Portrait: 2×2 action grid; landscape: single row. Tap cat to zoom.

@onready var cat: Node2D = %Cat
@onready var stats: PetStats = %PetStats
@onready var mood_bar: ProgressBar = %MoodBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_bar: ProgressBar = %BondBar
@onready var btn_pet: Button = %BtnPet
@onready var btn_feed: Button = %BtnFeed
@onready var btn_play: Button = %BtnPlay
@onready var btn_theme: Button = %BtnTheme
@onready var stats_card: PanelContainer = $Root/SafeMargin/Layout/StatsCard
@onready var buttons: GridContainer = $Root/SafeMargin/Layout/Buttons
@onready var feedback_label: Label = %FeedbackLabel
@onready var speech_bubble: Node = %SpeechBubble
@onready var camera: Camera2D = $"../World/Camera2D"
@onready var room_cosmetics: RoomCosmetics = %RoomCosmetics
@onready var safe_margin: MarginContainer = $Root/SafeMargin
@onready var btn_zoom_back: Button = %BtnZoomBack

var _sfx_ui: AudioStream
var _ui_player: AudioStreamPlayer
var _portrait := false
var _zoomed := false
var _cam_fit_zoom := Vector2(2.25, 2.25)
var _cam_fit_pos := Vector2(160, 104)
var _cam_tween: Tween
var _last_tap_ms := -10000
var _cam_follow := true
const CAM_FOLLOW_SPEED := 4.0
const BASE_PORTRAIT := Vector2i(720, 1280)
const BASE_LANDSCAPE := Vector2i(1280, 720)
const ROOM_SIZE := Vector2(320, 208)
var _ui_scale := 1.0
var food_picker: PickPanel
var toy_picker: PickPanel
var pet_hand: PetHand

func _ready() -> void:
	_style_ui()
	_setup_ui_audio()
	_load_game()
	btn_pet.pressed.connect(_on_pet)
	btn_feed.pressed.connect(_on_feed)
	btn_play.pressed.connect(_on_play)
	if btn_theme:
		btn_theme.pressed.connect(_on_theme)
	if btn_zoom_back:
		btn_zoom_back.pressed.connect(_on_zoom_back)
		btn_zoom_back.visible = false
	if cat:
		if cat.has_signal("interaction_started"):
			cat.interaction_started.connect(_on_busy)
		if cat.has_signal("interaction_ready"):
			cat.interaction_ready.connect(_on_ready_again)
		if cat.has_signal("pet_stroke"):
			cat.pet_stroke.connect(_on_pet_stroke)
		if cat.has_signal("save_requested"):
			cat.save_requested.connect(_save_game)
	_build_pickers()
	if stats:
		stats.stats_changed.connect(_refresh)
		if stats.has_signal("milestone_unlocked"):
			stats.milestone_unlocked.connect(_on_milestone_ui)
		_refresh()
	get_viewport().size_changed.connect(_on_viewport_resized)
	if feedback_label:
		feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if speech_bubble and speech_bubble.has_method("setup"):
		speech_bubble.setup(camera, cat)
	_on_viewport_resized()
	_update_theme_button()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if DisplayServer.is_touchscreen_available():
			return
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_tap_cat(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_tap_cat(st.position)

func _try_tap_cat(screen_pos: Vector2) -> void:
	if cat == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 450:
		return
	var space := get_viewport().world_2d.direct_space_state
	if space == null:
		return
	var world_pos := _screen_to_world(screen_pos)
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := space.intersect_point(query, 8)
	var under_cat := false
	for hit in hits:
		var n: Node = hit.get("collider") as Node
		var walk := n
		while walk:
			if walk == cat:
				under_cat = true
				break
			walk = walk.get_parent()
		if under_cat:
			break
	# Fallback: axis-aligned body box around the feet origin.
	if not under_cat:
		var feet: Vector2 = cat.global_position
		var box := Rect2(feet + Vector2(-22, -58), Vector2(44, 60))
		if box.has_point(world_pos):
			under_cat = true
	if not under_cat:
		return
	_last_tap_ms = now
	get_viewport().set_input_as_handled()
	_toggle_zoom()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if cat and is_instance_valid(cat):
		return cat.get_canvas_transform().affine_inverse() * screen_pos
	if camera:
		return camera.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos

func _toggle_zoom() -> void:
	if _zoomed:
		_exit_zoom()
	else:
		_enter_zoom()

func _fit_camera_metrics() -> void:
	var vis := get_viewport().get_visible_rect().size
	if vis.x < 1.0 or vis.y < 1.0:
		return
	# Fit the whole room, then nudge downward a little so HUD doesn't cover the floor.
	var z := minf(vis.x / ROOM_SIZE.x, vis.y / ROOM_SIZE.y)
	_cam_fit_zoom = Vector2(z, z)
	var visible_h := vis.y / z
	var extra := visible_h - ROOM_SIZE.y
	var y := ROOM_SIZE.y * 0.5
	if _portrait and extra > 0.0:
		# Keep the room optically between the HUD and the buttons.
		y = ROOM_SIZE.y * 0.5 + minf(extra * 0.06, 12.0)
	elif not _portrait:
		# Nudge up so the bottom action row covers less of the floor.
		y = ROOM_SIZE.y * 0.5 - 12.0
	_cam_fit_pos = Vector2(ROOM_SIZE.x * 0.5, y)

func _snap_camera() -> void:
	if camera == null:
		return
	_fit_camera_metrics()
	camera.zoom = _cam_fit_zoom
	camera.position = _cam_fit_pos
	camera.enabled = true
	camera.make_current()

func _process(delta: float) -> void:
	if camera == null or cat == null or _zoomed or not _cam_follow:
		return
	# Gentle pull toward the roaming cat, but stay mostly room-framed.
	var target := _cam_fit_pos.lerp(cat.global_position + Vector2(0, -20), 0.22)
	camera.position = camera.position.lerp(target, clampf(CAM_FOLLOW_SPEED * delta, 0.0, 1.0))

func _enter_zoom() -> void:
	if camera == null or cat == null:
		return
	_zoomed = true
	_close_pickers()
	_cam_follow = false
	if cat.has_method("set_autonomy_paused"):
		cat.set_autonomy_paused(true)
	if btn_zoom_back:
		btn_zoom_back.visible = true
	_play_ui()
	var focus: Vector2 = cat.get_focus_point() if cat.has_method("get_focus_point") else cat.global_position + Vector2(0, -36)
	var z := _cam_fit_zoom * (2.15 if _portrait else 1.9)
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera, "position", focus + Vector2(0, 8), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "zoom", z, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bubble_say("近距离看我～")

func _exit_zoom() -> void:
	_zoomed = false
	if btn_zoom_back:
		btn_zoom_back.visible = false
	_play_ui()
	_restore_camera(true)

func _on_zoom_back() -> void:
	if _zoomed:
		_exit_zoom()

func _restore_camera(animated: bool) -> void:
	if camera == null:
		return
	_fit_camera_metrics()
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	if not animated:
		_cam_follow = true
		_snap_camera()
		return
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera, "position", _cam_fit_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "zoom", _cam_fit_zoom, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.set_parallel(false)
	_cam_tween.tween_callback(func ():
		_cam_follow = true
		if cat and cat.has_method("set_autonomy_paused"):
			cat.set_autonomy_paused(false)
	)

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
	var root := $Root as Control
	if root:
		root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var theme := Theme.new()
		var f := PixelUtil.font()
		if f:
			theme.default_font = f
			theme.default_font_size = 16
			theme.set_font("font", "Label", f)
			theme.set_font("font", "Button", f)
			theme.set_font("font", "ProgressBar", f)
		root.theme = theme
	_apply_stats_card_style()
	_style_bar(mood_bar, Color(0.95, 0.55, 0.68))
	_style_bar(hunger_bar, Color(0.96, 0.72, 0.38))
	_style_bar(bond_bar, Color(0.68, 0.64, 0.94))
	for b in [btn_pet, btn_feed, btn_play, btn_theme, btn_zoom_back]:
		_style_button(b)

func _nine_tex(path: String, ml: int, mt: int, mr: int, mb: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PixelUtil.tex(path)
	sb.texture_margin_left = ml
	sb.texture_margin_top = mt
	sb.texture_margin_right = mr
	sb.texture_margin_bottom = mb
	return sb

func _apply_stats_card_style() -> void:
	if stats_card == null:
		return
	stats_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sb := _nine_tex("res://assets/pixel/ui/panel_mood.png", 12, 12, 12, 12)
	if sb.texture:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		stats_card.add_theme_stylebox_override("panel", sb)
	else:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(1.0, 0.965, 0.95, 0.94)
		panel.set_corner_radius_all(8)
		stats_card.add_theme_stylebox_override("panel", panel)

func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.78, 0.68, 0.66, 0.42)
	bg.set_corner_radius_all(2)
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	bg.set_border_width_all(1)
	bg.border_color = Color(0.45, 0.32, 0.34, 0.55)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16

func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var normal := _nine_tex("res://assets/pixel/ui/button.png", 10, 6, 10, 6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	var pressed := _nine_tex("res://assets/pixel/ui/button_pressed.png", 10, 6, 10, 6)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 4
	var disabled := normal.duplicate()
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.35, 0.25, 0.28))
	btn.add_theme_color_override("font_hover_color", Color(0.28, 0.18, 0.22))
	btn.add_theme_color_override("font_pressed_color", Color(0.22, 0.14, 0.16))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.45, 0.7))
	var f := PixelUtil.font()
	if f:
		btn.add_theme_font_override("font", f)

func _on_viewport_resized() -> void:
	var win := get_window()
	var wsize := Vector2(win.size)
	if wsize.x < 1.0 or wsize.y < 1.0:
		return
	var portrait_now := wsize.y > wsize.x
	var base := BASE_PORTRAIT if portrait_now else BASE_LANDSCAPE
	if win.content_scale_size != base:
		win.content_scale_size = base
	var vis := get_viewport().get_visible_rect().size
	_portrait = portrait_now
	_ui_scale = wsize.x / maxf(vis.x, 1.0)
	_apply_layout()

func _safe_insets() -> Vector4:
	var win := get_window()
	var scr_size := DisplayServer.screen_get_size(win.current_screen)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or absi(win.size.x - scr_size.x) > 4 or absi(win.size.y - scr_size.y) > 4:
		return Vector4.ZERO
	var k := 1.0 / maxf(_ui_scale, 0.01)
	var l := clampf(float(safe.position.x) * k, 0.0, 120.0)
	var t := clampf(float(safe.position.y) * k, 0.0, 120.0)
	var r := clampf(float(scr_size.x - safe.end.x) * k, 0.0, 120.0)
	var b := clampf(float(scr_size.y - safe.end.y) * k, 0.0, 120.0)
	return Vector4(l, t, r, b)

func _set_stats_fonts(title_fs: int, label_fs: int, label_w: float, bar_h: float) -> void:
	var panel := stats_card.get_node_or_null("StatsPanel")
	if panel == null:
		return
	var title := panel.get_node_or_null("Title") as Label
	if title:
		title.add_theme_font_size_override("font_size", title_fs)
	for row_name in ["MoodRow", "HungerRow", "BondRow"]:
		var row := panel.get_node_or_null(row_name)
		if row == null:
			continue
		for c in row.get_children():
			if c is Label:
				c.add_theme_font_size_override("font_size", label_fs)
				c.custom_minimum_size.x = label_w
			elif c is ProgressBar:
				c.custom_minimum_size.y = bar_h
				c.custom_minimum_size.x = 120.0
	(panel as VBoxContainer).add_theme_constant_override("separation", int(maxf(bar_h * 0.25, 4.0)))

func _apply_layout() -> void:
	if stats_card == null or buttons == null:
		return
	var ins := _safe_insets()
	var btn_list: Array = [btn_pet, btn_feed, btn_play, btn_theme]
	if _portrait:
		var m := 20.0
		safe_margin.add_theme_constant_override("margin_left", int(m + ins.x))
		safe_margin.add_theme_constant_override("margin_right", int(m + ins.z))
		safe_margin.add_theme_constant_override("margin_top", int(16.0 + ins.y))
		safe_margin.add_theme_constant_override("margin_bottom", int(22.0 + ins.w))
		stats_card.anchor_left = 0.0
		stats_card.anchor_right = 1.0
		stats_card.anchor_top = 0.0
		stats_card.anchor_bottom = 0.0
		stats_card.offset_left = 0.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 10.0
		_set_stats_fonts(22, 20, 72.0, 18.0)
		var bh := 96.0
		buttons.columns = 2
		buttons.anchor_left = 0.0
		buttons.anchor_right = 1.0
		buttons.anchor_top = 1.0
		buttons.anchor_bottom = 1.0
		buttons.offset_left = 0.0
		buttons.offset_right = 0.0
		buttons.offset_top = -(bh * 2.0 + 12.0)
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("h_separation", 12)
		buttons.add_theme_constant_override("v_separation", 10)
		for b in btn_list:
			if b:
				b.custom_minimum_size = Vector2(0, bh)
				b.add_theme_font_size_override("font_size", 28)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_zoom_back:
			btn_zoom_back.anchor_left = 0.5
			btn_zoom_back.anchor_right = 0.5
			btn_zoom_back.anchor_top = 1.0
			btn_zoom_back.anchor_bottom = 1.0
			btn_zoom_back.offset_left = -120.0
			btn_zoom_back.offset_right = 120.0
			btn_zoom_back.offset_bottom = -(bh * 2.0 + 12.0 + 12.0)
			btn_zoom_back.offset_top = btn_zoom_back.offset_bottom - 72.0
			btn_zoom_back.add_theme_font_size_override("font_size", 26)
		if speech_bubble and speech_bubble.has_method("set_metrics"):
			speech_bubble.set_metrics(26, 480.0)
	else:
		safe_margin.add_theme_constant_override("margin_left", int(28.0 + ins.x))
		safe_margin.add_theme_constant_override("margin_right", int(28.0 + ins.z))
		safe_margin.add_theme_constant_override("margin_top", int(16.0 + ins.y))
		safe_margin.add_theme_constant_override("margin_bottom", int(18.0 + ins.w))
		stats_card.anchor_left = 1.0
		stats_card.anchor_right = 1.0
		stats_card.anchor_top = 0.0
		stats_card.anchor_bottom = 0.0
		stats_card.offset_left = -340.0
		stats_card.offset_right = 0.0
		stats_card.offset_top = 0.0
		stats_card.offset_bottom = 10.0
		_set_stats_fonts(18, 18, 64.0, 16.0)
		var bh := 72.0
		buttons.columns = 4
		buttons.anchor_left = 0.5
		buttons.anchor_right = 0.5
		buttons.anchor_top = 1.0
		buttons.anchor_bottom = 1.0
		buttons.offset_left = -480.0
		buttons.offset_right = 480.0
		buttons.offset_top = -bh
		buttons.offset_bottom = 0.0
		buttons.add_theme_constant_override("h_separation", 14)
		buttons.add_theme_constant_override("v_separation", 8)
		for b in btn_list:
			if b:
				b.custom_minimum_size = Vector2(0, bh)
				b.add_theme_font_size_override("font_size", 22)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if btn_zoom_back:
			btn_zoom_back.anchor_left = 0.0
			btn_zoom_back.anchor_right = 0.0
			btn_zoom_back.anchor_top = 0.0
			btn_zoom_back.anchor_bottom = 0.0
			btn_zoom_back.offset_left = 0.0
			btn_zoom_back.offset_right = 180.0
			btn_zoom_back.offset_top = 0.0
			btn_zoom_back.offset_bottom = 64.0
			btn_zoom_back.add_theme_font_size_override("font_size", 22)
		if speech_bubble and speech_bubble.has_method("set_metrics"):
			speech_bubble.set_metrics(22, 420.0)
	if btn_theme:
		btn_theme.add_theme_font_size_override("font_size", 24 if _portrait else 20)
	_layout_pickers(ins)
	if not _zoomed:
		_restore_camera(false)

func _set_buttons_enabled(enabled: bool) -> void:
	btn_pet.disabled = not enabled
	btn_feed.disabled = not enabled
	btn_play.disabled = not enabled

func _on_busy(_action: String, _item: String = "") -> void:
	_set_buttons_enabled(false)

func _on_ready_again() -> void:
	_set_buttons_enabled(true)

func _bubble_say(text: String, soft: bool = true) -> void:
	if speech_bubble and speech_bubble.has_method("show_line"):
		speech_bubble.show_line(text, soft)
	elif feedback_label:
		feedback_label.text = text

func _on_pet() -> void:
	_close_pickers()
	if cat and cat.has_method("do_pet"):
		cat.do_pet()

func _on_feed() -> void:
	if food_picker == null:
		if cat and cat.has_method("do_feed"):
			cat.do_feed()
		return
	var open := not food_picker.visible
	_close_pickers()
	food_picker.visible = open
	_play_ui()

func _on_play() -> void:
	if toy_picker == null:
		if cat and cat.has_method("do_play"):
			cat.do_play()
		return
	var open := not toy_picker.visible
	_close_pickers()
	toy_picker.visible = open
	_play_ui()

func _on_food_picked(id: String) -> void:
	_close_pickers()
	if cat and cat.has_method("do_feed"):
		cat.do_feed(id)

func _on_toy_picked(id: String) -> void:
	_close_pickers()
	if cat and cat.has_method("do_play"):
		cat.do_play(id)

func _close_pickers() -> void:
	if food_picker:
		food_picker.visible = false
	if toy_picker:
		toy_picker.visible = false

func _on_pet_stroke(duration: float = 0.9) -> void:
	if pet_hand:
		pet_hand.play(duration)

func _build_pickers() -> void:
	var root := $Root
	var names: Array = []
	for id in CatProps.FOOD_ORDER:
		names.append(CatProps.FOODS[id]["name"])
	food_picker = PickPanel.new()
	food_picker.name = "FoodPicker"
	root.add_child(food_picker)
	food_picker.setup("想吃什么呢？", CatProps.FOOD_ORDER, names)
	food_picker.picked.connect(_on_food_picked)
	names = []
	for id in CatProps.TOY_ORDER:
		names.append(CatProps.TOYS[id]["name"])
	toy_picker = PickPanel.new()
	toy_picker.name = "ToyPicker"
	root.add_child(toy_picker)
	toy_picker.setup("玩什么呢？", CatProps.TOY_ORDER, names)
	toy_picker.picked.connect(_on_toy_picked)
	pet_hand = PetHand.new()
	pet_hand.name = "PetHand"
	root.add_child(pet_hand)
	pet_hand.setup(camera, cat)

func _layout_pickers(ins: Vector4) -> void:
	if food_picker == null:
		return
	for pk in [food_picker, toy_picker]:
		pk.anchor_top = 1.0
		pk.anchor_bottom = 1.0
		if _portrait:
			var bottom := -(96.0 * 2.0 + 12.0 + 22.0 + ins.w + 12.0)
			pk.anchor_left = 0.0
			pk.anchor_right = 1.0
			pk.offset_left = 20.0 + ins.x
			pk.offset_right = -(20.0 + ins.z)
			pk.offset_bottom = bottom
			pk.offset_top = bottom - 220.0
			pk.set_metrics(22, 220.0)
		else:
			var bottom := -(72.0 + 18.0 + ins.w + 10.0)
			pk.anchor_left = 0.5
			pk.anchor_right = 0.5
			pk.offset_left = -480.0
			pk.offset_right = 480.0
			pk.offset_bottom = bottom
			pk.offset_top = bottom - 180.0
			pk.set_metrics(20, 180.0)

func _on_theme() -> void:
	if room_cosmetics == null or stats == null:
		return
	var id := room_cosmetics.cycle_next(stats.bond)
	_play_ui()
	_update_theme_button()
	_bubble_say("房间换成「%s」啦" % room_cosmetics.theme_display_name(id))
	_save_game()

func _on_milestone_ui(_threshold: int, _title: String) -> void:
	_update_theme_button()
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
