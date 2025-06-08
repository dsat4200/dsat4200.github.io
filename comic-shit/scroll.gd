@tool
extends PathFollow2D

@export var speed_multiplier: float = 100.0
@export var deceleration_rate: float = 0.95
@export var base_zoom: float = 1.0  # NEW: Overall zoom level for the camera
@export var min_swipe_velocity_threshold: float = 5.0

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

# Caches the distance along the curve for each main point.
var _point_distances: PackedFloat64Array = []

var current_target_speed: float = 1.0
var smooth_current_speed: float = 1.0

func _ready():
	_initialize_node_references()
	_update_point_data_array()
	_apply_current_zoom()

func _process(delta):
	# Update target speed
	var path_node = get_parent() as Path2D
	if path_node and path_node.curve:
		var current_point_index = get_closest_point_index(path_node.curve, self.progress / path_length)
		var current_point_data: PathPointData = _get_point_data_for_index(current_point_index)
		
		if current_point_data:
			current_target_speed = current_point_data.speed
		else:
			current_target_speed = 1.0

	# Smoothly interpolate current speed towards target speed
	smooth_current_speed = lerp(smooth_current_speed, current_target_speed, 0.1)

	if Engine.is_editor_hint():
		if parent_path_2d and parent_path_2d.curve:
			if parent_path_2d.curve.get_point_count() != last_curve_point_count:
				_update_point_data_array()
		
		_apply_current_zoom()
		return

	if !is_swiping and abs(current_velocity) > min_swipe_velocity_threshold:
		var path_node_runtime = get_parent() as Path2D
		if !path_node_runtime or !path_node_runtime.curve: return

		current_velocity *= deceleration_rate
		var delta_progress_from_momentum = current_velocity * smooth_current_speed
		self.progress = clamp(self.progress + delta_progress_from_momentum, 0, path_length)
		
		if abs(current_velocity) < min_swipe_velocity_threshold:
			current_velocity = 0.0
		
		_apply_current_zoom()

func _input(event):
	if Engine.is_editor_hint():
		return

	if event is InputEventScreenTouch:
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
			
			var progress_change_from_swipe: float = vertical_swipe_amount * speed_multiplier * smooth_current_speed
			self.progress = clamp(self.progress + progress_change_from_swipe, 0, path_length)
			current_velocity = progress_change_from_swipe
			last_touch_pos = event.position
			
			_apply_current_zoom()

func _initialize_node_references():
	if get_parent() is Path2D:
		parent_path_2d = get_parent() as Path2D
		if parent_path_2d.curve:
			path_length = parent_path_2d.curve.get_baked_length()
			_update_path_distances() # Cache the distances
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
		
		# Recalculate distances when points change
		_update_path_distances()
		
		for i in range(point_data.size()):
			if point_data[i] == null:
				var new_point_data = PathPointData.new()
				new_point_data.speed = 1.0
				new_point_data.zoom = 1.0
				point_data[i] = new_point_data
	elif Engine.is_editor_hint():
		# Fallback for editor if parent path isn't ready
		for i in range(point_data.size()):
			if point_data[i] == null:
				var new_point_data = PathPointData.new()
				new_point_data.speed = 1.0
				new_point_data.zoom = 1.0
				point_data[i] = new_point_data

func _update_path_distances():
	"""
	Calculates the distance from the start of the path to each control point
	and caches the results in the _point_distances array.
	"""
	if not parent_path_2d or not parent_path_2d.curve:
		return
	
	var curve = parent_path_2d.curve
	var point_count = curve.get_point_count()
	_point_distances.resize(point_count)
	
	for i in range(point_count):
		var point_pos = curve.get_point_position(i)
		_point_distances[i] = curve.get_closest_offset(point_pos)


# --- MODIFIED FUNCTION ---
func _apply_current_zoom():
	"""
	Calculates and applies zoom based on the progress between two points,
	using a smoothing function for a more natural transition.
	"""
	if not camera_2d_node or not parent_path_2d or not parent_path_2d.curve:
		return

	var curve = parent_path_2d.curve
	if curve.get_point_count() < 1 or point_data.is_empty():
		# If no points, just apply the base zoom
		camera_2d_node.zoom = Vector2(base_zoom, base_zoom)
		return

	# Step 1: Find which two points we are between and the linear progress
	var segment_info = _get_segment_info_at_progress(self.progress)
	var prev_index = segment_info.prev_point_index
	var next_index = segment_info.next_point_index
	var t = segment_info.segment_progress # 't' is our linear progress (0.0 to 1.0)

	# Step 2: Get the zoom data for those two points
	var zoom_a = point_data[prev_index].zoom if point_data[prev_index] else 1.0
	var zoom_b = point_data[next_index].zoom if point_data[next_index] else 1.0

	# Step 3: Apply a smoothing function (Smoothstep) to 't'
	# This is the key change. It reshapes the linear progress into an S-curve,
	# making the zoom "hug" the start and end values of the segment.
	# The formula is: f(t) = 3t^2 - 2t^3
	var smoothed_t = t * t * (3.0 - 2.0 * t)
	
	# Step 4: Linearly interpolate using the *smoothed* progress value
	var calculated_zoom = lerp(zoom_a, zoom_b, smoothed_t)
	
	# Step 5: Apply the combined zoom (base * point-specific)
	var final_zoom = calculated_zoom * base_zoom
	camera_2d_node.zoom = Vector2(final_zoom, final_zoom)

func _get_segment_info_at_progress(current_dist: float) -> Dictionary:
	"""
	Finds the previous point, next point, and the progress (0.0 to 1.0)
	along the segment connecting them, based on the current distance.
	"""
	if _point_distances.size() < 2:
		return {"prev_point_index": 0, "next_point_index": 0, "segment_progress": 0.0}

	# Find the segment that contains the current_dist
	for i in range(_point_distances.size() - 1):
		var dist_a = _point_distances[i]
		var dist_b = _point_distances[i+1]
		
		if current_dist >= dist_a and current_dist <= dist_b:
			var segment_length = dist_b - dist_a
			if segment_length < 0.001: # Avoid division by zero
				return {"prev_point_index": i, "next_point_index": i, "segment_progress": 0.0}
			
			var progress_into_segment = current_dist - dist_a
			var t = progress_into_segment / segment_length
			return {"prev_point_index": i, "next_point_index": i + 1, "segment_progress": t}
	
	# Handle being before the first point or after the last point
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
	if curve == null or curve.get_point_count() == 0:
		return -1

	var target_progress_dist = progress_ratio * curve.get_baked_length()
	var closest_index = 0
	# This part of the logic could be optimized, but we'll leave it as is for now.
	var cumulative_lengths = [0.0]
	for i in range(1, curve.get_point_count()):
		# This calculation is for straight-line distance, not curve distance.
		# For a more accurate speed transition, consider using curve.get_closest_offset.
		var p1 = curve.get_point_position(i - 1)
		var p2 = curve.get_point_position(i)
		var segment_length = p1.distance_to(p2)
		cumulative_lengths.append(cumulative_lengths[i-1] + segment_length)

	for i in range(cumulative_lengths.size() - 1, -1, -1):
		if target_progress_dist >= cumulative_lengths[i]:
			closest_index = i
			break

	return closest_index
