extends Node2D

# CONFIG
@export var MAX_VELOCITY = 20
@export var GRAVITY: float = 1.5
@export var MIN_TIME: float = 1.0
@export var MAX_TIME: float = 10.0

@export var CLICK_THREHOLD: int = 5
@export var CLICK_TIME: float = 1.0

var click_count = 0
var click_timer: Timer

const DRAG_THRESHOLD = 5
const BOUNCE_DAMPING = 0.5
const FRICTION = 0.9
const SETTLE_VELOCITY = 0.5

# Define the State of mode the Sprite
enum State {
	WALKING,
	CHILLING,
	DRAGGING,
	THROWN
}

# @export var random_anim = ["sneeze"]

var drag_offset: Vector2i = Vector2i.ZERO # distance of mouse click from right corner window
var drag_start_pos: Vector2i = Vector2i.ZERO
var velocity: Vector2 = Vector2.ZERO
var last_mouse_pos: Vector2i = Vector2i.ZERO

var state: State = State.WALKING

var move_speed: int = 1
var direction: Vector2 = Vector2(1, 0) # Move Right
var is_chilling: bool = false

var texture
var image

@onready var area = $Area2D
@onready var anim = $AnimatedSprite2D
@onready var soundfx = $Hi

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Get access to the actual OS Window
	var window = get_window()
	
	texture = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	image = texture.get_image()

	#Transparent Setup
	get_viewport().transparent_bg = true
	window.transparent = true

	# Window Shape
	window.borderless = true

	# Keep above yout web browser
	window.always_on_top = true

	# Force to can't resize
	window.unresizable = false

	# Find the floor / taskbar
	# Get the safe area of the screen (minus taskbar)
	var usable_rect = DisplayServer.screen_get_usable_rect()

	# Calculate the floor position
	# end.y is pixel coordinate the taskbar start.
	# subtract window height to make slime on the line, no under.
	var target_y = usable_rect.end.y - window.size.y

	# Move the slime there
	# 	x = 0 (left edge), y = target_y (The taskbar/floor)
	window.position = Vector2i(0, target_y)

	# This Code not working on linux wayland
	# Run once at start
	# _update_mouse_mask()
	#Update every time animation changes
	# $AnimatedSprite2D.frame_changed.connect(_update_mouse_mask)

	area.input_event.connect(_on_area_input)

	anim.play("walk")

	_random_animation()

	click_timer = Timer.new()
	click_timer.wait_time = CLICK_TIME
	click_timer.one_shot = true
	click_timer.timeout.connect(_on_click_timer_timeout)
	add_child(click_timer)


func _process(_delta: float):
	# If are chilling, we hit 'return'
	# if state == State.CHILLING: return
	# _process_walking()
	match state:
		State.WALKING:
			_process_walking()
		State.CHILLING:
			pass
		State.DRAGGING:
			_process_dragging()
			pass
		State.THROWN:
			_process_thrown()
			pass


func _process_walking():
	# Get the window
	var window = get_window()

	# Vector2i used interger with Vector2 for the monitor pixel
	# Calculate the move
	var move_vector = Vector2i(direction * move_speed)

	# Apply to Os Window
	window.position += move_vector

	# Safe Zone
	# screen_get_usable_rect() return the screen Minus the taskbar/dock
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()

	# Check right and left edge
	if window.position.x + window.size.x > usable_rect.end.x:
		direction.x = -1 # Reverse direction
		anim.flip_h = true # flip visual
	elif window.position.x < usable_rect.position.x:
		direction.x = 1
		anim.flip_h = false


func _process_dragging():
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("Mouse terlepas")
		_end_dragging()
		return

	var window = get_window()
	var mouse_pos = DisplayServer.mouse_get_position()

	var new_positionn = mouse_pos - drag_offset

	velocity = Vector2(mouse_pos - last_mouse_pos)
	last_mouse_pos = mouse_pos

	window.position = new_positionn
	print(velocity)


