class_name WorkshopArt
extends RefCounted
## Original generated PNGs remain untouched. Atlas regions preserve their alpha.
const ROOT := "res://assets/era_one/"
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func definition(id: String) -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/workshop_art.json"))
	return _manifest.get(id, {})

static func texture(id: String, frame: int = 0) -> Texture2D:
	var key := id + str(frame)
	if _textures.has(key): return _textures[key]
	var data := definition(id)
	if data.is_empty(): return null
	var path := ROOT + id + ".png"
	if not ResourceLoader.exists(path): return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	var box: Array = data.frames[frame % data.frames.size()]
	atlas.region = Rect2(box[0],box[1],box[2],box[3])
	_textures[key] = atlas
	return atlas

static func sprite(id: String, width: float, frame: int = 0) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = texture(id,frame)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if node.texture != null:
		node.scale = Vector2.ONE * width / node.texture.get_width()
		node.position.y = -node.texture.get_height()*node.scale.y/2
	return node
