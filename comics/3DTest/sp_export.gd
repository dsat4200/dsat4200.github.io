extends Node3D
@export var animplayer:AnimationPlayer

func _ready():
	print(animplayer.get_animation_list())
	animplayer.play(animplayer.get_animation_list()[1])
