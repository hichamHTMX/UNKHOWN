extends Node2D

@export var font_size: int = 20
@export var name_font_size: int = 24
@export var text_color: Color = Color.WHITE
@export var border_width: int = 4
@export var padding: int = 25
@export var rect_width: int = 576
@export var rect_height: int = 128
@export var line_spacing: int = 4
@export var default_speed: float = 0.1
@export var skip_key: String = "o"
@export var next_key: String = "x"
@export var box_color: Color = Color(0, 0, 0, 1)
@export var image_scale: float = 3.0
@export var default_box_position: Vector2 = Vector2.ZERO

@export var option_spacing: int = 30
@export var option_fixed_y: int = 100
@export var vertical_option_spacing: int = 25
@export var option_layout_mode: String = "horizontal"

@export var font_path: String = "res://Assets/Fonts/Raqami.ttf"
@export var arabic_font_path: String = "res://Assets/Fonts/Raqami.ttf"
var font_en: Font
var font_ar: Font

var current_char_index: int = 0
var current_line: String = ""
var lines: Array = []
var font: Font
var text_rect: Rect2
var is_typing: bool = false
var words: Array = []
var current_word_index: int = 0
var current_word_char_index: int = 0
var dialogue_data: Array = []
var current_dialogue_index: int = 0
var current_dialogue: Dictionary = {}
var typing_timer: Timer
var pause_timer: Timer
var image_animation_timer: Timer
var is_paused: bool = false
var char_sound: AudioStreamPlayer
var image_textures: Array[Texture2D] = []
var current_image_index: int = 0
var image_duration: float = 0.0
var image_size: Vector2
var image_side_padding: int = 10
var image_side: int = 0
var auto_advance: bool = false

var current_language: String = "en"
var is_rtl: bool = false
var box_visible: bool = true

var text_align: String = "left"
var vertical_align: String = "top"

var current_typing_speed: float = 0.1

var last_language := "en"
var last_box_visible := true
var last_position := Vector2.ZERO
var last_typing_speed := 0.1
var last_text_align := "left"
var last_vertical_align := "top"
var last_choices_layout := "horizontal"
var last_image_position := "left"

var end_dialogue_index: int = -1

var line_pause_time: float = 0.2
var punctuation_pause_time: float = 0.2
var punctuation_marks: Array = [".", "", "!", ",", ":", ";"]

signal dialogue_finished
signal option_selected(option_index: int, option_text: String)
signal custom_signal_triggered(signal_name: String, signal_data: Dictionary)

var color_codes: Dictionary = {
	"[red]": Color.RED,
	"[green]": Color.GREEN,
	"[blue]": Color.BLUE,
	"[yellow]": Color.YELLOW,
	"[purple]": Color.PURPLE,
	"[cyan]": Color.CYAN,
	"[orange]": Color.ORANGE,
	"[pink]": Color.PINK,
	"[white]": Color.WHITE,
	"[black]": Color.BLACK,
	"[gray]": Color.GRAY,
	"[lime]": Color.LIME_GREEN,
	"[brown]": Color(0.6, 0.4, 0.2, 1.0)
}

var processed_words: Array = []
var word_colors: Array = []
var current_word_color: Color = Color.WHITE

var has_options: bool = false
var options: Array = []
var current_option_index: int = 0
var option_color_selected: Color = Color(1.0, 0.7, 0.2, 1.0)
var option_color_normal: Color = Color.WHITE
var option_prefix: String = ""

var option_positions: Array = []
var total_options_width: float = 0

var option_dialogue_sequence: Array = []
var current_option_dialogue_index: int = 0
var is_in_option_sequence: bool = false

func _ready():
	font_en = load(font_path)
	if font_en == null:
		font_en = ThemeDB.fallback_font

	font_ar = load(arabic_font_path)
	if font_ar == null:
		font_ar = font_en
		push_warning("لم يتم العثور على خط عربي في: " + arabic_font_path + " — استخدم خطاً يدعم الحروف العربية.")

	font = font_en
	last_typing_speed = default_speed
	last_position = default_box_position
	setup_timers()
	char_sound = AudioStreamPlayer.new()
	add_child(char_sound)

func setup_timers():
	typing_timer = Timer.new()
	add_child(typing_timer)
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_on_typing_timer_timeout)

	pause_timer = Timer.new()
	add_child(pause_timer)
	pause_timer.one_shot = true
	pause_timer.timeout.connect(_on_pause_timer_timeout)

	image_animation_timer = Timer.new()
	add_child(image_animation_timer)
	image_animation_timer.timeout.connect(_on_image_animation_timeout)

