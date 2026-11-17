extends "res://scripts/player.gd"

signal combat_message(message: String)
signal progression_changed

const PURSUIT_UPDATE_INTERVAL := 0.15
const PURSUIT_UPDATE_DISTANCE := 0.4
const BODY_COLOR := Color(0.18, 0.48, 0.72)
const CLEAVE_UNLOCK_LEVEL := 2
const LEVEL_TWO_XP := 100
const LEVEL_THREE_XP := 240

@export var stats: ValeCombatStats
@export var level := 1
@export var health_per_level := 0
@export var starting_weapon: ValeItem
@export var starting_armor: ValeItem
@export var starting_bag: ValeItem
@export var starting_supplies: Array[ValeItem] = []
@export var recovery_point: Node3D
@export var refuge_radius := 2.5
@export var cleave_damage := 12
@export var cleave_range := 2.8
@export_range(1.0, 90.0) var cleave_half_angle := 65.0
@export var cleave_cooldown := 4.0
@export_range(0.1, 10.0, 0.05) var guard_duration := 1.25
@export_range(0.1, 30.0, 0.05) var guard_cooldown := 6.0
@export_range(0.0, 1.0, 0.05) var guard_reduction := 0.5
@onready var health: ValeHealth = $Health
@onready var sword: Node3D = $Visual/Sword
@onready var blade: MeshInstance3D = $Visual/Sword/Blade
@onready var guard_ring: MeshInstance3D = $GuardRing
@onready var cleave_arc: MeshInstance3D = $CleaveArc
var attack_cooldown := 0.0
var windup_remaining := 0.0
var guard_remaining := 0.0
var guard_cooldown_remaining := 0.0
var cleave_cooldown_remaining := 0.0
var cleave_flash_remaining := 0.0
var pursuit_update_remaining := 0.0
var swing_target: Node3D
var swing_tween: Tween
var hit_tween: Tween
var body_material: StandardMaterial3D
var blade_material: StandardMaterial3D
var spawn_position: Vector3
var experience := 0
var owned_items: Dictionary[StringName, ValeItem] = {}
var equipped_weapon: ValeItem
var equipped_armor: ValeItem
var equipped_bag: ValeItem
var waiting_rewards: Dictionary[StringName, ValeItem] = {}
var bag_feedback := ""

func _ready() -> void:
	spawn_position = global_position
	body_material = $Visual/Body.mesh.material.duplicate()
	$Visual/Body.material_override = body_material
	blade_material = blade.mesh.material.duplicate()
	blade.material_override = blade_material
	for item: ValeItem in [starting_bag, starting_weapon, starting_armor]:
		if item and item.id != &"":
			owned_items[item.id] = item
			equip_item(item.id)
	for item in starting_supplies:
		grant_item(item)
	health.died.connect(_die)
	_build_cleave_arc()
	reset_combat()

func is_alive() -> bool:
	return health.current > 0

func request_move(point: Vector3, target: Node3D = null) -> bool:
	if not is_alive() or (is_instance_valid(target) and target.has_method("is_alive") and not target.is_alive()):
		return false
	if target is ValeEnemy or target is ValeInteractable:
		point = target.global_position
	if not super.request_move(point, target):
		return false
	_cancel_swing()
	if target is ValeEnemy:
		pursuit_update_remaining = PURSUIT_UPDATE_INTERVAL
		command_changed.emit("Approaching %s" % target.stats.display_name)
	elif target is ValeInteractable:
		command_changed.emit("Approaching %s" % target.display_name)
	return true

func is_in_refuge() -> bool:
	return is_instance_valid(recovery_point) and global_position.distance_to(recovery_point.global_position) <= refuge_radius

func activate_guard() -> bool:
	if not is_alive() or guard_remaining > 0.0 or guard_cooldown_remaining > 0.0:
		return false
	guard_remaining = guard_duration
	guard_cooldown_remaining = guard_cooldown
	guard_ring.show()
	return true

func has_cleave() -> bool:
	return level >= CLEAVE_UNLOCK_LEVEL

func award_experience(amount: int) -> void:
	var previous_experience := experience
	experience = clampi(experience + maxi(0, amount), 0, LEVEL_THREE_XP)
	if experience >= LEVEL_THREE_XP:
		level = 3
	elif experience >= LEVEL_TWO_XP:
		level = maxi(level, 2)
	health.increase_maximum(maximum_health())
	if experience != previous_experience:
		progression_changed.emit()

