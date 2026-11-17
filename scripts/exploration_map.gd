class_name ValeExplorationMap
extends Control

const CELL_SIZE := 24.0
const FRAME_PADDING := Vector2(72.0, 24.0)
const FOG := Color(0.065, 0.10, 0.105)
const GRID := Color(0.13, 0.18, 0.17)
const CLEARED := Color(0.115, 0.19, 0.16)
const LAND := Color(0.38, 0.50, 0.36)
const INK := Color(0.92, 0.88, 0.74)
const GOLD := Color(1.0, 0.71, 0.35)

var _terrain: Dictionary[Vector2i, Array] = {}
var _visited: Dictionary[Vector2i, bool] = {}
var _landmarks: Dictionary[String, Vector2] = {}
var _first_cell := Vector2i.ZERO
var _last_cell := Vector2i.ZERO
var _has_terrain := false
var _player_position := Vector2.ZERO

func configure(region: NavigationRegion3D, landmarks: Dictionary[String, Vector3]) -> void:
	var mesh := region.navigation_mesh
	var vertices := mesh.get_vertices()
	for index in mesh.get_polygon_count():
		var polygon := PackedVector2Array()
		for vertex in mesh.get_polygon(index):
			polygon.append(_top_down(region.to_global(vertices[vertex])))
		_store_terrain(polygon)
	for label in landmarks:
		_landmarks[label] = _top_down(landmarks[label])
	queue_redraw()

func reveal(position_3d: Vector3) -> void:
	var next_position := _top_down(position_3d)
	var cell := _cell_at(next_position)
	if not _terrain.has(cell):
		return
	var moved := not next_position.is_equal_approx(_player_position)
	var newly_visited := not _visited.has(cell)
	_player_position = next_position
	_visited[cell] = true
	if moved or newly_visited:
		queue_redraw()

func is_explored(position_3d: Vector3) -> bool:
	return _visited.has(_cell_at(_top_down(position_3d)))

func _top_down(position_3d: Vector3) -> Vector2:
	return Vector2(position_3d.x, position_3d.z)

func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL_SIZE).floor())

func _store_terrain(polygon: PackedVector2Array) -> void:
	if polygon.is_empty():
		return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var first := _cell_at(bounds.position)
	var last := _cell_at(bounds.end)
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var cell := Vector2i(column, row)
			var start := Vector2(cell) * CELL_SIZE
			var corners := PackedVector2Array([
				start, start + Vector2(CELL_SIZE, 0), start + Vector2(CELL_SIZE, CELL_SIZE),
				start + Vector2(0, CELL_SIZE),
			])
			var pieces := Geometry2D.intersect_polygons(polygon, corners)
			if pieces.is_empty():
				continue
			if not _terrain.has(cell):
				_terrain[cell] = []
			_terrain[cell].append_array(pieces)
			if not _has_terrain:
				_first_cell = cell
				_last_cell = cell
				_has_terrain = true
			else:
				_first_cell = Vector2i(mini(_first_cell.x, column), mini(_first_cell.y, row))
				_last_cell = Vector2i(maxi(_last_cell.x, column), maxi(_last_cell.y, row))

func _draw() -> void:
	if not _has_terrain:
		return
	var bounds := Rect2(Vector2(_first_cell) * CELL_SIZE,
		Vector2(_last_cell - _first_cell + Vector2i.ONE) * CELL_SIZE)
	var available := size - FRAME_PADDING * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var zoom := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var map_size := bounds.size * zoom
	var origin := (size - map_size) * 0.5 - bounds.position * zoom
	var frame := Rect2(bounds.position * zoom + origin, map_size)
	draw_rect(frame, FOG)
	for cell in _visited:
		var rect := Rect2(Vector2(cell) * CELL_SIZE * zoom + origin, Vector2.ONE * CELL_SIZE * zoom)
		draw_rect(rect, CLEARED)
		for piece: PackedVector2Array in _terrain[cell]:
			var scaled := PackedVector2Array()
			for point in piece:
				scaled.append(point * zoom + origin)
			draw_colored_polygon(scaled, LAND)
		draw_rect(rect, GRID, false, 1.0)
	draw_rect(frame, GRID.lightened(0.18), false, 1.0)
	_draw_landmarks(zoom, origin)
	if not _visited.is_empty():
		var player_mark := _player_position * zoom + origin
		draw_circle(player_mark, 7.0, FOG)
		draw_circle(player_mark, 4.5, GOLD, true, -1.0, true)

func _draw_landmarks(zoom: float, origin: Vector2) -> void:
	var font := get_theme_default_font()
	for label in _landmarks:
		var map_point := _landmarks[label]
		if not _visited.has(_cell_at(map_point)):
			continue
		var point := map_point * zoom + origin
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var label_position := Vector2(clampf(point.x + 8.0, 4.0, size.x - width - 4.0), point.y - 7.0)
		draw_circle(point, 2.5, INK, true, -1.0, true)
		draw_rect(Rect2(label_position - Vector2(3, 14), Vector2(width + 6, 18)), FOG)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
