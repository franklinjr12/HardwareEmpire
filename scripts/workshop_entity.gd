extends Node2D
const Art = preload("res://scripts/workshop_art.gd")
const ART_IDS := {"front_desk":"front_desk", "outgoing_shelf":"pickup_desk", "repair_bench_1":"repair_bench", "parts_shelf":"parts_shelf"}
var visual_variant := 0
var _sprite: Sprite2D
var _carried_sprite: Sprite2D
var _upgrade_sprite: Sprite2D
var _clock := 0.0
var _art_id := ""

func _ready() -> void:
	_art_id = str(ART_IDS.get(kind,kind))
	var texture := Art.texture(_art_id)
	if texture == null: return
	_sprite = Sprite2D.new()
	_sprite.name = "Artwork"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_carried_sprite = Sprite2D.new()
	_carried_sprite.name = "CarriedItemArtwork"
	_carried_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_carried_sprite)
	_upgrade_sprite = Art.sprite("package",25)
	_upgrade_sprite.name = "UpgradeArtwork"
	_upgrade_sprite.position = Vector2(55,-22)
	add_child(_upgrade_sprite)
	_update_art()

func _process(delta: float) -> void:
	_clock += delta
	_update_art()

func _update_art() -> void:
	if _sprite == null: return
	var character := kind in ["founder","customer","courier"]
	var frame := 3 if working else (1 + int(_clock*6.0)%2 if moving else 0)
	_sprite.texture = Art.texture(_art_id,frame if character else 0)
	var width := 225.0 if kind == "repair_bench_1" else (150.0 if kind == "parts_shelf" else (190.0 if kind == "front_desk" else 180.0))
	if kind in ["device","package"]: width = 36.0
	var factor := 76.0 / Art.texture(_art_id).get_height() if character else width / _sprite.texture.get_width()
	_sprite.scale = Vector2.ONE*factor
	_sprite.position = Vector2(0,-_sprite.texture.get_height()*factor/2)
	_sprite.flip_h = character and facing < 0
	_sprite.modulate = Color.WHITE
	if kind == "customer":
		_sprite.modulate = [Color.WHITE,Color("d9edff"),Color("fff0d0"),Color("e1ffd9"),Color("f5d9ff"),Color("d9fff5")][visual_variant%6]
	if highlighted: _sprite.modulate = Color(1.15,1.12,1.03)
	_carried_sprite.visible = not carrying.is_empty()
	if _carried_sprite.visible:
		_carried_sprite.texture = Art.texture("device" if carrying == "device" else "package")
		_carried_sprite.scale = Vector2.ONE * 27.0 / _carried_sprite.texture.get_width()
		_carried_sprite.position = Vector2(12*facing,-31)
	_upgrade_sprite.visible = upgraded
	queue_redraw()
## Replace this node's drawing with Sprite2D without changing simulation.
var kind := "customer"
var tint := Color("769ca0")
var moving := false
var carrying := ""
var phase := 0.0
var facing := 1.0
var highlighted := false
var working := false
var upgraded := false
var waiting := false
var work_progress := -1.0

func _draw() -> void:
	if _sprite != null:
		if waiting: draw_circle(Vector2(0,-85),3,Color("e4c375"))
		if work_progress >= 0.0:
			draw_rect(Rect2(-65,7,130,6),Color("344944"))
			draw_rect(Rect2(-65,7,130*work_progress,6),Color("8bc6a3"))
		return
	if kind == "device" or kind == "package":
		draw_rect(Rect2(-18,-20,36,22), Color("be915b") if kind == "package" else Color("83b6aa"))
		draw_rect(Rect2(-13,-17,26,12), Color("354e57"))
		return
	if kind in ["front_desk", "outgoing_shelf", "parts_shelf", "repair_bench_1"]:
		var width := 225.0 if kind == "repair_bench_1" else (150.0 if kind == "parts_shelf" else 180.0)
		draw_rect(Rect2(-width/2, -65, width, 65), Color("544840"))
		draw_rect(Rect2(-width/2, -65, width, 42), tint)
		draw_rect(Rect2(-width/2+8, -57, width-16, 3), Color("c4aa7d"))
		if kind == "parts_shelf":
			for i in range(5):
				draw_rect(Rect2(-65+i*27,-48,20,22), Color("8b9c8a") if i%2 else Color("c29c6a"))
		elif kind == "front_desk":
			draw_rect(Rect2(-60,-90,48,32), Color("344a50"))
			draw_rect(Rect2(-55,-86,38,22), Color("769a99"))
			draw_rect(Rect2(15,-52,30,18), Color("d2c8a4"))
		elif kind == "repair_bench_1":
			draw_rect(Rect2(-50,-55,85,25), Color("537b6a"))
			draw_line(Vector2(70,-40),Vector2(70,-100),Color("9eaaa0"),5)
			draw_rect(Rect2(40,-105,40,10),Color("e0c17a"))
		if highlighted: draw_rect(Rect2(-width/2-3,-68,width+6,71),Color("e8c778"),false,2)
		if upgraded: draw_rect(Rect2(40,-60,22,24),Color("bb6456"))
		if work_progress >= 0.0:
			draw_rect(Rect2(-65,7,130,6),Color("344944"))
			draw_rect(Rect2(-65,7,130*work_progress,6),Color("8bc6a3"))
		return
	var step := sin(phase * 12.0) * 3.0 if moving else 0.0
	draw_set_transform(Vector2(0, step * 0.3))
	draw_rect(Rect2(-15,-3,30,6),Color(0.05,0.08,0.08,0.35))
	draw_rect(Rect2(-9,-13+step,7,12),Color("374350"))
	draw_rect(Rect2(3,-13-step,7,12),Color("374350"))
	draw_rect(Rect2(-13,-35,26,24),tint)
	draw_rect(Rect2(-10,-54,20,20),Color("d1a27c"))
	draw_rect(Rect2(-11,-57,22,8),Color("45443c") if kind != "courier" else Color("b99854"))
	draw_rect(Rect2(facing*5,-47,3,3),Color("343d3e"))
	if working:
		draw_line(Vector2(-12,-25),Vector2(-22,-30+sin(phase*15)*5),Color("d1a27c"),5)
	if waiting:
		draw_rect(Rect2(-3,-68,6,6),Color("e4c375"))
	if not carrying.is_empty():
		draw_rect(Rect2(7,-30,24,20),Color("b99565") if carrying != "device" else Color("88b9ac"))
