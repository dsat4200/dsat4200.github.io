@tool
extends PathFollow2D

@export var speed_multiplier: float = 100.0 # Used for touch drag and trackpad pan sensitivity
@export var deceleration_rate: float = 0.95
@export var base_zoom: float = 1.0
@export var min_swipe_velocity_threshold: float = 5.0
@export var scroll_speed: float = 50.0 # Controls mouse wheel sensitivity
@export var TOUCHPAD_VELOCITY:float = 1.0

@export var point_data: Array[PathPointData]:
	set(value):
		point_data = value
		_update_point_data_array()

var is_swiping: bool = false
var last_touch_pos: Vector2
var current_velocity: float = 0.0

var path_length: float = 0.0
var camera_2d_node: Camera2D = null
var parent_path_2d: Path2D = null
var last_curve_point_count: int = 0

var _point_distances: PackedFloat64Array = []

var current_target_speed: float = 1.0
var smooth_current_speed: float = 1.0


var last_passed_point_index: int = -1
var audio_stream_player: AudioStreamPlayer
# This array will store all unique nodes that need to be managed.
var managed_node_paths: Array[NodePath] = []

func _ready():
	_initialize_node_references()
	_update_point_data_array() # This now also populates our managed nodes list
	_apply_current_zoom()

	# Create an AudioStreamPlayer for sound effects
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	
	# Ensures the correct nodes are visible/hidden at the starting position.
	if parent_path_2d and parent_path_2d.curve:
		var start_point_index = get_closest_point_index(parent_path_2d.curve, 0)
		_update_node_visibility(start_point_index)


func _process(delta):
	var path_node = get_parent() as Path2D
	if path_node and path_node.curve:
		var current_point_index = get_closest_point_index(path_node.curve, self.progress / path_length)
		
		# --- SOUND EFFECT LOGIC ---
		if current_point_index != last_passed_point_index:
			last_passed_point_index = current_point_index
			var point_data = _get_point_data_for_index(current_point_index)
			if point_data and point_data.sound_effect:
				audio_stream_player.stream = point_data.sound_effect
				audio_stream_player.play()

		# --- NODE VISIBILITY LOGIC ---
		_update_node_visibility(current_point_index)
		
		# --- Speed logic ---
		var current_point_data_for_speed: PathPointData = _get_point_data_for_index(current_point_index)
		if current_point_data_for_speed:
			current_target_speed = current_point_data_for_speed.speed
		else:
			current_target_speed = 1.0

	smooth_current_speed = lerp(smooth_current_speed, current_target_speed, 0.1)

	if Engine.is_editor_hint():
		if parent_path_2d and parent_path_2d.curve:
			if parent_path_2d.curve.get_point_count() != last_curve_point_count:
				_update_point_data_array()
		
		_apply_current_zoom()
		return

	# Apply coasting momentum if not actively swiping/panning
	if !is_swiping and abs(current_velocity) > min_swipe_velocity_threshold:
		current_velocity *= deceleration_rate
		var delta_progress_from_momentum = current_velocity * smooth_current_speed
		self.progress = clamp(self.progress + delta_progress_from_momentum, 0, path_length)
		
		if abs(current_velocity) < min_swipe_velocity_threshold:
			current_velocity = 0.0
		
		_apply_current_zoom()

func _input(event):
	if Engine.is_editor_hint():
		return

	# --- MOUSE SCROLL INPUT ---
	if event is InputEventMouseButton and event.is_pressed():
		var scroll_direction = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_direction = 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_direction = -1.0

		if scroll_direction != 0.0:
			current_velocity = 0.0
			var path_node_runtime = get_parent() as Path2D
			if !path_node_runtime or !path_node_runtime.curve: return
			var progress_change_from_scroll = scroll_direction * scroll_speed * smooth_current_speed
			self.progress = clamp(self.progress + progress_change_from_scroll, 0, path_length)
			_apply_current_zoom()
			var current_point_index = get_closest_point_index(path_node_runtime.curve, self.progress / path_length)
			_update_node_visibility(current_point_index)
			get_viewport().set_input_as_handled()
			return

	# --- START: NEW TRACKPAD PAN GESTURE LOGIC ---
	elif event is InputEventPanGesture:
		# Ensure any touch-based swipe flags are reset.
		is_swiping = false

		var path_node_runtime = get_parent() as Path2D
		if !path_node_runtime or !path_node_runtime.curve: return

		# Invert delta.y for "natural" trackpad scrolling (swipe up moves content up)
		var vertical_pan_amount = -event.delta.y

		# Reuse speed_multiplier for sensitivity. A pan is like a drag.
		var raw_velocity = vertical_pan_amount * speed_multiplier * TOUCHPAD_VELOCITY

		# Apply immediate change based on the local path speed.
		var progress_change_from_pan = raw_velocity * smooth_current_speed 
		self.progress = clamp(self.progress + progress_change_from_pan, 0, path_length)

		# Store the raw velocity for coasting, just like with screen drag.
		current_velocity = raw_velocity

		# Update visuals immediately.
		_apply_current_zoom()
		var current_point_index = get_closest_point_index(path_node_runtime.curve, self.progress / path_length)
		_update_node_visibility(current_point_index)

		get_viewport().set_input_as_handled()
		return
	# --- END: NEW TRACKPAD PAN GESTURE LOGIC ---

	# --- TOUCHSCREEN DRAG/SWIPE LOGIC ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_swiping = true
			last_touch_pos = event.position
			current_velocity = 0.0
		else:
			is_swiping = false
			
	elif event is InputEventScreenDrag:
		if is_swiping:
			var path_node_runtime = get_parent() as Path2D
			if !path_node_runtime or !path_node_runtime.curve: return

			var delta_pos = event.position - last_touch_pos
			var vertical_swipe_amount = delta_pos.y
			
			var raw_velocity = vertical_swipe_amount * speed_multiplier
			var progress_change_from_swipe = raw_velocity * smooth_current_speed
			self.progress = clamp(self.progress + progress_change_from_swipe, 0, path_length)
			current_velocity = raw_velocity
			
			last_touch_pos = event.position
			
			_apply_current_zoom()
			var current_point_index = get_closest_point_index(path_node_runtime.curve, self.progress / path_length)
			_update_node_visibility(current_point_index)

