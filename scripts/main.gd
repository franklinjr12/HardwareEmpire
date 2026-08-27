extends Node2D

const WORLD_SIZE := Vector2(2200, 1050)
const PANEL_X := 1030.0

var camera: Camera2D
var ui_layer: CanvasLayer
var ui_root: Control
var stats_label: Label
var era_label: Label
var event_label: Label
var inspector_panel: ColorRect
var inspector_title: Label
var inspector_body: RichTextLabel
var inspector_actions: VBoxContainer
var nav_buttons: Array[Button] = []
var notification_timer := 0.0
var refresh_timer := 0.0
var selected_kind := ""
var selected_id := ""
var active_screen := "workshop"
var overlays: Dictionary = {"throughput":false, "heatmap":false, "assignments":false, "shortage":false, "quality":false}
var event_history: Array[String] = []

const UI_BG := Color("#111827")
const UI_PANEL := Color("#1f2937")
const UI_ACCENT := Color("#f59e0b")
const TEXT := Color("#f8fafc")
const MUTED := Color("#94a3b8")
const WORLD_BG := Color("#0b1220")

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(720, 450)
	camera.zoom = Vector2.ONE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	_build_ui()
	GameState.state_changed.connect(_on_state_changed)
	GameState.event_logged.connect(_on_event_logged)
	_on_event_logged(GameState.last_offline_report, "info")
	queue_redraw()

func _process(delta: float) -> void:
	GameState.advance(delta)
	_move_camera(delta)
	notification_timer = max(0.0, notification_timer - delta)
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.25
		_refresh_ui()
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(ui_root)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1440, 68)
	top_bar.color = UI_BG
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(top_bar)
	var title := Label.new()
	title.text = "HARDWARE EMPIRE"
	title.position = Vector2(24, 10)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UI_ACCENT)
	top_bar.add_child(title)
	era_label = Label.new()
	era_label.position = Vector2(24, 39)
	era_label.add_theme_font_size_override("font_size", 12)
	era_label.add_theme_color_override("font_color", MUTED)
	top_bar.add_child(era_label)
	stats_label = Label.new()
	stats_label.position = Vector2(300, 24)
	stats_label.add_theme_font_size_override("font_size", 16)
	top_bar.add_child(stats_label)
	var save_button := _make_button("SAVE", Callable(self, "_save_game"), Vector2(1200, 16), Vector2(92, 34))
	top_bar.add_child(save_button)
	var expand_button := _make_button("EXPAND", Callable(self, "_expand"), Vector2(1095, 16), Vector2(96, 34))
	top_bar.add_child(expand_button)

	var hint := Label.new()
	hint.text = "WASD / drag camera  •  wheel zoom  •  click workers, stations, items"
	hint.position = Vector2(24, 76)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	ui_root.add_child(hint)

	inspector_panel = ColorRect.new()
	inspector_panel.position = Vector2(PANEL_X, 78)
	inspector_panel.size = Vector2(390, 700)
	inspector_panel.color = Color("#172033e8")
	inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(inspector_panel)
	inspector_title = Label.new()
	inspector_title.position = Vector2(18, 14)
	inspector_title.size = Vector2(354, 34)
	inspector_title.add_theme_font_size_override("font_size", 19)
	inspector_title.add_theme_color_override("font_color", UI_ACCENT)
	inspector_panel.add_child(inspector_title)
	inspector_body = RichTextLabel.new()
	inspector_body.position = Vector2(18, 56)
	inspector_body.size = Vector2(354, 320)
	inspector_body.bbcode_enabled = true
	inspector_body.fit_content = false
	inspector_body.add_theme_font_size_override("normal_font_size", 14)
	inspector_panel.add_child(inspector_body)
	inspector_actions = VBoxContainer.new()
	inspector_actions.position = Vector2(18, 392)
	inspector_actions.size = Vector2(354, 280)
	inspector_actions.add_theme_constant_override("separation", 7)
	inspector_panel.add_child(inspector_actions)

	var bottom_bar := ColorRect.new()
	bottom_bar.position = Vector2(0, 820)
	bottom_bar.size = Vector2(1440, 80)
	bottom_bar.color = UI_BG
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(bottom_bar)
	var nav_names := ["WORKSHOP", "DASHBOARD", "EMPLOYEES", "INVENTORY", "R&D", "PRODUCTS", "MARKET", "CONTRACTS", "QUALITY", "COMPANY", "SETTINGS"]
	for i in nav_names.size():
		var button := _make_button(nav_names[i], Callable(self, "_open_screen").bind(nav_names[i].to_lower()), Vector2(18 + i * 128, 834), Vector2(118, 38))
		bottom_bar.add_child(button)
		nav_buttons.append(button)
	var overlay_bar := HBoxContainer.new()
	overlay_bar.position = Vector2(740, 82)
	overlay_bar.size = Vector2(280, 32)
	overlay_bar.add_theme_constant_override("separation", 4)
	ui_root.add_child(overlay_bar)
	for overlay_name in overlays.keys():
		var button := _make_button(str(overlay_name).to_upper(), Callable(self, "_toggle_overlay").bind(str(overlay_name)), Vector2.ZERO, Vector2(0, 28))
		button.custom_minimum_size = Vector2(0, 28)
		overlay_bar.add_child(button)
		button.tooltip_text = "Toggle %s overlay" % overlay_name
	inspector_panel.visible = false
	_refresh_ui()