func _process_thrown():
	var window = get_window()
	var usable_rect = DisplayServer.screen_get_usable_rect()

	velocity.y += GRAVITY

	velocity = velocity.limit_length(MAX_VELOCITY)

	window.position += Vector2i(velocity)

	if velocity.y < 0:
		anim.play("thrownUp")
	else:
		anim.play("thrownDown")

	var floor_y = usable_rect.end.y - window.size.y

	if window.position.y >= floor_y:
		# window.position.y = floor_y
		# if abs(velocity.y) > 1.0:
			# velocity.y = - velocity.y * BOUNCE_DAMPING
			# velocity.x *= FRICTION
		# else:
		velocity.y = 0
		velocity.x = 0

	if window.position.x + window.size.x > usable_rect.end.x:
		window.position.x = usable_rect.end.x - window.size.x
		velocity.x = - velocity.x * BOUNCE_DAMPING
	elif window.position.x < usable_rect.position.x:
		window.position.x = usable_rect.position.x
		velocity.x = - velocity.x * BOUNCE_DAMPING

	var on_floor = window.position.y >= floor_y - 1
	if on_floor and velocity.length() < SETTLE_VELOCITY:
		velocity = Vector2.ZERO
		state = State.WALKING
		anim.play("walk")


#  Inputhandling for clicking the sprite
func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# _register_click()
			_start_dragging()
			# start_chilling()
		else:
			_end_dragging()


func _start_dragging():
	if state == State.CHILLING: return
	
	var window = get_window()
	var mouse_pos = DisplayServer.mouse_get_position()

	drag_offset = mouse_pos - window.position
	drag_start_pos = mouse_pos
	last_mouse_pos = mouse_pos
	velocity = Vector2.ZERO

	state = State.DRAGGING

	anim.play("short_grab")

	await get_tree().create_timer(1).timeout

	if state == State.DRAGGING:
		anim.play("long_grab")


# func _end_dragging():
# 	_register_click()

	# if state != State.DRAGGING: return

	# var mouse_pos = DisplayServer.mouse_get_position()
	# var moved_distance = mouse_pos.distance_to(drag_start_pos)

	# if moved_distance < DRAG_THRESHOLD:
	# 	state = State.WALKING
	# 	start_chilling()
	# else:
	# 	state = State.THROWN
		# anim.play("thrown")

		# print(last_mouse_pos.x - mouse_pos.x)
		# if last_mouse_pos.x - mouse_pos.x > 0:
		# 	anim.play("thrownX")
		# elif last_mouse_pos.x - mouse_pos.x < 0:
		# 	anim.play("thrownXFlip")
		# else:
		# 	anim.play("thrownUp")

		# print("start: ", drag_start_pos, ", end: ", mouse_pos, "calculate: ", drag_start_pos - mouse_pos)

func _random_animation():
	while true:
		var wait_time = randf_range(MIN_TIME, MAX_TIME)

		print(wait_time)

		await get_tree().create_timer(wait_time).timeout

		if state == State.WALKING:
			state = State.CHILLING
			
			# Used if animation quite a lot
			# var rand_anim = random_anim[randi() % random_anim.size()]

			anim.play("sneeze")

			await anim.animation_finished

			state = State.WALKING
			anim.play("walk")


func _on_click_timer_timeout() -> void:
	click_count = 0

	if click_count < CLICK_THREHOLD:
		start_chilling()


func _end_dragging() -> void:
	if state != State.DRAGGING: return

	var mouse_pos = DisplayServer.mouse_get_position()
	var moved_distance = mouse_pos.distance_to(drag_start_pos)

	click_count += 1
	click_timer.start()

	if moved_distance < DRAG_THRESHOLD:
		state = State.WALKING

		if click_count >= CLICK_THREHOLD:
			click_count = 0
			click_timer.stop()
			_on_multi_click_triggered()
		else:
			anim.play("walk")
	else:
		state = State.THROWN
		click_count = 0
		click_timer.stop()


func _on_multi_click_triggered() -> void:
	print("[Multi CLick Function Log] Multi click triggered!")

	if state != State.CHILLING and state != State.THROWN:
		state = State.CHILLING
		anim.play("multi_click")
		await anim.animation_finished
		state = State.WALKING
		anim.play("walk")


# This function not working on linux wayland
# func _update_mouse_mask():
# 	# Get the raw image data of the Current frame
# 	anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
# 	texture.get_image()

# 	# Manually flip the sprite while the image visual uncorrect.
# 	if anim.flip_h:
# 		image.flip_x()

# 	# Create the Bitmap (The Map of solid pixels)
# 	var bitmap = BitMap.new()
# 	bitmap.create_from_image_alpha(image, 0.1)

# 	# Create the Polygon
# 	# 0.1 = ignore fully transparent pixels
# 	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, texture.get_size()))

# 	# Apply to the OS Window
# 	if polygons.size() > 0:
# 		DisplayServer.window_set_mouse_passthrough(polygons[0])

func start_chilling():
	state = State.CHILLING
	anim.play("idle")

	# await get_tree().create_timer(3).timeout
	await anim.animation_finished

	state = State.WALKING
	anim.play("walk")
