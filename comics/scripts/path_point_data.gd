@tool # This is crucial for editor visibility

class_name PathPointData extends Resource

@export var speed: float = 1.0
@export var zoom: float = 1.0
@export var sound_effect: AudioStream = null

# --- NEW EXPORTS ---
# A path to the node in the scene you want to control.
@export var target_node: NodePath
# A toggle to determine if the target_node should be visible at this point.
@export var show_target_node: bool = false
