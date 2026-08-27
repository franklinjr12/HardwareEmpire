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
	print("Hardware Empire UI smoke test passed")
	quit(0)
