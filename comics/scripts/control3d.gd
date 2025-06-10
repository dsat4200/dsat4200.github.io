@tool
extends Node3D
class_name PathMarkerManager3D


@export var path_follow: PathFollow3D # Should be your PathReader3D node

# --- DATA & SCENE REFERENCES ---
const PathPointMarker3D_Scene = preload("res://scripts/PathPointMarker3D.tscn") # IMPORTANT: Update this path to your 3D marker scene
const PathPointMarker3D_Class = preload("res://scripts/PathPointMarker3D.gd")   # IMPORTANT: Update this path to your 3D marker script

# A reference to the currently selected marker in the editor
var selected: Node3D 

## Assign the Path3D node you want to visualize.
@export var path_node_path: NodePath:
	set(value):
		# When the path is changed, disconnect from the old one (if any)
		if is_instance_valid(_path_node) and _path_node.curve:
			if _path_node.curve.is_connected("changed", _update_markers):
				_path_node.curve.disconnect("changed", _update_markers)

		path_node_path = value
		_path_node = get_node_or_null(path_node_path)

		# Connect to the new path's curve 'changed' signal
		if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
			_path_node.curve.changed.connect(_update_markers)
		
		# Trigger a manual update to draw the initial state
		_update_markers()

# A button to manually refresh the nodes in the editor.
@export var refresh_button: bool:
	set(value):
		if value:
			print("Refreshing 3D markers...")
			_update_markers()

var _path_node: Path3D

func _enter_tree():
	# Initial setup when the node enters the scene tree
	_path_node = get_node_or_null(path_node_path)
	if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
		if not _path_node.curve.is_connected("changed", _update_markers):
			_path_node.curve.changed.connect(_update_markers)
	

	if Engine.is_editor_hint():
		# This ensures EditorInterface is available for selection logic
		EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
		_update_markers()
	else:
		hide()

func _exit_tree():
	# Clean up the connection when the node is removed from the scene
	if is_instance_valid(_path_node) and is_instance_valid(_path_node.curve):
		if _path_node.curve.is_connected("changed", _update_markers):
			_path_node.curve.disconnect("changed", _update_markers)
	
	if Engine.is_editor_hint():
		if EditorInterface.get_selection().is_connected("selection_changed", _on_editor_selection_changed):
			EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_changed)


func _update_markers():
	"""
	Synchronizes the number of 3D markers with the number of curve points,
	then updates each marker's position.
	"""
	if not is_instance_valid(_path_node) or not is_instance_valid(_path_node.curve):
		for child in get_children():
			if child is PathPointMarker3D_Class:
				child.queue_free()
		return

	var curve = _path_node.curve
	
	if curve.is_connected("changed", _update_markers):
		curve.disconnect("changed", _update_markers)

	var child_markers: Array[Node3D] = []
	for child in get_children():
		if child is PathPointMarker3D_Class:
			child_markers.append(child)
	
	var point_count = curve.get_point_count()
	var marker_count = child_markers.size()

	# --- 1. SYNCHRONIZE MARKER COUNT WITH POINT COUNT ---

	# Add new markers if there are more points than markers
	if marker_count < point_count:
		var markers_to_add = point_count - marker_count
		for i in range(markers_to_add):
			var new_marker = PathPointMarker3D_Scene.instantiate()
			new_marker.name = "PathPointMarker3D_%s" % Time.get_ticks_usec()
			add_child(new_marker)
			new_marker.owner = get_tree().edited_scene_root
			
	# Remove surplus markers if there are fewer points than markers
	elif marker_count > point_count:
		var markers_to_remove = marker_count - point_count
		for i in range(markers_to_remove):
			var marker_to_remove = child_markers.pop_back()
			marker_to_remove.queue_free()

	# --- 2. UPDATE ALL MARKERS ---
	# Get a fresh reference to the children after adding/removing
	var final_markers: Array[Node3D] = []
	for child in get_children():
		if child is PathPointMarker3D_Class:
			final_markers.append(child)

	for i in range(point_count):
		# Guard against index out of bounds errors
		if i < final_markers.size():
			var marker: Node3D = final_markers[i]
			var point_position: Vector3 = curve.get_point_position(i)
			
			if "disappear" in marker:
				marker.disappear()

			marker.position = point_position
			
			if "point_data" in marker:
				marker.point_data = {
					"index": i,
					"position": point_position
				}

	if not curve.is_connected("changed", _update_markers):
		curve.connect("changed", _update_markers)


func _on_editor_selection_changed():
	var editor_selection = EditorInterface.get_selection().get_selected_nodes()
	
	if editor_selection.size() == 1 and editor_selection[0] is PathPointMarker3D_Class:
		if is_instance_valid(selected) and "disappear" in selected:
			selected.disappear()
			
		selected = editor_selection[0]
		
		if "appear" in selected:
			selected.appear()
			
		if "point_data" in selected:
			var point_data = selected.point_data
				
	elif is_instance_valid(selected):
		if "disappear" in selected:
			selected.disappear()
		selected = null

func _process(_delta):
	if not Engine.is_editor_hint(): return
