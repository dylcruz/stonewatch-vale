class_name ValeMelee
extends RefCounted

static func can_hit(attacker: Node3D, target: Node3D, reach: float) -> bool:
	if not is_instance_valid(target) or not target.is_alive():
		return false
	var separation := target.global_position - attacker.global_position
	separation.y = 0.0
	if separation.length() > reach:
		return false
	# Scenery also blocks a swing that happens to be within melee range.
	var query := PhysicsRayQueryParameters3D.create(attacker.global_position + Vector3.UP,
		target.global_position + Vector3.UP, 2)
	return attacker.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
