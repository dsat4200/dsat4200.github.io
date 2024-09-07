extends Control

# Swipe thresholds (in pixels)
const SWIPE_THRESHOLD = 50
const swipefactor = .075
@export var pages: Node2D
# Variables to store touch start position
var touch_start_position = 0

# Enum for swipe direction
enum SwipeDirection {
	LEFT,
	RIGHT
}

# Declare custom signals
signal swipe_left()
signal swipe_right()

func _ready():
	# Initialize any required setup
	pass
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("click"):
		touch_start_position = get_global_mouse_position().x
	elif Input.is_action_pressed("click"):
		var offset = (touch_start_position-get_global_mouse_position().x)*swipefactor
		pages.position.x-=offset
		
	elif Input.is_action_just_released("click"):
		var swipe_distance = (get_global_mouse_position().x-touch_start_position)
		if abs(swipe_distance) > SWIPE_THRESHOLD:
			if swipe_distance > 0:
				_on_swipe(SwipeDirection.RIGHT)
			else:
				_on_swipe(SwipeDirection.LEFT)

func _on_swipe(direction: SwipeDirection):
	match direction:
		SwipeDirection.LEFT:
			emit_signal("swipe_left")
		SwipeDirection.RIGHT:
			emit_signal("swipe_right")
