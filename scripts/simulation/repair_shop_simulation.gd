class_name RepairShopSimulation
extends RefCounted

## Authoritative Era-1 repair-shop simulation. Rendering/UI only observe this state.

signal state_changed
signal event_logged(message: String, severity: String)
signal interaction_ready(station_id: String)

signal sound_requested(event_id: String)

const Layout = preload("res://scripts/simulation/era_one_layout.gd")
const FIRST_CUSTOMER_DELAY_MIN := 3.0
const FIRST_CUSTOMER_DELAY_MAX := 6.0
const CUSTOMER_ARRIVAL_MIN := 15.0
const CUSTOMER_ARRIVAL_MAX := 30.0
const CUSTOMER_MOVE_DURATION := 2.0
const SUPPLIER_TRAVEL_TIME := 7.0
const COURIER_MOVE_DURATION := 1.5
const COURIER_DROP_DURATION := 1.0
const CUSTOMER_PICKUP_DELAY_MIN := 4.0
const CUSTOMER_PICKUP_DELAY_MAX := 10.0
const CUSTOMER_PICKUP_DURATION := 1.0
const OUTBOUND_CAPACITY := 3
var random := RandomNumberGenerator.new()

const TICK_SECONDS: float = 0.25
const MAX_JOBS: int = 3
const BASE_STORAGE_CAPACITY: int = 12
const BASE_CARRY_CAPACITY: int = 1
const XP_THRESHOLDS: Array[int] = [0, 100, 250, 450, 700]

var catalog: Dictionary
var sales_total := 0.0
var money: float = 250.0
var reputation: float = 1.0
var technician_xp: float = 0.0
var technician_level: int = 1
var mastery: Dictionary = {"general_repair": 0}
var tools: Dictionary = {"screwdriver_set": true, "cheap_soldering_iron": true, "bench_lamp": true}
var upgrades: Dictionary = {}
var inventory: Dictionary = {}
var reserved_inventory: Dictionary = {}
var deliveries: Array = []
var jobs: Array = []
var milestones: Dictionary = {}
var player: Dictionary = {}
var selected_job_id: String = ""
var simulation_time: float = 0.0
var storage_capacity: int = BASE_STORAGE_CAPACITY
var carrying_capacity: int = BASE_CARRY_CAPACITY
var last_offline_report: String = ""

var _accumulator: float = 0.0
var _customer_timer: float = 18.0
var _request_index: int = 0
var _job_counter: int = 0
var _delivery_counter: int = 0

func _init(content_catalog: Dictionary = {}) -> void:
	catalog = content_catalog
	reset()

func reset() -> void:
	sales_total = 0.0
	money = 250.0
	reputation = 1.0
	technician_xp = 0.0
	technician_level = 1
	mastery = {"general_repair": 0}
	tools = {"screwdriver_set": true, "cheap_soldering_iron": true, "bench_lamp": true}
	upgrades = {}
	inventory = {}
	reserved_inventory = {}
	deliveries = []
	jobs = []
	milestones = {}
	selected_job_id = ""
	simulation_time = 0.0
	storage_capacity = BASE_STORAGE_CAPACITY
	carrying_capacity = BASE_CARRY_CAPACITY
	last_offline_report = "Solo repair workshop opened."
	_accumulator = 0.0
	random.seed = 1731
	_customer_timer = random.randf_range(FIRST_CUSTOMER_DELAY_MIN, FIRST_CUSTOMER_DELAY_MAX)
	_request_index = 0
	_job_counter = 0
	_delivery_counter = 0
	player = {"position": Layout.point("founder_start"), "target": Layout.point("founder_start"), "state": "IDLE", "pending_action": {}, "working_job_id": "", "phase": "", "carrying": "", "carried_parts": 0, "interaction_ready": ""}
	for definition in catalog.get("components", []):
		inventory[str(definition.get("id", ""))] = 0
	_refresh_milestones()
	state_changed.emit()

