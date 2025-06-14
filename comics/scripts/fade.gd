extends CanvasItem
class_name FadeInSprite

## The number of frames the fade-in animation should take.
## You can set this value in the Inspector tab in the Godot editor.
@export_range(1, 300, 1, "suffix:frames") var fade_duration_frames: int = 60
var _is_fading_in: bool = false
var _current_fade_frame: int = 0


func _ready() -> void:
	# Connect the 'visibility_changed' signal to our custom function.
	# This will automatically call _on_visibility_changed() whenever the
	# sprite's visibility is toggled.
	visibility_changed.connect(_on_visibility_changed)
	
	# Manually call the function once at the start.
	# This ensures the fade-in effect runs if the sprite is already
	# set to be visible when the scene loads.
	_on_visibility_changed()


# This function is called every frame. We use it to update the alpha value.
func _process(delta: float) -> void:
	# If we are not currently in the fading process, do nothing.
	if not _is_fading_in:
		return

	# Increment the frame counter for the fade animation.
	_current_fade_frame += 1

	# Calculate the new alpha value. This is a ratio of the current frame
	# to the total duration. We use clamp() to make sure the value stays
	# between 0.0 and 1.0.
	var new_alpha = clamp(float(_current_fade_frame) / fade_duration_frames, 0.0, 1.0)
	
	# Apply the new alpha value to the sprite's modulate property.
	# The 'modulate' property tints the sprite's color. By changing only the
	# alpha component ('a'), we can control its transparency.
	modulate.a = new_alpha

	# If the animation has completed (current frame is greater than or
	# equal to the duration), we stop the fading process.
	if _current_fade_frame >= fade_duration_frames:
		_is_fading_in = false


# This function is called whenever the sprite's 'visible' property changes.
func _on_visibility_changed() -> void:
	if visible:
		# If the sprite just became visible, start the fade-in process.
		_is_fading_in = true
		_current_fade_frame = 0
		
		# Immediately set the sprite to be fully transparent so it can fade in.
		# This prevents the sprite from "popping" into view for one frame
		# before the fade begins.
		modulate.a = 0.0
	else:
		# If the sprite became hidden, stop any ongoing fade process.
		_is_fading_in = false
