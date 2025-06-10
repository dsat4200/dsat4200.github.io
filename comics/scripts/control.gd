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
		hide_all_markers()
	else:
		hide()
func hide_all_markers():
	for i in get_children():
		i.disappear()

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
			if not _path_node.curve.is_connected("changed", _update_labels):
				_path_node.curve.changed.connect(_update_labels)
		
		# Trigger a manual update to draw the initial state
		#call_deferred("_update_labels")


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
	#call_deferred("_update_labels")


func _exit_tree():
	# Clean up the connection when the node is removed from the scene
	if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
		if _path_node.curve.is_connected("changed", _update_labels):
			_path_node.curve.disconnect("changed", _update_labels)

var _previous_curve_points: Array[Vector2] = []
var _label_map: Dictionary = {} # Stores a mapping of point_position (as string) to label node
func _update_labels():
	if not is_instance_valid(_path_node):
		for child in get_children():
			if child is PathPointMarker_Class:
				child.queue_free()
		_previous_curve_points.clear()
		_label_map.clear()
		return

	var curve = _path_node.curve
	var size = get_children().size()
	var current_point_count = curve.get_point_count()
	var state = ""
	if size+1 == current_point_count:
		state = "add"
	elif size-1 == current_point_count:
		state = "remove"
	elif size == current_point_count:
		state = "move"
	else:
		state = "other"
	print(state)
	
	if state=="other":
		initialize_points()
	
func initialize_points():
	var curve = _path_node.curve
	var current_point_count = curve.get_point_count()
	var existing_labels_on_node: Array[PathPointMarker_Class] = []
	for child in get_children():
		if child is PathPointMarker_Class:
			existing_labels_on_node.append(child)

	if not is_instance_valid(curve):
		for label in existing_labels_on_node:
			label.queue_free()
		_previous_curve_points.clear()
		_label_map.clear()
		return
	

	var current_curve_points: Array[Vector2] = []
	for i in range(current_point_count):
		current_curve_points.append(curve.get_point_position(i))

	var labels_to_keep: Array[PathPointMarker_Class] = []
	var labels_to_remove_after_processing: Array[PathPointMarker_Class] = existing_labels_on_node.duplicate()

	for i in range(current_point_count):
		# FIX: Convert point position to global space for a reliable comparison
		var point_pos_global = current_curve_points[i]
		var found_label: PathPointMarker_Class = null

		# Find an existing label by comparing global positions
		for label in existing_labels_on_node:
			if label.global_position.is_equal_approx(point_pos_global):
				found_label = label
				break
		
		if found_label:
			labels_to_keep.append(found_label)
			if labels_to_remove_after_processing.has(found_label):
				labels_to_remove_after_processing.erase(found_label)
			
			# FIX: Set position by converting global position back to our local space
			found_label.position = point_pos_global
			found_label.pivot_offset = found_label.size / 2.0
			found_label.update_info() # Refresh data on the marker
			if not selected or found_label != selected:
				found_label.disappear()
		else:
			# This is a new point, so create a new label for it.
			var new_marker = PathPointMarker_Scene.instantiate()
			new_marker.name = "PathPointMarker_%s" % Time.get_ticks_usec()
			add_child(new_marker)
			new_marker.owner = get_tree().edited_scene_root
			print(point_pos_global)
			# FIX: Set position correctly using the global position
			new_marker.position = point_pos_global
			new_marker.pivot_offset = new_marker.size / 2.0
			new_marker.disappear()
			
			labels_to_keep.append(new_marker)

	# Remove surplus labels
	for label_to_remove in labels_to_remove_after_processing:
		if is_instance_valid(label_to_remove):
			label_to_remove.queue_free()

	# Finalize state for the next update
	_previous_curve_points = current_curve_points.duplicate()
	_label_map.clear()
	if labels_to_keep.size() == current_curve_points.size():
		for i in range(current_point_count):
			_label_map[current_curve_points[i]] = labels_to_keep[i]
	#print("removed labels: "+str(labels_to_remove_after_processing))
	#print("kept labels: "+str(labels_to_keep))
func _on_editor_selection_changed():
	var editor_selection := EditorInterface.get_selection().get_selected_nodes()
	if (editor_selection.size() == 1 and (editor_selection[0] is PathPointMarker)):
		if (is_instance_valid(selected)):
			selected.disappear()
		selected = editor_selection[0]
		selected.appear()
		if is_instance_valid(preview_cam) and is_instance_valid(path_follow):
			preview_cam.position = selected.position
			preview_cam.zoom.x = selected.point_data.zoom * path_follow.base_zoom
			preview_cam.zoom.y = selected.point_data.zoom * path_follow.base_zoom
	elif (editor_selection.size() == 0 and is_instance_valid(selected)):
		selected.disappear()
		selected = null
		
		
func _process(_delta):
	if not is_instance_valid(selected):
		return
	if selected is PathPointMarker:
		selected.update_info()

	if is_instance_valid(preview_cam) and is_instance_valid(path_follow) and preview_cam.zoom.x != selected.point_data.zoom:
		preview_cam.zoom = Vector2(selected.point_data.zoom * path_follow.base_zoom, selected.point_data.zoom * path_follow.base_zoom)
