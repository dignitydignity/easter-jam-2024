extends Node3D
class_name Rabbit

var cam : Camera3D

@onready var _rabbit_body : MeshInstance3D = %rabbit_body
@onready var _rabbit_tail : MeshInstance3D = %rabbit_tail

func _ready() -> void:
	var mat_body := _rabbit_body.get_surface_override_material(0)
	var mat_tail := _rabbit_tail.get_surface_override_material(0)
	var rand_color := Color(randf(), randf(), randf())
	mat_body.set("albedo_color", rand_color)
	mat_tail.set("albedo_color", rand_color)

func _process(_delta) -> void:
	# Tail is 2D and should billboard.
	_rabbit_tail.look_at(cam.global_position)
	
