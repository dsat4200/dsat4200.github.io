@tool
extends Control

## Assign the Path2D node you want to visualize.
@export var path_node_path: NodePath:
	set(value):
		# When the path is changed in the editor, disconnect from the old one (if any)
		if is_instance_valid(_path_node) and _path_node.curve:
			if _path_node.curve.is_connected("changed", _update_labels):
				_path_node.curve.changed.disconnect(_update_labels)

		path_node_path = value
		_path_node = get_node_or_null(path_node_path)

		# Connect to the new path's curve signal
		if is_instance_valid(_path_node) and _path_node.curve:
			_path_node.curve.changed.connect(_update_labels)
		
		# Trigger a manual update to draw the initial state
		_update_labels()


## Optional: Customize the appearance of the index numbers.
@export var label_settings: LabelSettings

var _path_node: Path2D = null

func _ready():
	# Initial setup when the scene is loaded
	_path_node = get_node_or_null(path_node_path)
	if is_instance_valid(_path_node) and _path_node.curve:
		# Connect the signal if not already connected by the setter
		if not _path_node.curve.is_connected("changed", _update_labels):
			_path_node.curve.changed.connect(_update_labels)
	_update_labels()

func _exit_tree():
	# Clean up the connection when the node is removed from the scene
	if is_instance_valid(_path_node) and _path_node.curve:
		if _path_node.curve.is_connected("changed", _update_labels):
			_path_node.curve.changed.disconnect(_update_labels)

func _clear_labels():
	"""Removes all previously generated index labels."""
	for child in get_children():
		child.queue_free()

func _update_labels():
	"""
	Clears and recreates all index labels. This is now called automatically
	by the curve's 'changed' signal.
	"""
	_clear_labels()
	
	# Ensure we are in the editor and a valid path node is assigned
	if not Engine.is_editor_hint() or not is_instance_valid(_path_node):
		return

	var curve = _path_node.curve
	if not curve:
		return
	
	var point_count = curve.get_point_count()
	
	# Generate a new label for each point in the curve
	for i in range(point_count):
		var point_position = curve.get_point_position(i)
		
		var label = Label.new()
		label.text = str(i)
		
		# Apply custom font/color/size settings if they exist
		if label_settings:
			label.label_settings = label_settings
		
		# Set position and pivot offset to center the label on the point
		label.position = point_position
		label.pivot_offset = label.get_size() / 2.0

		add_child(label)
