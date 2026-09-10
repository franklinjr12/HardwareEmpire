class_name EraOneLayout
extends RefCounted

const POINTS := {
	"front_entrance": Vector2(190, 650), "front_desk_customer": Vector2(230, 505),
	"customer_wait_1": Vector2(230, 505), "customer_wait_2": Vector2(310, 540), "customer_wait_3": Vector2(390, 560),
	"front_desk_founder": Vector2(230, 365), "pickup_customer": Vector2(685, 505),
	"pickup_founder": Vector2(685, 365), "repair_bench": Vector2(470, 275),
	"parts_shelf": Vector2(200, 245), "service_entrance": Vector2(80, 155),
	"delivery_drop": Vector2(200, 155), "founder_start": Vector2(450, 350)
}
const STATIONS := {"front_desk":"front_desk_founder", "parts_shelf":"parts_shelf", "repair_bench_1":"repair_bench", "outgoing_shelf":"pickup_founder"}
const FOOTPRINTS := {"front_desk":Rect2(155, 405, 190, 65), "outgoing_shelf":Rect2(595, 405, 180, 65), "parts_shelf":Rect2(145, 80, 150, 65), "repair_bench_1":Rect2(370, 160, 225, 70)}
const FOUNDER_AREA := Rect2(125, 245, 650, 145)

static func point(id: String) -> Vector2:
	return POINTS.get(id, Vector2.ZERO)

static func customer_position(job: Dictionary) -> Vector2:
	var state := str(job.get("customer_state", "absent"))
	var waiting := point("customer_wait_%d" % (int(job.get("waiting_slot", 0)) + 1))
	var progress := float(job.get("customer_progress", 0.0))
	match state:
		"arriving": return point("front_entrance").lerp(waiting, progress)
		"waiting": return waiting
		"leaving": return waiting.lerp(point("front_entrance"), progress)
		"returning": return point("front_entrance").lerp(point("pickup_customer"), progress)
		"collecting": return point("pickup_customer")
		"exiting": return point("pickup_customer").lerp(point("front_entrance"), progress)
	return point("front_entrance")
