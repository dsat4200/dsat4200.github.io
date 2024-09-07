extends Node2D

@export var page_sprites : SpriteFrames
@onready var scroll = get_parent()
var page_array
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_left_area_entered(area: Area2D) -> void:
	pass
	#rotate_page(area, 1)

func _on_right_area_entered(area: Area2D) -> void:
	pass
	#rotate_page(area,-1)

func rotate_page(area, delta):
	var sprite = area.get_parent()
	var page = sprite.get_parent()
	page.position.x += 1920*5*delta
	sprite.texture = page_sprites.get_frame_texture("default", (scroll.page / 2)+5*delta)