func get_text_direction() -> int:
	return TextServer.DIRECTION_RTL if is_rtl else TextServer.DIRECTION_LTR

func calculate_horizontal_options_positions():
	option_positions.clear()
	total_options_width = 0

	if options.size() == 0:
		return

	var option_widths: Array = []
	for i in range(options.size()):
		var option_text = str(options[i])
		var width = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		option_widths.append(width)
		total_options_width += width

	if options.size() > 1:
		total_options_width += option_spacing * (options.size() - 1)

	var start_x = (rect_width - total_options_width) / 2.0
	var fixed_y = option_fixed_y

	if is_rtl:
		var current_x = start_x + total_options_width
		for i in range(options.size()):
			current_x -= option_widths[i]
			option_positions.append(Vector2(current_x, fixed_y))
			current_x -= option_spacing
	else:
		var current_x = start_x
		for i in range(options.size()):
			option_positions.append(Vector2(current_x, fixed_y))
			current_x += option_widths[i] + option_spacing

func calculate_vertical_options_positions():
	option_positions.clear()

	if options.size() == 0:
		return

	var available_height = rect_height - option_fixed_y - padding
	var total_options_height = (options.size() - 1) * vertical_option_spacing + options.size() * font_size

	var start_y = option_fixed_y
	if total_options_height < available_height:
		start_y = option_fixed_y + (available_height - total_options_height) / 2.0

	var current_y = start_y

	for i in range(options.size()):
		var option_text = str(options[i])
		var option_width = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var x_position = (rect_width - option_width) / 2.0

		option_positions.append(Vector2(x_position, current_y))
		current_y += font_size + vertical_option_spacing

func calculate_options_positions():
	if option_layout_mode == "vertical":
		calculate_vertical_options_positions()
	else:
		calculate_horizontal_options_positions()

func load_dialogue_json(json_path: String):
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		print("خطأ: لا يمكن فتح الملف: ", json_path)
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		print("خطأ في تحليل JSON: ", json.get_error_message())
		return
	dialogue_data = json.data
	if dialogue_data.size() > 0:
		start_dialogue(0)

func process_color_codes(text: String) -> void:
	processed_words.clear()
	word_colors.clear()

	var current_color = text_color
	var processed_text = text

	var regex = RegEx.new()
	regex.compile("\\[([a-zA-Z]+):\\s*([^\\]]+)\\]")

	var result = regex.search(processed_text)
	while result:
		var color_name = result.get_string(1).to_lower()
		var colored_text = result.get_string(2)
		var full_match = result.get_string(0)

		var color_key = "[" + color_name + "]"
		if color_key in color_codes:
			var temp_marker = "<!COLOR_" + str(processed_words.size()) + "_" + color_name + "!>" + colored_text + "<!END_COLOR!>"
			processed_text = processed_text.replace(full_match, temp_marker)

		result = regex.search(processed_text)

	var raw_words = processed_text.replace("\n", " \n ").split(" ")

	for word in raw_words:
		var word_str = str(word)

		if word_str.begins_with("<!COLOR_"):
			var end_marker_pos = word_str.find("!>")
			if end_marker_pos != -1:
				var color_info = word_str.substr(8, end_marker_pos - 8)
				var parts = color_info.split("_")
				if parts.size() >= 2:
					var color_name = parts[1]
					var color_key = "[" + color_name + "]"
					if color_key in color_codes:
						current_color = color_codes[color_key]

				word_str = word_str.substr(end_marker_pos + 2)

		if word_str.ends_with("<!END_COLOR!>"):
			word_str = word_str.replace("<!END_COLOR!>", "")
			var next_color = text_color

			if word_str.length() > 0:
				processed_words.append(word_str)
				word_colors.append(current_color)

			current_color = next_color
			continue

		var color_found = false
		for code in color_codes.keys():
			if word_str.begins_with(code):
				current_color = color_codes[code]
				word_str = word_str.substr(code.length())
				color_found = true
				break

		if word_str.length() > 0:
			processed_words.append(word_str)
			word_colors.append(current_color)
		elif not color_found and not word_str.begins_with("<!"):
			processed_words.append(word_str)
			word_colors.append(current_color)

func _parse_image_position(value) -> int:
	if typeof(value) == TYPE_STRING:
		return 1 if value.to_lower() == "right" else 0
	return int(value)

