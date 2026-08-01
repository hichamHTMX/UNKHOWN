extends Node2D



func _ready() -> void:
	await get_tree().create_timer(1).timeout
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", null, 0, 3)
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(1).timeout
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", null, 4)
	
