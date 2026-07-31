extends Node2D



func _ready() -> void:
	DialogueManager.start_from_json("res://Assets/Dialoues/ar.json", null, 0)
	pass
