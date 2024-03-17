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
	# Randomize the rabbit's color.
	var mat_body := _rabbit_body.get_surface_override_material(0) as ORMMaterial3D
	var mat_tail := _rabbit_tail.get_surface_override_material(0) as ORMMaterial3D
	var rand_color := Color(Main.rng.randf(), Main.rng.randf(), Main.rng.randf())
	# Random color must be bright for face details to be visible.
	while rand_color.get_luminance() < 0.9:
		rand_color = Color(Main.rng.randf(), Main.rng.randf(), Main.rng.randf())
	mat_body.albedo_color = rand_color
	mat_tail.albedo_color = rand_color
	# Materials shouldn't be shared so that rabbit colors are unique.
	assert(mat_body.is_local_to_scene())
	assert(mat_tail.is_local_to_scene())

func _process(_delta : float) -> void:
	# "Billboard" the 2D tail sprite.
	_rabbit_tail.look_at(Player.instance.cam.global_position)

