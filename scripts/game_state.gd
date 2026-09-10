class_name HardwareEmpireState
extends Node

signal state_changed
signal event_logged(message: String, severity: String)
signal item_completed(item_id: String, item_type: String)
signal interaction_ready(station_id: String)

const SAVE_VERSION: int = 2
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
var sales_today: float = 0.0
var sales_this_week: float = 0.0
var game_mode: String = "tiny_workshop"
var tiny_player: Dictionary = {}
var tiny_selected_job_id: String = ""
var repair_shop: RepairShopSimulation
var technician_xp: float = 0.0
var technician_level: int = 1
var repair_mastery: Dictionary = {}
var owned_tools: Dictionary = {}
var workshop_upgrades: Dictionary = {}
var storage_capacity: int = 12
var carrying_capacity: int = 1
var _financial_day: int = 0

var _job_counter: int = 0
var _worker_counter: int = 0
var _station_counter: int = 0
var _contract_counter: int = 0
var _supplier_timer: float = 25.0
var _job_timer: float = 8.0
var _product_timer: float = 18.0
var _contract_timer: float = 30.0
var _simulation_accumulator: float = 0.0
var _tiny_client_timer: float = 18.0
var _tiny_request_index: int = 0

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
	_new_legacy_game()

func new_game() -> void:
	_start_tiny_workshop()

func _new_legacy_game() -> void:
	game_mode = "legacy"
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
	sales_today = 0.0
	sales_this_week = 0.0
	_financial_day = 0
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

func start_tiny_workshop() -> void:
	_start_tiny_workshop()

func initialize_tiny_workshop_for_tests() -> void:
	_load_catalog()
	_start_tiny_workshop()

func _start_tiny_workshop() -> void:
	game_mode = "tiny_workshop"
	repair_shop = RepairShopSimulation.new(catalog)
	repair_shop.event_logged.connect(_on_repair_shop_event)
	repair_shop.interaction_ready.connect(_on_repair_shop_interaction)
	repair_shop.reset()
	workers.clear()
	stations.clear()
	jobs.clear()
	contracts.clear()
	deliveries.clear()
	quality_hold.clear()
	navigation_grid = WorkshopGrid.new(32, 22)
	inventory = repair_shop.inventory
	research = {"active_id": "", "completed": [], "progress": 0.0}
	milestones = {}
	money = repair_shop.money
	reputation = repair_shop.reputation
	knowledge = 0.0
	current_era = 1
	expansion_level = 1
	simulation_time = 0.0
	production_enabled = false
	last_offline_report = "Tiny Workshop opened."
	sales_today = 0.0
	sales_this_week = 0.0
	_financial_day = 0
	_job_counter = 0
	_worker_counter = 0
	_station_counter = 0
	_contract_counter = 0
	_tiny_client_timer = 18.0
	_tiny_request_index = 0
	tiny_selected_job_id = ""
	tiny_player = repair_shop.player
	for station_data in [["incoming_shelf", Vector2(180, 190)], ["parts_shelf", Vector2(180, 460)], ["repair_bench_1", Vector2(570, 390)], ["outgoing_shelf", Vector2(900, 190)]]:
		_add_station(str(station_data[0]), station_data[1])
	_add_worker("founder", "Founder", Vector2(410, 610))
	_sync_repair_shop_state()
	_refresh_milestones()
	state_changed.emit()

func _on_repair_shop_event(message: String, severity: String) -> void:
	event_logged.emit(message, severity)

func _on_repair_shop_interaction(station_id: String) -> void:
	interaction_ready.emit(station_id)

func _sync_repair_shop_state() -> void:
	if repair_shop == null:
		return
	money = repair_shop.money
	reputation = repair_shop.reputation
	jobs = repair_shop.jobs
	inventory = repair_shop.inventory
	deliveries = repair_shop.deliveries
	milestones = repair_shop.milestones
	tiny_player = repair_shop.player
	tiny_selected_job_id = repair_shop.selected_job_id
	technician_xp = repair_shop.technician_xp
	technician_level = repair_shop.technician_level
	repair_mastery = repair_shop.mastery
	owned_tools = repair_shop.tools
	workshop_upgrades = repair_shop.upgrades
	storage_capacity = repair_shop.storage_capacity
	carrying_capacity = repair_shop.carrying_capacity
	if not workers.is_empty():
		var founder: Dictionary = workers[0]
		founder["position"] = tiny_player.get("position", founder.get("position", Vector2.ZERO))
		founder["state"] = tiny_player.get("state", "IDLE")
		founder["animation"] = "work" if tiny_player.get("state", "") == "WORKING" else "carry" if not str(tiny_player.get("carrying", "")).is_empty() else "walk" if tiny_player.get("state", "") == "MOVING" else "idle"
		founder["carrying"] = tiny_player.get("carrying", "")

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

