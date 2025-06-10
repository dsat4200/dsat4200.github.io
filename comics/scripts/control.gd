@tool
extends Control
var selected:PathPointMarker
@export var preview_cam:Camera2D
@export var path_follow:PathFollow2D

const PathPointMarker_Scene = preload("res://scripts/PathPointMarker.tscn")
func _ready():
	# Connect to the selection_changed signal if in editor
	if Engine.is_editor_hint():
		# This ensures EditorInterface is available
		EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
	else:
		hide()


## Assign the Path2D node you want to visualize.
@export var path_node_path: NodePath:
	set(value):
		# When the path is changed, disconnect from the old one (if any)
		if is_instance_valid(_path_node) and _path_node.curve:
			if _path_node.curve.is_connected("changed", _update_labels):
				_path_node.curve.disconnect("changed", _update_labels)

		path_node_path = value
		_path_node = get_node_or_null(path_node_path)

		# Connect to the new path's curve 'changed' signal
		if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
			_path_node.curve.changed.connect(_update_labels)
		
		# Trigger a manual update to draw the initial state
		_update_labels()

## Optional: Customize the appearance of the index numbers.

# A button to manually refresh the nodes in the editor.
@export var refresh_button: bool:
	set(value):
		if value:
			print("Refreshing labels...")
			_update_labels()

var _path_node: Path2D

# Preload the custom node script for reliability in tool mode
const PathPointMarker_Class = preload("res://scripts/PathPointMarker.gd") # Ensure this path is correct!

func _enter_tree():
	# Initial setup when the node enters the scene tree
	_path_node = get_node_or_null(path_node_path)
	if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
		# Connect the signal if not already connected by the setter
		if not _path_node.curve.is_connected("changed", _update_labels):
			_path_node.curve.changed.connect(_update_labels)
	_update_labels()

func _exit_tree():
	# Clean up the connection when the node is removed from the scene
	if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
		if _path_node.curve.is_connected("changed", _update_labels):
			_path_node.curve.disconnect("changed", _update_labels)

var _previous_curve_points: Array[Vector2] = []
var _label_map: Dictionary = {} # Stores a mapping of point_position (as string) to label node
func _update_labels():
	print("updating labels..")
	
	if not is_instance_valid(_path_node):
		# If path node is invalid, clear any existing labels
		for child in get_children():
			if child is PathPointMarker_Class:
				child.queue_free()
		_previous_curve_points.clear()
		_label_map.clear() # Clear map too
		return

	var curve = _path_node.curve
	
	# Get all existing labels that are children of this node
	var existing_labels_on_node: Array[PathPointMarker_Class] = []
	for child in get_children():
		if child is PathPointMarker_Class:
			existing_labels_on_node.append(child)

	if not is_instance_valid(curve):
		for label in existing_labels_on_node:
			label.queue_free()
		_previous_curve_points.clear()
		_label_map.clear() # Clear map too
		return
	
	var current_point_count = curve.get_point_count()
	var current_curve_points: Array[Vector2] = []
	for i in range(current_point_count):
		current_curve_points.append(curve.get_point_position(i))

	var new_labels_created_this_frame: Array[PathPointMarker_Class] = []
	var labels_to_keep: Array[PathPointMarker_Class] = []
	var labels_to_remove_after_processing: Array[PathPointMarker_Class] = existing_labels_on_node.duplicate() # Start with all, remove those we keep

	# --- 1. Identify New and Existing Points and their Labels ---
	
	# Try to re-use existing labels by matching positions from the _label_map
	# We use the _label_map to persist the association of a label to a point position
	# across _update_labels calls.
	
	for i in range(current_point_count):
		var current_point_pos = current_curve_points[i]
		var found_label: PathPointMarker_Class = null

		# Check if we have a label for this point position in our persistent map
		# IMPORTANT: Vector2 as dictionary key relies on direct equality. For floats,
		# string conversion or a custom hash is needed for robust matching.
		# For simplicity, we'll iterate and use is_equal_approx() for matching existing labels.
		# If you expect many points, a more performant spatial hash might be needed.

		# Find if an existing label (from previous frame or map) matches this current point
		for label in existing_labels_on_node:
			if label.position.is_equal_approx(current_point_pos):
				found_label = label
				break
		
		if found_label:
			# This point has an existing label, re-associate it and mark it to keep
			labels_to_keep.append(found_label)
			labels_to_remove_after_processing.erase(found_label) # Don't remove it later
			# Ensure the label is correctly positioned (in case the point slightly moved or it's the first time)
			if not found_label.position.is_equal_approx(current_point_pos):
				found_label.position = current_point_pos
				found_label.pivot_offset = found_label.size / 2.0
				found_label.disappear() # Update visual state if needed
		else:
			# This is a new point or a point that didn't have a label assigned yet.
			# Create a new label for it.
			var new_marker = PathPointMarker_Scene.instantiate()
			new_marker.name = "PathPointMarker_%s" % Time.get_ticks_usec()
			add_child(new_marker)
			new_marker.owner = get_tree().edited_scene_root
			
			new_marker.position = current_point_pos
			new_marker.pivot_offset = new_marker.size / 2.0
			new_marker.disappear() # Initialize the new label's visual state
			
			labels_to_keep.append(new_marker) # Add the new label to our list of kept labels
			new_labels_created_this_frame.append(new_marker) # For tracking just created ones
			print("Created and positioned a new label for a new point.")

	# --- 2. Remove Surplus Labels (those that didn't match a current point) ---
	for label_to_remove in labels_to_remove_after_processing:
		if is_instance_valid(label_to_remove):
			remove_child(label_to_remove)
			label_to_remove.call_deferred("free")
			print("Removed a label corresponding to a deleted point.")

	# --- 3. Finalize _previous_curve_points ---
	# For the next comparison, _previous_curve_points should reflect the current state.
	_previous_curve_points = current_curve_points.duplicate() # Make a copy!

	# Update the _label_map to reflect the current state
	_label_map.clear()
	for i in range(current_point_count):
		# Rebuild the map with current (valid) label to point associations
		_label_map[current_curve_points[i]] = labels_to_keep[i] # This assumes labels_to_keep is ordered by point index.
		# A better approach for the map would be to store {unique_id_of_point: label_node} if points had stable IDs.
		# Since points are identified by position, the iteration ensures we link label to its current curve point.
		

func _on_editor_selection_changed():
	var editor_selection := EditorInterface.get_selection().get_selected_nodes()
	if (editor_selection.size() == 1 and (editor_selection[0] is PathPointMarker)):
		if (selected):
			selected.disappear()
		selected = editor_selection[0]
		selected.appear()
		preview_cam.position = selected.position
		preview_cam.zoom.x = selected.point_data.zoom * path_follow.base_zoom
		preview_cam.zoom.y = selected.point_data.zoom * path_follow.base_zoom
	elif (editor_selection.size() == 0):
		selected.disappear()
		selected = null
		
		
func _process(_delta):
	# This function only runs in the editor because of the @tool annotation.
	# First, check if a marker is actually selected and is valid.
	if not is_instance_valid(selected):
		return
	# Continuously update the camera's zoom to match the selected point's data.
	# This ensures that when you drag the zoom value in the Inspector,
	# the camera updates in real-time.
	if preview_cam and preview_cam.zoom.x != selected.point_data.zoom:
		preview_cam.zoom = Vector2(selected.point_data.zoom * path_follow.base_zoom, selected.point_data.zoom * path_follow.base_zoom)
	
