extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "main missing")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui = main.get_node("UI")
	var buttons = main.get_node("UI/Root/SafeMargin/Layout/Buttons")
	assert(buttons is GridContainer, "Buttons should be GridContainer")
	# Portrait layout without DisplayServer resize (headless-safe)
	ui._portrait = true
	ui._zoomed = false
	ui._apply_layout()
	assert(buttons.columns == 2, "portrait columns")
	# Landscape
	ui._portrait = false
	ui._apply_layout()
	assert(buttons.columns == 4, "landscape columns")
	var card: PanelContainer = main.get_node("UI/Root/SafeMargin/Layout/StatsCard")
	var sb = card.get_theme_stylebox("panel")
	assert(sb != null)
	assert(sb.bg_color.a >= 0.9, "card opacity")
	var cat = main.get_node("%Cat")
	assert(cat.get_node_or_null("CatTapBody") != null, "tap body")
	assert(cat.has_method("get_focus_point"))
	var back = main.get_node("%BtnZoomBack")
	assert(back != null)
	# Zoom toggle without relying on tweens completing
	ui._zoomed = false
	ui._enter_zoom()
	assert(ui._zoomed == true)
	assert(back.visible == true)
	await process_frame
	ui._exit_zoom()
	assert(ui._zoomed == false)
	print("smoke_hud_zoom ok columns_land=", buttons.columns, " card_a=", sb.bg_color.a)
	quit(0)
