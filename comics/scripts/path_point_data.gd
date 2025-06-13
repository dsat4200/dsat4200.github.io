@tool # This is crucial for editor visibility

class_name PathPointData extends Resource

@export_range (.1, 4) var zoom: float = 1.0
@export_range (.1,8) var speed: float = 1.0

@export var sound_effect: AudioStream = null

# --- NEW EXPORTS ---
# A path to the node in the scene you want to control.
@export var target_node: NodePath
