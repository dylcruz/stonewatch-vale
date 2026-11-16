extends "res://scripts/world_input.gd"

@export var recovery_delay := 2.0
@export var ready_text := "Ready"
@onready var wolf: ValeWolf = $Wolf
@onready var combat_hud: VBoxContainer = $HUD/CombatPanel/Margin/VBox
@onready var cleave_status: Label = $HUD/CombatPanel/Margin/VBox/CleaveStatus
@onready var guard_status: Label = $HUD/CombatPanel/Margin/VBox/GuardStatus
var enemies: Array[ValeEnemy] = []
var last_focused_enemy: ValeEnemy
var recovery_remaining := 0.0

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is ValeEnemy:
			enemies.append(child)
			child.aggro_target = player
			child.combat_message.connect(_show_hit)
	player.combat_message.connect(_show_hit)
	player.health.died.connect(_start_recovery)
	status.text = ready_text

func _process(_delta: float) -> void:
	combat_hud.get_node("WarriorHealth").max_value = player.health.maximum
	combat_hud.get_node("WarriorHealth").value = player.health.current
	combat_hud.get_node("WarriorName").text = "Warrior Lv. %d   %d / %d HP" % [
		player.level, player.health.current, player.health.maximum]
	var enemy := _focused_enemy()
	last_focused_enemy = enemy
	combat_hud.get_node("EnemyHealth").max_value = enemy.health.maximum
	combat_hud.get_node("EnemyHealth").value = enemy.health.current
	combat_hud.get_node("EnemyName").text = "%s   %d / %d HP" % [
		enemy.stats.display_name, enemy.health.current, enemy.health.maximum]
	var sword_state := "Sword ready"
	if is_instance_valid(player.swing_target):
		sword_state = "Sword windup"
	elif player.attack_cooldown > 0.0:
		sword_state = "Sword recovery %.1fs" % player.attack_cooldown
	if not player.is_alive():
		sword_state = "Warrior defeated"
	var timing: Label = combat_hud.get_node("Timing")
	var heavy_windup := false
	for threat in enemies:
		if threat is ValeRaider and threat.heavy_attacking:
			heavy_windup = true
			break
	timing.text = "Heavy attack · move or Guard" if heavy_windup else sword_state + "  ·  " + _enemy_status(enemy)
	timing.modulate = Color(1.0, 0.52, 0.35) if heavy_windup else Color.WHITE
	_update_abilities()

func _update_abilities() -> void:
	if not player.has_cleave():
		cleave_status.text = "1 · Cleave unlocks at level 2"
	elif not player.is_alive():
		cleave_status.text = "1 · Cleave unavailable"
	elif player.cleave_cooldown_remaining > 0.0:
		cleave_status.text = "1 · Cleave cooldown %.1fs" % player.cleave_cooldown_remaining
	else:
		cleave_status.text = "1 · Cleave ready"

	guard_status.modulate = Color.WHITE
	if not player.is_alive():
		guard_status.text = "2 · Guard unavailable"
	elif player.guard_remaining > 0.0:
		guard_status.text = "2 · Guard active %.1fs" % player.guard_remaining
		guard_status.modulate = Color(0.37, 0.85, 1.0)
	elif player.guard_cooldown_remaining > 0.0:
		guard_status.text = "2 · Guard cooldown %.1fs" % player.guard_cooldown_remaining
	else:
		guard_status.text = "2 · Guard ready"

func _focused_enemy() -> ValeEnemy:
	if player.selected_target is ValeEnemy and player.selected_target.is_alive():
		return player.selected_target
	for enemy in enemies:
		if enemy.attacking:
			return enemy
	for enemy in enemies:
		if is_instance_valid(enemy.opponent) or enemy.returning:
			return enemy
	return last_focused_enemy if is_instance_valid(last_focused_enemy) else wolf

func _enemy_status(enemy: ValeEnemy) -> String:
	var enemy_name := enemy.stats.display_name
	if not enemy.is_alive():
		return "%s defeated" % enemy_name
	if enemy.returning:
		return "%s returning" % enemy_name
	if enemy.attacking:
		return "%s %s windup" % [enemy_name, enemy.attack_name().to_lower()]
	if is_instance_valid(enemy.opponent):
		return "%s pursuing" % enemy_name if enemy.velocity.length_squared() > 0.05 else "%s recovering" % enemy_name
	return "%s idle" % enemy_name

func _physics_process(delta: float) -> void:
	if player.is_alive():
		super._physics_process(delta)
		return
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	status.text = "Returning to the watchpost in %.1fs" % recovery_remaining
	if recovery_remaining <= 0.0:
		player.reset_combat()
		status.text = "Recovered at the watchpost"
		_show_hit("You recovered at full health.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cleave"):
		player.activate_cleave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"guard"):
		player.activate_guard()
		get_viewport().set_input_as_handled()
	elif player.is_alive():
		super._unhandled_input(event)

func _show_hit(message: String) -> void:
	combat_hud.get_node("LastHit").text = message

func _start_recovery() -> void:
	recovery_remaining = recovery_delay
	_stop_following_cursor()
	_hide_marker()

func _hide_marker() -> void:
	if marker_tween:
		marker_tween.kill()
	marker.hide()
