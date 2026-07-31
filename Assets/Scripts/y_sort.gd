@tool
extends Node2D

func _process(delta: float) -> void:
	
	for child in get_parent().get_children():
		if child is Node2D:
			child.z_index = child.position.y
