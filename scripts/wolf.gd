class_name ValeWolf
extends CharacterBody3D
## First fight checkpoint: retaliates in melee, without roaming or pursuit yet.

signal combat_message(message: String)

@export var stats: ValeCombatStats
@onready var health: ValeHealth = $Health
@onready var visual: Node3D = $Visual
var opponent: Node3D
var attack_cooldown := 0.0
var windup_remaining := 0.0
var biting := false
var spawn_position: Vector3
var bite_tween: Tween
var hit_tween: Tween
var body_material: StandardMaterial3D

func _ready() -> void:
	spawn_position = global_position
	body_material = $Visual/Body.mesh.material.duplicate()
	$Visual/Body.material_override = body_material
	health.changed.connect(func(current: int, maximum: int):
		$Nameplate.text = "ROAD WOLF  %d / %d" % [current, maximum])
	health.died.connect(_die)
	reset_combat()

func is_alive() -> bool:
	return health.current > 0

func set_selected(value: bool) -> void:
	$SelectionRing.visible = value and is_alive()

func engage(attacker: Node3D) -> void:
	if is_alive() and attacker.is_alive():
		opponent = attacker

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not is_instance_valid(opponent) or not opponent.is_alive():
		biting = false
		return
	var in_range := ValeMelee.can_hit(self, opponent, stats.melee_range)
	if in_range:
		var direction := opponent.global_position - global_position
		visual.rotation.y = atan2(direction.x, direction.z)
	if biting:
		windup_remaining -= delta
		if windup_remaining <= 0.0:
			biting = false
			if ValeMelee.can_hit(self, opponent, stats.melee_range):
				var applied: int = opponent.receive_hit(stats.damage, self)
				combat_message.emit("Wolf bites for %d" % applied)
			else:
				combat_message.emit("Wolf bite misses · you moved clear")
	elif in_range and attack_cooldown <= 0.0:
		biting = true
		windup_remaining = stats.windup
		attack_cooldown = stats.attack_interval
		if bite_tween:
			bite_tween.kill()
		$Visual/Head.position.z = 0.55
		bite_tween = create_tween()
		bite_tween.tween_property($Visual/Head, "position:z", 0.9, stats.windup)
		bite_tween.tween_property($Visual/Head, "position:z", 0.55, 0.12)

func receive_hit(amount: int, source: Node3D) -> int:
	var applied := health.take_damage(amount)
	if applied > 0 and is_alive():
		engage(source)
		if hit_tween:
			hit_tween.kill()
		body_material.albedo_color = Color(1.0, 0.35, 0.25)
		hit_tween = create_tween()
		hit_tween.tween_property(body_material, "albedo_color", Color(0.48, 0.53, 0.57), 0.22)
	return applied

func _die() -> void:
	biting = false
	opponent = null
	collision_layer = 0
	set_selected(false)
	if bite_tween:
		bite_tween.kill()
	if hit_tween:
		hit_tween.kill()
	visual.rotation.z = 1.4
	body_material.albedo_color = Color(0.24, 0.26, 0.28)
	$Nameplate.text = "ROAD WOLF · DEFEATED"

func reset_combat() -> void:
	biting = false
	opponent = null
	attack_cooldown = 0.0
	windup_remaining = 0.0
	if bite_tween:
		bite_tween.kill()
	if hit_tween:
		hit_tween.kill()
	$Visual/Head.position.z = 0.55
	body_material.albedo_color = Color(0.48, 0.53, 0.57)
	global_position = spawn_position
	visual.rotation = Vector3.ZERO
	collision_layer = 8
	health.reset(stats.max_health)
	set_selected(false)
