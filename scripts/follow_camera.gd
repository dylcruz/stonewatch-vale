extends Camera3D

@export var subject: Node3D
@export var offset := Vector3(0, 22, 18)

func _ready() -> void:
	_follow()

func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	if is_instance_valid(subject):
		global_position = subject.global_position + offset
		look_at(subject.global_position)
