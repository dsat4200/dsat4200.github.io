@tool
extends ColorRect
class_name PathPointMarker

# This resource holds the custom data (speed, zoom, etc.) for this point.
# It's automatically populated by the main control script.
@export var point_data: PathPointData
@export var container:ColorRect
@export var pos_label: Label
@export var spd_label: Label


func appear():
	container.show()
	
func disappear():
	container.hide()
	
func update_info():
	update_info_text(position)
	
func _ready():
	#print("ready")
	# Ensure the label is hidden by default when the scene starts.
	update_info()
	# In the editor, it's crucial to ensure the data resource exists.
	if not is_instance_valid(point_data):
		point_data = PathPointData.new()


# This function is called by the main control script to keep the label text updated.
func update_info_text(pos: Vector2):
	pos_label.text = "Pos: (%d, %d)" % [int(pos.x), int(pos.y)]
	spd_label.text = "Speed: %.2f" % [point_data.speed]
