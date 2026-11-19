class_name ValeEnemy
extends CharacterBody3D

signal combat_message(message: String)
signal respawned

const PURSUIT_UPDATE_INTERVAL := 0.2
@export var stats: ValeCombatStats
@export var basic_attack_name := "Attack"
@export var aggro_target: Node3D
@export var aggro_range := 5.0
@export var leash_range := 10.0
@export var speed := 4.0
@export var encounter_id: StringName
@export_range(0.0, 600.0, 0.1, "or_greater", "suffix:s") var respawn_delay := 30.0
@onready var health: ValeHealth = $Health
@onready var visual: Node3D = $Visual
@onready var agent: NavigationAgent3D = $NavigationAgent3D
var opponent: Node3D
var attack_cooldown := 0.0
var windup_remaining := 0.0
var pursuit_update_remaining := 0.0
var attacking := false
var returning := false
var spawn_position: Vector3
var hit_tween: Tween
var body_material: StandardMaterial3D
var resting_color: Color
var defeat_reward_claimed := false
var _respawn_remaining := -1.0

func _ready() -> void:
	add_to_group(&"combat_enemies")
	spawn_position = global_position
	body_material = $Visual/Body.mesh.material.duplicate()
	$Visual/Body.material_override = body_material
	resting_color = body_material.albedo_color
	health.changed.connect(func(current: int, maximum: int):
		$Nameplate.text = "%s  %d / %d" % [stats.display_name.to_upper(), current, maximum])
	health.died.connect(_die)
	reset_combat()

func is_alive() -> bool:
	return health.current > 0

func set_selected(value: bool) -> void:
	$SelectionRing.visible = value and is_alive()

func attack_name() -> String:
	return basic_attack_name

func engage(attacker: Node3D) -> void:
	if is_alive() and not returning and _can_pursue(attacker):
		opponent = attacker

func _can_pursue(target: Node3D) -> bool:
	return is_instance_valid(target) and target.is_alive() and _is_in_encounter_area(target)

func _is_in_encounter_area(target: Node3D) -> bool:
	return spawn_position.distance_to(target.global_position) <= leash_range \
		and not (target.has_method("is_in_refuge") and target.is_in_refuge())

func _physics_process(delta: float) -> void:
	if not is_alive():
		_update_respawn(delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	_update_behavior(delta)
	move_and_slide()

func _update_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if returning:
		if global_position.distance_to(spawn_position) <= 0.3:
			returning = false
			attack_cooldown = 0.0
			health.reset(stats.max_health)
		else:
			_follow_path(delta)
		return
	if opponent == null and _can_pursue(aggro_target) and ValeMelee.can_hit(self, aggro_target, aggro_range):
		engage(aggro_target)
	if not is_instance_valid(opponent):
		if global_position.distance_to(spawn_position) > 0.3:
			_start_return()
		return
	if not _can_pursue(opponent) or global_position.distance_to(spawn_position) > leash_range:
		_start_return()
		return

	var in_range := ValeMelee.can_hit(self, opponent, stats.melee_range)
	if in_range:
		pursuit_update_remaining = 0.0
	if in_range and not attacking:
		var direction := opponent.global_position - global_position
		visual.rotation.y = atan2(direction.x, direction.z)
	if attacking:
		windup_remaining -= delta
		if windup_remaining <= 0.0:
			attacking = false
			_resolve_attack()
	elif in_range and attack_cooldown <= 0.0:
		_begin_attack()
	elif not in_range:
		pursuit_update_remaining -= delta
		if pursuit_update_remaining <= 0.0:
			pursuit_update_remaining = PURSUIT_UPDATE_INTERVAL
			agent.target_position = opponent.global_position
		if not _follow_path(delta):
			_start_return()

func _begin_attack() -> void:
	_start_windup(stats.windup)

func _start_windup(duration: float) -> void:
	attacking = true
	windup_remaining = duration
	attack_cooldown = maxf(stats.attack_interval, duration)
	_animate_attack(duration)

func _resolve_attack() -> void:
	if ValeMelee.can_hit(self, opponent, stats.melee_range):
		opponent.receive_hit(stats.damage, self, attack_name())
	else:
		combat_message.emit("%s misses · you moved clear" % attack_name())

func _animate_attack(_duration: float) -> void:
	pass

func _clear_attack_animation() -> void:
	pass

func _follow_path(delta: float) -> bool:
	var next := agent.get_next_path_position()
	if not agent.is_target_reachable() or agent.is_navigation_finished():
		return false
	var direction := next - global_position
	direction.y = 0.0
	var step := direction.limit_length(speed * delta) / delta
	velocity.x = step.x
	velocity.z = step.z
	if direction.length_squared() > 0.0001:
		visual.rotation.y = atan2(direction.x, direction.z)
	return true

func _start_return() -> void:
	opponent = null
	returning = true
	pursuit_update_remaining = 0.0
	_cancel_attack()
	agent.target_position = spawn_position

func _cancel_attack() -> void:
	attacking = false
	windup_remaining = 0.0
	_clear_attack_animation()

func receive_hit(amount: int, source: Node3D) -> int:
	var applied := health.take_damage(amount)
	$DamageNumbers.show_damage(applied)
	if applied > 0 and is_alive():
		engage(source)
		if hit_tween:
			hit_tween.kill()
		body_material.albedo_color = Color(1.0, 0.35, 0.25)
		hit_tween = create_tween()
		hit_tween.tween_property(body_material, "albedo_color", resting_color, 0.22)
	return applied

func _die() -> void:
	_cancel_attack()
	opponent = null
	returning = false
	velocity = Vector3.ZERO
	collision_layer = 0
	set_selected(false)
	if hit_tween:
		hit_tween.kill()
	visual.rotation.z = 1.4
	body_material.albedo_color = resting_color.darkened(0.5)
	$Nameplate.text = "%s · DEFEATED" % stats.display_name.to_upper()
	_respawn_remaining = respawn_delay

func _update_respawn(delta: float) -> void:
	if _respawn_remaining < 0.0:
		return
	_respawn_remaining = maxf(0.0, _respawn_remaining - delta)
	if _respawn_remaining > 0.0 or not is_instance_valid(aggro_target):
		return
	if _is_in_encounter_area(aggro_target):
		return
	reset_combat()
	respawned.emit()

func encounter_checkpoint() -> Dictionary:
	return {"respawn_remaining": _respawn_remaining, "reward_claimed": defeat_reward_claimed}

func restore_encounter(checkpoint: Dictionary) -> void:
	defeat_reward_claimed = checkpoint.get("reward_claimed") == true
	var remaining: Variant = checkpoint.get("respawn_remaining")
	if remaining is float and is_finite(remaining) and remaining >= 0.0:
		health.take_damage(health.current)
		_respawn_remaining = minf(remaining, respawn_delay)

func reset_combat() -> void:
	_respawn_remaining = -1.0
	_cancel_attack()
	opponent = null
	returning = false
	attack_cooldown = 0.0
	pursuit_update_remaining = 0.0
	if hit_tween:
		hit_tween.kill()
	body_material.albedo_color = resting_color
	global_position = spawn_position
	agent.target_position = spawn_position
	velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	collision_layer = 8
	health.reset(stats.max_health)
	set_selected(false)