func _tiny_service_definition(service_id: String) -> Dictionary:
	return repair_shop.get_service_definition(service_id) if repair_shop != null else {}

func _create_tiny_client() -> String:
	return repair_shop.create_customer() if repair_shop != null else ""

func get_tiny_client_at(position: Vector2) -> Dictionary:
	if repair_shop != null:
		var index := 0
		for job in repair_shop.jobs:
			if job.get("state", "") != "client_waiting":
				continue
			var client_position := Vector2(150.0 + float(index % 3) * 78.0, 145.0)
			if client_position.distance_to(position) <= 32.0:
				return job
			index += 1
		return {}
	var legacy_index := 0
	for job in jobs:
		if job.get("state", "") != "client_waiting":
			continue
		var client_position := Vector2(145.0 + float(legacy_index % 3) * 70.0, 150.0)
		if client_position.distance_to(position) <= 30.0:
			return job
		legacy_index += 1
	return {}

func get_tiny_jobs() -> Array:
	if repair_shop != null:
		return repair_shop.jobs
	var result: Array = []
	for job in jobs:
		if job.get("service_id", "") != "":
			result.append(job)
	return result

func _tiny_job(job_id: String) -> Dictionary:
	if repair_shop != null:
		return repair_shop.get_job(job_id)
	var job := _find_job(job_id)
	if job.get("service_id", "") == "":
		return {}
	return job

func accept_tiny_service(job_id: String) -> bool:
	if repair_shop != null:
		var accepted := repair_shop.accept_job(job_id)
		_sync_repair_shop_state()
		if accepted:
			state_changed.emit()
		return accepted
	var job := _tiny_job(job_id)
	if job.is_empty() or job.get("state", "") != "client_waiting":
		return false
	var cost := float(job.get("material_cost", 0.0))
	if money < cost:
		return false
	money -= cost
	job["state"] = "materials_delivering"
	tiny_selected_job_id = job_id
	var materials: Dictionary = job.get("required_materials", {})
	for component_id in materials:
		deliveries.append({"id":"tiny_delivery_%s_%s" % [job_id, component_id], "component_id":component_id, "quantity":int(materials[component_id]), "progress":0.0, "duration":7.0, "job_id":job_id})
	event_logged.emit("Accepted %s. Materials ordered." % job.get("label", "repair"), "success")
	state_changed.emit()
	return true

func decline_tiny_service(job_id: String) -> bool:
	if repair_shop != null:
		var declined := repair_shop.reject_job(job_id)
		_sync_repair_shop_state()
		if declined:
			state_changed.emit()
		return declined
	var job := _tiny_job(job_id)
	if job.is_empty() or job.get("state", "") != "client_waiting":
		return false
	job["state"] = "declined"
	event_logged.emit("Declined %s." % job.get("label", "repair"), "info")
	state_changed.emit()
	return true

func order_tiny_parts(component_id: String, quantity: int = 4) -> bool:
	if repair_shop != null:
		var ordered := repair_shop.order_parts(component_id, quantity)
		_sync_repair_shop_state()
		if ordered:
			state_changed.emit()
		return ordered
	if _component_definition(component_id).is_empty() or quantity <= 0:
		return false
	var unit_cost := float(_component_definition(component_id).get("order_cost", 10.0))
	var total_cost := unit_cost * quantity
	if money < total_cost:
		return false
	money -= total_cost
	deliveries.append({"id":"tiny_stock_delivery_%d" % int(simulation_time * 10.0), "component_id":component_id, "quantity":quantity, "progress":0.0, "duration":5.0, "job_id":""})
	event_logged.emit("Ordered %d %s." % [quantity, _component_definition(component_id).get("name", component_id)], "info")
	state_changed.emit()
	return true

func _component_definition(component_id: String) -> Dictionary:
	if repair_shop != null:
		return repair_shop.get_component_definition(component_id)
	for definition in catalog.get("components", []):
		if str(definition.get("id", "")) == component_id:
			return definition
	return {}

