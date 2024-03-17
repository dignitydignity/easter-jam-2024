extends Node3D

@export var _tree_trunk : MeshInstance3D

func _process(_delta : float) -> void:
	# "Billboard" the 2D treetrunk sprite.
	_tree_trunk.look_at(Player.instance.cam.global_position)
