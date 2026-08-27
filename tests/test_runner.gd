extends SceneTree

var failures: int = 0

func _init() -> void:
	_check_equal(SimulationRules.calculate_job_reward(100.0, 0.8), 80.0, "job reward scales quality")
	_check_equal(SimulationRules.calculate_production_units(120.0, 30.0), 60, "production uses elapsed simulation time")
	_check_equal(SimulationRules.calculate_offline_income(3600.0, 10.0, 20.0), 200.0, "offline income aggregates")
	_check_equal(SimulationRules.station_status(4, 2, true, true, false, false), "OVERLOADED", "station detects overload")
	_check_equal(SimulationRules.station_status(0, 2, false, false, false, false), "STARVED", "station detects starvation")

	var grid := WorkshopGrid.new(8, 8)
	_check(grid.can_place(Vector2i(2, 2), Vector2i(2, 2)), "grid accepts free placement")
	_check(grid.place("bench", Vector2i(2, 2), Vector2i(2, 2)), "grid places station footprint")
	_check(not grid.can_place(Vector2i(2, 2), Vector2i(1, 1)), "grid rejects occupied placement")
	_check(grid.find_path(Vector2i(0, 0), Vector2i(5, 5)).size() > 1, "grid provides worker path")

	var state := HardwareEmpireState.new()
	state.initialize_for_tests()
	_check_equal(state.current_era, 1, "new game starts Era 1")
	_check_equal(state.workers.size(), 1, "new game has founder")
	_check_equal(state.jobs.size(), 5, "new game seeds five repair jobs")
	state.advance(20.0)
	_check(state.get_summary().completed_jobs >= 1, "simulation advances jobs without frame assumptions")
	var old_save := {"save_version":0, "money":400.0, "current_era":1}
	var migrated := state.migrate_save(old_save)
	_check_equal(int(migrated.get("save_version", 0)), 1, "save migration bumps schema")
	_check(migrated.has("research") and migrated.has("expansion_level"), "save migration fills new fields")
	state.free()

	if failures > 0:
		push_error("%d regression test(s) failed" % failures)
		quit(1)
	else:
		print("Hardware Empire regression tests passed")
		quit(0)

func _check(condition: bool, name: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + name)

func _check_equal(actual: Variant, expected: Variant, name: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [name, str(actual), str(expected)])
