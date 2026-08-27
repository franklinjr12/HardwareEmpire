class_name WorkshopGrid
extends RefCounted

const TILE_SIZE: int = 32
var width: int
var height: int
var occupied: Dictionary = {}

func _init(grid_width: int = 40, grid_height: int = 26) -> void:
	width = grid_width
	height = grid_height

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func can_place(origin: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			var cell := origin + Vector2i(x, y)
			if not is_inside(cell) or occupied.has(cell):
				return false
	return true

func place(id: String, origin: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	if not can_place(origin, size):
		return false
	for y in range(size.y):
		for x in range(size.x):
			occupied[origin + Vector2i(x, y)] = id
	return true

func remove(id: String) -> void:
	for cell in occupied.keys():
		if occupied[cell] == id:
			occupied.erase(cell)

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_inside(start) or not is_inside(goal):
		return path
	var current := start
	path.append(current)
	while current != goal and path.size() < width * height:
		var next := current
		if current.x != goal.x:
			next.x += 1 if goal.x > current.x else -1
		elif current.y != goal.y:
			next.y += 1 if goal.y > current.y else -1
		if occupied.has(next) and occupied[next] != "walkable":
			if current.y + 1 < height and not occupied.has(Vector2i(current.x, current.y + 1)):
				next = Vector2i(current.x, current.y + 1)
			elif current.y - 1 >= 0 and not occupied.has(Vector2i(current.x, current.y - 1)):
				next = Vector2i(current.x, current.y - 1)
			else:
				break
		current = next
		path.append(current)
	return path