# ... (The rest of your script is unchanged and remains correct) ...

func _initialize_node_references():
	if get_parent() is Path2D:
		parent_path_2d = get_parent() as Path2D
		if parent_path_2d.curve:
			path_length = parent_path_2d.curve.get_baked_length()
			_update_path_distances()
	else:
		push_warning("This node is not a child of a Path2D. The script may not function as intended.")
		parent_path_2d = null
	
	if get_viewport():
		camera_2d_node = get_viewport().get_camera_2d()
	if camera_2d_node == null and !Engine.is_editor_hint():
		push_warning("No Camera2D node found in the current viewport. Zoom will not be applied.")

func _update_point_data_array():
	if parent_path_2d and parent_path_2d.curve:
		var curve_point_count = parent_path_2d.curve.get_point_count()
		last_curve_point_count = curve_point_count
		point_data.resize(curve_point_count)
		
		_update_path_distances()
		
		for i in range(point_data.size()):
			if point_data[i] == null:
				var new_point_data = PathPointData.new()
				new_point_data.speed = 1.0
				new_point_data.zoom = 1.0
				point_data[i] = new_point_data
	elif Engine.is_editor_hint():
		for i in range(point_data.size()):
			if point_data[i] == null:
				var new_point_data = PathPointData.new()
				new_point_data.speed = 1.0
				new_point_data.zoom = 1.0
				point_data[i] = new_point_data
	_update_managed_nodes_list()


func _update_path_distances():
	if not parent_path_2d or not parent_path_2d.curve:
		return
	
	var curve = parent_path_2d.curve
	var point_count = curve.get_point_count()
	_point_distances.resize(point_count)
	
	for i in range(point_count):
		var point_pos = curve.get_point_position(i)
		_point_distances[i] = curve.get_closest_offset(point_pos)

func _apply_current_zoom():
	if not camera_2d_node or not parent_path_2d or not parent_path_2d.curve:
		return

	var curve = parent_path_2d.curve
	if curve.get_point_count() < 1 or point_data.is_empty():
		camera_2d_node.zoom = Vector2(base_zoom, base_zoom)
		return

	var segment_info = _get_segment_info_at_progress(self.progress)
	var prev_index = segment_info.prev_point_index
	var next_index = segment_info.next_point_index
	var t = segment_info.segment_progress

	var zoom_a = point_data[prev_index].zoom if point_data[prev_index] else 1.0
	var zoom_b = point_data[next_index].zoom if point_data[next_index] else 1.0

	var smoothed_t = t * t * (3.0 - 2.0 * t)
	var calculated_zoom = lerp(zoom_a, zoom_b, smoothed_t)
	
	var final_zoom = calculated_zoom * base_zoom
	camera_2d_node.zoom = Vector2(final_zoom, final_zoom)

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

func _get_point_data_for_index(index: int) -> PathPointData:
	if !point_data.is_empty() and index >= 0 and index < point_data.size():
		return point_data[index]
	return null

func get_closest_point_index(curve: Curve2D, progress_ratio: float) -> int:
	if curve == null or curve.get_point_count() == 0 or _point_distances.is_empty():
		return -1

	var target_progress_dist = progress_ratio * curve.get_baked_length()

	for i in range(_point_distances.size() - 1, -1, -1):
		if target_progress_dist >= _point_distances[i]:
			return i
	
	return 0

func _update_managed_nodes_list():
	managed_node_paths.clear()
	if point_data.is_empty():
		return

	for data in point_data:
		if data and data.target_node and not data.target_node.is_empty():
			if not managed_node_paths.has(data.target_node):
				managed_node_paths.append(data.target_node)

func _update_node_visibility(current_point_index: int):
	var current_point_data = _get_point_data_for_index(current_point_index)
	
	if not current_point_data:
		return

	var active_node_path = current_point_data.target_node
	var should_show_active_node = current_point_data.show_target_node

	for path in managed_node_paths:
		var node = get_node_or_null(path)
		
		if is_instance_valid(node) and node is CanvasItem:
			if path == active_node_path:
				node.visible = should_show_active_node
			else:
				node.visible = false