func advance(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_accumulator += delta_seconds
	while _accumulator >= TICK_SECONDS:
		_accumulator -= TICK_SECONDS
		_simulate_tick(TICK_SECONDS)
	state_changed.emit()

func _simulate_tick(delta_seconds: float) -> void:
	simulation_time += delta_seconds
	_customer_timer -= delta_seconds
	if _customer_timer <= 0.0:
		_customer_timer = random.randf_range(CUSTOMER_ARRIVAL_MIN, CUSTOMER_ARRIVAL_MAX)
		if _waiting_customer_count() < 3:
			create_customer()
	_process_customers(delta_seconds)
	_process_deliveries(delta_seconds)
	_process_player(delta_seconds)
	_process_work(delta_seconds)
	_refresh_milestones()

func create_customer() -> String:
	var services: Array = catalog.get("repair_services", [])
	if services.is_empty() or _waiting_customer_count() >= 3:
		return ""
	var definition: Dictionary = services[_request_index % services.size()]
	_request_index += 1
	_job_counter += 1
	var customer_defs: Array = catalog.get("customers", [])
	var customer: Dictionary = customer_defs[(_request_index - 1) % customer_defs.size()] if not customer_defs.is_empty() else {"name":"Local customer", "archetype":"Home user"}
	var materials: Dictionary = definition.get("materials", {}).duplicate(true)
	var job_id := "repair_%03d" % _job_counter
	jobs.append({
		"id": job_id,
		"service_id": str(definition.get("id", "")),
		"label": str(definition.get("name", "Repair request")),
		"description": str(definition.get("description", "Inspect and repair customer device.")),
		"customer_name": str(customer.get("name", "Local customer")),
		"customer_archetype": str(customer.get("archetype", "Home user")),
		"device_type": str(definition.get("device_type", "electronics")),
		"reported_problem": str(definition.get("reported_problem", definition.get("description", "Device needs repair."))),
		"possible_faults": definition.get("possible_faults", ["Damaged component"]),
		"actual_fault": "",
		"visual_kind": str(definition.get("visual_kind", "device_board")),
		"state": "arriving",
		"customer_state": "arriving", "customer_progress": 0.0, "waiting_slot": _free_waiting_slot(),
		"visual_variant": (_job_counter - 1) % 6, "rewards_granted": false,
		"required_materials": materials,
		"reserved_materials": {},
		"collected_materials": {},
		"parts_cost": 0.0,
		"repair_cost": 0.0,
		"reward": float(definition.get("reward", 100.0)),
		"xp_reward": int(definition.get("xp", 15)),
		"reputation_reward": float(definition.get("reputation", 0.15)),
		"difficulty": str(definition.get("difficulty", "Basic")),
		"required_level": int(definition.get("required_level", 1)),
		"mastery_category": str(definition.get("mastery_category", "general_repair")),
		"progress": 0.0,
		"diagnostic_method": "",
		"repair_method": "",
		"created_at": simulation_time,
		"station_id": ""
	})
	sound_requested.emit("front_door")
	event_logged.emit("%s is entering the shop." % customer.get("name", "Customer"), "info")
	return job_id

func _waiting_customer_count() -> int:
	var count := 0
	for job in jobs:
		if job.get("state", "") in ["arriving", "client_waiting"]:
			count += 1
	return count

func get_job(job_id: String) -> Dictionary:
	for job in jobs:
		if str(job.get("id", "")) == job_id:
			return job
	return {}

func get_jobs() -> Array:
	return jobs

func get_component_definition(component_id: String) -> Dictionary:
	for definition in catalog.get("components", []):
		if str(definition.get("id", "")) == component_id:
			return definition
	return {}

func get_service_definition(service_id: String) -> Dictionary:
	for definition in catalog.get("repair_services", []):
		if str(definition.get("id", "")) == service_id:
			return definition
	return {}

func get_component_name(component_id: String) -> String:
	var definition := get_component_definition(component_id)
	return str(definition.get("name", component_id.capitalize()))

func get_component_cost(component_id: String) -> float:
	return float(get_component_definition(component_id).get("order_cost", 10.0))

func available_stock(component_id: String) -> int:
	return max(0, int(inventory.get(component_id, 0)) - int(reserved_inventory.get(component_id, 0)))

func storage_used() -> int:
	var total := 0
	for component_id in inventory:
		total += int(inventory[component_id])
	for delivery in deliveries:
		if delivery.get("credited", false):
			continue
		total += int(delivery.get("quantity", 0))
	return total

func incoming_quantity(component_id: String) -> int:
	var total := 0
	for delivery in deliveries:
		if str(delivery.get("component_id", "")) == component_id and not delivery.get("credited", false):
			total += int(delivery.get("quantity", 0))
	return total

func _accepted_job_count() -> int:
	var count := 0
	for job in jobs:
		if job.get("state", "") not in ["arriving", "client_waiting", "declined", "completed"]:
			count += 1
	return count

func accept_job(job_id: String) -> bool:
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "client_waiting" or _accepted_job_count() >= MAX_JOBS:
		return false
	if int(job.get("required_level", 1)) > technician_level:
		return false
	var required: Dictionary = job.get("required_materials", {})
	var missing_cost := 0.0
	var reserved: Dictionary = {}
	for component_id in required:
		var needed := int(required[component_id])
		var available: int = available_stock(str(component_id))
		var reserve_amount: int = min(needed, available)
		reserved[component_id] = reserve_amount
		var missing: int = needed - reserve_amount
		missing_cost += float(missing) * get_component_cost(str(component_id))
	if money < missing_cost:
		return false
	if storage_used() + _sum_missing_quantity(required, reserved) > storage_capacity:
		return false
	money -= missing_cost
	for component_id in reserved:
		reserved_inventory[component_id] = int(reserved_inventory.get(component_id, 0)) + int(reserved[component_id])
	job["reserved_materials"] = reserved
	job["parts_cost"] = missing_cost
	job["state"] = "ready_for_parts" if _job_parts_reserved(job) else "waiting_for_parts"
	job["customer_state"] = "leaving"
	job["customer_progress"] = 0.0
	sound_requested.emit("job_accepted")
	selected_job_id = job_id
	if job.get("state", "") == "waiting_for_parts":
		for component_id in required:
			var missing := int(required[component_id]) - int(reserved.get(component_id, 0))
			if missing > 0:
				_place_delivery(str(component_id), missing, job_id)
	event_logged.emit("Accepted %s. Missing parts ordered for $%d." % [job.get("label", "repair"), int(missing_cost)], "success")
	return true

func _sum_missing_quantity(required: Dictionary, reserved: Dictionary) -> int:
	var total := 0
	for component_id in required:
		total += max(0, int(required[component_id]) - int(reserved.get(component_id, 0)))
	return total

func _job_parts_reserved(job: Dictionary) -> bool:
	var required: Dictionary = job.get("required_materials", {})
	var reserved: Dictionary = job.get("reserved_materials", {})
	for component_id in required:
		if int(reserved.get(component_id, 0)) < int(required[component_id]):
			return false
	return true

func reject_job(job_id: String) -> bool:
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "client_waiting":
		return false
	job["state"] = "declined"
	job["customer_state"] = "leaving"
	job["customer_progress"] = 0.0
	event_logged.emit("Declined %s." % job.get("label", "repair"), "info")
	return true

func order_parts(component_id: String, quantity: int) -> bool:
	if get_component_definition(component_id).is_empty() or quantity <= 0:
		return false
	if storage_used() + quantity > storage_capacity:
		return false
	var total_cost := get_component_cost(component_id) * quantity
	if money < total_cost:
		return false
	money -= total_cost
	_place_delivery(component_id, quantity, "")
	event_logged.emit("Ordered %d %s. Delivery en route." % [quantity, get_component_name(component_id)], "info")
	return true

func _place_delivery(component_id: String, quantity: int, job_id: String) -> void:
	_delivery_counter += 1
	deliveries.append({"id":"delivery_%d" % _delivery_counter, "component_id":component_id, "quantity":quantity, "progress":0.0, "duration":SUPPLIER_TRAVEL_TIME, "state":"in_transit", "credited":false, "job_id":job_id})

func request_collect_parts(job_id: String) -> bool:
	if _busy():
		return false
	for other in jobs:
		if other.get("state", "") in ["diagnosing", "awaiting_repair_choice", "repairing", "ready_for_pickup"]:
			return false
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") not in ["ready_for_parts", "parts_partial"] or not str(player.get("carrying", "")).is_empty():
		return false
	selected_job_id = job_id
	_queue_player_action({"type":"collect_parts", "job_id":job_id}, Layout.point("parts_shelf"))
	return true

func request_start_diagnosis(job_id: String, method_id: String = "visual_inspection") -> bool:
	if _busy():
		return false
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "parts_collected" or not _diagnostic_method_available(job_id, method_id):
		return false
	for other in jobs:
		if other.get("state", "") in ["diagnosing", "awaiting_repair_choice", "repairing", "ready_for_pickup"]:
			return false
	selected_job_id = job_id
	_queue_player_action({"type":"start_diagnosis", "job_id":job_id, "method_id":method_id}, Layout.point("repair_bench"))
	return true

func request_pickup_device(job_id: String) -> bool:
	if _busy():
		return false
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "ready_for_pickup" or not str(player.get("carrying", "")).is_empty():
		return false
	_queue_player_action({"type":"pickup_device", "job_id":job_id}, Layout.point("repair_bench"))
	return true

func request_delivery(job_id: String) -> bool:
	if _busy():
		return false
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "ready_for_delivery" or outbound_count() >= OUTBOUND_CAPACITY or player.get("carried_job_id", "") != job_id:
		return false
	selected_job_id = job_id
	_queue_player_action({"type":"deliver_job", "job_id":job_id}, Layout.point("pickup_founder"))
	return true

func request_station_interaction(station_id: String) -> bool:
	if not Layout.STATIONS.has(station_id) or _busy():
		return false
	_queue_player_action({"type":"open_station", "station_id":station_id}, Layout.point(Layout.STATIONS[station_id]))
	return true

func move_player_to(position: Vector2) -> void:
	if not str(player.get("working_job_id", "")).is_empty():
		return
	player["pending_action"] = {}
	player["target"] = position.clamp(Layout.FOUNDER_AREA.position, Layout.FOUNDER_AREA.end)
	player["state"] = "MOVING"

func consume_interaction() -> String:
	var result := str(player.get("interaction_ready", ""))
	player["interaction_ready"] = ""
	return result

func _queue_player_action(action: Dictionary, target: Vector2) -> void:
	player["pending_action"] = action
	player["target"] = target
	player["state"] = "MOVING"

func _process_deliveries(delta_seconds: float) -> void:
	var active: Dictionary = {}
	for delivery in deliveries:
		if delivery.get("state", "in_transit") != "in_transit":
			active = delivery
		else:
			delivery["progress"] = minf(1.0, float(delivery.get("progress", 0.0)) + delta_seconds / SUPPLIER_TRAVEL_TIME)
	if active.is_empty():
		for delivery in deliveries:
			if float(delivery.get("progress", 0.0)) >= 1.0 - 0.000001:
				delivery["state"] = "courier_arriving"
				delivery["progress"] = 0.0
				sound_requested.emit("service_door")
				return
		return
	var duration := COURIER_DROP_DURATION if active.state == "delivering" else COURIER_MOVE_DURATION
	active["progress"] = minf(1.0, float(active.progress) + delta_seconds / duration)
	if float(active.progress) < 1.0 - 0.000001:
		return
	active["progress"] = 0.0
	match str(active.state):
		"courier_arriving": active["state"] = "delivering"
		"delivering":
			_credit_delivery(active)
			active["state"] = "courier_leaving"
		"courier_leaving": deliveries.erase(active)

func _credit_delivery(delivery: Dictionary) -> void:
	if delivery.get("credited", false):
		return
	delivery["credited"] = true
	sound_requested.emit("package_delivery")
	var component_id := str(delivery.get("component_id", ""))
	var quantity := int(delivery.get("quantity", 0))
	inventory[component_id] = int(inventory.get(component_id, 0)) + quantity
	var job_id := str(delivery.get("job_id", ""))
	if not job_id.is_empty():
		var job := get_job(job_id)
		if not job.is_empty():
			var reserved: Dictionary = job.get("reserved_materials", {})
			reserved[component_id] = int(reserved.get(component_id, 0)) + quantity
			reserved_inventory[component_id] = int(reserved_inventory.get(component_id, 0)) + quantity
			job["reserved_materials"] = reserved
			if _job_parts_reserved(job):
				job["state"] = "ready_for_parts"
				event_logged.emit("Parts arrived at Parts Storage: %s." % job.get("label", "repair"), "success")
	else:
		event_logged.emit("Delivery arrived at Parts Storage: %s x%d." % [get_component_name(component_id), quantity], "success")

func _process_player(delta_seconds: float) -> void:
	var position: Vector2 = player.get("position", Vector2.ZERO)
	var target: Vector2 = player.get("target", position)
	if position.distance_to(target) > 4.0:
		player["position"] = position.move_toward(target, 190.0 * delta_seconds)
		player["state"] = "MOVING"
		return
	player["position"] = target
	var action: Variant = player.get("pending_action", {})
	if action is Dictionary and not action.is_empty():
		_resolve_player_action(action)
	elif str(player.get("working_job_id", "")).is_empty():
		player["state"] = "IDLE"

func _resolve_player_action(action: Dictionary) -> void:
	player["pending_action"] = {}
	var job_id := str(action.get("job_id", ""))
	var job := get_job(job_id)
	match str(action.get("type", "")):
		"open_station":
			player["state"] = "IDLE"
			player["interaction_ready"] = str(action.get("station_id", ""))
			interaction_ready.emit(str(action.get("station_id", "")))
		"collect_parts":
			if job.is_empty():
				return
			var required: Dictionary = job.get("required_materials", {})
			var reserved: Dictionary = job.get("reserved_materials", {})
			var collected: Dictionary = job.get("collected_materials", {})
			for component_id in required:
				var amount := int(required[component_id]) - int(collected.get(component_id, 0))
				var take: int = min(amount, int(reserved.get(component_id, 0)))
				if take <= 0:
					continue
				inventory[component_id] = int(inventory.get(component_id, 0)) - take
				reserved_inventory[component_id] = int(reserved_inventory.get(component_id, 0)) - take
				reserved[component_id] = int(reserved.get(component_id, 0)) - take
				collected[component_id] = int(collected.get(component_id, 0)) + take
			job["reserved_materials"] = reserved
			job["collected_materials"] = collected
			if _materials_complete(job, "collected_materials"):
				job["state"] = "parts_collected"
				player["carrying"] = "parts_bundle"
				player["carried_job_id"] = job_id
				player["carried_parts"] = _sum_materials(collected)
				selected_job_id = job_id
			else:
				job["state"] = "parts_partial"
				event_logged.emit("Carry capacity limited: collect remaining parts later.", "warning")
		"start_diagnosis":
			if job.is_empty() or job.get("state", "") != "parts_collected":
				return
			job["state"] = "diagnosing"
			job["progress"] = 0.0
			job["diagnostic_method"] = str(action.get("method_id", "visual_inspection"))
			player["working_job_id"] = job_id
			player["phase"] = "diagnosis"
			player["carrying"] = ""
			player["carried_parts"] = 0
			player["state"] = "WORKING"
			event_logged.emit("Diagnosis started at Repair Bench: %s." % job.get("label", "repair"), "info")
		"pickup_device":
			if job.is_empty() or job.get("state", "") != "ready_for_pickup" or not str(player.get("carrying", "")).is_empty():
				return
			job["state"] = "ready_for_delivery"
			player["carrying"] = "device"
			player["carried_job_id"] = job_id
			player["carried_parts"] = 0
			event_logged.emit("Device collected. Carry it to Outbound Desk.", "success")
		"deliver_job":
			if job.is_empty() or job.get("state", "") != "ready_for_delivery" or outbound_count() >= OUTBOUND_CAPACITY or player.get("carried_job_id", "") != job_id:
				return
			job["state"] = "waiting_for_customer_pickup"
			job["pickup_timer"] = random.randf_range(CUSTOMER_PICKUP_DELAY_MIN, CUSTOMER_PICKUP_DELAY_MAX)
			job["outbound_slot"] = _free_outbound_slot(job_id)
			player["carrying"] = ""
			player["carried_job_id"] = ""
			event_logged.emit("Device placed at Customer Pickup. Customer notified.", "info")

func _materials_complete(job: Dictionary, field: String) -> bool:
	var required: Dictionary = job.get("required_materials", {})
	var current: Dictionary = job.get(field, {})
	for component_id in required:
		if int(current.get(component_id, 0)) < int(required[component_id]):
			return false
	return true

func _sum_materials(materials: Dictionary) -> int:
	var result := 0
	for component_id in materials:
		result += int(materials[component_id])
	return result

func _process_work(delta_seconds: float) -> void:
	var working_id := str(player.get("working_job_id", ""))
	if working_id.is_empty():
		return
	var job := get_job(working_id)
	if job.is_empty():
		return
	var phase := str(player.get("phase", "diagnosis"))
	var definition := get_service_definition(str(job.get("service_id", "")))
	var method := _find_diagnostic_method(definition, str(job.get("diagnostic_method", "visual_inspection")))
	var duration := float(method.get("duration", definition.get("diagnosis_duration", 4.0))) if phase == "diagnosis" else float(job.get("repair_duration", definition.get("repair_duration", 6.0)))
	var modifier := 1.0
	if phase == "diagnosis" and tools.get("multimeter", false) and str(job.get("diagnostic_method", "")) == "multimeter_test":
		modifier = 0.8
	if phase == "repair" and tools.get("better_soldering_station", false):
		modifier = 0.75
	job["progress"] = min(1.0, float(job.get("progress", 0.0)) + delta_seconds / max(0.1, duration * modifier))
	if float(job.get("progress", 0.0)) < 1.0:
		return
	if phase == "diagnosis":
		var faults: Array = job.get("possible_faults", ["Damaged component"])
		job["actual_fault"] = str(faults[0]) if not faults.is_empty() else "Damaged component"
		job["state"] = "awaiting_repair_choice"
		job["progress"] = 1.0
		player["working_job_id"] = ""
		player["phase"] = ""
		player["state"] = "IDLE"
		event_logged.emit("Diagnosis complete: %s." % job.get("actual_fault", "fault found"), "success")
	else:
		job["state"] = "ready_for_pickup"
		job["progress"] = 1.0
		player["working_job_id"] = ""
		player["phase"] = ""
		player["state"] = "IDLE"
		sound_requested.emit("repair_finished")
		event_logged.emit("Repair complete. Collect device at Repair Bench.", "success")

func _diagnostic_method_available(job_id: String, method_id: String) -> bool:
	var method := _find_diagnostic_method(get_service_definition(str(get_job(job_id).get("service_id", ""))), method_id)
	if method.is_empty() or int(method.get("required_level", 1)) > technician_level:
		return false
	var required_tool := str(method.get("required_tool", ""))
	return required_tool.is_empty() or bool(tools.get(required_tool, false))

func _find_diagnostic_method(definition: Dictionary, method_id: String) -> Dictionary:
	for method in definition.get("diagnostic_methods", []):
		if str(method.get("id", "")) == method_id:
			return method
	return {"id":"visual_inspection", "duration":float(definition.get("diagnosis_duration", 4.0)), "required_level":1}

func get_diagnostic_methods(job_id: String) -> Array:
	var definition := get_service_definition(str(get_job(job_id).get("service_id", "")))
	var result: Array = []
	var definitions: Array = definition.get("diagnostic_methods", [])
	if definitions.is_empty():
		definitions = [{"id":"visual_inspection", "name":"Visual inspection", "duration":float(definition.get("diagnosis_duration", 4.0)), "required_level":1}]
	for method in definitions:
		if int(method.get("required_level", 1)) <= technician_level and (str(method.get("required_tool", "")).is_empty() or tools.get(str(method.get("required_tool", "")), false)):
			result.append(method)
	return result

func get_repair_methods(job_id: String) -> Array:
	var definition := get_service_definition(str(get_job(job_id).get("service_id", "")))
	var methods: Array = definition.get("repair_methods", [])
	if methods.is_empty():
		methods = [{"id":"component_repair", "name":"Component repair", "cost":8.0, "duration":20.0, "success":0.9, "required_tool":"cheap_soldering_iron"}, {"id":"board_replacement", "name":"Board replacement", "cost":30.0, "duration":8.0, "success":0.99, "required_tool":"screwdriver_set"}]
	return methods

func start_repair_method(job_id: String, method_id: String) -> bool:
	var job := get_job(job_id)
	if job.is_empty() or job.get("state", "") != "awaiting_repair_choice" or _busy() or player.position.distance_to(Layout.point("repair_bench")) > 5.0:
		return false
	for method in get_repair_methods(job_id):
		if str(method.get("id", "")) != method_id:
			continue
		var tool_id := str(method.get("required_tool", ""))
		if not tool_id.is_empty() and not tools.get(tool_id, false):
			return false
		var cost := float(method.get("cost", 0.0))
		if money < cost:
			return false
		money -= cost
		job["repair_method"] = method_id
		job["repair_cost"] = cost
		job["repair_duration"] = float(method.get("duration", 8.0))
		job["repair_success"] = float(method.get("success", 0.9)) + (0.08 if tools.get("better_soldering_station", false) else 0.0) + float(mastery.get(str(job.get("mastery_category", "general_repair")), 0)) * 0.005
		job["state"] = "repairing"
		job["progress"] = 0.0
		player["working_job_id"] = job_id
		player["phase"] = "repair"
		player["state"] = "WORKING"
		sound_requested.emit("repair_loop")
		event_logged.emit("Repair started: %s." % method.get("name", method_id), "info")
		return true
	return false

func _finish_job(job: Dictionary) -> void:
	if job.get("rewards_granted", false) or job.get("state", "") != "customer_collecting":
		return
	job["rewards_granted"] = true
	job["state"] = "completed"
	job["station_id"] = "outgoing_shelf"
	sound_requested.emit("customer_pickup")
	sound_requested.emit("payment_received")
	var quality: float = clamp(float(job.get("repair_success", 0.9)), 0.45, 1.0)
	var reward: float = round(float(job.get("reward", 100.0)) * quality)
	money += reward
	sales_total += reward
	reputation += float(job.get("reputation_reward", 0.15))
	add_xp(int(job.get("xp_reward", 15)))
	var category := str(job.get("mastery_category", "general_repair"))
	mastery[category] = int(mastery.get(category, 0)) + 1
	event_logged.emit("%s collected device. +$%d  +%d XP  +%.2f REP." % [job.get("customer_name", "Customer"), int(reward), int(job.get("xp_reward", 15)), float(job.get("reputation_reward", 0.15))], "success")

func add_xp(amount: int) -> void:
	technician_xp += max(0, amount)
	var old_level := technician_level
	while technician_level < XP_THRESHOLDS.size() and technician_xp >= float(XP_THRESHOLDS[technician_level]):
		technician_level += 1
	if technician_level > old_level:
		sound_requested.emit("level_up")
		event_logged.emit("LEVEL UP — Technician %d" % technician_level, "success")
		if technician_level >= 2:
			tools["multimeter"] = true
			event_logged.emit("Technician Level %d: Basic Multimeter unlocked." % technician_level, "success")

func purchase_upgrade(upgrade_id: String) -> bool:
	if upgrades.get(upgrade_id, false):
		return false
	var definitions: Dictionary = {
		"parts_tray":{"cost":140.0, "name":"Parts Tray", "carry":2},
		"parts_cabinet":{"cost":220.0, "name":"Parts Cabinet", "storage":12},
		"better_soldering_station":{"cost":200.0, "name":"Better Soldering Station", "tool":"better_soldering_station"}
	}
	var definition: Dictionary = definitions.get(upgrade_id, {})
	if definition.is_empty() or money < float(definition.get("cost", 0.0)):
		return false
	money -= float(definition.get("cost", 0.0))
	upgrades[upgrade_id] = true
	if definition.has("carry"):
		carrying_capacity += int(definition.carry)
	if definition.has("storage"):
		storage_capacity += int(definition.storage)
	if definition.has("tool"):
		tools[str(definition.tool)] = true
	event_logged.emit("Workshop upgraded: %s." % definition.get("name", upgrade_id), "success")
	return true

func _refresh_milestones() -> void:
	milestones["customer_accepted"] = _accepted_job_count() > 0
	milestones["parts_stocked"] = storage_used() > 0
	milestones["first_repair"] = _completed_count() > 0
	milestones["better_equipment"] = tools.get("multimeter", false) or tools.get("better_soldering_station", false)
	milestones["organized_storage"] = storage_capacity > BASE_STORAGE_CAPACITY

func _completed_count() -> int:
	var count := 0
	for job in jobs:
		if job.get("state", "") == "completed":
			count += 1
	return count

func get_progress_label() -> String:
	var job := get_job(selected_job_id)
	if job.is_empty():
		for candidate in jobs:
			if candidate.state == "client_waiting": return "Inspect %s at the Front Desk." % candidate.customer_name
		return "A customer is entering the shop." if _waiting_customer_count() > 0 else "Shop ready. New customers arrive throughout the day."
	match str(job.get("state", "")):
		"waiting_for_parts": return "Waiting for parts delivery: %s." % job.get("label", "repair")
		"ready_for_parts": return "Walk to Parts Storage: collect job bundle."
		"parts_partial": return "More parts needed at Parts Storage."
		"parts_collected": return "Walk to Repair Bench: choose diagnostic method."
		"diagnosing": return "Diagnosing %s: %.0f%%." % [job.get("label", "device"), float(job.get("progress", 0.0)) * 100.0]
		"awaiting_repair_choice": return "Diagnosis found %s: choose repair method." % job.get("actual_fault", "a fault")
		"repairing": return "Repairing %s: %.0f%%." % [job.get("label", "device"), float(job.get("progress", 0.0)) * 100.0]
		"ready_for_pickup": return "Repair complete: collect device from bench."
		"ready_for_delivery": return "Carry repaired device to Customer Pickup."
		"waiting_for_customer_pickup": return "Waiting for %s to return." % job.get("customer_name", "Customer")
		"customer_collecting": return "Customer collecting repaired device."
		"completed": return "Job complete. Choose next customer or upgrade."
	return "Walk to a highlighted workstation."

func get_summary() -> Dictionary:
	var active := 0
	var completed := 0
	for job in jobs:
		if job.get("state", "") == "completed":
			completed += 1
		elif job.get("state", "") != "declined":
			active += 1
	return {"cash":money, "reputation":reputation, "knowledge":0.0, "xp":technician_xp, "level":technician_level, "active_jobs":active, "completed_jobs":completed, "active_contracts":0, "production":completed, "bottlenecks":0, "era":"Solo Repair Technician", "expansion":1, "sales_today":sales_total, "sales_this_week":sales_total, "deliveries":deliveries.size(), "storage_used":storage_used(), "storage_capacity":storage_capacity, "carry_capacity":carrying_capacity}

func serialize() -> Dictionary:
	var copy := {
		"schema_version":3, "sales_total":sales_total, "random_state":str(random.state), "accumulator":_accumulator, "money":money, "reputation":reputation, "technician_xp":technician_xp, "technician_level":technician_level, "mastery":mastery, "tools":tools, "upgrades":upgrades, "inventory":inventory, "reserved_inventory":reserved_inventory, "deliveries":deliveries, "jobs":jobs, "milestones":milestones, "selected_job_id":selected_job_id, "simulation_time":simulation_time, "storage_capacity":storage_capacity, "carrying_capacity":carrying_capacity, "customer_timer":_customer_timer, "request_index":_request_index, "job_counter":_job_counter, "delivery_counter":_delivery_counter
	}
	var player_copy: Dictionary = player.duplicate(true)
	for key in ["position", "target"]:
		var value: Vector2 = player_copy.get(key, Vector2.ZERO)
		player_copy[key] = {"x":value.x, "y":value.y}
	copy["player"] = player_copy
	return copy.duplicate(true)

func restore(source: Dictionary) -> void:
	var data := source.duplicate(true)
	sales_total = float(data.get("sales_total", 0.0))
	_accumulator = float(data.get("accumulator", 0.0))
	random.state = int(data.get("random_state", random.state))
	money = float(data.get("money", 250.0))
	reputation = float(data.get("reputation", 1.0))
	technician_xp = float(data.get("technician_xp", 0.0))
	technician_level = int(data.get("technician_level", 1))
	mastery = data.get("mastery", {"general_repair":0})
	tools = data.get("tools", {"screwdriver_set":true, "cheap_soldering_iron":true, "bench_lamp":true})
	upgrades = data.get("upgrades", {})
	inventory = data.get("inventory", {})
	var had_reserved_inventory := data.has("reserved_inventory")
	reserved_inventory = data.get("reserved_inventory", {})
	deliveries = data.get("deliveries", [])
	jobs = data.get("jobs", [])
	for job in jobs:
		if not job.has("customer_state"):
			job["customer_state"] = "waiting" if job.get("state", "") == "client_waiting" else "absent"
			job["customer_progress"] = 0.0
			job["waiting_slot"] = jobs.find(job) % 3
			job["visual_variant"] = jobs.find(job) % 6
			job["rewards_granted"] = job.get("state", "") == "completed"
		if not job.has("reward"):
			job["reward"] = float(job.get("base_reward", 100.0))
		if not job.has("xp_reward"):
			job["xp_reward"] = 15
		if not job.has("reputation_reward"):
			job["reputation_reward"] = 0.15
		if not job.has("possible_faults"):
			job["possible_faults"] = ["Damaged component"]
		if not job.has("device_type"):
			job["device_type"] = "electronics"
		if not job.has("mastery_category"):
			job["mastery_category"] = "general_repair"
		if not job.has("reserved_materials"):
			var old_state := str(job.get("state", ""))
			var old_delivered: Dictionary = job.get("materials_delivered", {})
			job["reserved_materials"] = job.get("required_materials", {}).duplicate(true) if old_state == "materials_ready" else old_delivered.duplicate(true)
		if not job.has("collected_materials"):
			job["collected_materials"] = job.get("collected_materials", {})
		if job.get("state", "") == "materials_delivering":
			job["state"] = "waiting_for_parts"
		elif job.get("state", "") == "materials_ready":
			job["state"] = "ready_for_parts"
		elif job.get("state", "") == "materials_partial":
			job["state"] = "parts_partial"
	if not had_reserved_inventory:
		for job in jobs:
			var reserved_materials: Dictionary = job.get("reserved_materials", {})
			for component_id in reserved_materials:
				reserved_inventory[component_id] = int(reserved_inventory.get(component_id, 0)) + int(reserved_materials[component_id])
	milestones = data.get("milestones", {})
	selected_job_id = str(data.get("selected_job_id", ""))
	simulation_time = float(data.get("simulation_time", 0.0))
	storage_capacity = int(data.get("storage_capacity", BASE_STORAGE_CAPACITY))
	carrying_capacity = int(data.get("carrying_capacity", BASE_CARRY_CAPACITY))
	_customer_timer = float(data.get("customer_timer", 18.0))
	_request_index = int(data.get("request_index", 0))
	_job_counter = int(data.get("job_counter", jobs.size()))
	_delivery_counter = int(data.get("delivery_counter", deliveries.size()))
	var raw_player: Dictionary = data.get("player", {})
	player = raw_player.duplicate(true) if not raw_player.is_empty() else {"position":Layout.point("founder_start"), "target":Layout.point("founder_start"), "state":"IDLE", "pending_action":{}, "working_job_id":"", "phase":"", "carrying":"", "carried_parts":0, "interaction_ready":""}
	for key in ["position", "target"]:
		var raw: Variant = player.get(key, {"x":540.0, "y":600.0})
		player[key] = Vector2(float(raw.get("x", 540.0)), float(raw.get("y", 600.0))) if raw is Dictionary else raw

	if int(data.get("schema_version", 0)) < 3:
		player["position"] = Layout.point("founder_start")
		player["target"] = player.position
		player["pending_action"] = {}
		for job in jobs:
			if job.get("state", "") in ["diagnosing", "repairing", "awaiting_repair_choice"]:
				player["position"] = Layout.point("repair_bench")
				player["target"] = player.position
			if job.get("state", "") in ["ready_for_delivery", "parts_collected"]:
				player["carried_job_id"] = job.id

func _busy() -> bool:
	return not str(player.get("working_job_id", "")).is_empty()

func _free_waiting_slot() -> int:
	for slot in range(3):
		var occupied := false
		for job in jobs:
			if job.get("state", "") in ["arriving", "client_waiting"] and int(job.get("waiting_slot", -1)) == slot:
				occupied = true
		if not occupied: return slot
	return 0

func outbound_count() -> int:
	var count := 0
	for job in jobs:
		if job.get("state", "") in ["waiting_for_customer_pickup", "customer_collecting"]: count += 1
	return count

func _free_outbound_slot(exclude: String) -> int:
	for slot in range(OUTBOUND_CAPACITY):
		var occupied := false
		for job in jobs:
			if job.id != exclude and job.get("state", "") in ["waiting_for_customer_pickup", "customer_collecting"] and int(job.get("outbound_slot", -1)) == slot: occupied = true
		if not occupied: return slot
	return 0

func _process_customers(delta: float) -> void:
	var pickup_busy := false
	for job in jobs:
		if job.get("customer_state", "absent") in ["returning", "collecting", "exiting"]: pickup_busy = true
	for job in jobs:
		var state := str(job.get("customer_state", "absent"))
		if job.get("state", "") == "waiting_for_customer_pickup" and state == "absent":
			job["pickup_timer"] = maxf(0.0, float(job.get("pickup_timer", 0.0)) - delta)
			if float(job.pickup_timer) <= 0.0 and not pickup_busy:
				job["customer_state"] = "returning"
				job["customer_progress"] = 0.0
				pickup_busy = true
				sound_requested.emit("front_door")
			continue
		if state in ["absent", "waiting"]: continue
		var duration := CUSTOMER_PICKUP_DURATION if state == "collecting" else CUSTOMER_MOVE_DURATION
		job["customer_progress"] = minf(1.0, float(job.get("customer_progress", 0.0)) + delta / duration)
		if float(job.customer_progress) < 1.0: continue
		job["customer_progress"] = 0.0
		match state:
			"arriving":
				job["customer_state"] = "waiting"
				job["state"] = "client_waiting"
				sound_requested.emit("new_request")
				event_logged.emit("%s is waiting at reception." % job.customer_name,"info")
			"leaving", "exiting": job["customer_state"] = "absent"
			"returning":
				job["customer_state"] = "collecting"
				job["state"] = "customer_collecting"
			"collecting":
				_finish_job(job)
				job["customer_state"] = "exiting"