func apply_language_settings(dialogue_dict: Dictionary):
	current_language = str(dialogue_dict.get("language", last_language)).to_lower()
	last_language = current_language
	is_rtl = current_language == "ar"
	font = font_ar if is_rtl else font_en

func _apply_common_fields(dialogue_dict: Dictionary):
	apply_language_settings(dialogue_dict)

	box_visible = dialogue_dict.get("box_visible", last_box_visible)
	last_box_visible = box_visible

	text_align = dialogue_dict.get("text_align", last_text_align)
	last_text_align = text_align

	vertical_align = dialogue_dict.get("vertical_align", last_vertical_align)
	last_vertical_align = vertical_align

	if dialogue_dict.has("position"):
		var pos_data = dialogue_dict.get("position")
		position = Vector2(pos_data.get("x", last_position.x), pos_data.get("y", last_position.y))
	else:
		position = last_position
	last_position = position

	option_layout_mode = dialogue_dict.get("choices_layout", last_choices_layout)
	last_choices_layout = option_layout_mode

	current_typing_speed = dialogue_dict.get("typing_speed", last_typing_speed)
	last_typing_speed = current_typing_speed

func start_dialogue(dialogue_index: int):
	if dialogue_index >= dialogue_data.size():
		return
	current_dialogue_index = dialogue_index
	current_dialogue = dialogue_data[dialogue_index]
	auto_advance = current_dialogue.get("auto_advance", false)

	_apply_common_fields(current_dialogue)

	has_options = current_dialogue.has("choices")
	if has_options:
		options = current_dialogue.get("choices", [])
		current_option_index = 0
	else:
		options.clear()

	var dialogue_text = str(current_dialogue.get("text", ""))
	process_color_codes(dialogue_text)

	words = processed_words
	current_char_index = 0
	current_line = ""
	lines.clear()
	current_word_index = 0
	current_word_char_index = 0
	is_typing = true
	is_paused = false
	image_textures.clear()
	current_image_index = 0
	image_animation_timer.stop()

	if word_colors.size() > 0:
		current_word_color = word_colors[0]
	else:
		current_word_color = text_color

	if current_dialogue.has("typing_sound"):
		char_sound.stream = load(current_dialogue["typing_sound"])

	if current_dialogue.has("image"):
		var image_data = current_dialogue["image"]
		if image_data is Array:
			for path in image_data:
				var tex = load(path)
				if tex:
					image_textures.append(tex.duplicate())
					image_textures[-1].set("flags/filter", false)
		else:
			var tex = false
			if FileAccess.file_exists(image_data):
				tex = load(image_data)
			if tex:
				image_textures.append(tex.duplicate())
				image_textures[-1].set("flags/filter", false)

		image_duration = current_dialogue.get("image_frame_duration", 0.2)
		if image_textures.size() > 1:
			image_animation_timer.wait_time = image_duration
			image_animation_timer.start()

	image_side = _parse_image_position(current_dialogue.get("image_position", last_image_position))
	last_image_position = "right" if image_side == 1 else "left"

	if image_textures.size() > 0:
		image_size = image_textures[0].get_size() * image_scale
	else:
		image_size = Vector2(128, 128)

	var left_offset = 0
	var right_offset = 0
	if image_textures.size() > 0:

		if image_side == 0:
			left_offset = image_size.x + image_side_padding
		else:
			right_offset = image_size.x + image_side_padding

	text_rect = Rect2(padding + left_offset, padding, rect_width - padding * 2 - left_offset - right_offset, rect_height - padding * 2)

	typing_timer.wait_time = current_typing_speed
	typing_timer.start()

	if has_options:
		calculate_options_positions()

	queue_redraw()

func _on_image_animation_timeout():
	current_image_index = (current_image_index + 1) % image_textures.size()
	image_animation_timer.start()
	queue_redraw()

