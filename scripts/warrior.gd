extends "res://scripts/player.gd"

signal combat_message(message: String)

@export var stats: ValeCombatStats
@onready var health: ValeHealth = $Health
@onready var sword: Node3D = $Visual/Sword
var attack_cooldown := 0.0
var windup_remaining := 0.0
var swing_target: Node3D
var swing_tween: Tween
var hit_tween: Tween
var body_material: StandardMaterial3D
var spawn_position: Vector3

func _ready() -> void:
	spawn_position = global_position
	body_material = $Visual/Body.mesh.material.duplicate()
	$Visual/Body.material_override = body_material
	health.died.connect(_die)
	reset_combat()

func is_alive() -> bool:
	return health.current > 0

func request_move(point: Vector3, target: Node3D = null) -> bool:
	if not is_alive() or (is_instance_valid(target) and target.has_method("is_alive") and not target.is_alive()):
		return false
	if not super.request_move(point, target):
		return false
	_cancel_swing()
	if target is ValeWolf:
		command_changed.emit("Approaching road wolf")
	return true

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if selected_target is ValeWolf and not selected_target.is_alive():
		clear_combat_target()
		command_changed.emit("Wolf defeated · press R to reset the fight")
	super._physics_process(delta)
	if not selected_target is ValeWolf:
		return
	var target := selected_target as ValeWolf
	var in_range := ValeMelee.can_hit(self, target, stats.melee_range)
	if in_range:
		moving = false
		var direction := target.global_position - global_position
		visual.rotation.y = atan2(direction.x, direction.z)
	if is_instance_valid(swing_target):
		windup_remaining -= delta
		if windup_remaining <= 0.0:
			var victim := swing_target
			swing_target = null
			if victim == selected_target and ValeMelee.can_hit(self, victim, stats.melee_range):
				var applied: int = victim.receive_hit(stats.damage, self)
				combat_message.emit("Sword hits for %d" % applied)
			else:
				combat_message.emit("Sword misses · target out of reach")
	elif in_range and attack_cooldown <= 0.0:
		swing_target = target
		windup_remaining = stats.windup
		attack_cooldown = stats.attack_interval
		target.engage(self)
		command_changed.emit("Auto-attacking · ground click cancels")
		_animate_swing()

func _finish_command() -> void:
	if selected_target is ValeWolf:
		moving = false
	else:
		super._finish_command()

func _animate_swing() -> void:
	if swing_tween:
		swing_tween.kill()
	sword.rotation.y = -0.8
	swing_tween = create_tween()
	swing_tween.tween_property(sword, "rotation:y", 0.9, stats.windup)
	swing_tween.tween_property(sword, "rotation:y", 0.0, 0.12)

func _cancel_swing() -> void:
	swing_target = null
	windup_remaining = 0.0
	if swing_tween:
		swing_tween.kill()
	sword.rotation.y = 0.0

func clear_combat_target() -> void:
	_cancel_swing()
	if is_instance_valid(selected_target):
		selected_target.set_selected(false)
	selected_target = null
	moving = false
	velocity = Vector3.ZERO

func receive_hit(amount: int, _source: Node3D) -> int:
	var applied := health.take_damage(amount)
	if applied > 0:
		if hit_tween:
			hit_tween.kill()
		body_material.albedo_color = Color(1.0, 0.3, 0.25)
		hit_tween = create_tween()
		hit_tween.tween_property(body_material, "albedo_color", Color(0.18, 0.48, 0.72), 0.22)
	return applied

func _die() -> void:
	clear_combat_target()
	visual.rotation.z = 1.2
	command_changed.emit("Warrior defeated · press R or Reset fight")

func reset_combat() -> void:
	clear_combat_target()
	attack_cooldown = 0.0
	if hit_tween:
		hit_tween.kill()
	body_material.albedo_color = Color(0.18, 0.48, 0.72)
	visual.rotation = Vector3.ZERO
	global_position = spawn_position
	destination = spawn_position
	agent.target_position = spawn_position
	health.reset(stats.max_health)