func _make_button(text: String, callback: Callable, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

func _refresh_ui() -> void:
	var summary: Dictionary = GameState.get_summary()
	stats_label.text = "CASH $%d    REP %.1f    KNOW %.1f    JOBS %d    BOTTLENECKS %d" % [int(summary.cash), summary.reputation, summary.knowledge, summary.active_jobs, summary.bottlenecks]
	era_label.text = "ERA %d  •  %s  •  EXPANSION %d  •  SPEED %.2fx" % [GameState.current_era, summary.era, GameState.expansion_level, GameState.time_scale]
	if notification_timer <= 0.0:
		event_label = event_label if is_instance_valid(event_label) else null
	if inspector_panel.visible and active_screen == "workshop" and not selected_id.is_empty():
		_refresh_selected_panel()

func _on_state_changed() -> void:
	queue_redraw()
	_refresh_ui()

func _on_event_logged(message: String, severity: String) -> void:
	if message.is_empty():
		return
	event_history.push_front(message)
	if event_history.size() > 5:
		event_history.pop_back()
	if is_instance_valid(inspector_panel) and active_screen != "workshop":
		_set_management_panel(active_screen)

func _save_game() -> void:
	if GameState.save_game():
		_on_event_logged("Game saved.", "success")
		notification_timer = 3.0

func _expand() -> void:
	if GameState.expand_workshop():
		_open_screen("workshop")
	else:
		_on_event_logged("Expansion needs more cash or next era.", "warning")

func _open_screen(screen: String) -> void:
	active_screen = screen
	selected_kind = ""
	selected_id = ""
	inspector_panel.visible = true
	if screen == "workshop":
		inspector_panel.visible = false
	else:
		_set_management_panel(screen)

func _set_management_panel(screen: String) -> void:
	if not is_instance_valid(inspector_panel):
		return
	_clear_actions()
	var summary := GameState.get_summary()
	var title := screen.capitalize()
	var body := ""
	var actions: Array = []
	match screen:
		"dashboard":
			title = "Company Dashboard"
			body = "[font_size=18]Operating snapshot[/font_size]\n\nCash: $%d\nReputation: %.1f\nKnowledge: %.1f\nActive jobs: %d\nActive contracts: %d\nProduction shipped: %d\nBottlenecks: %d\n\nTop goal: %s" % [int(summary.cash), summary.reputation, summary.knowledge, summary.active_jobs, summary.active_contracts, summary.production, summary.bottlenecks, _next_goal()]
			actions = [{"text":"Go to workshop", "callback":Callable(self, "_open_screen").bind("workshop")}, {"text":"Advance era ($%d)" % int(GameState.get_next_era_cost()), "callback":Callable(self, "_advance_era")}, {"text":"Expand floor ($%d)" % int(450.0 * GameState.expansion_level), "callback":Callable(self, "_expand")}]
		"employees":
			title = "Employees & Assignments"
			body = "Visible agents: %d\n\n" % GameState.workers.size()
			for worker in GameState.workers:
				body += "%s  •  %s\nState: %s\nSkill: %.2f\n\n" % [worker.name, worker.role, worker.state, worker.skill]
			actions = [{"text":"Hire Junior Technician ($%d)" % int(180.0 + (GameState.workers.size() - 1) * 75.0), "callback":Callable(self, "_hire_worker").bind("junior_technician")}, {"text":"Hire Diagnostics Technician", "callback":Callable(self, "_hire_worker").bind("diagnostics_technician")}]
		"inventory":
			title = "Inventory & Suppliers"
			body = "Warehouse stock\n\n"
			for component_id in GameState.inventory:
				body += "%s: %d\n" % [str(component_id).capitalize(), int(GameState.inventory[component_id])]
			body += "\nIncoming deliveries: %d\nLow stock highlights shortages in workshop." % GameState.deliveries.size()
			actions = [{"text":"Build warehouse shelf", "callback":Callable(self, "_build_station").bind("warehouse_shelf")}, {"text":"Go to parts shelf", "callback":Callable(self, "_inspect_id").bind("station", "parts_shelf")}]
		"r&d":
			title = "R&D / Blueprints"
			body = "Prototype room is physically represented by engineering desks.\n\n"
			var active_id := str(GameState.research.get("active_id", ""))
			body += "Active: %s\nProgress: %.0f\n\n" % [active_id if not active_id.is_empty() else "None", float(GameState.research.get("progress", 0.0))]
			for definition in GameState.catalog.get("research", []):
				var complete: bool = definition.id in GameState.research.get("completed", [])
				body += "%s  %s\n%s\n\n" % ["✓" if complete else "○", definition.name, definition.description]
				if not complete:
					actions.append({"text":"Research %s (%d knowledge)" % [definition.name, int(definition.cost)], "callback":Callable(self, "_start_research").bind(definition.id)})
		"products":
			title = "Products & Pipeline"
			body = "Production is visible from component pick to shipping.\n\n"
			for definition in GameState.catalog.get("products", []):
				body += "%s  •  $%d\nPipeline: %s\n\n" % [definition.name, int(definition.price), " → ".join(definition.pipeline)]
			actions = [{"text":"Toggle production %s" % ("OFF" if GameState.production_enabled else "ON"), "callback":Callable(self, "_toggle_production")}, {"text":"Build assembly cell", "callback":Callable(self, "_build_station").bind("assembly_station")}, {"text":"Build testing station", "callback":Callable(self, "_build_station").bind("testing_station")}]
		"market":
			title = "Market"
			body = "Customer demand follows company era.\n\nRepair sales: steady local demand\nSensor line: growing industrial demand\nDrone modules: premium contract demand\n\nCompleted items leave through outgoing shelves and shipping." 
			actions = [{"text":"Open workshop flow", "callback":Callable(self, "_open_screen").bind("workshop")}, {"text":"Build packaging station", "callback":Callable(self, "_build_station").bind("packaging_station")}]
		"contracts":
			title = "Contracts"
			body = "Industrial orders create throughput pressure.\n\n"
			if GameState.contracts.is_empty():
				body += "No offers yet. Reach Era 5."
			for contract in GameState.contracts:
				body += "%s  [%s]\nRemaining: %d / %d\nReward: $%d\n\n" % [contract.name, contract.state, contract.remaining, contract.units, int(contract.reward)]
				if contract.state == "offered":
					actions.append({"text":"Accept %s" % contract.name, "callback":Callable(self, "_accept_contract").bind(contract.id)})
		"quality":
			title = "Quality & QA"
			body = "Quality is carried through every process stage.\n\nQuality hold: %d items\nStations show red test failures and yellow waiting states.\nCertification room unlocks in Era 5.\n\nRecent issues:\n" % GameState.quality_hold.size()
			for bottleneck in GameState.get_active_bottlenecks():
				body += "• %s: %s\n" % [bottleneck.name, bottleneck.status]
			actions = [{"text":"Build QA lab", "callback":Callable(self, "_build_station").bind("qa_lab")}, {"text":"Build calibration rig", "callback":Callable(self, "_build_station").bind("calibration_bench")}]
		"company":
			title = "Company Progress"
			body = "Current era: %d — %s\nExpansion level: %d\n\nMilestones\n" % [GameState.current_era, GameState.get_current_era_name(), GameState.expansion_level]
			for milestone in GameState.milestones:
				body += "%s %s\n" % ["✓" if GameState.milestones[milestone] else "○", str(milestone).replace("_", " ").capitalize()]
			body += "\nNext goal: %s" % _next_goal()
			actions = [{"text":"Advance era ($%d)" % int(GameState.get_next_era_cost()), "callback":Callable(self, "_advance_era")}, {"text":"Expand workshop", "callback":Callable(self, "_expand")}]
		"settings":
			title = "Settings & Save"
			body = "Simulation is frame-rate independent.\nOffline progress cap: 8 hours.\nCurrent speed: %.2fx\n\nSave data uses versioned JSON with stable content IDs." % GameState.time_scale
			actions = [{"text":"Save game", "callback":Callable(self, "_save_game")}, {"text":"Speed 0.5x", "callback":Callable(self, "_set_speed").bind(0.5)}, {"text":"Speed 1x", "callback":Callable(self, "_set_speed").bind(1.0)}, {"text":"Speed 2x", "callback":Callable(self, "_set_speed").bind(2.0)}, {"text":"Speed 4x", "callback":Callable(self, "_set_speed").bind(4.0)}]
	_set_panel(title, body, actions)

func _set_panel(title: String, body: String, actions: Array) -> void:
	inspector_panel.visible = true
	inspector_title.text = title
	inspector_body.text = body
	_clear_actions()
	for action in actions:
		var button := Button.new()
		button.text = str(action.get("text", "Action"))
		button.custom_minimum_size = Vector2(0, 32)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(action.get("callback", Callable()))
		inspector_actions.add_child(button)

func _clear_actions() -> void:
	if not is_instance_valid(inspector_actions):
		return
	for child in inspector_actions.get_children():
		child.queue_free()

func _next_goal() -> String:
	if not GameState.milestones.get("staffed", false):
		return "Hire first technician"
	if GameState.current_era < 2:
		return "Open local repair shop"
	if GameState.current_era < 3:
		return "Fund PCB design"
	if GameState.current_era < 4:
		return "Start manufacturing"
	if GameState.current_era < 5:
		return "Prove product quality"
	return "Scale technology divisions"

func _refresh_selected_panel() -> void:
	if selected_kind == "station":
		var station := GameState._find_station(selected_id)
		if not station.is_empty():
			var queue: Array = station.get("queue", [])
			var body := "Zone: %s\nProcess: %s\nState: %s\nQueue: %d / %d\nProgress: %.0f%%\nTier: %d\n\n%s" % [station.zone, station.process, station.status, queue.size(), station.capacity, float(station.progress) * 100.0, station.tier, "Machine: %s" % station.machine if station.is_machine else "Worker-operated station"]
			_set_panel(str(station.name), body, [{"text":"Upgrade ($%d)" % int(160.0 * station.tier), "callback":Callable(self, "_upgrade_station").bind(selected_id)}, {"text":"Relocate to cursor", "callback":Callable(self, "_relocate_selected")}])
	elif selected_kind == "worker":
		var worker := GameState._find_worker(selected_id)
		if not worker.is_empty():
			var body := "Role: %s\nState: %s\nAnimation: %s\nSkill: %.2f\nTraining: %.0f%%\nAssignment: %s\nCarrying: %s" % [worker.role, worker.state, worker.animation, worker.skill, float(worker.training), worker.assignment if not worker.assignment.is_empty() else "None", worker.carrying if not worker.carrying.is_empty() else "Nothing"]
			_set_panel(str(worker.name), body, [{"text":"View employees", "callback":Callable(self, "_open_screen").bind("employees")}])
	elif selected_kind == "item":
		var job := GameState._find_job(selected_id)
		if not job.is_empty():
			var body := "Type: %s\nState: %s\nStage: %d / %d\nQuality: %.0f%%\nReward: $%d\n\nPipeline:\n%s" % [job.kind, job.state, int(job.stage) + 1, job.pipeline.size(), float(job.quality) * 100.0, int(job.base_reward), " → ".join(job.pipeline)]
			_set_panel(str(job.label), body, [{"text":"View quality panel", "callback":Callable(self, "_open_screen").bind("quality")}])

func _inspect_id(kind: String, id: String) -> void:
	active_screen = "workshop"
	selected_kind = kind
	selected_id = id
	inspector_panel.visible = true
	_refresh_selected_panel()

func _build_station(definition_id: String) -> void:
	if not GameState.build_station(definition_id):
		_on_event_logged("Cannot build %s: check era, cash, space, or duplicate." % definition_id, "warning")
	_open_screen(active_screen)

func _upgrade_station(station_id: String) -> void:
	if not GameState.upgrade_station(station_id):
		_on_event_logged("Upgrade needs more cash.", "warning")
	_refresh_selected_panel()

func _relocate_selected() -> void:
	if GameState.relocate_station(selected_id, get_global_mouse_position()):
		_refresh_selected_panel()

func _hire_worker(role_id: String) -> void:
	if not GameState.hire_worker(role_id):
		_on_event_logged("Cannot hire: cash, era, or role requirement unmet.", "warning")
	_set_management_panel("employees")

func _advance_era() -> void:
	if not GameState.advance_era():
		_on_event_logged("Era advancement needs $%d." % int(GameState.get_next_era_cost()), "warning")
	_set_management_panel(active_screen)

func _start_research(research_id: String) -> void:
	if not GameState.start_research(research_id):
		_on_event_logged("Research unavailable: need knowledge or finish current project.", "warning")
	_set_management_panel("r&d")

func _accept_contract(contract_id: String) -> void:
	GameState.accept_contract(contract_id)
	_set_management_panel("contracts")

func _toggle_production() -> void:
	GameState.production_enabled = not GameState.production_enabled
	_on_event_logged("Product line %s." % ("started" if GameState.production_enabled else "paused"), "info")
	_set_management_panel("products")

func _set_speed(speed: float) -> void:
	GameState.set_time_scale(speed)
	_set_management_panel("settings")

func _toggle_overlay(name: String) -> void:
	overlays[name] = not overlays.get(name, false)
	queue_redraw()

func _move_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction.length() > 0.0:
		camera.position += direction.normalized() * 360.0 * delta / camera.zoom.x
	var half_view := Vector2(700, 410) / camera.zoom.x
	camera.position.x = clamp(camera.position.x, half_view.x, WORLD_SIZE.x - half_view.x)
	camera.position.y = clamp(camera.position.y, half_view.y, WORLD_SIZE.y - half_view.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom + Vector2(0.1, 0.1)).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom - Vector2(0.1, 0.1)).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_world_click(get_global_mouse_position())

