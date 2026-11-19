extends AudioStreamPlayer3D

func _physics_process(_delta: float) -> void:
	var listener := get_viewport().get_audio_listener_3d()
	if not listener:
		return
	var in_range := global_position.distance_squared_to(listener.global_position) < max_distance * max_distance
	if in_range and not playing:
		play()
	elif not in_range and playing:
		stop()
