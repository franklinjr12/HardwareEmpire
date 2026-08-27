class_name HardwareEmpireState
extends Node

signal state_changed
signal event_logged(message: String, severity: String)
signal item_completed(item_id: String, item_type: String)

const SAVE_VERSION: int = 1
const MAX_OFFLINE_SECONDS: float = 8.0 * 60.0 * 60.0
const TICK_SECONDS: float = 0.25
const WORLD_ORIGIN: Vector2 = Vector2(32.0, 32.0)

var catalog: Dictionary = {}
var workers: Array = []
var stations: Array = []
var jobs: Array = []
var contracts: Array = []
var inventory: Dictionary = {}
var research: Dictionary = {}
var deliveries: Array = []
var quality_hold: Array = []
var milestones: Dictionary = {}
var navigation_grid: WorkshopGrid = WorkshopGrid.new(70, 34)

var money: float = 250.0
var reputation: float = 1.0
var knowledge: float = 0.0
var current_era: int = 1
var expansion_level: int = 1
var simulation_time: float = 0.0
var time_scale: float = 1.0
var production_enabled: bool = false
var last_saved_at: float = 0.0
var last_offline_report: String = ""

var _job_counter: int = 0
var _worker_counter: int = 0
var _station_counter: int = 0
var _contract_counter: int = 0
var _supplier_timer: float = 25.0
var _job_timer: float = 8.0
var _product_timer: float = 18.0
var _contract_timer: float = 30.0
var _simulation_accumulator: float = 0.0

const STATION_POSITIONS: Dictionary = {
	"incoming_shelf": Vector2(112, 112),
	"parts_shelf": Vector2(112, 304),
	"repair_bench_1": Vector2(336, 176),
	"outgoing_shelf": Vector2(560, 112),
	"diagnostics_bench": Vector2(784, 176),
	"repair_bench_2": Vector2(336, 368),
	"oscilloscope_bench": Vector2(1024, 176),
	"pcb_design_station": Vector2(1024, 368),
	"reflow_station": Vector2(1248, 176),
	"firmware_desk": Vector2(1248, 368),
	"assembly_station": Vector2(560, 560),
	"testing_station": Vector2(784, 560),
	"packaging_station": Vector2(1024, 560),
	"warehouse_shelf": Vector2(1248, 560),
	"qa_lab": Vector2(1456, 368),
	"calibration_bench": Vector2(1456, 560),
	"shipping_area": Vector2(1680, 560),
	"advanced_rd": Vector2(1680, 176)
}

const ERA_ROOM_NAMES: Array = [
	"Garage",
	"Repair floor",
	"Engineering wing",
	"Production floor",
	"QA + warehouse",
	"Technology campus"
]

func _ready() -> void:
	_load_catalog()
	if not load_game():
		new_game()

func initialize_for_tests() -> void:
	_load_catalog()
	new_game()

func new_game() -> void:
	workers.clear()
	stations.clear()
	jobs.clear()
	contracts.clear()
	deliveries.clear()
	quality_hold.clear()
	navigation_grid = WorkshopGrid.new(70, 34)
	inventory = {"microcontroller": 12, "sensor": 16, "pcb": 10, "power_module": 8}
	research = {"active_id": "", "completed": [], "progress": 0.0}
	milestones = {}
	money = 250.0
	reputation = 1.0
	knowledge = 0.0
	current_era = 1
	expansion_level = 1
	simulation_time = 0.0
	production_enabled = false
	last_offline_report = "New workshop opened."
	_job_counter = 0
	_worker_counter = 0
	_station_counter = 0
	_contract_counter = 0
	_job_timer = 8.0
	_supplier_timer = 25.0
	_product_timer = 18.0
	_contract_timer = 30.0
	_add_initial_stations()
	_add_worker("founder", "Founder", Vector2(272, 176))
	for i in range(5):
		_create_repair_job()
	_refresh_milestones()
	state_changed.emit()

