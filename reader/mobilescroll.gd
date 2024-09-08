extends Node2D

# Speed at which the node moves horizontally
var image_offset:float = 960
const DEFAULT_INTERPOLATION = 7.5
const MOBILE_INTERPOLATION = 30
const SCROLL_INTERPOLATION = 5
var interpolation_speed: float = 30


@export var page :int = 0
@export var start_page : int
var increment:int = 4
var last_spawned_page = 3
@onready var page_label = $Control/page_label
@onready var pages_node = $pages
@export var page_sprites : SpriteFrames
var target_position: Vector2
var smooth_scroll = true

@export var newestPage : int

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

func move_to_page(target):
	var x_cord = (-target*960)+512
	spawn_next_page(target-page)
	#page = int(((512-target_position.x)/960))
	target_position.x = x_cord
	print("moving from page " + str(page) + " to page! "+str(target))
	print(str(target - page))
	
	
func _ready():
	# Initialize the target position to the current position
	target_position = pages_node.position
	move_n_pages(start_page)
	


func move_n_pages(inc):
	for n in inc:
		move_page(1)
		check_spawn()
			
func _input(event):
	# Check if the input event is a mouse wheel event
	if event.is_action_pressed("close"):
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.is_action_pressed("scroll_up"):
			if (!smooth_scroll):
				move_page(-1)
			else:
				smooth_scroll_wheel(-1)
			
		elif event.is_action_pressed("scroll_down"):
			if (!smooth_scroll):
				move_page(1)
			else:
				smooth_scroll_wheel(1)
			
func move_page(delta):
	if (delta < 0) and (page <1):
		return
	if (delta > 0) and (page > page_sprites.get_frame_count("ch1")-3):
		return
	elif (delta != 0 ):
		target_position.x += (image_offset)*-delta
		page+=delta

func print_children_positions():
	# Iterate through each child node
	for i in range(pages_node.get_child_count()):
		# Get the child node
		var child = pages_node.get_child(i)
		
		# Check if the child node is a Node2D (or another type with a position property)
		if child is Node2D:
			# Print the position of the child node
			print(i, ": "+ child.name+ " position: ", child.position)
		else:
			print("Child ", i, " is not a Node2D and has no position property.")
	#print("/n")
			

func spawn_next_page(delta):
	for n in range(int(delta)):
		#print("delta n"+ str(n))
		var node = Sprite2D.new()	
		var name = "pg"+str(page+start_page+n)
		if pages_node.has_node(name):
			continue
		node.set_name(name)
		var node_pos = get_last_node().position.x
		pages_node.add_child(node)
		pages_node.move_child(node,-1)
		node.position.x= node_pos + (image_offset)
		node.texture = page_sprites.get_frame_texture("ch1",page+n)
		last_spawned_page = page+start_page+n
func get_first_node() -> Sprite2D:
	return pages_node.get_child(0)
	
func get_last_node() -> Sprite2D:
	return pages_node.get_child(-1)

	
func _process(delta):
	get_page()
	page_label.text = "Page: " + str(page)
	pages_node.position.x = (pages_node.position.slerp(target_position, interpolation_speed * delta)).x
	if (smooth_scroll):
		smooth_scroll_process()
	elif Input.is_action_just_pressed("click"):
		touch_start_position = get_global_mouse_position().x
	elif Input.is_action_pressed("click"):
		var offset = (touch_start_position-get_global_mouse_position().x)*swipefactor
		pages_node.position.x-=offset
	elif Input.is_action_just_released("click"):
		var swipe_distance = (get_global_mouse_position().x-touch_start_position)
		if abs(swipe_distance) > SWIPE_THRESHOLD:
			if swipe_distance > 0:
				_on_swipe(SwipeDirection.RIGHT)
			else:
				_on_swipe(SwipeDirection.LEFT)
				
func smooth_scroll_wheel(delta):
	interpolation_speed = SCROLL_INTERPOLATION
	var scrollamount = image_offset/6
	target_position.x-= scrollamount*delta


var swipeamount
func smooth_scroll_process():
	if Input.is_action_just_pressed("click"):
		touch_start_position = get_global_mouse_position().x
		interpolation_speed = MOBILE_INTERPOLATION
	elif Input.is_action_pressed("click"):
		swipeamount = touch_start_position - get_global_mouse_position().x 
		target_position.x-= swipeamount
		touch_start_position = get_global_mouse_position().x
	elif Input.is_action_just_released("click"):
		interpolation_speed=MOBILE_INTERPOLATION/4
		target_position.x-=swipeamount*4
func snap_to_nearest_page():
	target_position.x = 512
	for n in page:
		target_position.x -= (image_offset)
	
func get_page():
	page = int(((512-target_position.x)/960))
	check_spawn()

func check_spawn():
	if (last_spawned_page < (page + increment)):
		spawn_next_page(increment+1)
		print (str(last_spawned_page) +" < "+ str(page) +" + "+ str(increment) )
		#print_children_positions()
		
	
func _on_swipe(direction: SwipeDirection):
	match direction:
		SwipeDirection.LEFT:
			move_page(1)
		SwipeDirection.RIGHT:
			move_page(-1)

			

func _on_rightbutton_button_up() -> void:
	move_page(1)


func _on_leftbutton_button_up() -> void:
	move_page(-1)



func _on_line_edit_text_submitted(new_text: String) -> void:
	move_to_page(int($Control/LineEdit.text))


func _on_control_swipe_left() -> void:
	move_page(1)


func _on_control_swipe_right() -> void:
	move_page(-1)


func _on_button_toggled(toggled_on: bool) -> void:
	smooth_scroll = toggled_on
	if (toggled_on == true):
		interpolation_speed = MOBILE_INTERPOLATION
	if (toggled_on == false):
		interpolation_speed = DEFAULT_INTERPOLATION
		snap_to_nearest_page()


func _on_newest_page_button_pressed() -> void:
	move_to_page(newestPage)