func _handle_world_click(position: Vector2) -> void:
	var worker := GameState.get_worker_at(position)
	if not worker.is_empty():
		_inspect_id("worker", str(worker.id))
		return
	var station := GameState.get_station_at(position)
	if not station.is_empty():
		_inspect_id("station", str(station.id))
		return
	var item := GameState.get_item_at(position)
	if not item.is_empty():
		_inspect_id("item", str(item.id))
		return
	_show_build_panel(position)

func _show_build_panel(position: Vector2) -> void:
	active_screen = "workshop"
	selected_kind = ""
	selected_id = ""
	var actions: Array = []
	for definition in GameState.get_unlocked_station_definitions():
		actions.append({"text":"Build %s ($%d)" % [definition.name, int(definition.cost)], "callback":Callable(self, "_build_station").bind(definition.id)})
	actions.append({"text":"Close", "callback":Callable(self, "_open_screen").bind("workshop")})
	_set_panel("Build at grid tile", "Empty planned space.\nStations snap to workshop grid.\n\nClick a station later to relocate it to cursor.", actions)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), WORLD_BG)
	_draw_rooms()
	_draw_grid()
	_draw_stations()
	_draw_items()
	_draw_workers()
	_draw_overlays()

func _draw_rooms() -> void:
	var room_defs := [
		{"rect":Rect2(32, 32, 672, 416), "name":"REPAIR / RECEPTION", "era":1, "color":Color("#243447")},
		{"rect":Rect2(704, 32, 672, 416), "name":"ENGINEERING", "era":3, "color":Color("#1e3a4a")},
		{"rect":Rect2(1376, 32, 672, 416), "name":"ADVANCED R&D", "era":6, "color":Color("#3b2148")},
		{"rect":Rect2(32, 448, 672, 512), "name":"PRODUCTION", "era":4, "color":Color("#283b2d")},
		{"rect":Rect2(704, 448, 672, 512), "name":"QUALITY / WAREHOUSE", "era":5, "color":Color("#422b38")},
		{"rect":Rect2(1376, 448, 672, 512), "name":"INDUSTRIAL SHIPPING", "era":5, "color":Color("#3b3524")}
	]
	for room in room_defs:
		var rect: Rect2 = room.rect
		var unlocked: bool = GameState.current_era >= int(room.era) and GameState.expansion_level >= min(6, int(room.era))
		draw_rect(rect, room.color if unlocked else Color("#111827"))
		draw_rect(rect, Color("#526276") if unlocked else Color("#1f2937"), false, 4.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 25), str(room.name) if unlocked else "LOCKED — ERA %d" % int(room.era), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#cbd5e1") if unlocked else Color("#475569"))
		if unlocked:
			_draw_doors(rect)
	if GameState.expansion_level > 1:
		draw_string(ThemeDB.fallback_font, Vector2(48, 932), "EXPANSION %d — %s" % [GameState.expansion_level, GameState.ERA_ROOM_NAMES[GameState.expansion_level - 1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI_ACCENT)

func _draw_doors(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 12, rect.size.y / 2 - 24), Vector2(24, 48)), Color("#8b5e3c"))

