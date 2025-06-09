@tool
extends Control
var selected:PathPointMarker

const PathPointMarker_Scene = preload("res://PathPointMarker.tscn")
func _ready():

	# Connect to the selection_changed signal if in editor
	if Engine.is_editor_hint():
		# This ensures EditorInterface is available
		EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)


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
const PathPointMarker_Class = preload("res://PathPointMarker.gd") # Ensure this path is correct!

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

func _update_labels():
	"""
	Synchronizes the number of labels with the number of curve points,
	then updates each label's position and text. This method is more robust
	than mapping by index.
	"""
	if not is_instance_valid(_path_node):
		# If path node is invalid, clear any existing labels
		for child in get_children():
			if child is PathPointMarker_Class:
				child.queue_free()
		return

	var curve = _path_node.curve
	
	# Get all existing labels that are children of this node
	var child_labels: Array[PathPointMarker_Class] = []
	for child in get_children():
		if child is PathPointMarker_Class:
			child_labels.append(child)

	# If the curve is invalid or has no points, remove all labels
	if not is_instance_valid(curve):
		for label in child_labels:
			label.queue_free()
		return
	
	var point_count = curve.get_point_count()

	# --- 1. SYNCHRONIZE LABEL COUNT WITH POINT COUNT ---

	# Add new labels if there are more points than labels
	while child_labels.size() < point_count:
		#var new_label = PathPointLabel_Class.new()
		## Use a high-resolution timestamp for a unique name
		#new_label.name = "PathPointLabel_%s" % Time.get_ticks_usec()
		#
		#add_child(new_label)
		## This is crucial for saving the dynamically created node with the scene
		#new_label.owner = get_tree().edited_scene_root
		#child_labels.append(new_label)
		var new_marker = PathPointMarker_Scene.instantiate()
		new_marker.name = "PathPointMarker_%s" % Time.get_ticks_usec()
		
		add_child(new_marker)
		new_marker.owner = get_tree().edited_scene_root
		child_labels.append(new_marker)
		

	# Remove surplus labels if there are fewer points than labels
	while child_labels.size() > point_count:
		var label_to_remove = child_labels.pop_back()
		remove_child(label_to_remove)
		# Freeing should be deferred to avoid errors in the editor
		label_to_remove.call_deferred("free")

	# --- 2. UPDATE ALL LABELS ---
	
	# Now that counts match, update each label's properties
	for i in range(point_count):
		var label: PathPointMarker_Class = child_labels[i]
		var point_position: Vector2 = curve.get_point_position(i)
		#print(point_position)
		label.disappear()
		# The `PathPointLabel.gd` script should be responsible for initializing
		# its own data resource. You can add a check here if needed:
		#if not is_instance_valid(label.point_data):
			#label.point_data = PathPointData.new()

		# Update label's position and text
		label.position = point_position
		
		
		# Apply custom font/color/size settings if they exist

		# Center the label on the point. In Godot 4, use `size` property.
		label.pivot_offset = label.size / 2.0

	
func _on_editor_selection_changed():
	var editor_selection := EditorInterface.get_selection().get_selected_nodes()
	if (editor_selection.size() == 1 and (editor_selection[0] is PathPointMarker)):
		if (selected):
			selected.disappear()
		selected = editor_selection[0]
		selected.appear()
