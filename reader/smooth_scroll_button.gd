extends Button

func _on_toggled(toggled_on: bool) -> void:
	var state = "OFF"
	if (toggled_on): state = "ON"
	text = "Smooth Scroll: "+ state
