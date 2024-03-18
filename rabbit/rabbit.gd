extends CharacterBody3D
class_name Rabbit

# TODO: Ear physics?
# TODO: Color patterns / "rabbit types"?
# TODO: Player detection.
# TODO: Rabbit movement (two jump types, two states: wander, flee).

@export_group("References")
@export var _rabbit_body : MeshInstance3D
@export var _rabbit_tail : MeshInstance3D

func _ready() -> void:
	# Randomize the rabbit's color. Color must be bright for details to be visible.
	var mat_body := _rabbit_body.get_surface_override_material(0) as ORMMaterial3D
	var mat_tail := _rabbit_tail.get_surface_override_material(0) as ORMMaterial3D
	var rand_color := Color(Main.rng.randf(), Main.rng.randf(), Main.rng.randf())
	while rand_color.get_luminance() < .9:
		rand_color = rand_color.lightened(.01)
	mat_body.albedo_color = rand_color
	mat_tail.albedo_color = rand_color
	mat_body.emission = rand_color
	mat_tail.emission = rand_color
	# Materials shouldn't be shared so that rabbit colors are unique.
	assert(mat_body.is_local_to_scene())
	assert(mat_tail.is_local_to_scene())
