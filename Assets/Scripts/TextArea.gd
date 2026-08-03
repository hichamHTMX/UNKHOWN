extends Area2D


var dialogue_start_index : int
var dialogue_end_index : int


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and !global.Warp_entered:
		dialogue_start(dialogue_start_index, dialogue_end_index)
		global.Warp_entered = 1
	pass


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		global.Warp_entered = 0
		pass
	pass

func dialogue_start(start : int, end :int = -1):
	var canvas = get_tree().current_scene.get_node_or_null("DialogueCanvas")
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", canvas, start, end)
	global.Can_move = false
	await DialogueManager.dialogue_finished
	global.Can_move = true