func _on_typing_timer_timeout():
	if is_paused or not is_typing:
		return

	if current_word_index >= words.size():
		is_typing = false
		if current_line.length() > 0:
			lines.append(current_line)
			current_line = ""

		queue_redraw()
		if auto_advance and not has_options:
			await get_tree().create_timer(0.5).timeout
			next_dialogue()
		return

	if current_word_index < word_colors.size():
		current_word_color = word_colors[current_word_index]

	var current_word = str(words[current_word_index])
	if current_word == "\n":
		lines.append(current_line)
		current_line = ""
		current_word_index += 1
		current_word_char_index = 0
		queue_redraw()
		pause_typing(line_pause_time)
		return

	if current_word_char_index < current_word.length():
		var current_char = current_word[current_word_char_index]
		var test_line = current_line + current_char
		if current_word_char_index == 0 and current_line.length() > 0:
			test_line = current_line + " " + current_word
		var text_size = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x > text_rect.size.x and current_word_char_index == 0 and current_line.length() > 0:
			lines.append(current_line)
			current_line = ""
			queue_redraw()
			typing_timer.wait_time = current_typing_speed
			typing_timer.start()
			return
		if current_word_char_index == 0 and current_line.length() > 0:
			current_line += " "
		current_line += current_char
		current_word_char_index += 1
		if char_sound.stream:
			char_sound.play()
		if current_char in punctuation_marks:
			pause_typing(punctuation_pause_time)
			queue_redraw()
			return
		queue_redraw()
	else:
		current_word_index += 1
		current_word_char_index = 0
	typing_timer.wait_time = current_typing_speed
	typing_timer.start()

func pause_typing(pause_duration: float):
	is_paused = true
	pause_timer.wait_time = pause_duration
	pause_timer.start()

func _on_pause_timer_timeout():
	is_paused = false
	if is_typing:
		typing_timer.wait_time = current_typing_speed
		typing_timer.start()

func start_option_dialogue_sequence(dialogues: Array):
	option_dialogue_sequence = dialogues
	current_option_dialogue_index = 0
	is_in_option_sequence = true
	start_option_dialogue(option_dialogue_sequence[0])

func start_option_dialogue(dialogue_dict: Dictionary):
	current_dialogue = dialogue_dict

	_apply_common_fields(dialogue_dict)

	has_options = dialogue_dict.has("choices")
	if has_options:
		options = dialogue_dict.get("choices", [])
		current_option_index = 0
	else:
		options.clear()

	var dialogue_text = str(dialogue_dict.get("text", ""))
	process_color_codes(dialogue_text)

	words = processed_words
	current_char_index = 0
	current_line = ""
	lines.clear()
	current_word_index = 0
	current_word_char_index = 0
	is_typing = true
	is_paused = false

	if word_colors.size() > 0:
		current_word_color = word_colors[0]
	else:
		current_word_color = text_color

	if dialogue_dict.has("typing_sound"):
		char_sound.stream = load(dialogue_dict["typing_sound"])

	typing_timer.wait_time = current_typing_speed
	typing_timer.start()

	if has_options:
		calculate_options_positions()

	call_deferred("check_and_emit_custom_signal")

	queue_redraw()

func _can_advance_to(index: int) -> bool:
	if index < 0 or index >= dialogue_data.size():
		return false
	if end_dialogue_index >= 0 and index > end_dialogue_index:
		return false
	return true

func next_dialogue():
	if is_in_option_sequence and current_option_dialogue_index + 1 < option_dialogue_sequence.size():
		current_option_dialogue_index += 1
		start_option_dialogue(option_dialogue_sequence[current_option_dialogue_index])
		return

	if is_in_option_sequence:
		is_in_option_sequence = false
		option_dialogue_sequence.clear()
		current_option_dialogue_index = 0
		if _can_advance_to(current_dialogue_index + 1):
			start_dialogue(current_dialogue_index + 1)
		else:
			emit_signal("dialogue_finished")
			queue_free()
		return

	if has_options:
		return

	if _can_advance_to(current_dialogue_index + 1):
		start_dialogue(current_dialogue_index + 1)
	else:
		emit_signal("dialogue_finished")
		queue_free()

func select_option():
	if has_options and current_option_index < options.size():
		var selected_option = options[current_option_index]
		emit_signal("option_selected", current_option_index, selected_option)

		if current_dialogue.has("choices_branches") and current_dialogue.choices_branches.size() > current_option_index:
			var branch_dialogues = current_dialogue.choices_branches[current_option_index]
			if branch_dialogues is Array and branch_dialogues.size() > 0:
				start_option_dialogue_sequence(branch_dialogues)
				return

		if current_dialogue.has("choices_goto") and current_dialogue.choices_goto.size() > current_option_index:
			var action = current_dialogue.choices_goto[current_option_index]
			if action.has("goto"):
				start_dialogue(action.goto)
				return

		next_dialogue()