func _draw_grid() -> void:
	var max_x := 2048 if GameState.current_era >= 6 else 1376 if GameState.current_era >= 3 else 704
	var max_y := 960 if GameState.current_era >= 4 else 448
	for x in range(32, max_x + 1, 32):
		draw_line(Vector2(x, 32), Vector2(x, max_y), Color("#ffffff08"), 1.0)
	for y in range(32, max_y + 1, 32):
		draw_line(Vector2(32, y), Vector2(max_x, y), Color("#ffffff08"), 1.0)

func _draw_stations() -> void:
	for station in GameState.stations:
		if not station.get("unlocked", false):
			continue
		var position: Vector2 = station.position
		var rect := Rect2(position - Vector2(64, 40), Vector2(128, 80))
		var color := Color(str(station.color))
		var status := str(station.status)
		var status_color := Color("#22c55e") if status == "PROCESSING" else Color("#f59e0b") if status in ["WAITING", "OVERLOADED"] else Color("#ef4444") if status in ["BLOCKED", "STARVED"] else Color("#64748b")
		if overlays.heatmap and status == "PROCESSING":
			draw_circle(position, 104, Color(0.2, 0.8, 0.35, 0.12))
		if overlays.shortage and status in ["STARVED", "WAITING"]:
			draw_circle(position, 92, Color(0.95, 0.65, 0.1, 0.16))
		if overlays.quality and station.zone == "quality":
			draw_circle(position, 100, Color(0.75, 0.15, 0.35, 0.13))
		draw_rect(rect, Color("#00000055"))
		draw_rect(rect.grow(-3), color)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 8), Vector2(rect.size.x * float(station.progress), 8)), status_color)
		if station.is_machine:
			draw_rect(Rect2(position - Vector2(42, 24), Vector2(84, 38)), color.lightened(0.2), false, 3.0)
			draw_circle(position + Vector2(34, -15), 6, status_color)
			draw_circle(position + Vector2(34, -15), 3, Color("#0f172a"))
		else:
			draw_rect(Rect2(position - Vector2(48, 25), Vector2(96, 30)), color.lightened(0.15))
			draw_line(position + Vector2(-42, 13), position + Vector2(42, 13), Color("#1f2937"), 4.0)
		var label := str(station.name)
		draw_string(ThemeDB.fallback_font, position + Vector2(-60, -49), label, HORIZONTAL_ALIGNMENT_LEFT, 120, 12, TEXT)
		draw_string(ThemeDB.fallback_font, position + Vector2(-60, 60), status, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, status_color)
		var queue_size: int = station.queue.size()
		if queue_size > 0:
			draw_circle(position + Vector2(55, -30), 12, status_color)
			draw_string(ThemeDB.fallback_font, position + Vector2(51, -25), str(queue_size), HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color("#111827"))
		if status in ["BLOCKED", "STARVED", "OVERLOADED"]:
			draw_colored_polygon(PackedVector2Array([position + Vector2(-10, -67), position + Vector2(4, -43), position + Vector2(-24, -43)]), Color("#ef4444"))
			draw_string(ThemeDB.fallback_font, position + Vector2(-17, -48), "!", HORIZONTAL_ALIGNMENT_LEFT, 16, 12, Color.WHITE)

