class_name ValeWolf
extends ValeEnemy

@onready var head: Node3D = $Visual/Head
var bite_tween: Tween
var biting: bool:
	get:
		return attacking

func _animate_attack(duration: float) -> void:
	_clear_attack_animation()
	bite_tween = create_tween()
	bite_tween.tween_property(head, "position:z", 0.9, duration)
	bite_tween.tween_property(head, "position:z", 0.55, 0.12)

func _clear_attack_animation() -> void:
	if bite_tween:
		bite_tween.kill()
	head.position.z = 0.55
