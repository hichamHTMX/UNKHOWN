extends Node2D

var alpha: float = 0.0
var screen_size: Vector2

func _ready():
	z_index = 999
	screen_size = get_viewport_rect().size

func _process(_delta):
	var camera = get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position()
		queue_redraw()

func _draw():
	var rect_pos = -screen_size / 2.0
	draw_rect(Rect2(rect_pos, screen_size), Color(0, 0, 0, alpha))

func fade_out(duration: float = 1.0):
	global.Can_move = false
	_set_alpha(0.0)
	var tween = create_tween()
	tween.tween_method(_set_alpha, alpha, 1.0, duration)
	await tween.finished
	global.Can_move = true

func fade_in(duration: float = 1.0):
	global.Can_move = false
	_set_alpha(1.0)
	var tween = create_tween()
	tween.tween_method(_set_alpha, alpha, 0.0, duration)
	await tween.finished
	global.Can_move = true

func _set_alpha(value: float):
	alpha = value
