class_name ValePlayer
extends CharacterBody3D
## A reusable click-command motor. Only complete navigation paths are accepted.
signal command_changed(message: String)

@export var speed: float = 5.0
@export var interaction_distance: float = 1.6
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual
var selected_target: Node3D
var moving := false
var destination := Vector3.ZERO

func request_move(point: Vector3, target: Node3D = null) -> bool:
	var map := agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var goal := NavigationServer3D.map_get_closest_point(map, point)
	# Do not turn clicks on void, disconnected islands, or scenery into nearby moves.
	if goal.distance_to(point) > 0.55:
		return false
	var path := NavigationServer3D.map_get_path(map, global_position, goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > 0.15:
		return false
	if is_instance_valid(selected_target):
		selected_target.set_selected(false)
	selected_target = target
	if is_instance_valid(selected_target):
		selected_target.set_selected(true)
	destination = goal
	agent.target_position = goal
	moving = true
	command_changed.emit("Approaching practice target" if target != null else "Moving to destination")
	return true

func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	if moving:
		if is_instance_valid(selected_target) and global_position.distance_to(selected_target.global_position) <= interaction_distance:
			_finish_command()
		elif agent.is_navigation_finished():
			_finish_command()
		else:
			var next := agent.get_next_path_position()
			var direction := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
			# Clamp the last step so a low frame rate cannot overshoot a waypoint.
			var step_speed := minf(speed, direction.length() / delta)
			if direction.length_squared() > 0.0001:
				direction = direction.normalized()
				velocity.x = direction.x * step_speed
				velocity.z = direction.z * step_speed
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 14.0))
	move_and_slide()

func _finish_command() -> void:
	moving = false
	if is_instance_valid(selected_target):
		var direction := selected_target.global_position - global_position
		visual.rotation.y = atan2(direction.x, direction.z)
		command_changed.emit("Practice target selected · in range (combat comes next)")
	else:
		command_changed.emit("Destination reached")