func _draw_items() -> void:
	for item in GameState.get_item_visuals():
		var position: Vector2 = item.position
		var visual_kind := str(item.visual_kind)
		var color := Color("#a78bfa") if item.kind == "product" else Color("#f97316")
		if "pcb" in visual_kind:
			color = Color("#4ade80")
		elif "board" in visual_kind:
			color = Color("#38bdf8")
		elif "laptop" in visual_kind:
			color = Color("#94a3b8")
		elif "drone" in visual_kind:
			color = Color("#facc15")
		elif "industrial" in visual_kind:
			color = Color("#fb7185")
		if item.state == "quality_hold":
			color = Color("#ef4444")
		if item.kind == "product":
			draw_rect(Rect2(position - Vector2(14, 10), Vector2(28, 20)), color)
			draw_line(position + Vector2(-12, 0), position + Vector2(12, 0), Color("#312e81"), 3.0)
		else:
			draw_rect(Rect2(position - Vector2(13, 13), Vector2(26, 26)), color)
			draw_rect(Rect2(position - Vector2(8, 8), Vector2(16, 16)), color.lightened(0.22), false, 2.0)
		if item.state == "completed":
			draw_string(ThemeDB.fallback_font, position + Vector2(-8, -17), "✓", HORIZONTAL_ALIGNMENT_LEFT, 16, 14, Color("#4ade80"))

