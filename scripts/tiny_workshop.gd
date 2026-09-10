extends Node2D

## Physical Era-1 workshop presentation. No economy or job rules live here.

const WORLD_RECT := Rect2(0, 68, 1040, 652)
const PANEL_RECT := Rect2(1060, 84, 360, 620)
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
var panel: ColorRect
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
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	var top_bar := ColorRect.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(1440, 68)
	top_bar.color = Color("#101b29")
	ui_layer.add_child(top_bar)
	var title := Label.new()
	title.text = "HARDWARE EMPIRE  /  SOLO REPAIR SHOP"
	title.position = Vector2(24, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ACCENT)
	top_bar.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ERA 1  •  YOU ARE THE TECHNICIAN  •  WALK THE WORKFLOW"
	subtitle.position = Vector2(26, 39)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", MUTED)
	top_bar.add_child(subtitle)
	money_label = Label.new()
	money_label.position = Vector2(510, 19)
	money_label.add_theme_font_size_override("font_size", 15)
	top_bar.add_child(money_label)
	var upgrade_button := _make_button("UPGRADES", Callable(self, "_show_upgrades"), Vector2(1190, 16), Vector2(105, 34))
	top_bar.add_child(upgrade_button)
	var save_button := _make_button("SAVE", Callable(self, "_save_game"), Vector2(1305, 16), Vector2(82, 34))
	top_bar.add_child(save_button)
	status_label = Label.new()
	status_label.position = Vector2(24, 734)
	status_label.size = Vector2(1010, 28)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", ACCENT)
	ui_layer.add_child(status_label)
	notice_label = Label.new()
	notice_label.position = Vector2(24, 766)
	notice_label.size = Vector2(1010, 28)
	notice_label.add_theme_font_size_override("font_size", 13)
	ui_layer.add_child(notice_label)
	panel = ColorRect.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.color = Color("#172536f5")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(panel)
	panel_title = Label.new()
	panel_title.position = Vector2(20, 18)
	panel_title.size = Vector2(320, 35)
	panel_title.add_theme_font_size_override("font_size", 19)
	panel_title.add_theme_color_override("font_color", ACCENT)
	panel.add_child(panel_title)
	panel_body = RichTextLabel.new()
	panel_body.position = Vector2(20, 62)
	panel_body.size = Vector2(320, 210)
	panel_body.bbcode_enabled = true
	panel_body.add_theme_font_size_override("normal_font_size", 13)
	panel_body.add_theme_color_override("default_color", INK)
	panel.add_child(panel_body)
	panel_actions = VBoxContainer.new()
	panel_actions.position = Vector2(20, 285)
	panel_actions.size = Vector2(320, 315)
	panel_actions.add_theme_constant_override("separation", 6)
	panel.add_child(panel_actions)
	panel.visible = false
	_refresh_ui()

