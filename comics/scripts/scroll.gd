@tool
extends PathFollow2D
class_name PathReader

# --- MOVEMENT & INPUT ---
@export var speed_multiplier: float = 100.0
@export var deceleration_rate: float = 0.95
@export var min_swipe_velocity_threshold: float = 5.0
@export var scroll_speed: float = 50.0
@export var scroll_decay_rate = 0.05   
@export var TOUCHPAD_VELOCITY:float = 1.0
var _scroll_target_progress = 0.0


# --- CAMERA & DATA ---
## Assign the Control node that manages the PathPointLabel nodes.
@export var data_source_control_path: NodePath
@export var base_zoom: float = 1.0

# --- INTERNAL STATE ---
var is_swiping: bool = false
var last_touch_pos: Vector2
var current_velocity: float = 0.0

var path_length: float = 0.0
var _point_distances: PackedFloat64Array = []

var current_target_speed: float = 1.0
var smooth_current_speed: float = 1.0

var last_passed_point_index: int = -1
var last_curve_point_count: int = 0

# --- NODE REFERENCES ---
var camera_2d_node: Camera2D
var parent_path_2d: Path2D
var data_source_control: Control
var audio_stream_player: AudioStreamPlayer
var managed_node_paths: Array[NodePath] = []


var progress_change = 0.0
var scroll_smoothing_factor = 0.1
		 # creating a "momentum" effect. Adjust as needed.


func _ready():
	print(progress)
	# This function now handles all initial setup.
	_initialize_node_references()
	_apply_current_zoom()

	# Create an AudioStreamPlayer for sound effects
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	
	# Ensures the correct nodes are visible/hidden at the starting position.

	
	if parent_path_2d and parent_path_2d.curve:
		var start_point_index = _get_closest_point_index(parent_path_2d.curve, 0)
		_update_node_visibility(start_point_index)

func _process(delta):
	# In the editor, check if the path's point count has changed.
	if Engine.is_editor_hint():
		if parent_path_2d and parent_path_2d.curve:
			if parent_path_2d.curve.get_point_count() != last_curve_point_count:
				# If it has, re-sync path distances and managed nodes.
				_on_path_changed()
		
		return
	else:
		#print(progress)
		smooth_scroll(delta)
	_apply_current_zoom()

	# --- RUNTIME LOGIC ---
	var current_point_index = -1
	if parent_path_2d and parent_path_2d.curve:
		current_point_index = _get_closest_point_index(parent_path_2d.curve, self.progress / path_length)
	
	if current_point_index != -1:
		# --- SOUND EFFECT LOGIC ---
		if current_point_index != last_passed_point_index:
			last_passed_point_index = current_point_index
			var data = _get_point_data_for_index(current_point_index)
			if data and data.sound_effect:
				audio_stream_player.stream = data.sound_effect
				audio_stream_player.play()

		# --- NODE VISIBILITY LOGIC ---
		_update_node_visibility(current_point_index)
		
		# --- SPEED LOGIC ---
		var data_for_speed: PathPointData = _get_point_data_for_index(current_point_index)
		current_target_speed = data_for_speed.speed if data_for_speed else 1.0

	smooth_current_speed = lerp(smooth_current_speed, current_target_speed, 0.1)

	# Apply coasting momentum if not actively swiping/panning
	if not is_swiping and abs(current_velocity) > 0:
		current_velocity = lerp(current_velocity, 0.0, 1.0 - deceleration_rate)
		var delta_progress = current_velocity * smooth_current_speed
		self.progress = clamp(self.progress + delta_progress, 0, path_length)
		
		if abs(current_velocity) < min_swipe_velocity_threshold:
			current_velocity = 0.0
		
		_apply_current_zoom()


func _input(event):
	if Engine.is_editor_hint(): return

	var path_node_runtime = get_parent() as Path2D
	if not path_node_runtime or not path_node_runtime.curve: return

	var handled = false

	if event is InputEventPanGesture:
		# Invert delta.y for "natural" trackpad scrolling
		progress_change = -event.delta.y * speed_multiplier * TOUCHPAD_VELOCITY
		current_velocity = progress_change # Store raw velocity for coasting
		is_swiping = false # Ensure touch swipe flags are reset
		handled = true
		
	# --- MOUSE SCROLL INPUT ---
	
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_target_progress += scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_target_progress -= scroll_speed
		# If the scroll wheel is moved up
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Subtract from the target value for upward scrolling.
			_scroll_target_progress -= scroll_speed

		
	# --- TOUCHSCREEN DRAG/SWIPE ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_swiping = true
			last_touch_pos = event.position
			current_velocity = 0.0
		else:
			is_swiping = false
		handled = true
			
	elif event is InputEventScreenDrag and is_swiping:
		var delta_pos = event.position - last_touch_pos
		progress_change = delta_pos.y * speed_multiplier
		current_velocity = progress_change
		last_touch_pos = event.position
		handled = true

	if handled and progress_change != 0.0:
		self.progress = clamp(self.progress + (progress_change * smooth_current_speed), 0, path_length)
		_apply_current_zoom()
		get_viewport().set_input_as_handled()

### CORE LOGIC & HELPER FUNCTIONS ###
func smooth_scroll(delta: float) -> void:
	progress_change = lerp(progress_change, _scroll_target_progress, scroll_smoothing_factor)

	if abs(_scroll_target_progress) > 0.01:
		_scroll_target_progress = lerp(_scroll_target_progress, 0.0, scroll_decay_rate)
	else:
		_scroll_target_progress = 0.0
	self.progress = clamp(self.progress + (progress_change * smooth_current_speed), 0, path_length)
		
