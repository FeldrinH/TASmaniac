extends Node2D

var color: Color
var outline_color: Color
var shape: Shape2D

func _init(color: Color):
	self.color = color
	self.outline_color = color
	self.outline_color.a = 1.0

func _ready():
	add_to_group("_collision_drawers")
	z_index = 1

func _draw():
	var parent := get_parent()
	if parent is CollisionShape2D:
		parent.shape.draw(self.get_canvas_item(), color)
	elif parent is TileMapLayer:
		for cell in parent.get_used_cells():
			var tile_data: TileData = parent.get_cell_tile_data(cell)
			if not tile_data:
				continue
			if tile_data.get_collision_polygons_count(2) == 0:
				continue
			var polygon := tile_data.get_collision_polygon_points(2, 0)
			draw_set_transform_matrix(Transform2D(0.0, parent.map_to_local(cell)))
			draw_colored_polygon(polygon, color)
			draw_polyline(polygon, outline_color)
			draw_line(polygon[-1], polygon[0], outline_color)
