extends SceneTree

func _init() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var game_state := HardwareEmpireState.new()
	game_state.name = "GameState"
	root.add_child(game_state)
	game_state.initialize_for_tests()
	var main_scene := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	for screen in ["dashboard", "employees", "inventory", "r&d", "products", "market", "contracts", "quality", "company", "settings", "workshop"]:
		main_scene._open_screen(screen)
		await process_frame
	main_scene.queue_free()
	game_state.start_tiny_workshop()
	var tiny_scene := preload("res://scenes/tiny_workshop.tscn").instantiate()
	root.add_child(tiny_scene)
	await process_frame
	tiny_scene._show_front_desk()
	await process_frame
	assert(tiny_scene.ui_layer.get_node("HUDRoot/TopHUD") != null)
	assert(tiny_scene.xp_bar != null)
	for station in ["front_desk", "parts_shelf", "repair_bench_1", "outgoing_shelf"]:
		tiny_scene._open_station(station)
		await process_frame
		assert(tiny_scene.panel.visible)
	tiny_scene._show_upgrades()
	assert(tiny_scene.panel.visible)
	tiny_scene._close_panel()
	assert(not tiny_scene.panel.visible)
	assert(tiny_scene.world != null and tiny_scene.world.visible)
	tiny_scene.queue_free()
	print("Hardware Empire UI smoke test passed")
	quit(0)
