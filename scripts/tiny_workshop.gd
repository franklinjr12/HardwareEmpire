extends Node2D

## Physical Era-1 workshop presentation. No economy or job rules live here.

const Layout = preload("res://scripts/simulation/era_one_layout.gd")
const Art = preload("res://scripts/workshop_art.gd")
const Entity = preload("res://scripts/workshop_entity.gd")
var world: Node2D
var front_door: Node2D
var service_door: Node2D
var entities: Node2D
var xp_bar: ProgressBar
var bench_progress: ProgressBar
var bench_status: Label
var delivery_status: Label
var pickup_status: Label
var xp_label: Label
var storage_bar: ProgressBar
var cash_delta: Label
var old_cash := -1.0
var old_level := 1
var panel_signature := ""
var entity_nodes := {}
const FLOOR := Color("#182838")
const FLOOR_LINE := Color("#294354")
const INK := Color("#e8f1f2")
const MUTED := Color("#91a9ad")
const ACCENT := Color("#f4bd55")
const GREEN := Color("#65d391")
const RED := Color("#ed7777")
const BLUE := Color("#65b9e8")
const PURPLE := Color("#b69bf2")

var game_state: HardwareEmpireState
var ui_layer: CanvasLayer
var money_label: Label
var status_label: Label
var notice_label: Label
var panel: PanelContainer
var panel_title: Label
var panel_body: RichTextLabel
var panel_actions: VBoxContainer
var panel_context := ""
var panel_job_id := ""
var notice_time := 0.0

func _ready() -> void:
	game_state = get_node_or_null("/root/GameState") as HardwareEmpireState
	if game_state == null:
		push_error("TinyWorkshop requires /root/GameState autoload")
		return
	if game_state.game_mode != "tiny_workshop":
		game_state.start_tiny_workshop()
	_build_world()
	_build_ui()
	game_state.state_changed.connect(_on_state_changed)
	game_state.event_logged.connect(_on_event_logged)
	_on_event_logged(game_state.last_offline_report, "info")
	queue_redraw()

func _process(delta: float) -> void:
	if game_state == null:
		return
	game_state.advance(delta)
	var station_id := game_state.consume_tiny_interaction()
	if not station_id.is_empty():
		_open_station(station_id)
	notice_time = max(0.0, notice_time - delta)
	_refresh_ui()
	_update_entities()
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	var top := PanelContainer.new()
	top.name = "TopHUD"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top.add_child(_margin(row))
	var brand := VBoxContainer.new()
	row.add_child(brand)
	brand.add_child(_label("HARDWARE EMPIRE", 20, ACCENT))
	brand.add_child(_label("Solo Repair Shop • Era 1", 12, MUTED))
	var progression := VBoxContainer.new()
	progression.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progression)
	xp_label = _label("LV 1", 14, INK)
	progression.add_child(xp_label)
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPProgress"
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(120, 10)
	progression.add_child(xp_bar)
	var economy := VBoxContainer.new()
	row.add_child(economy)
	money_label = _label("", 17, INK)
	economy.add_child(money_label)
	storage_bar = ProgressBar.new()
	storage_bar.show_percentage = false
	storage_bar.custom_minimum_size.y = 8
	economy.add_child(storage_bar)
	cash_delta = _label("", 13, GREEN)
	economy.add_child(cash_delta)
	row.add_child(_make_button("Upgrades", _show_upgrades, Vector2.ZERO, Vector2.ZERO))
	row.add_child(_make_button("Save", _save_game, Vector2.ZERO, Vector2.ZERO))
	var bottom := PanelContainer.new()
	bottom.name = "ObjectiveBar"
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -48
	status_label = _label("", 15, ACCENT)
	bottom.add_child(_margin(status_label))
	notice_label = _label("", 15, GREEN)
	notice_label.name = "ToastLayer"
	root.add_child(notice_label)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice_label.offset_top = -82
	notice_label.offset_left = 24
	panel = PanelContainer.new()
	panel.name = "ContextDrawer"
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -370
	panel.offset_top = 112
	panel.offset_bottom = -95
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_margin(scroll))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	panel_title = _label("", 22, ACCENT)
	panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(panel_title)
	column.add_child(_make_button("Close  ·  Esc", _close_panel, Vector2.ZERO, Vector2.ZERO))
	column.add_child(HSeparator.new())
	panel_body = RichTextLabel.new()
	panel_body.bbcode_enabled = true
	panel_body.fit_content = true
	panel_body.scroll_active = false
	panel_body.custom_minimum_size.y = 70
	column.add_child(panel_body)
	panel_actions = VBoxContainer.new()
	panel_actions.add_theme_constant_override("separation", 10)
	column.add_child(panel_actions)
	panel.hide()
	_refresh_ui()