func next_level_experience() -> int:
	match level:
		1:
			return LEVEL_TWO_XP
		2:
			return LEVEL_THREE_XP
		_:
			return 0

func maximum_health() -> int:
	return stats.max_health + (level - 1) * health_per_level

func grant_item(item: ValeItem) -> bool:
	if item == null or item.id == &"" or owned_items.has(item.id) or waiting_rewards.has(item.id):
		return false
	if free_bag_slots() <= 0:
		waiting_rewards[item.id] = item
		bag_feedback = "Bag is full. %s is waiting to be claimed." % item.display_name
		return false
	owned_items[item.id] = item
	return true

func claim_reward(item_id: StringName) -> bool:
	var item := waiting_rewards.get(item_id) as ValeItem
	if item == null:
		return false
	if free_bag_slots() <= 0:
		bag_feedback = "Bag is full. %s is waiting to be claimed." % item.display_name
		return false
	waiting_rewards.erase(item_id)
	owned_items[item_id] = item
	bag_feedback = "%s added to your bag." % item.display_name
	return true

func stored_items() -> Array[ValeItem]:
	var items: Array[ValeItem] = []
	for item in owned_items.values():
		if item != equipped_weapon and item != equipped_armor and item != equipped_bag:
			items.append(item)
	return items

func bag_capacity() -> int:
	return equipped_bag.bag_slots if equipped_bag else 0

func free_bag_slots() -> int:
	return bag_capacity() - stored_items().size()

func equip_item(item_id: StringName) -> bool:
	var item := owned_items.get(item_id) as ValeItem
	if item == null:
		return false
	bag_feedback = ""
	if item.slot == ValeItem.Slot.BAG:
		var slots_after_swap := stored_items().size() - (0 if equipped_bag else 1)
		if slots_after_swap > item.bag_slots:
			bag_feedback = "%s has %d slots. Your stored items need %d." % [
				item.display_name, item.bag_slots, slots_after_swap]
			return false
		equipped_bag = item
	elif item.slot == ValeItem.Slot.WEAPON:
		equipped_weapon = item
		blade_material.albedo_color = item.blade_color
	elif item.slot == ValeItem.Slot.ARMOR:
		equipped_armor = item
		if hit_tween:
			hit_tween.kill()
		body_material.albedo_color = _coat_color()
	else:
		return false
	return true

func sword_damage() -> int:
	return stats.damage + (equipped_weapon.bonus_damage if equipped_weapon else 0)

func armor_value() -> int:
	return equipped_armor.armor if equipped_armor else 0

func _coat_color() -> Color:
	return equipped_armor.coat_color if equipped_armor else BODY_COLOR

func activate_cleave() -> bool:
	if not is_alive() or not has_cleave() or cleave_cooldown_remaining > 0.0:
		return false
	cleave_cooldown_remaining = cleave_cooldown
	cleave_flash_remaining = 0.18
	cleave_arc.global_transform = Transform3D(
		Basis(Vector3.UP, visual.global_rotation.y), global_position + Vector3.UP * 0.08)
	cleave_arc.show()
	var forward := cleave_arc.global_basis.z
	var minimum_dot := cos(deg_to_rad(cleave_half_angle))
	var hits := 0
	for enemy: ValeEnemy in get_tree().get_nodes_in_group(&"combat_enemies"):
		if enemy.get_world_3d() != get_world_3d() or not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if not offset.is_zero_approx() and forward.dot(offset.normalized()) < minimum_dot:
			continue
		if ValeMelee.can_hit(self, enemy, cleave_range):
			enemy.receive_hit(cleave_damage, self)
			hits += 1
	if hits == 0:
		combat_message.emit("Cleave misses")
	else:
		combat_message.emit("Cleave hits %d %s" % [hits, "enemy" if hits == 1 else "enemies"])
	return true

