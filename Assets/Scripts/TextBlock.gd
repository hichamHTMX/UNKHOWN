extends TileMapLayer


var area_scene: PackedScene = preload("res://Assets/Scenes/TextArea.tscn")

func _ready():
	hide()
	
	var start_index := 0
	var end_index := 0
	var dialogue_start = get_node_or_null("Text")
	if dialogue_start and dialogue_start.has_meta("start_index"):
		start_index = dialogue_start.get_meta("start_index")
	if dialogue_start and dialogue_start.has_meta("end_index"):
		end_index = dialogue_start.get_meta("end_index")
	
	for cell in get_used_cells():
		var data = get_cell_tile_data(cell)
		if data and data.get_custom_data("is_trigger"):
			var area = area_scene.instantiate()
			area.global_position = map_to_local(cell) + global_position
			area.dialogue_start_index = start_index
			area.dialogue_end_index = end_index
			add_child(area)
