@tool
extends AnimationPlayer
@export var path_follow:PathFollow2D
@export var progress:float
@export var start_anim: String
@export var edit_mode:bool
var selected = false;

func _ready() -> void:
	current_animation = start_anim
	if !Engine.is_editor_hint():
		edit_mode = false
		set_path_preview(false)

	
	
func set_path_preview(val:bool):
	current_animation = start_anim
	get_animation(current_animation).track_set_enabled(0,val)
	
func _process(delta: float) -> void:
	if !edit_mode and !selected:
		progress = path_follow.progress_ratio*current_animation_length
		seek(progress, true, true)


func _on_point_data_clicked_point(index: Variant, progress: Variant) -> void:
	pass # Replace with function body.
	
func select_point(p_ratio):
	set_path_preview(false)
	print("message recieved "+str(p_ratio))
	selected = true
	progress = p_ratio
	
func deselect_point():
	set_path_preview(true)
	selected = false
