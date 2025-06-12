extends Line2D
func _ready() -> void:
	if !Engine.is_editor_hint():
		hide()