func _make_button(label: String, callback: Callable, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

func _refresh_ui() -> void:
	if game_state == null:
		return
	var summary := game_state.get_summary()
	money_label.text = "CASH $%d    LV %d  XP %.0f    REP %.1f    STORAGE %d/%d" % [int(summary.get("cash", 0.0)), int(summary.get("level", 1)), float(summary.get("xp", 0.0)), float(summary.get("reputation", 0.0)), int(summary.get("storage_used", 0)), int(summary.get("storage_capacity", 12))]
	status_label.text = game_state.get_tiny_progress_label()
	if notice_time <= 0.0:
		notice_label.text = ""
	if panel.visible and panel_context == "job":
		var job := game_state._tiny_job(panel_job_id)
		if job.is_empty() or job.get("state", "") in ["completed", "declined"]:
			_close_panel()

func _on_state_changed() -> void:
	_refresh_ui()
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
	for child in panel_actions.get_children():
		child.queue_free()

func _add_action(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	panel_actions.add_child(button)

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
		panel_body.text += "\n\nNo customer waiting. Keep workshop ready."
	_add_action("CLOSE", Callable(self, "_close_panel"))

func _show_job(job_id: String) -> void:
	var job := game_state._tiny_job(job_id)
	if job.is_empty():
		return
	panel_context = "job"
	panel_job_id = job_id
	var parts := _format_materials(job.get("required_materials", {}))
	var available := _format_availability(job.get("required_materials", {}))
	_set_panel(str(job.get("label", "Repair request")), "Customer: %s (%s)\nDevice: %s\n\nReported problem:\n%s\n\nRequired parts: %s\n%s\nParts cost now: $%.0f\nExpected payment: $%.0f\nDifficulty: %s\nXP: %d" % [job.get("customer_name", "Customer"), job.get("customer_archetype", "Home user"), job.get("device_type", "electronics"), job.get("reported_problem", "Device needs repair."), parts, available, float(_job_missing_cost(job)), float(job.get("reward", 0.0)), job.get("difficulty", "Basic"), int(job.get("xp_reward", 0))])
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
		body += "%s  stock %d  incoming %d  $%.0f\n" % [definition.get("name", id), int(game_state.inventory.get(id, 0)), _incoming(id), float(definition.get("order_cost", 0.0))]
	_set_panel("PARTS STORAGE", body + "\nPre-stock common parts to reduce future trips and delivery waits.")
	for definition in game_state.catalog.get("components", []):
		var id := str(definition.get("id", ""))
		_add_action("ORDER 2 %s  /  $%.0f" % [definition.get("name", id), float(definition.get("order_cost", 0.0)) * 2.0], Callable(self, "_order_parts").bind(id))
	var ready := _job_in_state(["ready_for_parts", "parts_partial"])
	if not ready.is_empty():
		_add_action("TAKE PARTS FOR %s" % ready.get("label", "JOB"), Callable(self, "_collect_parts").bind(str(ready.get("id", ""))))
	_add_action("CLOSE", Callable(self, "_close_panel"))

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
	var body := "Your workbench.\nDiagnosis creates a choice; repair method changes time, cost, and margin.\n\n"
	var selected := game_state._tiny_job(game_state.tiny_selected_job_id)
	if not selected.is_empty():
		body += "Selected: %s\nState: %s\n" % [selected.get("label", "Job"), selected.get("state", "Unknown")]
		if selected.get("state", "") == "diagnosing":
			body += "Progress: %.0f%%" % (float(selected.get("progress", 0.0)) * 100.0)
		elif selected.get("state", "") == "awaiting_repair_choice":
			body += "Fault found: %s" % selected.get("actual_fault", "Unknown fault")
		elif selected.get("state", "") == "repairing":
			body += "Repair progress: %.0f%%" % (float(selected.get("progress", 0.0)) * 100.0)
	_set_panel("REPAIR BENCH", body)
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
				_add_action("REPAIR %s  •  $%.0f / %ss" % [method.get("name", "Repair"), float(method.get("cost", 0.0)), str(method.get("duration", 8.0))], Callable(self, "_start_repair_method").bind(str(job.get("id", "")), str(method.get("id", ""))))
		elif state == "ready_for_pickup":
			actionable = true
			_add_action("PICK UP COMPLETED DEVICE", Callable(self, "_pickup_device").bind(str(job.get("id", ""))))
	if not actionable:
		body += "\n\nNo job ready for a bench decision."
		panel_body.text = body
	_add_action("CLOSE", Callable(self, "_close_panel"))

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
	_set_panel("OUTBOUND DESK", "Completed devices leave workshop here.\nCarry each repaired device to customer pickup.")
	var ready := _job_in_state(["ready_for_delivery"])
	if not ready.is_empty():
		_add_action("DELIVER %s  /  RECEIVE $%.0f" % [ready.get("label", "DEVICE"), float(ready.get("reward", 0.0))], Callable(self, "_deliver_job").bind(str(ready.get("id", ""))))
	else:
		panel_body.text += "\n\nNo repaired device waiting."
	_add_action("CLOSE", Callable(self, "_close_panel"))

func _deliver_job(job_id: String) -> void:
	if not game_state.deliver_tiny_repair(job_id):
		_on_event_logged("Carry repaired device to Outbound Desk first.", "warning")
	else:
		_close_panel()

func _show_upgrades() -> void:
	panel_context = "upgrades"
	_set_panel("WORKSHOP UPGRADES", "Each upgrade removes physical friction and changes workshop capability.")
	var upgrade_defs := [{"id":"parts_tray", "name":"Parts Tray", "description":"Carry more parts per trip", "cost":140.0}, {"id":"parts_cabinet", "name":"Parts Cabinet", "description":"+12 storage capacity", "cost":220.0}, {"id":"better_soldering_station", "name":"Better Soldering Station", "description":"Repair 25% faster; better success", "cost":200.0}]
	for definition in upgrade_defs:
		var id := str(definition.id)
		if not game_state.workshop_upgrades.get(id, false):
			_add_action("BUY %s  /  $%.0f" % [definition.name, definition.cost], Callable(self, "_buy_upgrade").bind(id))
	_add_action("CLOSE", Callable(self, "_close_panel"))

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
	var total := 0
	for delivery in game_state.deliveries:
		if str(delivery.get("component_id", "")) == component_id:
			total += int(delivery.get("quantity", 0))
	return total

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
		result.append("%s: %d stock / %d incoming" % [game_state.repair_shop.get_component_name(id), game_state.repair_shop.available_stock(id), _incoming(id)])
	return "\n".join(result)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if panel.visible:
			return
		_handle_world_click(event.position)

func _handle_world_click(position: Vector2) -> void:
	if Rect2(80, 95, 280, 230).has_point(position):
		game_state.interact_tiny_station("front_desk")
	elif Rect2(80, 350, 270, 220).has_point(position):
		game_state.interact_tiny_station("parts_shelf")
	elif Rect2(370, 330, 340, 250).has_point(position):
		game_state.interact_tiny_station("repair_bench_1")
	elif Rect2(760, 95, 250, 230).has_point(position):
		game_state.interact_tiny_station("outgoing_shelf")
	else:
		game_state.move_tiny_player_to(position)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and panel.visible:
		_close_panel()

func _draw() -> void:
	draw_rect(WORLD_RECT, FLOOR)
	_draw_floor()
	_draw_zone(Rect2(80, 95, 280, 230), "FRONT DESK  /  CUSTOMERS", Color("#31556a"))
	_draw_zone(Rect2(80, 350, 270, 220), "PARTS STORAGE", Color("#6e512c"))
	_draw_zone(Rect2(370, 330, 340, 250), "REPAIR BENCH", Color("#704937"))
	_draw_zone(Rect2(760, 95, 250, 230), "OUTBOUND DESK", Color("#315c49"))
	_draw_customers()
	_draw_storage()
	_draw_bench()
	_draw_outbound()
	_draw_deliveries()
	_draw_player()

func _draw_floor() -> void:
	for x in range(0, 1041, 32):
		draw_line(Vector2(x, 68), Vector2(x, 720), FLOOR_LINE, 1.0)
	for y in range(68, 721, 32):
		draw_line(Vector2(0, y), Vector2(1040, y), FLOOR_LINE, 1.0)
	draw_line(Vector2(380, 68), Vector2(380, 720), Color("#d5aa5e55"), 3.0)
	draw_line(Vector2(745, 68), Vector2(745, 720), Color("#d5aa5e55"), 3.0)

func _draw_zone(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, Color(color, 0.22), true)
	draw_rect(rect, color, false, 3.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 27), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)

func _draw_customers() -> void:
	var index := 0
	for job in game_state.get_tiny_jobs():
		if job.get("state", "") != "client_waiting":
			continue
		var position := Vector2(150.0 + float(index % 3) * 78.0, 175.0)
		draw_circle(position, 15.0, [Color("#d48767"), Color("#c5a06b"), Color("#9d82c4")][index % 3])
		draw_rect(Rect2(position + Vector2(-13, 11), Vector2(26, 25)), Color("#6b8fb5"), true)
		draw_string(ThemeDB.fallback_font, position + Vector2(-28, 56), "INSPECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ACCENT)
		draw_string(ThemeDB.fallback_font, position + Vector2(-34, 71), str(job.get("customer_archetype", "CUSTOMER")), HORIZONTAL_ALIGNMENT_LEFT, 70, 9, MUTED)
		index += 1
	if index == 0:
		draw_string(ThemeDB.fallback_font, Vector2(112, 220), "No customer waiting", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

func _draw_storage() -> void:
	for row in range(2):
		for column in range(4):
			var position := Vector2(112 + column * 55, 405 + row * 52)
			draw_rect(Rect2(position, Vector2(42, 30)), Color("#a87537"), true)
			draw_rect(Rect2(position, Vector2(42, 30)), Color("#d6a85d"), false, 2.0)
			var components: Array = game_state.catalog.get("components", [])
			if column < components.size():
				var id := str(components[column].get("id", ""))
				var amount := int(game_state.inventory.get(id, 0))
				draw_string(ThemeDB.fallback_font, position + Vector2(5, 20), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK if amount > 0 else RED)
				draw_string(ThemeDB.fallback_font, Vector2(position.x - 2, position.y + 44), str(components[column].get("short", id.left(4).to_upper())), HORIZONTAL_ALIGNMENT_LEFT, 48, 9, MUTED)
	var summary := game_state.get_summary()
	draw_string(ThemeDB.fallback_font, Vector2(104, 548), "CAPACITY %d / %d" % [int(summary.get("storage_used", 0)), int(summary.get("storage_capacity", 12))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACCENT)

func _draw_bench() -> void:
	var bench := Vector2(540, 465)
	draw_rect(Rect2(bench - Vector2(130, 30), Vector2(260, 60)), Color("#9a633f"), true)
	draw_rect(Rect2(bench - Vector2(130, 30), Vector2(260, 60)), Color("#d99b62"), false, 3.0)
	draw_line(bench + Vector2(-100, 30), bench + Vector2(-100, 74), Color("#4b3025"), 7.0)
	draw_line(bench + Vector2(100, 30), bench + Vector2(100, 74), Color("#4b3025"), 7.0)
	draw_rect(Rect2(bench + Vector2(-90, -20), Vector2(44, 20)), Color("#d0d7dc"), true)
	draw_line(bench + Vector2(-69, -10), bench + Vector2(-25, -10), Color("#303b45"), 3.0)
	draw_circle(bench + Vector2(76, -12), 13, Color("#f4bd55"))
	draw_line(bench + Vector2(76, -12), bench + Vector2(45, -35), Color("#e2e8f0"), 4.0)
	if game_state.owned_tools.get("multimeter", false):
		draw_rect(Rect2(bench + Vector2(12, -22), Vector2(30, 24)), Color("#6aa7c4"), true)
		draw_line(bench + Vector2(42, -10), bench + Vector2(64, -4), Color("#202b35"), 2.0)
	if game_state.owned_tools.get("better_soldering_station", false):
		draw_rect(Rect2(bench + Vector2(-12, -22), Vector2(20, 22)), Color("#bf5b4f"), true)
	var job := _job_in_state(["diagnosing", "awaiting_repair_choice", "repairing", "ready_for_pickup"])
	if not job.is_empty():
		_draw_device(bench + Vector2(0, -58), str(job.get("visual_kind", "device_board")), job.get("state", "") == "ready_for_pickup")
		if job.get("state", "") in ["diagnosing", "repairing"]:
			var color := BLUE if job.get("state", "") == "diagnosing" else GREEN
			draw_rect(Rect2(455, 525, 170, 8), Color("#0d151f"), true)
			draw_rect(Rect2(455, 525, 170 * float(job.get("progress", 0.0)), 8), color, true)

func _draw_device(position: Vector2, visual_kind: String, ready: bool) -> void:
	var body_color := ACCENT if ready else Color("#74a7be")
	draw_rect(Rect2(position - Vector2(42, 25), Vector2(84, 50)), body_color, true)
	draw_rect(Rect2(position - Vector2(42, 25), Vector2(84, 50)), Color("#d8e8e8"), false, 3.0)
	draw_rect(Rect2(position - Vector2(30, 16), Vector2(60, 27)), Color("#162638"), true)
	draw_string(ThemeDB.fallback_font, position + Vector2(-30, 5), "DEVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

func _draw_outbound() -> void:
	draw_rect(Rect2(800, 185, 170, 65), Color("#4e956f"), true)
	draw_rect(Rect2(800, 185, 170, 65), Color("#a5e3ad"), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(824, 225), "CUSTOMER PICKUP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	var count := 0
	for job in game_state.get_tiny_jobs():
		if job.get("state", "") == "completed":
			count += 1
	for i in range(min(count, 4)):
		draw_rect(Rect2(818 + i * 34, 265, 25, 20), Color("#66bb77"), true)

func _draw_deliveries() -> void:
	var index := 0
	for delivery in game_state.deliveries:
		var start := Vector2(930, 75 - index * 22)
		var finish := Vector2(200, 385)
		var position: Vector2 = start.lerp(finish, float(delivery.get("progress", 0.0)))
		draw_rect(Rect2(position - Vector2(12, 9), Vector2(24, 18)), Color("#fbbf24"), true)
		draw_line(position + Vector2(-8, -3), position + Vector2(8, -3), Color("#78350f"), 2.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(-18, -14), "COURIER", HORIZONTAL_ALIGNMENT_LEFT, 55, 8, BLUE)
		index += 1

func _draw_player() -> void:
	var position: Vector2 = game_state.tiny_player.get("position", Vector2(540, 600))
	var moving: bool = str(game_state.tiny_player.get("state", "")) == "MOVING"
	draw_circle(position + Vector2(0, -22), 12.0, Color("#f2c14e"))
	draw_rect(Rect2(position + Vector2(-14, -10), Vector2(28, 35)), Color("#d66a52"), true)
	draw_line(position + Vector2(-7, 25), position + Vector2(-10, 42), INK, 4.0)
	draw_line(position + Vector2(7, 25), position + Vector2(10, 42), INK, 4.0)
	draw_string(ThemeDB.fallback_font, position + Vector2(-27, -45), "WALKING" if moving else "FOUNDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BLUE if moving else ACCENT)
	var carrying := str(game_state.tiny_player.get("carrying", ""))
	if not carrying.is_empty():
		draw_rect(Rect2(position + Vector2(17, -3), Vector2(24, 22)), Color("#c99551"), true)
		draw_string(ThemeDB.fallback_font, position + Vector2(14, 34), "CARRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ACCENT)