func _draw_workers() -> void:
	for worker in GameState.workers:
		var position: Vector2 = worker.position
		var color := Color(str(worker.color))
		var walk_offset := sin(float(worker.walk_cycle)) * 3.0 if worker.animation in ["walk", "carry"] else 0.0
		if overlays.assignments and not str(worker.assignment).is_empty():
			var station := GameState._find_station(str(worker.assignment))
			if not station.is_empty():
				draw_dashed_line(position, station.position, Color("#fbbf24aa"), 2.0, 6.0)
		draw_rect(Rect2(position + Vector2(-10, -1 + walk_offset), Vector2(20, 24)), color)
		draw_rect(Rect2(position + Vector2(-8, -18 + walk_offset), Vector2(16, 16)), Color("#f1c27d"))
		draw_rect(Rect2(position + Vector2(-9, -19 + walk_offset), Vector2(18, 5)), Color("#1e293b"))
		draw_rect(Rect2(position + Vector2(-8, 22), Vector2(6, 10)), Color("#334155"))
		draw_rect(Rect2(position + Vector2(2, 22), Vector2(6, 10)), Color("#334155"))
		if worker.animation == "carry" and not str(worker.carrying).is_empty():
			draw_rect(Rect2(position + Vector2(12, 2), Vector2(13, 13)), Color("#fbbf24"))
		var state_color := Color("#22c55e") if worker.state == "WORKING" else Color("#f59e0b") if worker.state.begins_with("MOVING") else Color("#94a3b8")
		draw_circle(position + Vector2(0, -27), 4, state_color)
		draw_string(ThemeDB.fallback_font, position + Vector2(-38, 47), str(worker.name), HORIZONTAL_ALIGNMENT_LEFT, 76, 10, TEXT)

func _draw_overlays() -> void:
	if overlays.throughput:
		for station in GameState.stations:
			if station.get("unlocked", false):
				draw_string(ThemeDB.fallback_font, station.position + Vector2(-46, 76), "%.0f%% / tier %d" % [float(station.progress) * 100.0, int(station.tier)], HORIZONTAL_ALIGNMENT_LEFT, 110, 10, Color("#bfdbfe"))
	if overlays.shortage:
		var stock_text := "STOCK "
		for component_id in GameState.inventory:
			stock_text += "%s:%d  " % [str(component_id).left(3).to_upper(), int(GameState.inventory[component_id])]
		draw_rect(Rect2(44, 976, 520, 30), Color("#7c2d12aa"))
		draw_string(ThemeDB.fallback_font, Vector2(56, 997), stock_text, HORIZONTAL_ALIGNMENT_LEFT, 500, 12, Color("#fed7aa"))
