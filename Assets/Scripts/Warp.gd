extends TileMapLayer


var area_scene: PackedScene = preload("res://Assets/Scenes/AreaWarp.tscn")

func _ready():
	for cell in get_used_cells():
		var data = get_cell_tile_data(cell)
		if data and data.get_custom_data("is_trigger"):
			var area = area_scene.instantiate()
			area.global_position = map_to_local(cell) + global_position
			add_child(area)
