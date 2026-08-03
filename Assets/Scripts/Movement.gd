extends Node2D

var move_speed := 85
var trail := []
var max_trail_length := 300
var last_trail_pos := Vector2.ZERO
var min_trail_spacing := 1.0

@export var start_direction: Vector2 = Vector2.DOWN

var characters: Array = []
var leader: Node2D = null

@export var follower_distances := [16, 32, 48]

var last_directions := {}

func _ready():
	load_characters()
	update_party()
	apply_spawn_point()
	await BlackScreen.fade_in(1)
	

func apply_spawn_point():
	if global.next_spawn_point == "":
		set_start_direction(start_direction)
		return
	var scene_root = get_tree().current_scene
	var spawn_container = scene_root.get_node_or_null("SpawnPoints")
	if spawn_container == null:
		set_start_direction(start_direction)
		return
	var target_node = spawn_container.get_node_or_null(global.next_spawn_point)
	if target_node == null:
		set_start_direction(start_direction)
		return
	var target_pos: Vector2 = target_node.global_position

	var offset_dir: Vector2 = Vector2.ZERO
	if target_node.has_meta("offset_direction"):
		offset_dir = target_node.get_meta("offset_direction")

	var face_dir: Vector2 = start_direction
	if target_node.has_meta("face_direction"):
		face_dir = target_node.get_meta("face_direction")

	trail.clear()
	last_trail_pos = target_pos

	var ordered = get_ordered_characters()
	var offset_step := 16.0

	for i in range(ordered.size()):
		var character = ordered[i]
		var back_offset = offset_dir * i * offset_step
		character.global_position = target_pos + back_offset
		trail.append(target_pos + back_offset)

	set_start_direction(face_dir)
	global.next_spawn_point = ""

func set_start_direction(direction: Vector2):
	last_directions[leader] = direction
	last_dominant_axis[leader] = "x" if abs(direction.x) > abs(direction.y) else "y"
	update_animation(leader, Vector2.ZERO)
	for character in characters:
		last_directions[character] = direction
		last_dominant_axis[character] = "x" if abs(direction.x) > abs(direction.y) else "y"
		update_animation(character, Vector2.ZERO)
	
func load_characters():
	characters.clear()
	for child in get_children():
		if child is Node2D and child.name != "o_Cam" and child.name != "Decor":
			characters.append(child)
			child.add_to_group("Player")

func update_party():
	global.party_members = characters
	set_leader_by_global()

func set_leader_by_global():
	var index = global.LEADER_INDEX
	if index < 0 or index >= characters.size():
		index = 0
	leader = characters[index]
	update_collision_states()

func update_collision_states():
	for i in range(characters.size()):
		var character = characters[i]

		if not character.has_node("Coll"):
			continue

		var col = character.get_node("Coll")

		if character == leader:
			col.disabled = false
		else:
			col.disabled = true

func get_ordered_characters() -> Array:
	var ordered := []
	var leader_index: int = global.LEADER_INDEX
	if leader_index < 0 or leader_index >= characters.size():
		leader_index = 0
	for i in range(characters.size()):
		var idx := (leader_index + i) % characters.size()
		ordered.append(characters[idx])
	return ordered

@onready var o_cam: Camera2D = $o_Cam
@export var follow_speed := 4.0

func _physics_process(delta):
	#if global.Camera_follow and leader:
		#o_cam.global_position = o_cam.global_position.lerp(
			#leader.global_position,
			#follow_speed * delta
		#)
	if leader and global.Can_move:
		if leader:
			_mover(delta)
			record_trail()

			var ordered = get_ordered_characters()

			for i in range(1, ordered.size()):
				var follower = ordered[i]
				var distance = get_follower_distance(i)
				move_follower(follower, distance)
	else:
		set_all_idle()

func set_all_idle():
	for character in characters:
		update_animation(character, Vector2.ZERO)

func _mover(_delta):
	var input_vector := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	if input_vector != Vector2.ZERO:
		leader.velocity = input_vector * move_speed
		leader.move_and_slide()
		update_animation(leader, input_vector)
	else:
		leader.velocity = Vector2.ZERO
		update_animation(leader, Vector2.ZERO)

