extends "res://Assets/Scripts/TextBlock.gd"

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
	await DialogueManager.dialogue_finished
	await BlackScreen.fade_out()
	var canvas = get_tree().current_scene.get_node_or_null("DialogueCanvas")
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", canvas, 31, 39)
	global.Can_move = false
	await DialogueManager.dialogue_finished
	await BlackScreen.fade_in()
	await get_tree().create_timer(1.0).timeout
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", canvas, 40, 41)
	global.Can_move = false
	await DialogueManager.dialogue_finished
	global.Can_move = true
	global.Camera_follow = true
	queue_free()
	
