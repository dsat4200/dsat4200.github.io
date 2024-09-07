extends Node2D

# Speed at which the node moves horizontally
var move_speed: float = DisplayServer.screen_get_size().x
var interpolation_speed: float = 7.5
@export var page :int = 0
@export var start_page : int
@onready var page_label = $page_label
@onready var pages_node = $pages
@export var page_sprites : SpriteFrames
# Target position for smooth interpolation
var target_position: Vector2

func _ready():
	# Initialize the target position to the current position
	target_position = pages_node.position
	initialize_pages()
	
func initialize_pages():
	if start_page == 0: return
	elif start_page == 1 or start_page ==2:
		var t_page = start_page
		start_page = 0
		move_page(t_page*2)
	elif start_page >= 3:
		for i in range(pages_node.get_child_count()):
			var child = pages_node.get_child(i)
			child.texture = page_sprites.get_frame_texture("default",i+start_page-2)
			child.name = "pg"+str(i+start_page-2)
			
func _input(event):
	# Check if the input event is a mouse wheel event
	if event.is_action_pressed("close"):
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.is_action_pressed("scroll_up"):
			pass
			move_page(-1)
		elif event.is_action_pressed("scroll_down"):
			pass
			move_page(1)
			
func move_page(delta):
	if (delta < 0) and ((page + start_page) < 1):
		return
	if (delta > 0) and ((page + start_page) > page_sprites.get_frame_count("ch1")-2):
		return
	if (delta != 0):
		target_position.x += move_speed*-delta
		page+=delta
			
		if (delta > 0):
			var node = Sprite2D.new()	
			var name = "pg"+str(page+start_page+2)
			var result = page+start_page
			#print(str(result))
			if pages_node.has_node(name):
				return
			node.set_name(name)
			#print("pg"+str(result)+": "+ str(pages_node.global_position))
			#print(node.name)
			pages_node.add_child(node)
			node.global_position=pages_node.global_position
			node.global_position.x+=1920*(page+2)
			node.texture = page_sprites.get_frame_texture("ch1",result+2)
			#print(node.name+": "+ str(node.global_position))
	
		if (delta < 0):
			var node = Sprite2D.new()	
			var name = "pg"+str(page+start_page-2)
			var result = page+start_page
			if pages_node.has_node(name):
				return
			node.set_name(name)
			#print("pg"+str(result)+": "+ str(pages_node.global_position))
			#print(node.name)
			var node_pos = get_first_node().position.x
			pages_node.add_child(node)
			pages_node.move_child(node,0)
			node.position.x= node_pos - 1920
			node.texture = page_sprites.get_frame_texture("ch1",result-2)
			print_children_positions()
			#print(node.name+": "+ str(node.global_position))

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
			

func get_first_node() -> Sprite2D:
	return pages_node.get_child(0)

	
func _process(delta):
	page_label.text = "Page: " + str(page) + " StartPage: "+ str(start_page) + " Result: " + str(page+start_page)
	# Smoothly interpolate the node's position towards the target position
	pages_node.position = pages_node.position.lerp(target_position, interpolation_speed * delta)
