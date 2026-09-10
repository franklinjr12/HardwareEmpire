extends SceneTree
var failures := 0
var checks := 0
var catalog: Dictionary

func _init() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var shop := RepairShopSimulation.new(catalog)
	check(shop.jobs.is_empty(), "new shop empty")
	var saved := clone(shop)
	shop.advance(8)
	saved.advance(8)
	check(shop.jobs == saved.jobs, "arrival and RNG restore")
	check(shop.jobs.size() == 1 and shop.jobs[0].state == "client_waiting", "first arrival")
	shop.advance(200)
	check(shop._waiting_customer_count() == 3, "queue capped")
	var first: Dictionary = shop.jobs[0]
	check(shop.accept_job(first.id), "accept")
	check(first.customer_state == "leaving" and shop._waiting_customer_count() == 2, "accepted leaves")
	check(shop.reject_job(shop.jobs[1].id), "reject")
	check(shop.jobs[1].customer_state == "leaving", "reject departure physical")
	check(shop._waiting_customer_count() == 1, "rejected frees capacity")
	shop.advance(60)
	check(shop._waiting_customer_count() == 3, "arrival resumes")
	var delivery_shop := RepairShopSimulation.new(catalog)
	check(delivery_shop.order_parts("pcb", 2), "order")
	check(delivery_shop.money < 250 and delivery_shop.inventory.pcb == 0, "charge without stock")
	delivery_shop.advance(7)
	check(delivery_shop.deliveries[0].state == "courier_arriving", "courier after transit")
	check(delivery_shop.inventory.pcb == 0, "spawn no credit")
	check_restore(delivery_shop, "courier arriving")
	delivery_shop.advance(1.5)
	check(delivery_shop.deliveries[0].state == "delivering" and delivery_shop.inventory.pcb == 0, "drop phase before stock")
	check_restore(delivery_shop, "courier dropping")
	delivery_shop.advance(1)
	check(delivery_shop.inventory.pcb == 2 and delivery_shop.incoming_quantity("pcb") == 0, "credit exactly at storage")
	check(delivery_shop.storage_used() == 2, "credited delivery not double counted")
	check_restore(delivery_shop, "courier leaving")
	delivery_shop.advance(20)
	check(delivery_shop.inventory.pcb == 2 and delivery_shop.deliveries.is_empty(), "delivery completes once")
	var loop := RepairShopSimulation.new(catalog)
	loop.advance(8)
	var id := str(loop.jobs[0].id)
	var identity: Array = [loop.jobs[0].customer_name, loop.jobs[0].customer_archetype, loop.jobs[0].visual_variant]
	check_restore(loop, "waiting")
	check(loop.accept_job(id), "loop accept")
	check_restore(loop, "accepted departure")
	check_restore(loop, "supplier transit")
	loop.advance(20)
	check(loop.get_job(id).state == "ready_for_parts", "job reservation")
	check(loop.request_collect_parts(id), "collect command")
	loop.advance(3)
	check(loop.get_job(id).state == "parts_collected", "collect arrives")
	check(loop.request_start_diagnosis(id), "diagnose command")
	loop.advance(2)
	check(loop.get_job(id).state == "diagnosing", "diagnosing")
	check_restore(loop, "diagnosing")
	check(not loop.request_station_interaction("front_desk"), "busy founder stays")
	loop.advance(6)
	check(loop.start_repair_method(id,"component_repair"), "repair choice")
	check(not loop.request_collect_parts(id), "occupied bench rejects new bundle")
	check_restore(loop, "repairing")
	var cash := loop.money
	loop.advance(25)
	check(loop.money == cash, "repair no payment")
	check(loop.request_pickup_device(id), "pickup from bench")
	loop.advance(1)
	check(loop.money == cash, "carry no payment")
	check(loop.request_delivery(id), "place command")
	loop.advance(2)
	check(loop.get_job(id).state == "waiting_for_customer_pickup" and loop.money == cash, "outbound no payment")
	check(not loop.request_delivery(id), "repeat placement rejected")
	check_restore(loop, "outbound return timer")
	while loop.get_job(id).customer_state != "collecting": loop.advance(0.25)
	check(loop.money == cash, "arriving customer no payment")
	check(identity == [loop.get_job(id).customer_name,loop.get_job(id).customer_archetype,loop.get_job(id).visual_variant], "return identity")
	check_restore(loop, "collecting")
	loop.advance(1)
	check(loop.money > cash and loop.technician_xp > 0 and loop.reputation > 1, "pickup rewards")
	check(loop.get_job(id).customer_state == "exiting", "customer exits with device")
	check_restore(loop, "completed")
	cash = loop.money
	loop._finish_job(loop.get_job(id))
	loop.advance(30)
	check(loop.money == cash and loop.get_job(id).customer_state == "absent", "no double reward")
	# Multiple independent jobs and serialized sequential delivery queue.
	var multi := RepairShopSimulation.new(catalog)
	multi.money = 2000
	multi.advance(80)
	for job in multi.jobs:
		check(multi.accept_job(job.id), "multi accept")
	multi.advance(40)
	for job in multi.jobs.slice(0,3):
		check(job.state == "ready_for_parts", "multi reservation")
		for component in job.required_materials:
			check(int(job.reserved_materials.get(component, 0)) == int(job.required_materials[component]), "reservation association")
	# Set up outbound boundary directly; physical workflow covered above.
	var expected := multi.money
	for index in range(3):
		var job: Dictionary = multi.jobs[index]
		job.state = "waiting_for_customer_pickup"
		job.customer_state = "absent"
		job.pickup_timer = 0.0
		job.outbound_slot = index
		expected += round(float(job.reward)*0.9)
	check(multi.outbound_count() == 3, "outbound capacity")
	check_restore(multi, "three pickup visits")
	multi.advance(30)
	check(multi.money == expected, "each job own reward once")
	for job in multi.jobs.slice(0,3): check(job.rewards_granted, "each customer collected own job")
	var legacy := loop.serialize()
	legacy.erase("schema_version")
	for job in legacy.jobs: job.erase("customer_state")
	var migrated := RepairShopSimulation.new(catalog)
	migrated.restore(legacy)
	cash = migrated.money
	migrated.advance(40)
	check(migrated.money == cash, "legacy completed stays paid")
	var coarse := RepairShopSimulation.new(catalog)
	var fine := RepairShopSimulation.new(catalog)
	coarse.advance(80)
	for i in range(320): fine.advance(0.25)
	check(coarse.serialize() == fine.serialize(), "frame-rate independent")
	print("Epic 1: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func clone(shop: RepairShopSimulation) -> RepairShopSimulation:
	var result := RepairShopSimulation.new(catalog)
	result.restore(JSON.parse_string(JSON.stringify(shop.serialize())))
	return result

func check_restore(shop: RepairShopSimulation, phase: String) -> void:
	var snapshot := shop.serialize()
	var b := clone(shop)
	shop.advance(30)
	for i in range(120): b.advance(0.25)
	check(JSON.parse_string(JSON.stringify(shop.serialize())) == JSON.parse_string(JSON.stringify(b.serialize())), "save/load " + phase)
	shop.restore(snapshot)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
