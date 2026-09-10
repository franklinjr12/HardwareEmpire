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
	_check_equal(int(migrated.get("save_version", 0)), 2, "save migration bumps schema")
	_check(migrated.has("research") and migrated.has("expansion_level"), "save migration fills new fields")
	state.money = 50000.0
	for era_step in range(5):
		_check(state.advance_era(), "era progression step %d" % (era_step + 2))
	_check_equal(state.current_era, 6, "era progression reaches advanced company")
	_check(state.stations.size() >= 15, "era progression creates visible facility stations")
	_check(state.build_station("advanced_rd", Vector2(1920, 704)), "grid placement accepts free station tile")
	_check(state.hire_worker("qa_technician"), "role hiring unlocks specialist")
	state.contracts.append({"id":"test_contract", "name":"Test Order", "remaining":1, "units":1, "reward":100.0, "deadline":1.0, "age":0.0, "state":"active"})
	state.advance(2.0)
	_check_equal(state.contracts[-1].get("state", ""), "failed", "contract deadline applies penalty state")
	state.free()

	var tiny := HardwareEmpireState.new()
	tiny.initialize_tiny_workshop_for_tests()
	_check_equal(tiny.game_mode, "tiny_workshop", "tiny workshop mode initializes")
	_check_equal(tiny.get_tiny_jobs().size(), 3, "tiny workshop starts with three clients")
	var tiny_job: Dictionary = tiny.get_tiny_jobs()[0]
	var starting_cash := tiny.money
	_check(tiny.accept_tiny_service(str(tiny_job.get("id", ""))), "client request accepts and orders materials")
	_check(tiny.money < starting_cash and tiny.deliveries.size() == 2, "accepted service charges and creates deliveries")
	tiny.advance(8.0)
	tiny_job = tiny._find_job(str(tiny_job.get("id", "")))
	_check_equal(tiny_job.get("state", ""), "ready_for_parts", "materials arrive at shelf")
	_check(tiny.repair_shop.reserved_inventory.get("pcb", 0) == 1 and tiny.repair_shop.reserved_inventory.get("power_module", 0) == 1, "delivered parts stay reserved for accepted job")
	var tiny_components: Array[String] = ["pcb", "power_module"]
	_check(tiny.collect_tiny_materials(str(tiny_job.get("id", "")), tiny_components), "player starts material collection")
	tiny.advance(3.0)
	_check_equal(tiny_job.get("state", ""), "parts_collected", "player collects selected materials")
	_check(tiny.start_tiny_repair(str(tiny_job.get("id", ""))), "player starts selected repair")
	tiny.advance(3.0)
	_check_equal(tiny_job.get("state", ""), "diagnosing", "player reaches bench and diagnosis starts")
	tiny.advance(4.0)
	_check_equal(tiny_job.get("state", ""), "awaiting_repair_choice", "diagnosis reveals repair decision")
	_check(tiny.start_tiny_repair_method(str(tiny_job.get("id", "")), "component_repair"), "player selects component repair method")
	tiny.advance(21.0)
	_check_equal(tiny_job.get("state", ""), "ready_for_pickup", "repair completes at bench")
	_check(tiny.collect_tiny_device(str(tiny_job.get("id", ""))), "player picks up repaired device")
	tiny.advance(1.0)
	_check_equal(tiny_job.get("state", ""), "ready_for_delivery", "device becomes carried outbound item")
	_check(tiny.deliver_tiny_repair(str(tiny_job.get("id", ""))), "player starts delivery")
	tiny.advance(4.0)
	_check_equal(tiny_job.get("state", ""), "completed", "outcome port pays completed repair")
	_check(tiny.technician_xp > 0.0 and tiny.repair_mastery.get("power_repair", 0) == 1, "completion rewards XP and repair mastery")
	var shop_snapshot: Dictionary = tiny.repair_shop.serialize()
	var restored_shop := RepairShopSimulation.new(tiny.catalog)
	restored_shop.restore(shop_snapshot)
	_check_equal(restored_shop.get_job(str(tiny_job.get("id", ""))).get("state", ""), "completed", "repair shop save restores job state")
	_check_equal(int(restored_shop.money), int(tiny.money), "repair shop save restores cash")
	tiny.free()

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