func _margin(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_child(child)
	return margin

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_button(label: String, callback: Callable, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	return button

func _refresh_ui() -> void:
	if game_state == null:
		return
	var shop := game_state.repair_shop
	money_label.text = "$%d   •   Parts %d/%d" % [shop.money, shop.storage_used(), shop.storage_capacity]
	if old_cash >= 0 and not is_equal_approx(old_cash, shop.money):
		cash_delta.text = ("+$%d" if shop.money > old_cash else "-$%d") % abs(shop.money - old_cash)
		cash_delta.modulate = GREEN if shop.money > old_cash else RED
		var tween := create_tween()
		tween.tween_property(cash_delta, "modulate:a", 0.0, 3.0)
	old_cash = shop.money
	var level := shop.technician_level
	if level > old_level:
		xp_label.modulate = ACCENT
		create_tween().tween_property(xp_label,"modulate",Color.WHITE,2.5)
	old_level = level
	var base := shop.XP_THRESHOLDS[level - 1]
	var capped := level == shop.XP_THRESHOLDS.size()
	xp_bar.max_value = 1 if capped else shop.XP_THRESHOLDS[level] - base
	xp_bar.value = 1 if capped else shop.technician_xp - base
	xp_label.text = "LV %d  •  %s  •  REP %.1f" % [level, "MAX" if capped else "%d / %d XP" % [xp_bar.value, xp_bar.max_value], shop.reputation]
	storage_bar.max_value = shop.storage_capacity
	storage_bar.value = shop.storage_used()
	storage_bar.modulate = RED if shop.storage_used() >= shop.storage_capacity - 2 else GREEN
	if is_instance_valid(bench_progress):
		var active := _job_in_state(["diagnosing", "repairing"])
		bench_progress.value = float(active.get("progress",0.0))*100
		bench_status.text = "%s — %.0f%%" % [str(active.get("state", "Workbench idle")).capitalize(),bench_progress.value]
	if is_instance_valid(delivery_status):
		delivery_status.text = ""
		for delivery in shop.deliveries:
			delivery_status.text += ("Supplier: %.0fs" % ((1-float(delivery.progress))*shop.SUPPLIER_TRAVEL_TIME) if delivery.get("state","in_transit") == "in_transit" else str(delivery.state).replace("_"," ").capitalize()) + "\n"
	if is_instance_valid(pickup_status):
		pickup_status.text = ""
		for job in shop.jobs:
			if job.state in ["waiting_for_customer_pickup", "customer_collecting"]:
				pickup_status.text += "%s — %s\n%s\n\n" % [job.customer_name,job.label,"Returning in %.0fs" % job.get("pickup_timer",0.0) if job.customer_state == "absent" else str(job.customer_state).capitalize()]
	status_label.text = game_state.get_tiny_progress_label()
	if notice_time <= 0.0:
		notice_label.text = ""
	var signature := ""
	for job in shop.jobs: signature += str(job.state) + str(job.get("customer_state", ""))
	for delivery in shop.deliveries: signature += str(delivery.get("state", ""))
	signature += str(shop.inventory)
	if panel.visible and signature != panel_signature:
		panel_signature = signature
		match panel_context:
			"front": _show_front_desk()
			"storage": _show_parts_storage()
			"bench": _show_repair_bench()
			"outbound": _show_outbound()
	if panel.visible and panel_context == "job":
		var job := game_state._tiny_job(panel_job_id)
		if job.is_empty() or job.get("state", "") in ["completed", "declined"]:
			_close_panel()

func _on_state_changed() -> void:
	_refresh_ui()
	_update_entities()
	queue_redraw()

func _on_event_logged(message: String, severity: String) -> void:
	if message.is_empty() or not is_instance_valid(notice_label):
		return
	notice_label.text = message
	notice_time = 4.0
	notice_label.add_theme_color_override("font_color", RED if severity == "warning" else GREEN)

func _save_game() -> void:
	if game_state.save_game():
		_on_event_logged("Game saved.", "success")

func _clear_actions() -> void:
	bench_progress = null
	bench_status = null
	delivery_status = null
	pickup_status = null
	for child in panel_actions.get_children():
		panel_actions.remove_child(child)
		child.queue_free()

func _add_action(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("654546") if "REJECT" in label else Color("365951")
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_actions.add_child(button)
	return button

func _set_panel(title: String, body: String) -> void:
	panel.visible = true
	panel_title.text = title
	panel_body.text = body
	_clear_actions()

func _close_panel() -> void:
	panel.visible = false
	panel_context = ""
	panel_job_id = ""
	_clear_actions()

func _open_station(station_id: String) -> void:
	match station_id:
		"front_desk": _show_front_desk()
		"parts_shelf": _show_parts_storage()
		"repair_bench_1": _show_repair_bench()
		"outgoing_shelf": _show_outbound()

func _show_front_desk() -> void:
	panel_context = "front"
	_set_panel("FRONT DESK", "Customers waiting: %d / 3\n\nInspect each request. Accepting reserves stock and orders only missing parts." % _waiting_customers())
	var found := false
	for job in game_state.get_tiny_jobs():
		if job.get("state", "") != "client_waiting":
			continue
		found = true
		_add_action("INSPECT %s  •  %s" % [job.get("customer_name", "Customer"), job.get("label", "Repair")], Callable(self, "_show_job").bind(str(job.get("id", ""))))
	if not found:
		panel_body.text += "\n\nNo customers waiting. New customers arrive throughout the day."

func _show_job(job_id: String) -> void:
	var job := game_state._tiny_job(job_id)
	if job.is_empty():
		return
	panel_context = "job"
	panel_job_id = job_id
	_set_panel(str(job.get("label", "Repair request")), "[b]%s • %s[/b]\n%s\n\n[b]Reported problem[/b]\n%s\n\n[b]Required parts[/b]\n%s\n\n[b]Missing parts cost: $%.0f[/b]\n\nPayment up to $%.0f • +%d XP • +%.2f REP\n%s" % [job.customer_name,job.customer_archetype,job.device_type,job.reported_problem,_format_availability(job.required_materials),_job_missing_cost(job),job.reward,job.xp_reward,job.reputation_reward,job.difficulty])
	_add_action("ACCEPT JOB", Callable(self, "_accept_job").bind(job_id))
	_add_action("REJECT", Callable(self, "_reject_job").bind(job_id))
	_add_action("BACK TO FRONT DESK", Callable(self, "_show_front_desk"))

func _accept_job(job_id: String) -> void:
	if not game_state.accept_tiny_service(job_id):
		_on_event_logged("Cannot accept: check cash, level, capacity, or storage space.", "warning")
	else:
		_show_front_desk()

func _reject_job(job_id: String) -> void:
	game_state.decline_tiny_service(job_id)
	_show_front_desk()

func _show_parts_storage() -> void:
	panel_context = "storage"
	var summary := game_state.get_summary()
	var body := "Capacity: %d / %d slots\n\n" % [int(summary.get("storage_used", 0)), int(summary.get("storage_capacity", 12))]
	for definition in game_state.catalog.get("components", []):
		var id := str(definition.get("id", ""))
		body += "[b]%s[/b]\nStock %d • Reserved %d • Incoming %d • $%.0f each\n\n" % [definition.get("name", id), int(game_state.inventory.get(id, 0)), int(game_state.repair_shop.reserved_inventory.get(id, 0)), _incoming(id), float(definition.get("order_cost", 0.0))]
	for delivery in game_state.repair_shop.deliveries:
		body += "\nPackage: %s" % ("Supplier delivery %.0fs" % ((1.0-float(delivery.progress))*7.0) if delivery.get("state", "in_transit") == "in_transit" else str(delivery.state).replace("_", " ").capitalize())
	_set_panel("PARTS STORAGE", body + "\nPre-stock common parts to reduce future trips and delivery waits.")
	for definition in game_state.catalog.get("components", []):
		var id := str(definition.get("id", ""))
		var order_button := _add_action("ORDER 2 %s  /  $%.0f" % [definition.get("name", id), float(definition.get("order_cost", 0.0)) * 2.0], Callable(self, "_order_parts").bind(id))
		order_button.disabled = game_state.repair_shop.money < float(definition.get("order_cost", 0.0))*2 or game_state.repair_shop.storage_used()+2 > game_state.repair_shop.storage_capacity
		order_button.tooltip_text = "Requires enough cash and two free storage slots." if order_button.disabled else "Supplier will deliver to the rear service entrance."
	delivery_status = _label("", 14, BLUE)
	panel_actions.add_child(delivery_status)
	var ready := _job_in_state(["ready_for_parts", "parts_partial"])
	if not ready.is_empty():
		_add_action("TAKE PARTS FOR %s" % ready.get("label", "JOB"), Callable(self, "_collect_parts").bind(str(ready.get("id", ""))))

func _order_parts(component_id: String) -> void:
	if not game_state.order_tiny_parts(component_id, 2):
		_on_event_logged("Order blocked: cash or storage capacity.", "warning")
	_show_parts_storage()

func _collect_parts(job_id: String) -> void:
	if not game_state.collect_tiny_materials(job_id, []):
		_on_event_logged("Parts not ready or already reserved.", "warning")
	else:
		_close_panel()

func _show_repair_bench() -> void:
	panel_context = "bench"
	var body := "One bench • Founder operated\n\n"
	var selected := _job_in_state(["diagnosing","awaiting_repair_choice","repairing","ready_for_pickup"])
	if not selected.is_empty():
		body += "Selected: %s\nState: %s\n" % [selected.get("label", "Job"), selected.get("state", "Unknown")]
		if selected.get("state", "") == "diagnosing":
			body += "Progress: %.0f%%" % (float(selected.get("progress", 0.0)) * 100.0)
		elif selected.get("state", "") == "awaiting_repair_choice":
			body += "Fault found: %s" % selected.get("actual_fault", "Unknown fault")
		elif selected.get("state", "") == "repairing":
			body += "Repair progress: %.0f%%" % (float(selected.get("progress", 0.0)) * 100.0)
	_set_panel("REPAIR BENCH", body)
	if not selected.is_empty() and selected.state in ["diagnosing", "repairing"]:
		bench_status = _label("", 15, BLUE)
		panel_actions.add_child(bench_status)
		bench_progress = ProgressBar.new()
		bench_progress.custom_minimum_size.y = 18
		panel_actions.add_child(bench_progress)
	var actionable := false
	for job in game_state.get_tiny_jobs():
		var state := str(job.get("state", ""))
		if state == "parts_collected":
			actionable = true
			for method in game_state.get_tiny_diagnostic_methods(str(job.get("id", ""))):
				_add_action("DIAGNOSE %s  •  %ss" % [method.get("name", "Visual inspection"), str(method.get("duration", 4.0))], Callable(self, "_start_diagnosis").bind(str(job.get("id", "")), str(method.get("id", "visual_inspection"))))
		elif state == "awaiting_repair_choice":
			actionable = true
			for method in game_state.get_tiny_repair_methods(str(job.get("id", ""))):
				panel_actions.add_child(_label("%.0f%% success • Tool: %s" % [float(method.get("success", 0.9))*100, str(method.get("required_tool", "None")).replace("_", " ")], 12, MUTED))
				_add_action("REPAIR %s  •  $%.0f / %ss" % [method.get("name", "Repair"), float(method.get("cost", 0.0)), str(method.get("duration", 8.0))], Callable(self, "_start_repair_method").bind(str(job.get("id", "")), str(method.get("id", ""))))
		elif state == "ready_for_pickup":
			actionable = true
			_add_action("PICK UP COMPLETED DEVICE", Callable(self, "_pickup_device").bind(str(job.get("id", ""))))
	if not actionable and selected.is_empty():
		body += "\n\nNo job ready for a bench decision."
		panel_body.text = body

func _start_diagnosis(job_id: String, method_id: String) -> void:
	if not game_state.repair_shop.request_start_diagnosis(job_id, method_id):
		_on_event_logged("Diagnosis unavailable: need parts, level, or tool.", "warning")
	else:
		game_state._sync_repair_shop_state()
		_close_panel()

func _start_repair_method(job_id: String, method_id: String) -> void:
	if not game_state.start_tiny_repair_method(job_id, method_id):
		_on_event_logged("Repair unavailable: check cash or required tool.", "warning")
	else:
		_close_panel()

func _pickup_device(job_id: String) -> void:
	if not game_state.collect_tiny_device(job_id):
		_on_event_logged("Device is not ready.", "warning")
	else:
		_close_panel()

func _show_outbound() -> void:
	panel_context = "outbound"
	_set_panel("CUSTOMER PICKUP", "Place repaired devices here. Payment follows customer collection.")
	var ready := _job_in_state(["ready_for_delivery"])
	if not ready.is_empty():
		_add_action("PLACE %s AT PICKUP" % ready.get("label", "DEVICE"), Callable(self, "_deliver_job").bind(str(ready.get("id", ""))))
	else:
		panel_body.text += "\n\nNo carried device."
	pickup_status = _label("", 15, INK)
	pickup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_actions.add_child(pickup_status)

func _deliver_job(job_id: String) -> void:
	if not game_state.deliver_tiny_repair(job_id):
		_on_event_logged("Pickup blocked: carry repaired device; counter capacity 3.", "warning")
	else:
		_close_panel()

func _show_upgrades() -> void:
	panel_context = "upgrades"
	_set_panel("WORKSHOP UPGRADES", "Each upgrade removes physical friction and changes workshop capability.")
	var upgrade_defs := [{"id":"parts_tray", "name":"Parts Tray", "description":"Carry more parts per trip", "cost":140.0}, {"id":"parts_cabinet", "name":"Parts Cabinet", "description":"+12 storage capacity", "cost":220.0}, {"id":"better_soldering_station", "name":"Better Soldering Station", "description":"Repair 25% faster; better success", "cost":200.0}]
	for definition in upgrade_defs:
		var id := str(definition.id)
		if not game_state.workshop_upgrades.get(id, false):
			panel_actions.add_child(_label(str(definition.description), 13, MUTED))
			_add_action("BUY %s  /  $%.0f" % [definition.name, definition.cost], Callable(self, "_buy_upgrade").bind(id))

func _buy_upgrade(upgrade_id: String) -> void:
	if not game_state.purchase_tiny_upgrade(upgrade_id):
		_on_event_logged("Upgrade unavailable: need cash.", "warning")
	_show_upgrades()

func _waiting_customers() -> int:
	var count := 0
	for job in game_state.get_tiny_jobs():
		if job.get("state", "") == "client_waiting":
			count += 1
	return count

func _job_in_state(states: Array) -> Dictionary:
	for job in game_state.get_tiny_jobs():
		if str(job.get("state", "")) in states:
			return job
	return {}

func _incoming(component_id: String) -> int:
	return game_state.repair_shop.incoming_quantity(component_id)

func _job_missing_cost(job: Dictionary) -> float:
	var cost := 0.0
	var required: Dictionary = job.get("required_materials", {})
	for component_id in required:
		var needed := int(required[component_id])
		var available: int = max(0, int(game_state.inventory.get(component_id, 0)) - int(game_state.repair_shop.reserved_inventory.get(component_id, 0)))
		cost += float(max(0, needed - available)) * game_state.repair_shop.get_component_cost(str(component_id))
	return cost

func _format_materials(materials: Dictionary) -> String:
	var result: Array[String] = []
	for component_id in materials:
		result.append("%dx %s" % [int(materials[component_id]), game_state.repair_shop.get_component_name(str(component_id))])
	return ", ".join(result)

func _format_availability(materials: Dictionary) -> String:
	var result: Array[String] = []
	for component_id in materials:
		var id := str(component_id)
		result.append("%s • Need %d / Stock %d / Incoming %d" % [game_state.repair_shop.get_component_name(id), int(materials[id]), game_state.repair_shop.available_stock(id), _incoming(id)])
	return "\n".join(result)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if panel.visible:
			_close_panel()
			return
		_handle_world_click(event.position)

func _handle_world_click(screen_position: Vector2) -> void:
	var point := world.to_local(screen_position)
	for station in Layout.FOOTPRINTS:
		if Layout.FOOTPRINTS[station].has_point(point):
			game_state.interact_tiny_station(station)
			return
	for job in game_state.get_tiny_jobs():
		if job.get("state", "") == "client_waiting" and Layout.customer_position(job).distance_to(point) < 30:
			game_state.interact_tiny_station("front_desk")
			return
	if Layout.FOUNDER_AREA.has_point(point): game_state.move_tiny_player_to(point)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and panel.visible:
		_close_panel()

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var environment := Node2D.new()
	environment.name = "Environment"
	world.add_child(environment)
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2(80,60),Vector2(850,60),Vector2(850,650),Vector2(80,650)])
	floor.color = Color("898877")
	environment.add_child(floor)
	var floor_art := Sprite2D.new()
	floor_art.name = "FloorArtwork"
	floor_art.texture = load("res://assets/era_one/floor.png")
	floor_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_art.centered = false
	floor_art.region_enabled = true
	floor_art.region_rect = Rect2(0,0,3080,2360)
	floor_art.scale = Vector2.ONE*0.25
	floor_art.position = Vector2(80,60)
	floor_art.modulate = Color("beb9a8")
	environment.add_child(floor_art)
	front_door = Node2D.new()
	front_door.name = "FrontDoorArtwork"
	front_door.position = Vector2(190,660)
	front_door.add_child(Art.sprite("door",78))
	environment.add_child(front_door)
	service_door = Node2D.new()
	service_door.name = "ServiceDoorArtwork"
	service_door.position = Vector2(87,187)
	service_door.add_child(Art.sprite("door",53))
	service_door.modulate = Color("bac6cd")
	environment.add_child(service_door)
	for rect in [Rect2(65,45,800,25),Rect2(65,45,20,85),Rect2(65,190,20,470),Rect2(845,45,20,615),Rect2(65,650,85,20),Rect2(230,650,635,20),Rect2(85,415,70,45),Rect2(345,415,250,45),Rect2(775,415,70,45)]:
		var wall := Polygon2D.new()
		wall.polygon = PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
		wall.color = Color("4b5350")
		environment.add_child(wall)
	for entry in [["SERVICE",Vector2(85,100)],["ENTRANCE",Vector2(155,625)],["RECEPTION",Vector2(170,475)],["CUSTOMER PICKUP",Vector2(610,475)],["PARTS",Vector2(180,42)],["WORKBENCH",Vector2(410,145)]]:
		var label := _label(entry[0], 12, Color("e5d9b7"))
		label.position = entry[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		environment.add_child(label)
	for point in [Vector2(320,615),Vector2(390,615)]:
		var chair := Node2D.new()
		chair.position = point
		chair.add_child(Art.sprite("waiting_chair",34))
		environment.add_child(chair)
	for point in [Vector2(315,125),Vector2(335,143)]:
		var box := Node2D.new()
		box.position = point
		box.add_child(Art.sprite("package",28))
		environment.add_child(box)
	entities = Node2D.new()
	entities.name = "FurnitureItemsNPCsFounder"
	entities.y_sort_enabled = true
	world.add_child(entities)
	for id in Layout.FOOTPRINTS:
		var rect: Rect2 = Layout.FOOTPRINTS[id]
		var node := _entity(id, id, Vector2(rect.get_center().x, rect.end.y))
		node.tint = Color("a18b64") if id != "outgoing_shelf" else Color("709182")

func _entity(id: String, kind: String, point: Vector2) -> Node2D:
	if not entity_nodes.has(id):
		var node := Node2D.new()
		node.set_script(Entity)
		node.kind = kind
		if kind in ["device", "package"]: node.z_index = 1
		node.position = point.round()
		node.name = id
		entities.add_child(node)
		entity_nodes[id] = node
	var entity: Node2D = entity_nodes[id]
	if absf(point.x - entity.position.x) > 1.0:
		entity.facing = -1.0 if point.x < entity.position.x else 1.0
	entity.position = entity.position.lerp(point, minf(1.0, get_process_delta_time()*14.0)).round() if is_processing() else point.round()
	entity.show()
	return entity

func _update_entities() -> void:
	if world == null: return
	var viewport := get_viewport_rect().size
	var factor := minf((viewport.x-48)/930.0, (viewport.y-180)/680.0)
	world.scale = Vector2.ONE * factor
	world.position = Vector2((viewport.x-930*factor)/2,110)
	for id in entity_nodes:
		if not Layout.FOOTPRINTS.has(id): entity_nodes[id].hide()
	var shop := game_state.repair_shop
	var founder := _entity("Founder", "founder", shop.player.position)
	founder.tint = Color("c67c57")
	founder.moving = shop.player.state == "MOVING"
	founder.carrying = shop.player.get("carrying", "")
	founder.phase = shop.simulation_time
	founder.working = shop.player.state == "WORKING"
	entity_nodes["repair_bench_1"].upgraded = bool(shop.tools.get("better_soldering_station",false))
	entity_nodes["parts_shelf"].upgraded = shop.storage_capacity > 12
	front_door.scale.x = 1.0
	service_door.scale.x = 1.0
	entity_nodes["repair_bench_1"].work_progress = -1.0
	for job in shop.jobs:
		if job.get("customer_state", "absent") in ["arriving","leaving","returning","exiting"]:
			front_door.scale.x = 0.24
		if job.state in ["diagnosing","repairing"]:
			entity_nodes["repair_bench_1"].work_progress = float(job.progress)
		if job.get("customer_state", "absent") != "absent":
			var customer := _entity("customer_"+job.id,"customer",Layout.customer_position(job))
			customer.tint = [Color("7c9d9c"),Color("b58e68"),Color("9c83a4"),Color("87a776"),Color("bc7974"),Color("778fb2")][int(job.get("visual_variant",0))%6]
			customer.visual_variant = int(job.get("visual_variant",0))
			customer.moving = job.customer_state in ["arriving","leaving","returning","exiting"]
			customer.phase = shop.simulation_time
			customer.waiting = job.customer_state == "waiting"
			customer.carrying = "device" if job.customer_state == "exiting" else ""
		if job.state in ["waiting_for_customer_pickup","customer_collecting"]:
			_entity("device_"+job.id,"device",Vector2(625+int(job.get("outbound_slot",0))*52,431))
		elif job.state in ["diagnosing","repairing","awaiting_repair_choice","ready_for_pickup"]:
			_entity("device_"+job.id,"device",Vector2(460,202))
	for delivery in shop.deliveries:
		var state := str(delivery.get("state","in_transit"))
		if state == "in_transit": continue
		service_door.scale.x = 0.24
		var start := Layout.point("service_entrance")
		var finish := Layout.point("delivery_drop")
		var point := start.lerp(finish,float(delivery.progress)) if state == "courier_arriving" else (finish.lerp(start,float(delivery.progress)) if state == "courier_leaving" else finish)
		var courier := _entity("courier_"+delivery.id,"courier",point)
		courier.tint = Color("b29a59")
		courier.moving = state != "delivering"
		courier.phase = shop.simulation_time
		courier.carrying = "package" if not delivery.get("credited",false) else ""
	for id in entity_nodes.keys():
		if not entity_nodes[id].visible:
			entity_nodes[id].queue_free()
			entity_nodes.erase(id)
			continue
		if Layout.FOOTPRINTS.has(id): entity_nodes[id].highlighted = Layout.FOOTPRINTS[id].has_point(world.get_local_mouse_position())
		entity_nodes[id]._update_art()
		entity_nodes[id].queue_redraw()

func _draw() -> void:
	draw_rect(get_viewport_rect(),Color("273633"))