func collect_tiny_materials(job_id: String, component_ids: Array[String]) -> bool:
	if repair_shop != null:
		var requested := repair_shop.request_collect_parts(job_id)
		_sync_repair_shop_state()
		if requested:
			state_changed.emit()
		return requested
	var job := _tiny_job(job_id)
	if job.is_empty() or job.get("state", "") not in ["materials_ready", "materials_partial"]:
		return false
	if component_ids.is_empty():
		return false
	tiny_selected_job_id = job_id
	tiny_player["pending_action"] = {"type":"collect", "job_id":job_id, "components":component_ids}
	tiny_player["target"] = _tiny_station_position("parts_shelf") + Vector2(80, 55)
	tiny_player["state"] = "MOVING_TO_PICKUP"
	return true

func start_tiny_repair(job_id: String) -> bool:
	if repair_shop != null:
		var methods := repair_shop.get_diagnostic_methods(job_id)
		var method_id := "visual_inspection"
		if not methods.is_empty():
			method_id = str(methods[0].get("id", method_id))
		var requested := repair_shop.request_start_diagnosis(job_id, method_id)
		_sync_repair_shop_state()
		if requested:
			state_changed.emit()
		return requested
	var job := _tiny_job(job_id)
	if job.is_empty() or job.get("state", "") != "materials_collected":
		return false
	tiny_selected_job_id = job_id
	tiny_player["pending_action"] = {"type":"start_repair", "job_id":job_id}
	tiny_player["target"] = _tiny_station_position("repair_bench_1") + Vector2(-40, 70)
	tiny_player["state"] = "MOVING_TO_STATION"
	return true

func deliver_tiny_repair(job_id: String) -> bool:
	if repair_shop != null:
		var requested := repair_shop.request_delivery(job_id)
		_sync_repair_shop_state()
		if requested:
			state_changed.emit()
		return requested
	var job := _tiny_job(job_id)
	if job.is_empty() or job.get("state", "") != "ready_for_delivery":
		return false
	tiny_selected_job_id = job_id
	tiny_player["pending_action"] = {"type":"deliver", "job_id":job_id}
	tiny_player["target"] = _tiny_station_position("outgoing_shelf") + Vector2(-70, 65)
	tiny_player["state"] = "MOVING_TO_DROPOFF"
	return true

func move_tiny_player_to(position: Vector2) -> void:
	if repair_shop != null:
		repair_shop.move_player_to(position)
		_sync_repair_shop_state()
		return
	if not str(tiny_player.get("working_job_id", "")).is_empty():
		return
	tiny_player["pending_action"] = ""
	tiny_player["target"] = position.clamp(Vector2(60, 80), Vector2(940, 650))
	tiny_player["state"] = "MOVING"

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
	if game_mode == "tiny_workshop":
		_simulate_tiny_tick(delta_seconds)
		return
	simulation_time += delta_seconds
	var financial_day := int(simulation_time / 86400.0)
	if financial_day > _financial_day:
		sales_today = 0.0
		_financial_day = financial_day
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

func _tiny_station_position(definition_id: String) -> Vector2:
	for station in stations:
		if station.get("definition_id", "") == definition_id:
			return station.get("position", Vector2.ZERO)
	return _position_for_station(definition_id)

func _simulate_tiny_tick(delta_seconds: float) -> void:
	if repair_shop == null:
		return
	repair_shop.advance(delta_seconds)
	simulation_time = repair_shop.simulation_time
	_sync_repair_shop_state()

func _process_tiny_deliveries(delta_seconds: float) -> void:
	for delivery in deliveries:
		delivery["progress"] = min(1.0, float(delivery.get("progress", 0.0)) + delta_seconds / float(delivery.get("duration", 7.0)))
	for delivery in deliveries.duplicate():
		if float(delivery.get("progress", 0.0)) < 1.0:
			continue
		var component_id := str(delivery.get("component_id", ""))
		var quantity := int(delivery.get("quantity", 0))
		inventory[component_id] = int(inventory.get(component_id, 0)) + quantity
		var job_id := str(delivery.get("job_id", ""))
		if not job_id.is_empty():
			var job := _find_job(job_id)
			if not job.is_empty():
				var delivered: Dictionary = job.get("materials_delivered", {})
				delivered[component_id] = int(delivered.get(component_id, 0)) + quantity
				job["materials_delivered"] = delivered
				if _tiny_materials_complete(job, "materials_delivered"):
					job["state"] = "materials_ready"
					event_logged.emit("Materials ready at Parts Shelf: %s." % job.get("label", "repair"), "success")
		deliveries.erase(delivery)

