extends Area2D




func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and !global.Warp_entered:
		go_to_last_scene()
		global.Warp_entered = 1
	pass


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		global.Warp_entered = 0
		pass
	pass

func go_to_last_scene():
	var current_path = get_tree().current_scene.scene_file_path
	var dir_path = current_path.get_base_dir()
	var current_file = current_path.get_file()
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	var scenes = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			scenes.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	scenes.sort()
	var current_index = scenes.find(current_file)
	if current_index != -1 and current_index - 1 >= 0:
		var prev_scene_path = dir_path + "/" + scenes[current_index - 1]
		await BlackScreen.fade_out(1)
		global.next_spawn_point = "Door"
		get_tree().call_deferred("change_scene_to_file", prev_scene_path)
		await get_tree().process_frame