func _build_cleave_arc() -> void:
	var arc := ImmediateMesh.new()
	var half_angle := deg_to_rad(cleave_half_angle)
	arc.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 24:
		var start := lerpf(-half_angle, half_angle, segment / 24.0)
		var end := lerpf(-half_angle, half_angle, (segment + 1) / 24.0)
		arc.surface_add_vertex(Vector3.ZERO)
		arc.surface_add_vertex(Vector3(sin(start), 0.0, cos(start)) * cleave_range)
		arc.surface_add_vertex(Vector3(sin(end), 0.0, cos(end)) * cleave_range)
	arc.surface_end()
	cleave_arc.mesh = arc

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	guard_remaining = maxf(0.0, guard_remaining - delta)
	guard_cooldown_remaining = maxf(0.0, guard_cooldown_remaining - delta)
	guard_ring.visible = guard_remaining > 0.0
	cleave_cooldown_remaining = maxf(0.0, cleave_cooldown_remaining - delta)
	cleave_flash_remaining = maxf(0.0, cleave_flash_remaining - delta)
	cleave_arc.visible = cleave_flash_remaining > 0.0
	pursuit_update_remaining = maxf(0.0, pursuit_update_remaining - delta)
	if selected_target is ValeEnemy:
		if not selected_target.is_alive():
			var defeated_name: String = selected_target.stats.display_name
			clear_combat_target()
			command_changed.emit("%s defeated" % defeated_name)
		elif pursuit_update_remaining <= 0.0 and not _is_target_in_range():
			pursuit_update_remaining = PURSUIT_UPDATE_INTERVAL
			var target_position := selected_target.global_position
			if not moving or target_position.distance_to(destination) > PURSUIT_UPDATE_DISTANCE:
				if _set_movement_destination(target_position):
					command_changed.emit("Approaching %s" % selected_target.stats.display_name)
	super._physics_process(delta)
	if not selected_target is ValeEnemy:
		return
	var target := selected_target as ValeEnemy
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
				var applied: int = victim.receive_hit(sword_damage(), self)
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

func _is_target_in_range() -> bool:
	if selected_target is ValeEnemy:
		return ValeMelee.can_hit(self, selected_target, stats.melee_range)
	if selected_target is ValeInteractable:
		return selected_target.is_in_range(self)
	return super._is_target_in_range()

func _finish_command() -> void:
	if selected_target is ValeEnemy:
		moving = false
	elif selected_target is ValeInteractable:
		var target := selected_target as ValeInteractable
		clear_combat_target()
		if target.is_in_range(self):
			var direction := target.global_position - global_position
			visual.rotation.y = atan2(direction.x, direction.z)
			command_changed.emit("Speaking with %s" % target.display_name)
			target.interacted.emit()
		else:
			command_changed.emit("Couldn't reach %s" % target.display_name)
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

func receive_hit(amount: int, source: Node3D, attack_name := "") -> int:
	if not is_alive():
		return 0
	var after_armor := maxi(0, amount - armor_value())
	var damage := roundi(after_armor * (1.0 - guard_reduction)) if guard_remaining > 0.0 else after_armor
	var applied := health.take_damage(damage)
	if applied > 0:
		if hit_tween:
			hit_tween.kill()
		body_material.albedo_color = Color(1.0, 0.3, 0.25)
		hit_tween = create_tween()
		hit_tween.tween_property(body_material, "albedo_color", _coat_color(), 0.22)
	var hit_text := "Hit for %d" % applied
	if source is ValeEnemy and not attack_name.is_empty():
		hit_text = "%s %s · %d damage" % [source.stats.display_name, attack_name.to_lower(), applied]
	if damage < after_armor:
		hit_text += " · Guard blocked %d" % (after_armor - damage)
	combat_message.emit(hit_text)
	return applied

func _die() -> void:
	clear_combat_target()
	guard_remaining = 0.0
	guard_ring.hide()
	cleave_arc.hide()
	visual.rotation.z = 1.2

func reset_combat() -> void:
	clear_combat_target()
	attack_cooldown = 0.0
	guard_remaining = 0.0
	guard_cooldown_remaining = 0.0
	guard_ring.hide()
	cleave_cooldown_remaining = 0.0
	cleave_flash_remaining = 0.0
	cleave_arc.hide()
	if hit_tween:
		hit_tween.kill()
	body_material.albedo_color = _coat_color()
	visual.rotation = Vector3.ZERO
	global_position = recovery_point.global_position if is_instance_valid(recovery_point) else spawn_position
	destination = global_position
	agent.target_position = global_position
	health.reset(maximum_health())