func _process_tiny_player(delta_seconds: float) -> void:
	if tiny_player.is_empty():
		return
	var worker: Dictionary = {}
	if not workers.is_empty():
		worker = workers[0]
	var position: Vector2 = tiny_player.get("position", Vector2.ZERO)
	var target: Vector2 = tiny_player.get("target", position)
	if position.distance_to(target) > 4.0:
		tiny_player["position"] = position.move_toward(target, 150.0 * delta_seconds)
		tiny_player["state"] = tiny_player.get("state", "MOVING")
		if not worker.is_empty():
			worker["position"] = tiny_player["position"]
			worker["state"] = tiny_player["state"]
			worker["animation"] = "carry" if not str(tiny_player.get("carrying", "")).is_empty() else "walk"
		return
	if not str(tiny_player.get("working_job_id", "")).is_empty():
		tiny_player["state"] = "WORKING"
		if not worker.is_empty():
			worker["state"] = "WORKING"
			worker["animation"] = "work"
			worker["carrying"] = tiny_player.get("carrying", "")
		return
	var action: Variant = tiny_player.get("pending_action", "")
	if action is Dictionary and not action.is_empty():
		_resolve_tiny_player_action(action)
	else:
		tiny_player["state"] = "IDLE"
		if not worker.is_empty():
			worker["state"] = "IDLE"
			worker["animation"] = "idle"
	var carrying := str(tiny_player.get("carrying", ""))
	if not worker.is_empty():
		worker["position"] = tiny_player.get("position", worker.get("position", Vector2.ZERO))
		worker["carrying"] = carrying

func _resolve_tiny_player_action(action: Dictionary) -> void:
	var job_id := str(action.get("job_id", ""))
	var job := _tiny_job(job_id)
	if job.is_empty():
		tiny_player["pending_action"] = ""
		return
	match str(action.get("type", "")):
		"collect":
			var collected: Dictionary = job.get("collected_materials", {})
			var delivered: Dictionary = job.get("materials_delivered", {})
			for component_id in action.get("components", []):
				var needed := int(job.get("required_materials", {}).get(component_id, 0)) - int(collected.get(component_id, 0))
				var available: int = min(needed, min(int(inventory.get(component_id, 0)), int(delivered.get(component_id, 0)) - int(collected.get(component_id, 0))))
				if available > 0:
					inventory[component_id] = int(inventory.get(component_id, 0)) - available
					collected[component_id] = int(collected.get(component_id, 0)) + available
			job["collected_materials"] = collected
			job["state"] = "materials_collected" if _tiny_materials_complete(job, "collected_materials") else "materials_partial"
			tiny_player["carrying"] = job.get("visual_kind", "device_board")
			tiny_selected_job_id = job_id
			tiny_player["pending_action"] = ""
			tiny_player["state"] = "IDLE"
		"start_repair":
			if job.get("state", "") != "materials_collected":
				tiny_player["pending_action"] = ""
				return
			job["state"] = "diagnosing"
			job["station_id"] = "repair_bench_1"
			job["progress"] = 0.0
			tiny_player["pending_action"] = ""
			tiny_player["working_job_id"] = job_id
			tiny_player["phase"] = "diagnosis"
			tiny_player["state"] = "WORKING"
			event_logged.emit("Diagnosis started: %s." % job.get("label", "repair"), "info")
		"deliver":
			if job.get("state", "") != "ready_for_delivery":
				tiny_player["pending_action"] = ""
				return
			_finish_tiny_job(job)
			tiny_player["pending_action"] = ""
			tiny_player["working_job_id"] = ""
			tiny_player["carrying"] = ""
			tiny_player["state"] = "IDLE"

func _tiny_materials_complete(job: Dictionary, field: String) -> bool:
	var required: Dictionary = job.get("required_materials", {})
	var current: Dictionary = job.get(field, {})
	for component_id in required:
		if int(current.get(component_id, 0)) < int(required[component_id]):
			return false
	return true