func _initialize_node_references():
	"""Get references to all required nodes and initialize path data."""
	# Get the Path2D parent
	parent_path_2d = get_parent() as Path2D
	if not parent_path_2d:
		push_warning("This node is not a child of a Path2D.")
		return

	# Get the Control node that holds the data
	data_source_control = get_node_or_null(data_source_control_path)
	if not data_source_control:
		push_warning("Data Source Control node not assigned or found.")

	# Get the Camera2D
	if get_viewport():
		camera_2d_node = get_viewport().get_camera_2d()
	if not camera_2d_node and not Engine.is_editor_hint():
		push_warning("No Camera2D found in the viewport.")
	
	# Initial setup of path-dependent data
	_on_path_changed()

func _on_path_changed():
	"""
	Called when the script starts or when the path's point count changes.
	Recalculates distances and rebuilds the list of managed nodes.
	"""
	if not parent_path_2d or not parent_path_2d.curve: return
	
	path_length = parent_path_2d.curve.get_baked_length()
	last_curve_point_count = parent_path_2d.curve.get_point_count()
	
	_update_path_distances()
	_update_managed_nodes_list()

func _update_path_distances():
	"""Caches the distance from the start of the path to each point."""
	if not parent_path_2d or not parent_path_2d.curve: return
	
	var curve = parent_path_2d.curve
	var point_count = curve.get_point_count()
	_point_distances.resize(point_count)
	
	for i in range(point_count):
		var point_pos = curve.get_point_position(i)
		_point_distances[i] = curve.get_closest_offset(point_pos)

func _get_point_data_for_index(index: int) -> PathPointData:
	"""
	Retrieves the PathPointData resource for a given point index
	by looking up the corresponding PathPointMarker instance on the control node.
	"""
	if not is_instance_valid(data_source_control):
		return null

	# Get all children that are markers from the control node.
	var markers = []
	for child in data_source_control.get_children():
		# --- THIS IS THE IMPORTANT CHANGE ---
		# Look for the new marker script instead of the old label script.
		if child.get_script() and "PathPointMarker.gd" in child.get_script().resource_path:
			markers.append(child)

	# Check if the index is valid and return the data from the marker's property.
	if index >= 0 and index < markers.size():
		if "point_data" in markers[index]:
			return markers[index].point_data
			
	return null
	
func _apply_current_zoom():
	"""Calculates and applies the camera zoom by interpolating between points."""
	if not camera_2d_node or not parent_path_2d or not parent_path_2d.curve: return

	var curve = parent_path_2d.curve
	if curve.get_point_count() < 1:
		camera_2d_node.zoom = Vector2(base_zoom, base_zoom)
		return

	var segment_info = _get_segment_info_at_progress(self.progress)
	var prev_data = _get_point_data_for_index(segment_info.prev_point_index)
	var next_data = _get_point_data_for_index(segment_info.next_point_index)

		
	var zoom_a = prev_data.zoom if prev_data else 1.0
	var zoom_b = next_data.zoom if next_data else 1.0

	var t = segment_info.segment_progress
	var smoothed_t = t * t * (3.0 - 2.0 * t) # Smoothstep interpolation
	var calculated_zoom = lerp(zoom_a, zoom_b, smoothed_t)
	print(calculated_zoom)
	camera_2d_node.zoom = Vector2(calculated_zoom * base_zoom, calculated_zoom * base_zoom)

func _update_managed_nodes_list():
	"""Scans all data points to build a unique list of nodes to show/hide."""
	managed_node_paths.clear()
	if not parent_path_2d or not parent_path_2d.curve: return

	var point_count = parent_path_2d.curve.get_point_count()
	for i in range(point_count):
		var data = _get_point_data_for_index(i)
		if data and data.target_node and not data.target_node.is_empty():
			if not managed_node_paths.has(data.target_node):
				managed_node_paths.append(data.target_node)

func _update_node_visibility(current_point_index: int):
	"""Shows the node for the current point and hides all others."""
	var current_point_data = _get_point_data_for_index(current_point_index)
	if not current_point_data: return

	var active_node_path = current_point_data.target_node
	var should_show = current_point_data.show_target_node

	for path in managed_node_paths:
		var node = get_node_or_null(path)
		if node is CanvasItem:
			node.visible = (path == active_node_path and should_show)
			
# (The rest of your utility functions like _get_segment_info_at_progress and 
# _get_closest_point_index remain the same and are correct)

func _get_segment_info_at_progress(current_dist: float) -> Dictionary:
	if _point_distances.size() < 2:
		return {"prev_point_index": 0, "next_point_index": 0, "segment_progress": 0.0}

	for i in range(_point_distances.size() - 1):
		var dist_a = _point_distances[i]
		var dist_b = _point_distances[i+1]
		
		if current_dist >= dist_a and current_dist <= dist_b:
			var segment_length = dist_b - dist_a
			if segment_length < 0.001:
				return {"prev_point_index": i, "next_point_index": i, "segment_progress": 0.0}
			
			var progress_into_segment = current_dist - dist_a
			var t = progress_into_segment / segment_length
			return {"prev_point_index": i, "next_point_index": i + 1, "segment_progress": t}
	
	if current_dist < _point_distances[0]:
		return {"prev_point_index": 0, "next_point_index": 0, "segment_progress": 0.0}
	else:
		var last_index = _point_distances.size() - 1
		return {"prev_point_index": last_index, "next_point_index": last_index, "segment_progress": 1.0}

func _get_closest_point_index(curve: Curve2D, progress_ratio: float) -> int:
	if not curve or curve.get_point_count() == 0 or _point_distances.is_empty():
		return -1

	var target_progress_dist = progress_ratio * curve.get_baked_length()

	# Iterate backwards to find the last point we've passed
	for i in range(_point_distances.size() - 1, -1, -1):
		if target_progress_dist >= _point_distances[i]:
			return i
	
	return 0 # Default to the first point if before it
