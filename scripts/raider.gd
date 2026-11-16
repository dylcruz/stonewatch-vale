class_name ValeRaider
extends ValeEnemy

@export var heavy_damage := 0
@export var heavy_radius := 2.2
@export var heavy_windup := 1.2
@export var heavy_cooldown := 5.5
@onready var weapon: Node3D = $Visual/Weapon
@onready var telegraph: Node3D = $HeavyTelegraph
var heavy_attacking := false
var heavy_cooldown_remaining := 0.0
var attack_tween: Tween

func attack_name() -> String:
	return "Heavy attack" if heavy_attacking else super.attack_name()

func _update_behavior(delta: float) -> void:
	heavy_cooldown_remaining = maxf(0.0, heavy_cooldown_remaining - delta)
	super._update_behavior(delta)

func _begin_attack() -> void:
	if heavy_damage <= 0 or heavy_cooldown_remaining > 0.0:
		super._begin_attack()
		return
	heavy_attacking = true
	heavy_cooldown_remaining = heavy_cooldown
	telegraph.global_position = opponent.global_position + Vector3.UP * 0.055
	telegraph.scale = Vector3(heavy_radius, 1.0, heavy_radius)
	telegraph.show()
	_start_windup(heavy_windup)

func _resolve_attack() -> void:
	if not heavy_attacking:
		super._resolve_attack()
		return
	var offset := opponent.global_position - telegraph.global_position
	offset.y = 0.0
	if offset.length_squared() <= heavy_radius * heavy_radius and ValeMelee.has_line_of_sight(self, opponent):
		opponent.receive_hit(heavy_damage, self, attack_name())
	else:
		combat_message.emit("Heavy attack misses · you moved clear")
	heavy_attacking = false
	telegraph.hide()

func _animate_attack(duration: float) -> void:
	if attack_tween:
		attack_tween.kill()
	weapon.rotation = Vector3.ZERO
	attack_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if heavy_attacking:
		attack_tween.tween_property(weapon, "rotation:x", -1.65, duration * 0.35)
		attack_tween.tween_interval(duration * 0.65)
		attack_tween.tween_property(weapon, "rotation:x", 0.8, 0.12)
		attack_tween.tween_property(weapon, "rotation:x", 0.0, 0.2)
	else:
		attack_tween.tween_property(weapon, "rotation:y", -1.15, duration)
		attack_tween.tween_property(weapon, "rotation:y", 1.0, 0.12)
		attack_tween.tween_property(weapon, "rotation:y", 0.0, 0.18)

func _clear_attack_animation() -> void:
	if attack_tween:
		attack_tween.kill()
	weapon.rotation = Vector3.ZERO
	heavy_attacking = false
	telegraph.hide()

func reset_combat() -> void:
	super.reset_combat()
	heavy_cooldown_remaining = 0.0