func _load_catalog() -> void:
	var path := "res://data/content.json"
	if not FileAccess.file_exists(path):
		push_error("Missing data catalog: " + path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		catalog = parsed
	else:
		push_error("Invalid content catalog JSON")

func _add_initial_stations() -> void:
	for station_id in ["incoming_shelf", "parts_shelf", "repair_bench_1", "outgoing_shelf"]:
		_add_station(station_id)

func _add_station(definition_id: String, custom_position: Vector2 = Vector2(-1, -1)) -> String:
	var definition: Dictionary = _station_definition(definition_id)
	if definition.is_empty():
		return ""
	_station_counter += 1
	var station_id := definition_id
	if not _find_station(station_id).is_empty():
		station_id = definition_id + "_" + str(_station_counter)
	var position: Vector2 = custom_position if custom_position.x >= 0.0 else _position_for_station(definition_id)
	var station := {
		"id": station_id,
		"definition_id": definition_id,
		"name": definition.get("name", definition_id),
		"kind": definition.get("kind", "bench"),
		"zone": definition.get("zone", "workshop"),
		"process": definition.get("process", "repair"),
		"position": position,
		"queue": [],
		"current": "",
		"progress": 0.0,
		"tier": 1,
		"capacity": int(definition.get("capacity", 1)),
		"base_duration": float(definition.get("duration", 10.0)),
		"cost": float(definition.get("cost", 0.0)),
		"color": str(definition.get("color", "#64748b")),
		"machine": str(definition.get("machine", "")),
		"status": "IDLE",
		"unlocked": true,
		"maintenance": 1.0,
		"is_machine": definition.get("kind", "") == "machine"
	}
	stations.append(station)
	navigation_grid.place(station_id, navigation_grid.world_to_cell(position), Vector2i(3, 2))
	return station_id

func _station_definition(definition_id: String) -> Dictionary:
	for definition in catalog.get("stations", []):
		if definition.get("id", "") == definition_id:
			return definition
	return {}

func _role_definition(role_id: String) -> Dictionary:
	for definition in catalog.get("roles", []):
		if definition.get("id", "") == role_id:
			return definition
	return {}

func _product_definition(product_id: String) -> Dictionary:
	for definition in catalog.get("products", []):
		if definition.get("id", "") == product_id:
			return definition
	return {}

func _position_for_station(definition_id: String) -> Vector2:
	if STATION_POSITIONS.has(definition_id):
		return STATION_POSITIONS[definition_id]
	var index := stations.size()
	return Vector2(336 + (index % 6) * 224, 752 + (index / 6) * 128)

func _find_station(station_id: String) -> Dictionary:
	for station in stations:
		if station.get("id", "") == station_id:
			return station
	return {}

func _find_job(job_id: String) -> Dictionary:
	for job in jobs:
		if job.get("id", "") == job_id:
			return job
	return {}

func _find_worker(worker_id: String) -> Dictionary:
	for worker in workers:
		if worker.get("id", "") == worker_id:
			return worker
	return {}

func _add_worker(role_id: String, display_name: String = "", spawn_position: Vector2 = Vector2(272, 176)) -> String:
	var role: Dictionary = _role_definition(role_id)
	_worker_counter += 1
	var worker_id := "worker_%d" % _worker_counter
	var worker_name := display_name if not display_name.is_empty() else "%s %d" % [role.get("name", "Technician"), _worker_counter]
	workers.append({
		"id": worker_id,
		"name": worker_name,
		"role_id": role_id,
		"role": role.get("name", "Technician"),
		"color": str(role.get("color", "#65c18c")),
		"skill": float(role.get("skill", 1.0)),
		"position": spawn_position,
		"home_position": spawn_position,
		"state": "IDLE",
		"animation": "idle",
		"assignment": "",
		"carrying": "",
		"training": 0.0,
		"walk_cycle": 0.0,
		"target": spawn_position,
		"path": []
	})
	return worker_id

func _create_repair_job() -> String:
	_job_counter += 1
	var pipeline: Array = ["repair", "outgoing"]
	if current_era >= 2:
		pipeline = ["diagnostics", "repair"]
		if current_era >= 4:
			pipeline.append("testing")
		pipeline.append("outgoing")
	var job_id := "repair_%03d" % _job_counter
	var job := {
		"id": job_id,
		"kind": "repair",
		"label": ["Laptop repair", "Power supply repair", "Console repair", "Tablet repair"][_job_counter % 4],
		"visual_kind": ["device_laptop", "device_board", "device_console", "device_tablet"][_job_counter % 4],
		"pipeline": pipeline,
		"stage": 0,
		"station_id": "",
		"state": "incoming",
		"progress": 0.0,
		"quality": 0.86 + float(_job_counter % 3) * 0.035,
		"base_reward": 72.0 + float(_job_counter % 3) * 18.0,
		"created_at": simulation_time,
		"contract_id": ""
	}
	jobs.append(job)
	return job_id

func _create_product(product_id: String = "temperature_sensor") -> String:
	var definition := _product_definition(product_id)
	if definition.is_empty():
		return ""
	var components: Dictionary = definition.get("components", {})
	for component_id in components:
		if int(inventory.get(component_id, 0)) < int(components[component_id]):
			return ""
	for component_id in components:
		inventory[component_id] = int(inventory.get(component_id, 0)) - int(components[component_id])
	_job_counter += 1
	var product_id_runtime := "product_%03d" % _job_counter
	var product := {
		"id": product_id_runtime,
		"kind": "product",
		"product_id": product_id,
		"label": definition.get("name", product_id),
		"visual_kind": "product_" + str(definition.get("family", "sensor")),
		"pipeline": definition.get("pipeline", []),
		"stage": 0,
		"station_id": "",
		"state": "incoming",
		"progress": 0.0,
		"quality": float(definition.get("quality", 0.85)),
		"base_reward": float(definition.get("price", 100.0)),
		"created_at": simulation_time,
		"contract_id": _active_contract_id()
	}
	jobs.append(product)
	return product_id_runtime

func _active_contract_id() -> String:
	for contract in contracts:
		if contract.get("state", "") == "active" and int(contract.get("remaining", 0)) > 0:
			return str(contract.get("id", ""))
	return ""

func advance(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_simulation_accumulator += delta_seconds * time_scale
	var changed := false
	while _simulation_accumulator >= TICK_SECONDS:
		_simulation_accumulator -= TICK_SECONDS
		_simulate_tick(TICK_SECONDS)
		changed = true
	if changed:
		state_changed.emit()

func _simulate_tick(delta_seconds: float) -> void:
	simulation_time += delta_seconds
	_job_timer -= delta_seconds
	_supplier_timer -= delta_seconds
	_product_timer -= delta_seconds
	_contract_timer -= delta_seconds
	if _job_timer <= 0.0:
		_job_timer = 14.0 if current_era < 3 else 9.0
		_create_repair_job()
	if _supplier_timer <= 0.0:
		_supplier_timer = 48.0
		_receive_delivery()
	if current_era >= 4 and production_enabled and _product_timer <= 0.0:
		_product_timer = 20.0
		var product_ids: Array = ["temperature_sensor"]
		if current_era >= 5:
			product_ids.append("farming_drone_module")
		if current_era >= 6:
			product_ids.append("industrial_controller")
		_create_product(product_ids[int(simulation_time) % product_ids.size()])
	if current_era >= 5 and _contract_timer <= 0.0:
		_contract_timer = 100.0
		_offer_contract()
	_dispatch_incoming_jobs()
	_assign_workers()
	_update_workers(delta_seconds)
	_process_stations(delta_seconds)
	_process_research(delta_seconds)
	_process_deliveries(delta_seconds)
	_process_contracts(delta_seconds)
	_refresh_milestones()

func _dispatch_incoming_jobs() -> void:
	for job in jobs:
		if job.get("state", "") != "incoming":
			continue
		var pipeline: Array = job.get("pipeline", [])
		var stage := int(job.get("stage", 0))
		if stage >= pipeline.size():
			continue
		var process := str(pipeline[stage])
		var station := _station_for_process(process)
		if station.is_empty():
			job["state"] = "blocked"
			continue
		var queue: Array = station.get("queue", [])
		if queue.size() < int(station.get("capacity", 1)) * 2:
			queue.append(job["id"])
			station["queue"] = queue
			job["station_id"] = station["id"]
			job["state"] = "queued"

func _station_for_process(process: String) -> Dictionary:
	for station in stations:
		if station.get("unlocked", false) and station.get("process", "") == process:
			return station
	return {}

func _assign_workers() -> void:
	for worker in workers:
		var assignment := str(worker.get("assignment", ""))
		if not assignment.is_empty():
			var assigned_station := _find_station(assignment)
			if not assigned_station.is_empty() and (not str(assigned_station.get("current", "")).is_empty() or assigned_station.get("queue", []).size() > 0):
				continue
			worker["assignment"] = ""
			worker["carrying"] = ""
			worker["state"] = "IDLE"
			worker["animation"] = "idle"
	for station in stations:
		if not station.get("unlocked", false) or station.get("is_machine", false):
			continue
		if str(station.get("current", "")).is_empty() and station.get("queue", []).is_empty():
			continue
		if _worker_for_station(str(station.get("id", ""))).is_empty():
			var candidate := _best_available_worker(station)
			if not candidate.is_empty():
				candidate["assignment"] = station["id"]
				candidate["state"] = "MOVING_TO_STATION"
				candidate["animation"] = "walk"
				candidate["target"] = station["position"]
				var start_cell := navigation_grid.world_to_cell(candidate.get("position", Vector2.ZERO))
				var target_cell := navigation_grid.world_to_cell(station.get("position", Vector2.ZERO)) + Vector2i(-2, 2)
				candidate["path"] = navigation_grid.find_path(start_cell, target_cell)

func _best_available_worker(station: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for worker in workers:
		if not str(worker.get("assignment", "")).is_empty():
			continue
		if not _worker_can_run(worker, station):
			continue
		var distance: float = worker.get("position", Vector2.ZERO).distance_to(station.get("position", Vector2.ZERO))
		if distance < best_distance:
			best = worker
			best_distance = distance
	return best

func _worker_can_run(worker: Dictionary, station: Dictionary) -> bool:
	var role_id := str(worker.get("role_id", ""))
	var process := str(station.get("process", ""))
	if role_id in ["founder", "junior_technician", "senior_technician"]:
		return process in ["repair", "diagnostics", "component_pick"]
	if role_id == "diagnostics_technician":
		return process in ["diagnostics", "testing", "calibration"]
	if role_id in ["electronics_specialist", "pcb_designer", "firmware_engineer"]:
		return process in ["oscilloscope", "pcb_design", "pcb_assembly", "reflow", "firmware", "assembly"]
	if role_id == "qa_technician":
		return process in ["testing", "qa", "calibration"]
	if role_id == "production_operator":
		return process in ["component_pick", "pcb_assembly", "reflow", "assembly", "packaging", "shipping"]
	return true

func _worker_for_station(station_id: String) -> Dictionary:
	for worker in workers:
		if worker.get("assignment", "") == station_id:
			return worker
	return {}

func _update_workers(delta_seconds: float) -> void:
	for worker in workers:
		worker["walk_cycle"] = float(worker.get("walk_cycle", 0.0)) + delta_seconds * 8.0
		var assignment := str(worker.get("assignment", ""))
		if assignment.is_empty():
			worker["state"] = "IDLE"
			worker["animation"] = "idle"
			worker["carrying"] = ""
			continue
		var station := _find_station(assignment)
		if station.is_empty():
			continue
		var work_target: Vector2 = station.get("position", worker.get("position", Vector2.ZERO)) + Vector2(-48, 46)
		var target: Vector2 = work_target
		var path: Array = worker.get("path", [])
		if path.size() > 1:
			var waypoint: Vector2 = navigation_grid.cell_to_world(path[1])
			if worker.get("position", Vector2.ZERO).distance_to(waypoint) <= 10.0:
				path.pop_front()
				worker["path"] = path
			else:
				target = waypoint
		worker["target"] = target
		var position: Vector2 = worker.get("position", Vector2.ZERO)
		var distance := position.distance_to(target)
		if distance > 8.0:
			worker["position"] = position.move_toward(target, 96.0 * delta_seconds)
			worker["state"] = "MOVING_TO_STATION"
			worker["animation"] = "carry" if not str(worker.get("carrying", "")).is_empty() else "walk"
		else:
			worker["position"] = target
			worker["state"] = "WORKING"
			worker["animation"] = "work"
			worker["training"] = min(100.0, float(worker.get("training", 0.0)) + delta_seconds * 0.2)
			var current_id := str(station.get("current", ""))
			if not current_id.is_empty():
				var job := _find_job(current_id)
				worker["carrying"] = job.get("visual_kind", "")

func _process_stations(delta_seconds: float) -> void:
	for station in stations:
		if not station.get("unlocked", false):
			continue
		var queue: Array = station.get("queue", [])
		if str(station.get("current", "")).is_empty() and not queue.is_empty():
			station["current"] = queue.pop_front()
			station["queue"] = queue
			station["progress"] = 0.0
		var current_id := str(station.get("current", ""))
		var has_input := not current_id.is_empty()
		if not has_input:
			station["status"] = "OVERLOADED" if queue.size() > int(station.get("capacity", 1)) else "IDLE"
			continue
		var worker := _worker_for_station(str(station.get("id", "")))
		var worker_ready: bool = not worker.is_empty() and worker.get("state", "") == "WORKING"
		var machine_ready := bool(station.get("is_machine", false)) and float(station.get("maintenance", 1.0)) > 0.0
		if not worker_ready and not machine_ready:
			station["status"] = "WAITING"
			continue
		var speed := float(worker.get("skill", 1.0)) if worker_ready else 1.0
		speed *= 0.75 + float(station.get("tier", 1)) * 0.25
		station["progress"] = float(station.get("progress", 0.0)) + delta_seconds * speed / max(0.1, float(station.get("base_duration", 10.0)))
		station["status"] = "PROCESSING"
		if float(station.get("progress", 0.0)) >= 1.0:
			_complete_station_work(station, current_id, worker)
		var capacity := int(station.get("capacity", 1))
		if queue.size() > capacity:
			station["status"] = "OVERLOADED"

func _complete_station_work(station: Dictionary, job_id: String, worker: Dictionary) -> void:
	var job := _find_job(job_id)
	if job.is_empty():
		station["current"] = ""
		station["progress"] = 0.0
		return
	var skill := float(worker.get("skill", 1.0)) if not worker.is_empty() else 1.0
	job["quality"] = SimulationRules.quality_after_process(float(job.get("quality", 0.85)), skill)
	var pipeline: Array = job.get("pipeline", [])
	job["stage"] = int(job.get("stage", 0)) + 1
	station["current"] = ""
	station["progress"] = 0.0
	job["station_id"] = ""
	job["progress"] = 0.0
	if not worker.is_empty():
		worker["assignment"] = ""
		worker["state"] = "IDLE"
		worker["animation"] = "idle"
		worker["carrying"] = ""
	if int(job.get("stage", 0)) >= pipeline.size():
		_finish_job(job)
		return
	var next_process := str(pipeline[int(job.get("stage", 0))])
	if next_process == "outgoing":
		_finish_job(job)
		return
	if next_process == "qa" and float(job.get("quality", 0.0)) < 0.72:
		job["state"] = "quality_hold"
		quality_hold.append(job["id"])
		return
	var next_station := _station_for_process(next_process)
	if next_station.is_empty():
		job["state"] = "blocked"
		event_logged.emit("%s waiting for %s" % [job.get("label", "Item"), next_process], "warning")
		return
	var next_queue: Array = next_station.get("queue", [])
	if next_queue.size() >= int(next_station.get("capacity", 1)) * 3:
		job["state"] = "blocked"
		return
	next_queue.append(job["id"])
	next_station["queue"] = next_queue
	job["station_id"] = next_station["id"]
	job["state"] = "queued"

func _finish_job(job: Dictionary) -> void:
	job["state"] = "completed"
	job["station_id"] = "outgoing_shelf" if job.get("kind", "") == "repair" else "shipping_area"
	var reward := SimulationRules.calculate_job_reward(float(job.get("base_reward", 0.0)), float(job.get("quality", 0.85)))
	money += reward
	reputation = clamp(reputation + (0.025 if float(job.get("quality", 0.85)) >= 0.75 else -0.02), 0.0, 100.0)
	knowledge += 0.15 if job.get("kind", "") == "repair" else 0.35
	if job.get("kind", "") == "product":
		_complete_contract_unit(str(job.get("contract_id", "")))
	item_completed.emit(str(job.get("id", "")), str(job.get("kind", "")))

func _complete_contract_unit(contract_id: String) -> void:
	if contract_id.is_empty():
		return
	var contract := _find_contract(contract_id)
	if contract.is_empty():
		return
	contract["remaining"] = max(0, int(contract.get("remaining", 0)) - 1)
	if int(contract.get("remaining", 0)) == 0:
		contract["state"] = "completed"
		money += float(contract.get("reward", 0.0))
		reputation += 0.5
		event_logged.emit("Contract complete: %s" % contract.get("name", "Order"), "success")

func _find_contract(contract_id: String) -> Dictionary:
	for contract in contracts:
		if contract.get("id", "") == contract_id:
			return contract
	return {}

func _process_research(delta_seconds: float) -> void:
	var active_id := str(research.get("active_id", ""))
	if active_id.is_empty():
		return
	var definition := _research_definition(active_id)
	if definition.is_empty():
		research["active_id"] = ""
		return
	research["progress"] = float(research.get("progress", 0.0)) + delta_seconds * max(0.1, knowledge / 4.0)
	if float(research.get("progress", 0.0)) >= float(definition.get("duration", 60.0)):
		var completed: Array = research.get("completed", [])
		completed.append(active_id)
		research["completed"] = completed
		research["active_id"] = ""
		research["progress"] = 0.0
		knowledge += float(definition.get("cost", 1.0))
		event_logged.emit("Research complete: %s" % definition.get("name", active_id), "success")

func _research_definition(research_id: String) -> Dictionary:
	for definition in catalog.get("research", []):
		if definition.get("id", "") == research_id:
			return definition
	return {}

func _process_deliveries(delta_seconds: float) -> void:
	for delivery in deliveries:
		delivery["progress"] = min(1.0, float(delivery.get("progress", 0.0)) + delta_seconds / float(delivery.get("duration", 12.0)))
	for delivery in deliveries.duplicate():
		if float(delivery.get("progress", 0.0)) >= 1.0:
			var component_id := str(delivery.get("component_id", ""))
			inventory[component_id] = int(inventory.get(component_id, 0)) + int(delivery.get("quantity", 0))
			deliveries.erase(delivery)
			event_logged.emit("Delivery arrived: %s" % component_id, "success")

func _process_contracts(delta_seconds: float) -> void:
	for contract in contracts:
		if contract.get("state", "") != "active":
			continue
		contract["age"] = float(contract.get("age", 0.0)) + delta_seconds
		if float(contract.get("age", 0.0)) >= float(contract.get("deadline", 180.0)) and int(contract.get("remaining", 0)) > 0:
			contract["state"] = "failed"
			reputation = max(0.0, reputation - 0.75)
			event_logged.emit("Contract failed: %s" % contract.get("name", "Order"), "warning")

func _receive_delivery() -> void:
	var component_ids: Array = ["microcontroller", "sensor", "pcb", "power_module"]
	var component_id := str(component_ids[int(simulation_time) % component_ids.size()])
	deliveries.append({"id":"delivery_%d" % int(simulation_time), "component_id":component_id, "quantity":8 + current_era * 2, "progress":0.0, "duration":12.0})

func _offer_contract() -> void:
	for definition in catalog.get("contracts", []):
		if int(definition.get("era", 1)) <= current_era:
			var already_offered := false
			for existing in contracts:
				if existing.get("definition_id", "") == definition.get("id", "") and existing.get("state", "") == "active":
					already_offered = true
			if not already_offered:
				_contract_counter += 1
				contracts.append({"id":"contract_%d" % _contract_counter, "definition_id":definition.get("id", ""), "name":definition.get("name", "Contract"), "units":int(definition.get("units", 1)), "remaining":int(definition.get("units", 1)), "reward":float(definition.get("reward", 0.0)), "deadline":float(definition.get("deadline", 180.0)), "age":0.0, "state":"offered"})
				break

func _refresh_milestones() -> void:
	milestones["repair_started"] = jobs.size() > 0
	milestones["staffed"] = workers.size() >= 2
	milestones["engineering"] = current_era >= 3
	milestones["manufacturing"] = current_era >= 4
	milestones["quality"] = current_era >= 5
	milestones["advanced"] = current_era >= 6

func hire_worker(role_id: String = "junior_technician") -> bool:
	var cost := 180.0 + float(workers.size() - 1) * 75.0
	if money < cost:
		return false
	var role := _role_definition(role_id)
	if role.is_empty() or int(_role_era(role_id)) > current_era:
		return false
	money -= cost
	_add_worker(role_id)
	event_logged.emit("Hired %s" % role.get("name", "technician"), "success")
	state_changed.emit()
	return true

func _role_era(role_id: String) -> int:
	if role_id in ["founder", "junior_technician", "senior_technician"]:
		return 1
	if role_id == "diagnostics_technician":
		return 2
	if role_id in ["electronics_specialist", "pcb_designer", "firmware_engineer"]:
		return 3
	if role_id in ["qa_technician", "production_operator"]:
		return 4
	return 5

func upgrade_station(station_id: String) -> bool:
	var station := _find_station(station_id)
	if station.is_empty():
		return false
	var cost := 160.0 * float(station.get("tier", 1))
	if money < cost:
		return false
	money -= cost
	station["tier"] = int(station.get("tier", 1)) + 1
	station["capacity"] = int(station.get("capacity", 1)) + 1
	station["maintenance"] = 1.0
	event_logged.emit("%s upgraded to tier %d" % [station.get("name", "Station"), station["tier"]], "success")
	state_changed.emit()
	return true

func build_station(definition_id: String, preferred_position: Vector2 = Vector2(-1, -1)) -> bool:
	var definition := _station_definition(definition_id)
	if definition.is_empty() or int(definition.get("era", 1)) > current_era:
		return false
	var cost := float(definition.get("cost", 0.0))
	if money < cost:
		return false
	var position := preferred_position.snapped(Vector2(32, 32)) if preferred_position.x >= 0.0 else _find_free_position()
	if preferred_position.x >= 0.0 and not _position_is_free(position):
		return false
	if position.x < 0.0:
		return false
	money -= cost
	_add_station(definition_id, position)
	event_logged.emit("Built %s" % definition.get("name", definition_id), "success")
	state_changed.emit()
	return true

func _position_is_free(position: Vector2) -> bool:
	if position.x < 64.0 or position.y < 64.0 or position.x > 1984.0 or position.y > 920.0:
		return false
	for station in stations:
		if station.get("position", Vector2.ZERO).distance_to(position) < 110.0:
			return false
	return true

func _find_free_position() -> Vector2:
	for row in range(1, 8):
		for column in range(1, 10):
			var candidate := Vector2(112 + column * 160, 112 + row * 112)
			var clear := true
			for station in stations:
				if station.get("position", Vector2.ZERO).distance_to(candidate) < 110.0:
					clear = false
			if clear:
				return candidate
	return Vector2(-1, -1)

func expand_workshop() -> bool:
	var cost := 450.0 * float(expansion_level)
	if money < cost or expansion_level >= 6:
		return false
	money -= cost
	expansion_level += 1
	event_logged.emit("Workshop expanded: %s" % ERA_ROOM_NAMES[expansion_level - 1], "success")
	state_changed.emit()
	return true

func advance_era() -> bool:
	if current_era >= 6:
		return false
	var next_era := current_era + 1
	var definition: Dictionary = catalog.get("eras", [])[next_era - 1]
	var cost := float(definition.get("cost", 0.0))
	if money < cost:
		return false
	money -= cost
	current_era = next_era
	expansion_level = max(expansion_level, current_era)
	if current_era >= 4:
		production_enabled = true
	_unlock_era_stations()
	if current_era >= 2:
		for job in jobs:
			if job.get("kind", "") == "repair" and job.get("state", "") == "incoming":
				job["pipeline"] = ["diagnostics", "repair", "testing", "outgoing"] if current_era >= 4 else ["diagnostics", "repair", "outgoing"]
	event_logged.emit("Era %d unlocked: %s" % [current_era, definition.get("name", "" )], "success")
	state_changed.emit()
	return true

func _unlock_era_stations() -> void:
	for definition in catalog.get("stations", []):
		var definition_id := str(definition.get("id", ""))
		if int(definition.get("era", 1)) <= current_era and _find_station(definition_id).is_empty():
			if definition_id in ["incoming_shelf", "parts_shelf", "repair_bench_1", "outgoing_shelf"]:
				continue
			_add_station(definition_id)

func start_research(research_id: String) -> bool:
	var definition := _research_definition(research_id)
	if definition.is_empty() or int(definition.get("era", 1)) > current_era:
		return false
	var completed: Array = research.get("completed", [])
	if research_id in completed or not str(research.get("active_id", "")).is_empty():
		return false
	var cost := float(definition.get("cost", 1.0))
	if knowledge < cost:
		return false
	knowledge -= cost
	research["active_id"] = research_id
	research["progress"] = 0.0
	event_logged.emit("Research started: %s" % definition.get("name", research_id), "info")
	state_changed.emit()
	return true

func accept_contract(contract_id: String) -> bool:
	var contract := _find_contract(contract_id)
	if contract.is_empty() or contract.get("state", "") != "offered":
		return false
	contract["state"] = "active"
	event_logged.emit("Accepted contract: %s" % contract.get("name", "Order"), "info")
	state_changed.emit()
	return true

func relocate_station(station_id: String, position: Vector2) -> bool:
	var station := _find_station(station_id)
	if station.is_empty() or position.x < 64.0 or position.y < 64.0:
		return false
	var snapped_position := position.snapped(Vector2(32, 32))
	var old_position: Vector2 = station.get("position", Vector2.ZERO)
	navigation_grid.remove(station_id)
	if not _position_is_free(snapped_position):
		navigation_grid.place(station_id, navigation_grid.world_to_cell(old_position), Vector2i(3, 2))
		return false
	station["position"] = snapped_position
	navigation_grid.place(station_id, navigation_grid.world_to_cell(snapped_position), Vector2i(3, 2))
	event_logged.emit("Relocated %s" % station.get("name", "Station"), "info")
	state_changed.emit()
	return true

func set_time_scale(value: float) -> void:
	time_scale = clamp(value, 0.25, 4.0)

func get_station_at(position: Vector2) -> Dictionary:
	for station in stations:
		if station.get("position", Vector2.ZERO).distance_to(position) <= 64.0:
			return station
	return {}

func get_worker_at(position: Vector2) -> Dictionary:
	for worker in workers:
		if worker.get("position", Vector2.ZERO).distance_to(position) <= 24.0:
			return worker
	return {}

func get_item_at(position: Vector2) -> Dictionary:
	for job in jobs:
		var item_position := get_item_position(job)
		if item_position.distance_to(position) <= 22.0:
			return job
	return {}

func get_item_position(job: Dictionary) -> Vector2:
	var station_id := str(job.get("station_id", ""))
	if station_id == "outgoing_shelf":
		return _position_for_station("outgoing_shelf") + Vector2(32 + (int(job.get("id", "").hash()) % 4) * 12, 40)
	if station_id == "shipping_area":
		return _position_for_station("shipping_area") + Vector2(32 + (int(job.get("id", "").hash()) % 4) * 12, 40)
	if not station_id.is_empty():
		var station := _find_station(station_id)
		if not station.is_empty():
			var queue: Array = station.get("queue", [])
			var index := queue.find(job.get("id", ""))
			if station.get("current", "") == job.get("id", ""):
				return station.get("position", Vector2.ZERO) + Vector2(0, -48)
			return station.get("position", Vector2.ZERO) + Vector2(-38 + max(0, index) * 20, 46)
	return _position_for_station("incoming_shelf") + Vector2(30 + (int(job.get("id", "").hash()) % 5) * 16, 44)

func get_item_visuals() -> Array:
	var result: Array = []
	for job in jobs:
		if job.get("state", "") in ["incoming", "queued", "blocked", "quality_hold", "completed", "processing"]:
			result.append({"id":job.get("id", ""), "kind":job.get("kind", "repair"), "visual_kind":job.get("visual_kind", "device_board"), "label":job.get("label", "Item"), "position":get_item_position(job), "state":job.get("state", ""), "quality":job.get("quality", 0.85), "progress":job.get("progress", 0.0)})
	return result

func get_active_bottlenecks() -> Array:
	var result: Array = []
	for station in stations:
		var queue_size: int = station.get("queue", []).size()
		if station.get("status", "") in ["OVERLOADED", "BLOCKED", "WAITING"] or queue_size > int(station.get("capacity", 1)):
			result.append({"station_id":station.get("id", ""), "name":station.get("name", "Station"), "status":station.get("status", "IDLE"), "queue":queue_size})
	if inventory.get("microcontroller", 0) < 3 or inventory.get("sensor", 0) < 3:
		result.append({"station_id":"parts_shelf", "name":"Parts Shelf", "status":"STARVED", "queue":0})
	return result

func get_unlocked_station_definitions() -> Array:
	var result: Array = []
	for definition in catalog.get("stations", []):
		if int(definition.get("era", 1)) <= current_era and str(definition.get("id", "")) not in ["incoming_shelf", "parts_shelf", "outgoing_shelf"]:
			result.append(definition)
	return result

func get_current_era_name() -> String:
	var eras: Array = catalog.get("eras", [])
	if current_era <= 0 or current_era > eras.size():
		return "Unknown Era"
	return str(eras[current_era - 1].get("name", "Era %d" % current_era))

func get_next_era_cost() -> float:
	if current_era >= 6:
		return 0.0
	return float(catalog.get("eras", [])[current_era].get("cost", 0.0))

func save_game() -> bool:
	last_saved_at = Time.get_unix_time_from_system()
	var save_data := {
		"save_version": SAVE_VERSION,
		"game_version": "0.1.0",
		"timestamp": last_saved_at,
		"money": money,
		"reputation": reputation,
		"knowledge": knowledge,
		"current_era": current_era,
		"expansion_level": expansion_level,
		"simulation_time": simulation_time,
		"time_scale": time_scale,
		"production_enabled": production_enabled,
		"workers": _serialize_workers(),
		"stations": _serialize_stations(),
		"jobs": jobs,
		"contracts": contracts,
		"inventory": inventory,
		"research": research,
		"deliveries": deliveries,
		"quality_hold": quality_hold,
		"milestones": milestones,
		"counters":{"job":_job_counter,"worker":_worker_counter,"station":_station_counter,"contract":_contract_counter}
	}
	var file := FileAccess.open("user://hardware_empire_save.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(save_data))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists("user://hardware_empire_save.json"):
		return false
	var file := FileAccess.open("user://hardware_empire_save.json", FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var data: Dictionary = migrate_save(parsed)
	_money_from_save(data)
	var previous_timestamp := float(data.get("timestamp", Time.get_unix_time_from_system()))
	last_saved_at = Time.get_unix_time_from_system()
	var offline_seconds: float = clamp(last_saved_at - previous_timestamp, 0.0, MAX_OFFLINE_SECONDS)
	_apply_offline_progress(offline_seconds)
	state_changed.emit()
	return true

func migrate_save(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := int(migrated.get("save_version", 0))
	if version < 1:
		migrated["save_version"] = 1
		migrated["expansion_level"] = int(migrated.get("expansion_level", 1))
		migrated["research"] = migrated.get("research", {"active_id":"", "completed":[], "progress":0.0})
		migrated["deliveries"] = migrated.get("deliveries", [])
	return migrated

func _money_from_save(data: Dictionary) -> void:
	money = float(data.get("money", 250.0))
	reputation = float(data.get("reputation", 1.0))
	knowledge = float(data.get("knowledge", 0.0))
	current_era = clamp(int(data.get("current_era", 1)), 1, 6)
	expansion_level = clamp(int(data.get("expansion_level", current_era)), 1, 6)
	simulation_time = float(data.get("simulation_time", 0.0))
	time_scale = float(data.get("time_scale", 1.0))
	production_enabled = bool(data.get("production_enabled", current_era >= 4))
	workers = _deserialize_workers(data.get("workers", []))
	stations = _deserialize_stations(data.get("stations", []))
	jobs = data.get("jobs", [])
	contracts = data.get("contracts", [])
	inventory = data.get("inventory", {})
	research = data.get("research", {"active_id":"", "completed":[], "progress":0.0})
	deliveries = data.get("deliveries", [])
	quality_hold = data.get("quality_hold", [])
	milestones = data.get("milestones", {})
	var counters: Dictionary = data.get("counters", {})
	_job_counter = int(counters.get("job", jobs.size()))
	_worker_counter = int(counters.get("worker", workers.size()))
	_station_counter = int(counters.get("station", stations.size()))
	_contract_counter = int(counters.get("contract", contracts.size()))

func _serialize_workers() -> Array:
	var result: Array = []
	for worker in workers:
		var copy: Dictionary = worker.duplicate(true)
		var position: Vector2 = copy.get("position", Vector2.ZERO)
		var target: Vector2 = copy.get("target", position)
		copy["position"] = {"x":position.x,"y":position.y}
		copy["target"] = {"x":target.x,"y":target.y}
		result.append(copy)
	return result

func _serialize_stations() -> Array:
	var result: Array = []
	for station in stations:
		var copy: Dictionary = station.duplicate(true)
		var position: Vector2 = copy.get("position", Vector2.ZERO)
		copy["position"] = {"x":position.x,"y":position.y}
		result.append(copy)
	return result

func _deserialize_workers(raw: Array) -> Array:
	var result: Array = []
	for worker in raw:
		var copy: Dictionary = worker.duplicate(true)
		var position: Dictionary = copy.get("position", {})
		var target: Dictionary = copy.get("target", position)
		copy["position"] = Vector2(float(position.get("x", 272)), float(position.get("y", 176)))
		copy["target"] = Vector2(float(target.get("x", 272)), float(target.get("y", 176)))
		result.append(copy)
	return result

func _deserialize_stations(raw: Array) -> Array:
	var result: Array = []
	navigation_grid = WorkshopGrid.new(70, 34)
	for station in raw:
		var copy: Dictionary = station.duplicate(true)
		var position: Dictionary = copy.get("position", {})
		copy["position"] = Vector2(float(position.get("x", 112)), float(position.get("y", 112)))
		result.append(copy)
		navigation_grid.place(str(copy.get("id", "")), navigation_grid.world_to_cell(copy["position"]), Vector2i(3, 2))
	return result

func _apply_offline_progress(seconds: float) -> void:
	if seconds < 1.0:
		last_offline_report = "No offline time elapsed."
		return
	var worker_count: int = max(1, workers.size())
	var completed_jobs: int = int(min(float(jobs.size()), seconds / 18.0 * worker_count))
	var income := SimulationRules.calculate_offline_income(seconds, float(worker_count) * 180.0 / 18.0, 80.0)
	money += income
	knowledge += seconds / 3600.0 * float(worker_count) * 1.5
	for delivery in deliveries:
		var component_id := str(delivery.get("component_id", ""))
		inventory[component_id] = int(inventory.get(component_id, 0)) + int(delivery.get("quantity", 0))
	deliveries.clear()
	last_offline_report = "Offline %dm: +$%d, %d simulated completions, deliveries received." % [int(seconds / 60.0), int(income), completed_jobs]
	event_logged.emit(last_offline_report, "info")

func get_summary() -> Dictionary:
	var active_jobs := 0
	var completed_jobs := 0
	for job in jobs:
		if job.get("state", "") != "completed":
			active_jobs += 1
		else:
			completed_jobs += 1
	var active_contracts := 0
	for contract in contracts:
		if contract.get("state", "") == "active":
			active_contracts += 1
	return {"cash":money,"reputation":reputation,"knowledge":knowledge,"active_jobs":active_jobs,"completed_jobs":completed_jobs,"active_contracts":active_contracts,"production":completed_jobs,"bottlenecks":get_active_bottlenecks().size(),"era":get_current_era_name(),"expansion":expansion_level}
