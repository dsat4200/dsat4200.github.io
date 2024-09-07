extends Node2D

# Speed at which the node moves horizontally
var image_offset:float = 960
var interpolation_speed: float = 7.5
@export var page :int = 0
@export var start_page : int
@onready var page_label = $Control/page_label
@onready var pages_node = $pages
@export var page_sprites : SpriteFrames
var desktop = true
# Target position for smooth interpolation
var target_position: Vector2
var smooth_scroll = false

func move_to_page(target):
	var move = 1
	if (target < page):
		move = -1
	for n in (abs(target - page)):
		move_page(move)
	
func _ready():
	# Initialize the target position to the current position
	target_position = pages_node.position
	initialize_pages()
	

func initialize_pages():
	for n in start_page:
		move_page(1)
			
func _input(event):
	# Check if the input event is a mouse wheel event
	if event.is_action_pressed("close"):
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.is_action_pressed("scroll_up"):
			if (!smooth_scroll):
				move_page(-1)
			else:
				pass
			
		elif event.is_action_pressed("scroll_down"):
			if (!smooth_scroll):
				move_page(1)
			else:
				pass
			
func move_page(delta):
	if (delta < 0) and (page <1):
		return
	if (delta > 0) and (page > page_sprites.get_frame_count("ch1")-3):
		return
	elif (delta != 0 ):
		target_position.x += (image_offset)*-delta
		page+=delta
		if (delta > 0):
			spawn_next_page((delta))
		if (desktop==true):
			spawn_next_page((delta+1))

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
	print("/n")
			

func spawn_next_page(delta):
	var node = Sprite2D.new()	
	var name = "pg"+str(page+start_page+delta)
	if pages_node.has_node(name):
		return
	node.set_name(name)
	var node_pos = get_last_node().position.x
	pages_node.add_child(node)
	pages_node.move_child(node,-1)
	node.position.x= node_pos + (image_offset)
	node.texture = page_sprites.get_frame_texture("ch1",page+delta)

func get_first_node() -> Sprite2D:
	return pages_node.get_child(0)
	
func get_last_node() -> Sprite2D:
	return pages_node.get_child(-1)

	
func _process(delta):
	page_label.text = "Page: " + str(page) + " StartPage: "+ str(start_page)
	pages_node.position = pages_node.position.lerp(target_position, interpolation_speed * delta)


			

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
