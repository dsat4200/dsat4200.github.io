@tool
extends TextureRect # The base node is TextureRect, so we use self_modulate for color.
class_name PathPointMarker

# This resource holds the custom data (speed, zoom, etc.) for this point.
# It's automatically populated by the main control script.
@export var point_data: PathPointData
@export var speaker: Sprite2D
@export var container: Control
@export var base_size: Vector2 = Vector2(256,256)
@export var spd_label: Label # Assuming this is a standard Godot Label node
@export var zoom_label: Label
# Define the speed range for mapping to the gradient.
# You'll need to adjust these values based on your expected speed range.
@export var min_speed: float = 0.0
@export var max_speed: float = 4.0 # Adjust this to your maximum expected speed

# Define the specific speed value that will map to the 'mid_hue'.
# A change from 1.0 to 0.0 will be as drastic as 1.0 to 4.0 in terms of hue interpolation.
@export var hue_midpoint_speed: float = 1.0

# Define the hue values for the gradient.
# Hue 0.0 is Red, Hue 0.333 is Green, Hue 0.5 is Cyan, Hue 0.666 is Blue.
@export_range(0.0, 1.0, 0.01) var start_hue: float = 0.5 # Coolest color (e.g., Cyan/Green-Blue for speed = min_speed)
@export_range(0.0, 1.0, 0.01) var mid_hue: float = 0.15 # Midpoint color (e.g., Yellow/Orange for speed = hue_midpoint_speed)
@export_range(0.0, 1.0, 0.01) var end_hue: float = 0.0 # Warmest color (e.g., Red for speed = max_speed)

# Saturation and Value (brightness) for the gradient.
# Keep these constant for a gradient that primarily changes hue.
@export_range(0.0, 1.0, 0.01) var gradient_saturation: float = 1.0 # Full saturation
@export_range(0.0, 1.0, 0.01) var gradient_value: float = 1.0 # Full brightness

func appear():
	update_info()
	container.show()
	
func disappear():
	container.hide()
	
func update_info():
	#print("updating!")
	if point_data:
		#size = base_size / point_data.zoom
		if point_data.sound_effect:
			speaker.show()
		else:
			speaker.hide() # Ensure speaker is hidden if no sound effect
		# Update color based on speed using hue interpolation
		update_color_from_speed_hue()
		
		spd_label.text = "S: %.2f" % [point_data.speed]
		zoom_label.text = "Z: %.2f" % [point_data.zoom]
	
func _ready():
	if !Engine.is_editor_hint():
		hide()
	size = base_size
	# In the editor, it's crucial to ensure the data resource exists.
	if not is_instance_valid(point_data):
		point_data = PathPointData.new()
	update_info() # Call update_info after ensuring point_data exists

# Function to update the TextureRect's color based on speed by interpolating hue
func update_color_from_speed_hue():
	if point_data:
		var current_speed = point_data.speed
		var current_hue: float
		
		# Ensure current_speed is clamped within the overall min_speed and max_speed
		current_speed = clampf(current_speed, min_speed, max_speed)
		
		if current_speed <= hue_midpoint_speed:
			# Speed is in the first segment: from min_speed to hue_midpoint_speed
			# Normalize this segment to a 0.0 - 1.0 range
			var normalized_segment_speed = inverse_lerp(min_speed, hue_midpoint_speed, current_speed)
			# Interpolate hue from start_hue to mid_hue
			current_hue = lerp(start_hue, mid_hue, normalized_segment_speed)
		else: # current_speed > hue_midpoint_speed
			# Speed is in the second segment: from hue_midpoint_speed to max_speed
			# Normalize this segment to a 0.0 - 1.0 range
			var normalized_segment_speed = inverse_lerp(hue_midpoint_speed, max_speed, current_speed)
			# Interpolate hue from mid_hue to end_hue
			current_hue = lerp(mid_hue, end_hue, normalized_segment_speed)
		
		# Create the color from HSV components
		# Note: Godot's Color.from_hsv expects hue, saturation, value all in 0.0-1.0 range
		self_modulate = Color.from_hsv(current_hue, gradient_saturation, gradient_value)


# This function is called by the main control script to keep the label text updated.
func update_info_text(pos: Vector2):
	pass # pos_label is not used in this function as per your script.