func record_trail():
	if trail.size() == 0 or leader.position.distance_to(last_trail_pos) >= min_trail_spacing:
		trail.append(leader.position)
		last_trail_pos = leader.position

	if trail.size() > max_trail_length:
		trail.pop_front()

func get_follower_distance(follower_index: int) -> int:
	if follower_index - 1 < follower_distances.size():
		return follower_distances[follower_index - 1]
	return follower_distances[-1] + (16 * (follower_index - follower_distances.size()))

func move_follower(follower: Node2D, distance: int):
	if trail.size() > distance:
		var target_pos: Vector2 = trail[trail.size() - distance - 1]
		var direction: Vector2 = (target_pos - follower.position).normalized()

		if follower.position.distance_to(target_pos) > 0.5:
			follower.position = follower.position.move_toward(target_pos, move_speed * get_physics_process_delta_time())
			update_animation(follower, direction)
		else:
			follower.velocity = Vector2.ZERO
			update_animation(follower, Vector2.ZERO)
	else:
		follower.velocity = Vector2.ZERO
		update_animation(follower, Vector2.ZERO)

var last_dominant_axis := {}

func update_animation(character: Node2D, direction: Vector2):
	if not character.has_node("Sprite"):
		return
	
	var anim_sprite := character.get_node("Sprite")
	
	if not last_directions.has(character):
		last_directions[character] = Vector2.DOWN
	if not last_dominant_axis.has(character):
		last_dominant_axis[character] = "y"

	if direction != Vector2.ZERO:
		last_directions[character] = direction

	var last_direction: Vector2 = last_directions[character]

	if direction == Vector2.ZERO:
		if last_dominant_axis[character] == "x":
			anim_sprite.play("IdleRight" if last_direction.x > 0 else "IdleLeft")
		else:
			anim_sprite.play("IdleDown" if last_direction.y > 0 else "IdleUp")
		return

	
	var threshold := 1.2
	var ax = abs(direction.x)
	var ay = abs(direction.y)

	if ax > ay * threshold:
		last_dominant_axis[character] = "x"
	elif ay > ax * threshold:
		last_dominant_axis[character] = "y"
	

	if last_dominant_axis[character] == "x":
		anim_sprite.play("RunRight" if direction.x > 0 else "RunLeft")
	else:
		anim_sprite.play("RunDown" if direction.y > 0 else "RunUp")

func change_leader(new_index: int):
	if new_index >= 0 and new_index < characters.size():
		global.LEADER_INDEX = new_index
		trail.clear()
		last_trail_pos = Vector2.ZERO
		update_party()

func get_leader_position() -> Vector2:
	if leader:
		return leader.global_position
	return Vector2.ZERO

func get_character_by_index(index: int) -> Node2D:
	if index >= 0 and index < characters.size():
		return characters[index]
	return null

func get_follower_target_position(follower_index: int) -> Vector2:
	if follower_index < 1 or follower_index >= characters.size():
		return Vector2.ZERO
	var distance = get_follower_distance(follower_index)
	if trail.size() > distance:
		return trail[trail.size() - distance - 1]
	return Vector2.ZERO

func set_follower_distance(follower_index: int, new_distance: int):
	if follower_index - 1 < follower_distances.size():
		follower_distances[follower_index - 1] = new_distance

func set_move_speed(new_speed: int):
	move_speed = new_speed

func set_min_trail_spacing(new_spacing: float):
	min_trail_spacing = new_spacing

func print_party_info():
	for i in range(characters.size()):
		var character = characters[i]
		var pos = character.global_position
		var distance = get_follower_distance(i) if i > 0 else 0
		print("العضو ", i, ": ", character.name, " | الموقع: ", pos, " | المسافة: ", distance)

func visualize_trail():
	if trail.size() < 2:
		return
	for i in range(1, trail.size()):
		draw_line(trail[i - 1], trail[i], Color.CYAN)
