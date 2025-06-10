@tool
extends Node3D
class_name PathPointMarker3D

# This resource holds the custom data (speed, zoom, etc.) for this point.
# It's automatically populated by the main control script.
@export var point_data: PathPointData
@export var integer: int

func appear():
	show()
	
func disappear():
	hide()
	
func update_info():
	pass
	
func _ready():
	#print("ready")
	# Ensure the label is hidden by default when the scene starts.
	update_info()
	# In the editor, it's crucial to ensure the data resource exists.
	if not is_instance_valid(point_data):
		point_data = PathPointData.new()
