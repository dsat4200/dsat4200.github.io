@tool
extends AnimationPlayer
@export var path_follow:PathFollow2D
@export var progress:float
@export var start_anim: String
@export var edit_mode:bool

func _ready() -> void:
	current_animation = start_anim

func _process(delta: float) -> void:
	if !edit_mode:
		progress = path_follow.progress_ratio*current_animation_length
		seek(progress, true, true)
