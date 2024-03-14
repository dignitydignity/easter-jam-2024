extends Node3D
class_name Main

@onready var cam : Camera3D = %Camera

func _process(_delta):
	# TODO: This might lead to performance issues.
	# Instead, maybe we should inject the "cam" dependency only
	# when a new rabbit is spawned.
	var rabbits = find_children("","Rabbit")
	for r in rabbits:
		var r_as_rabbit = r as Rabbit
		r_as_rabbit.cam = cam
