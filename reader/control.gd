
extends Control
signal next_page
signal prev_page

func _process(delta: float) -> void:
		if Input.is_action_just_pressed("arrowkey_next"):
			emit_signal("next_page")
		elif Input.is_action_just_pressed("arrowkey_prev"):
			emit_signal("prev_page")


func _on_rightbutton_button_up() -> void:
	emit_signal("next_page")


func _on_leftbutton_button_up() -> void:
	emit_signal("prev_page")