func _process_tiny_work(delta_seconds: float) -> void:
	var job := _tiny_job(str(tiny_player.get("working_job_id", "")))
	if job.is_empty():
		return
	var phase := str(tiny_player.get("phase", "diagnosis"))
	var definition := _tiny_service_definition(str(job.get("service_id", "")))
	var duration := float(definition.get("diagnosis_duration", 4.0)) if phase == "diagnosis" else float(definition.get("repair_duration", 6.0))
	job["progress"] = min(1.0, float(job.get("progress", 0.0)) + delta_seconds / max(0.1, duration))
	if float(job.get("progress", 0.0)) < 1.0:
		return
	if phase == "diagnosis":
		job["state"] = "repairing"
		job["progress"] = 0.0
		tiny_player["phase"] = "repair"
		event_logged.emit("Diagnosis complete. Repair started: %s." % job.get("label", "repair"), "info")
	else:
		job["state"] = "ready_for_delivery"
		job["progress"] = 1.0
		tiny_player["working_job_id"] = ""
		tiny_player["state"] = "IDLE"
		event_logged.emit("Repair complete. Move device to Outcome Port." , "success")

func _finish_tiny_job(job: Dictionary) -> void:
	job["state"] = "completed"
	job["station_id"] = "outgoing_shelf"
	var reward := SimulationRules.calculate_job_reward(float(job.get("base_reward", 0.0)), float(job.get("quality", 0.9)))
	money += reward
	sales_today += reward
	sales_this_week += reward
	reputation = clamp(reputation + 0.1, 0.0, 100.0)
	knowledge += 0.25
	item_completed.emit(str(job.get("id", "")), "repair")
	event_logged.emit("Client paid $%d for %s." % [int(reward), job.get("label", "repair")], "success")

func get_tiny_progress_label() -> String:
	if repair_shop != null:
		return repair_shop.get_progress_label()
	var job := _tiny_job(tiny_selected_job_id)
	if job.is_empty():
		return "Select client request at Front Desk."
	match str(job.get("state", "")):
		"materials_delivering": return "Waiting: materials en route to Parts Shelf."
		"materials_ready": return "Materials ready: collect selected parts at shelf."
		"materials_partial": return "Materials partly collected: return to Parts Shelf."
		"materials_collected": return "Parts collected: choose repair at Repair Bench."
		"diagnosing": return "Diagnosis in progress: %.0f%%" % (float(job.get("progress", 0.0)) * 100.0)
		"repairing": return "Repair in progress: %.0f%%" % (float(job.get("progress", 0.0)) * 100.0)
		"ready_for_delivery": return "Repair ready: move device to Outcome Port."
		"completed": return "Service complete. Client reward received."
	return "Select next action in workshop."

func get_tiny_diagnostic_methods(job_id: String) -> Array:
	return repair_shop.get_diagnostic_methods(job_id) if repair_shop != null else []

func get_tiny_repair_methods(job_id: String) -> Array:
	return repair_shop.get_repair_methods(job_id) if repair_shop != null else []

func start_tiny_repair_method(job_id: String, method_id: String) -> bool:
	if repair_shop == null:
		return false
	var started := repair_shop.start_repair_method(job_id, method_id)
	_sync_repair_shop_state()
	if started:
		state_changed.emit()
	return started

func collect_tiny_device(job_id: String) -> bool:
	if repair_shop == null:
		return false
	var collected := repair_shop.request_pickup_device(job_id)
	_sync_repair_shop_state()
	if collected:
		state_changed.emit()
	return collected

func interact_tiny_station(station_id: String) -> bool:
	if repair_shop == null:
		return false
	var requested := repair_shop.request_station_interaction(station_id)
	_sync_repair_shop_state()
	if requested:
		state_changed.emit()
	return requested

func consume_tiny_interaction() -> String:
	if repair_shop == null:
		return ""
	return repair_shop.consume_interaction()

