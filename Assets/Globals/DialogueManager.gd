extends Node
const DIALOGUE_BOX_SCENE: PackedScene = preload("res://Assets/Scenes/DialogueBox.tscn")
var _instance: Node2D = null
var _is_active: bool = false
var _cached_json_path: String = ""
var _cached_dialogue_data: Array = []
signal dialogue_started
signal dialogue_finished
signal option_selected(option_index: int, option_text: String)
signal custom_signal_triggered(signal_name: String, signal_data: Dictionary)

func start_from_json(json_path: String, parent_node: Node = null, start_index: int = 0, end_index: int = -1) -> void:
	var data: Array = _load_json_file(json_path)
	if data.is_empty():
		return
	start_from_array(data, parent_node, start_index, end_index)

func start_from_array(dialogue_array: Array, parent_node: Node = null, start_index: int = 0, end_index: int = -1) -> void:
	_create_instance(parent_node)
	_instance.dialogue_data = dialogue_array
	if start_index < 0 or start_index >= dialogue_array.size():
		push_warning("DialogueManager: start_index (%d) خارج نطاق المصفوفة (الحجم: %d). سيبدأ من 0." % [start_index, dialogue_array.size()])
		start_index = 0
	if end_index >= 0 and end_index < start_index:
		push_warning("DialogueManager: end_index (%d) أصغر من start_index (%d). سيتم تجاهله." % [end_index, start_index])
		end_index = -1
	_instance.end_dialogue_index = end_index
	if dialogue_array.size() > 0:
		_instance.start_dialogue(start_index)
	dialogue_started.emit()

func start_simple(text: String, speaker_name: String = "", language: String = "en") -> void:
	var dialogue_array: Array = [
		{
			"name": speaker_name,
			"language": language,
			"text": text
		}
	]
	start_from_array(dialogue_array)

func _load_json_file(json_path: String) -> Array:
	if json_path == _cached_json_path and not _cached_dialogue_data.is_empty():
		return _cached_dialogue_data
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: لا يمكن فتح الملف: " + json_path)
		return []
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("DialogueManager: خطأ في تحليل JSON: " + json.get_error_message())
		return []
	var data = json.data
	if typeof(data) != TYPE_ARRAY:
		push_error("DialogueManager: محتوى الملف ليس مصفوفة (Array).")
		return []
	_cached_json_path = json_path
	_cached_dialogue_data = data
	return data

func is_active() -> bool:
	return _is_active

func get_current_dialogue_node() -> Node2D:
	return _instance

func _create_instance(parent_node: Node) -> void:
	if _instance and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = DIALOGUE_BOX_SCENE.instantiate()
	var target_parent: Node = parent_node if parent_node else get_tree().current_scene
	target_parent.add_child(_instance)
	_instance.dialogue_finished.connect(_on_dialogue_finished)
	_instance.option_selected.connect(_on_option_selected)
	_instance.custom_signal_triggered.connect(_on_custom_signal)
	_is_active = true

func _on_dialogue_finished() -> void:
	_is_active = false
	_instance = null
	dialogue_finished.emit()

func _on_option_selected(option_index: int, option_text: String) -> void:
	option_selected.emit(option_index, option_text)

func _on_custom_signal(signal_name: String, signal_data: Dictionary) -> void:
	custom_signal_triggered.emit(signal_name, signal_data)