func check_and_emit_custom_signal():
	if not current_dialogue.has("event"):
		return

	var signal_info = current_dialogue.get("event")

	if signal_info is String:
		var signal_name = str(signal_info)
		call_deferred("emit_custom_signal_deferred", signal_name, {})

	elif signal_info is Dictionary:
		var signal_name = signal_info.get("name", "")
		var signal_data = signal_info.get("data", {})

		if signal_name != "":
			call_deferred("emit_custom_signal_deferred", signal_name, signal_data)

func emit_custom_signal_deferred(signal_name: String, signal_data: Dictionary):
	custom_signal_triggered.emit(signal_name, signal_data)

func draw_colored_text(text: String, pos: Vector2, color: Color):
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color, 0, get_text_direction())

func _draw():
	if box_visible:
		draw_rect(Rect2(0, 0, rect_width, rect_height), box_color)
		draw_rect(Rect2(border_width, border_width, rect_width - 2 * border_width, rect_height - 2 * border_width), Color.WHITE, false, border_width)

	var speaker_name = current_dialogue.get("speaker", "")

	var total_lines = lines.size()
	if current_line.length() > 0:
		total_lines += 1
	if total_lines == 0:
		total_lines = 1

	var font_ascent = font.get_ascent(font_size)
	var font_descent = font.get_descent(font_size)

	var text_block_height = (total_lines - 1) * (font_size + line_spacing) + font_ascent + font_descent
	var name_height = (name_font_size + 10) if speaker_name != "" else 0

	var y_offset = padding
	if vertical_align == "center":
		var available_height = text_rect.size.y - name_height
		var block_top = text_rect.position.y + name_height + max((available_height - text_block_height) / 2.0, 0)
		y_offset = block_top + font_ascent - font_size
	else:
		if speaker_name != "":
			y_offset = padding + name_height
		else:
			y_offset = padding - 10

	if speaker_name != "":
		var name_x = text_rect.position.x
		if is_rtl:
			var name_width = font.get_string_size(speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size).x
			name_x = text_rect.position.x + text_rect.size.x - name_width
		var name_pos = Vector2(name_x, padding + name_font_size)
		draw_string(font, name_pos, speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, Color.WHITE, 0, get_text_direction())

	y_offset += font_size

	for i in range(lines.size()):
		var line_pos = Vector2(text_rect.position.x, y_offset + i * (font_size + line_spacing))
		draw_colored_line(str(lines[i]), line_pos, i)

	if current_line.length() > 0:
		var current_line_pos = Vector2(text_rect.position.x, y_offset + lines.size() * (font_size + line_spacing))
		draw_colored_line(current_line, current_line_pos, lines.size())

	if has_options and not is_typing:
		draw_options()

	if image_textures.size() > 0:
		var tex = image_textures[current_image_index]
		var image_pos = Vector2()

		if image_side == 0:
			image_pos = Vector2(image_side_padding, rect_height - image_size.y - image_side_padding)
		else:
			image_pos = Vector2(rect_width - image_size.x - image_side_padding, rect_height - image_size.y - image_side_padding)
		draw_texture_rect(tex, Rect2(image_pos, image_size), false)

func draw_options():
	var direction = get_text_direction()
	for i in range(options.size()):
		if i < option_positions.size():
			var option_text = str(options[i])
			var option_color = option_color_selected if i == current_option_index else option_color_normal
			var option_pos = option_positions[i]

			if option_layout_mode == "vertical" and i == current_option_index:
				var arrow_char = "◄" if is_rtl else "►"
				if is_rtl:
					var option_width = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					var arrow_pos = Vector2(option_pos.x + option_width + 8, option_pos.y)
					draw_string(font, arrow_pos, arrow_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, option_color_selected)
				else:
					var arrow_pos = Vector2(option_pos.x - 20, option_pos.y)
					draw_string(font, arrow_pos, arrow_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, option_color_selected)

			draw_string(font, option_pos, option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, option_color, 0, direction)

