extends Node3D
class_name Rabbit

var cam : Camera3D

@onready var _rabbit_tail : MeshInstance3D = %rabbit_tail

func _process(_delta) -> void:
	_rabbit_tail.look_at(cam.global_position)