func purchase_tiny_upgrade(upgrade_id: String) -> bool:
	if repair_shop == null:
		return false
	var purchased := repair_shop.purchase_upgrade(upgrade_id)
	_sync_repair_shop_state()
	if purchased:
		state_changed.emit()
	return purchased

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
	sales_today += reward
	sales_this_week += reward
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
	if game_mode == "tiny_workshop":
		_sync_repair_shop_state()
	last_saved_at = Time.get_unix_time_from_system()
	var save_data := {
		"save_version": SAVE_VERSION,
		"game_version": "0.1.0",
		"game_mode": game_mode,
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
		"sales_today": sales_today,
		"sales_this_week": sales_this_week,
		"financial_day": _financial_day,
		"tiny_client_timer": _tiny_client_timer,
		"tiny_request_index": _tiny_request_index,
		"tiny_selected_job_id": tiny_selected_job_id,
		"tiny_player": _serialize_tiny_player(),
		"repair_shop": repair_shop.serialize() if repair_shop != null else {},
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
		migrated["game_mode"] = migrated.get("game_mode", "legacy")
	if version < 2:
		migrated["save_version"] = 2
		migrated["repair_shop"] = migrated.get("repair_shop", {})
	return migrated

func _money_from_save(data: Dictionary) -> void:
	game_mode = str(data.get("game_mode", "legacy"))
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
	sales_today = float(data.get("sales_today", 0.0))
	sales_this_week = float(data.get("sales_this_week", 0.0))
	_financial_day = int(data.get("financial_day", int(simulation_time / 86400.0)))
	var counters: Dictionary = data.get("counters", {})
	_job_counter = int(counters.get("job", jobs.size()))
	_worker_counter = int(counters.get("worker", workers.size()))
	_station_counter = int(counters.get("station", stations.size()))
	_contract_counter = int(counters.get("contract", contracts.size()))
	_tiny_client_timer = float(data.get("tiny_client_timer", 18.0))
	_tiny_request_index = int(data.get("tiny_request_index", 0))
	tiny_selected_job_id = str(data.get("tiny_selected_job_id", ""))
	var raw_tiny_player: Dictionary = data.get("tiny_player", {})
	if not raw_tiny_player.is_empty():
		var raw_position: Dictionary = raw_tiny_player.get("position", {})
		var raw_target: Dictionary = raw_tiny_player.get("target", raw_position)
		raw_tiny_player["position"] = Vector2(float(raw_position.get("x", 410.0)), float(raw_position.get("y", 610.0)))
		raw_tiny_player["target"] = Vector2(float(raw_target.get("x", 410.0)), float(raw_target.get("y", 610.0)))
		tiny_player = raw_tiny_player
	if game_mode == "tiny_workshop":
		repair_shop = RepairShopSimulation.new(catalog)
		repair_shop.event_logged.connect(_on_repair_shop_event)
		repair_shop.interaction_ready.connect(_on_repair_shop_interaction)
		var shop_data: Dictionary = data.get("repair_shop", {})
		if shop_data.is_empty():
			shop_data = {"money":money, "reputation":reputation, "inventory":inventory, "jobs":jobs, "deliveries":deliveries, "selected_job_id":tiny_selected_job_id, "player":_serialize_tiny_player()}
		repair_shop.restore(shop_data)
		_sync_repair_shop_state()

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

func _serialize_tiny_player() -> Dictionary:
	var copy := tiny_player.duplicate(true)
	var position: Vector2 = copy.get("position", Vector2.ZERO)
	var target: Vector2 = copy.get("target", position)
	copy["position"] = {"x":position.x,"y":position.y}
	copy["target"] = {"x":target.x,"y":target.y}
	return copy

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
	if game_mode == "tiny_workshop":
		last_offline_report = "Solo workshop paused. No offline work performed."
		return
	if seconds < 1.0:
		last_offline_report = "No offline time elapsed."
		return
	var worker_count: int = max(1, workers.size())
	var completed_jobs: int = int(min(float(jobs.size()), seconds / 18.0 * worker_count))
	var income := SimulationRules.calculate_offline_income(seconds, float(worker_count) * 180.0 / 18.0, 80.0)
	money += income
	sales_today += income
	sales_this_week += income
	knowledge += seconds / 3600.0 * float(worker_count) * 1.5
	for delivery in deliveries:
		var component_id := str(delivery.get("component_id", ""))
		inventory[component_id] = int(inventory.get(component_id, 0)) + int(delivery.get("quantity", 0))
	deliveries.clear()
	last_offline_report = "Offline %dm: +$%d, throughput estimate %d jobs, deliveries received." % [int(seconds / 60.0), int(income), completed_jobs]
	event_logged.emit(last_offline_report, "info")

func get_summary() -> Dictionary:
	if game_mode == "tiny_workshop" and repair_shop != null:
		return repair_shop.get_summary()
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
	return {"cash":money,"reputation":reputation,"knowledge":knowledge,"active_jobs":active_jobs,"completed_jobs":completed_jobs,"active_contracts":active_contracts,"production":completed_jobs,"bottlenecks":get_active_bottlenecks().size(),"era":get_current_era_name(),"expansion":expansion_level,"sales_today":sales_today,"sales_this_week":sales_this_week}