func draw_colored_line(line_text: String, start_pos: Vector2, line_index: int):
	var words_in_line = line_text.split(" ")

	var full_width = 0.0
	if text_align == "center" or text_align == "right" or text_align == "left":
		full_width = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var global_word_index = 0
	for i in range(line_index):
		var prev_line_words = str(lines[i]).split(" ") if i < lines.size() else []
		global_word_index += prev_line_words.size()

	var direction = get_text_direction()
	var space_width = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	if is_rtl:
		var x_offset = text_rect.size.x
		if text_align == "center":
			x_offset = (text_rect.size.x + full_width) / 2.0
		elif text_align == "left":
			x_offset = full_width

		for word in words_in_line:
			if str(word).length() > 0:
				var word_color = text_color
				if global_word_index < word_colors.size():
					word_color = word_colors[global_word_index]

				var word_width = font.get_string_size(str(word), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				x_offset -= word_width
				var word_pos = Vector2(start_pos.x + x_offset, start_pos.y)
				draw_string(font, word_pos, str(word), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word_color, 0, direction)
				x_offset -= space_width

				global_word_index += 1
			else:
				global_word_index += 1
	else:
		var x_offset = 0.0
		if text_align == "center":
			x_offset = (text_rect.size.x - full_width) / 2.0
		elif text_align == "right":
			x_offset = text_rect.size.x - full_width

		for word in words_in_line:
			if str(word).length() > 0:
				var word_color = text_color
				if global_word_index < word_colors.size():
					word_color = word_colors[global_word_index]

				var word_pos = Vector2(start_pos.x + x_offset, start_pos.y)
				draw_string(font, word_pos, str(word), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, word_color, 0, direction)

				var word_width = font.get_string_size(str(word), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				x_offset += word_width + space_width

				global_word_index += 1
			else:
				global_word_index += 1

func _input(event):
	if has_options and not is_typing:
		if option_layout_mode == "vertical":
			if event.is_action_pressed("ui_up"):
				current_option_index = (current_option_index - 1) % options.size()
				if current_option_index < 0:
					current_option_index = options.size() - 1
				queue_redraw()
			elif event.is_action_pressed("ui_down"):
				current_option_index = (current_option_index + 1) % options.size()
				queue_redraw()
		else:
			var prev_pressed = event.is_action_pressed("ui_right") if is_rtl else event.is_action_pressed("ui_left")
			var next_pressed = event.is_action_pressed("ui_left") if is_rtl else event.is_action_pressed("ui_right")

			if prev_pressed:
				current_option_index = (current_option_index - 1) % options.size()
				if current_option_index < 0:
					current_option_index = options.size() - 1
				queue_redraw()
			elif next_pressed:
				current_option_index = (current_option_index + 1) % options.size()
				queue_redraw()

		if event.is_action_pressed(next_key) or event.is_action_pressed("ui_accept"):
			select_option()
		return

	if event.is_action_pressed(next_key):
		if not is_typing and not auto_advance and not has_options:
			next_dialogue()
	if event.is_action_pressed(skip_key):
		if is_typing:
			skip_typing()
	elif event.is_action_pressed("ui_cancel"):
		restart_dialogue()

func skip_typing():
	is_typing = false
	is_paused = false
	typing_timer.stop()
	pause_timer.stop()
	lines.clear()
	current_line = ""

	var temp_line = ""

	for word in words:
		var word_str = str(word)

		if word_str == "\n":
			if temp_line.length() > 0:
				lines.append(temp_line)
			temp_line = ""
			continue

		var test_line = temp_line
		if temp_line.length() > 0:
			test_line += " "
		test_line += word_str

		var text_size = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x > text_rect.size.x and temp_line.length() > 0:
			lines.append(temp_line)
			temp_line = word_str
		else:
			temp_line = test_line

	if temp_line.length() > 0:
		lines.append(temp_line)

	queue_redraw()

func restart_dialogue():
	current_dialogue_index = 0
	if dialogue_data.size() > 0:
		start_dialogue(0)

func set_dialogue_json(json_path: String):
	load_dialogue_json(json_path)

func set_dialogue(dialogue_index: int):
	if dialogue_index >= 0 and dialogue_index < dialogue_data.size():
		start_dialogue(dialogue_index)

func get_current_dialogue_info() -> Dictionary:
	return current_dialogue

func is_currently_typing() -> bool:
	return is_typing

func emit_custom_signal_manually(signal_name: String, signal_data: Dictionary = {}):
	custom_signal_triggered.emit(signal_name, signal_data)

func connect_to_custom_signal(target_object: Object, target_method: String):
	var callable = Callable(target_object, target_method)
	if not custom_signal_triggered.is_connected(callable):
		custom_signal_triggered.connect(callable)

func set_option_layout_mode(mode: String):
	if mode == "vertical" or mode == "horizontal":
		option_layout_mode = mode
		last_choices_layout = mode
		if has_options:
			calculate_options_positions()
			queue_redraw()

func get_option_layout_mode() -> String:
	return option_layout_mode

func get_current_language() -> String:
	return current_language

func is_current_dialogue_rtl() -> bool:
	return is_rtl

func set_end_dialogue_index(index: int) -> void:
	end_dialogue_index = index
