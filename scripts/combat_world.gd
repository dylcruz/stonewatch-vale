extends "res://scripts/world_input.gd"

@export var idle_preview_enemy: ValeEnemy
@export var recovery_delay := 2.0
@export var recovery_location := "the watchpost"
@export var ready_text := "Ready"
@onready var combat_hud: VBoxContainer = $HUD/CombatPanel/Margin/VBox
@onready var enemy_name: Label = $HUD/CombatPanel/Margin/VBox/EnemyName
@onready var enemy_health: ProgressBar = $HUD/CombatPanel/Margin/VBox/EnemyHealth
@onready var ability_hud: ValeAbilityHUD = $HUD/AbilityHUD
@onready var last_hit: Label = $HUD/CombatPanel/Margin/VBox/LastHit
var enemies: Array[ValeEnemy] = []
var last_focused_enemy: ValeEnemy
var recovery_remaining := 0.0

func _ready() -> void:
	super._ready()
	ability_hud.bind_player(player as ValeWarrior)
	for child in find_children("*", "CharacterBody3D", true, false):
		if child is ValeEnemy:
			enemies.append(child)
			child.aggro_target = player
			child.combat_message.connect(_show_hit)
	player.combat_message.connect(_show_hit)
	player.health.died.connect(_start_recovery)
	last_hit.visible = not last_hit.text.is_empty()
	status.text = ready_text

func _process(_delta: float) -> void:
	combat_hud.get_node("WarriorHealth").max_value = player.health.maximum
	combat_hud.get_node("WarriorHealth").value = player.health.current
	combat_hud.get_node("WarriorName").text = "Warrior Lv. %d   %d / %d HP" % [
		player.level, player.health.current, player.health.maximum]
	var enemy := _focused_enemy()
	last_focused_enemy = enemy
	enemy_name.visible = enemy != null
	enemy_health.visible = enemy != null
	if enemy:
		enemy_health.max_value = enemy.health.maximum
		enemy_health.value = enemy.health.current
		enemy_name.text = "%s   %d / %d HP" % [enemy.stats.display_name, enemy.health.current, enemy.health.maximum]
	var sword_state := "Sword ready"
	if is_instance_valid(player.swing_target):
		sword_state = "Sword windup"
	elif player.attack_cooldown > 0.0:
		sword_state = "Sword recovery %.1fs" % player.attack_cooldown
	if not player.is_alive():
		sword_state = "Warrior defeated"
	if enemy:
		sword_state += "  ·  " + _enemy_status(enemy)
	var timing: Label = combat_hud.get_node("Timing")
	var heavy_windup := false
	for threat in enemies:
		if threat is ValeRaider and threat.heavy_attacking:
			heavy_windup = true
			break
	timing.text = "Heavy attack · move or Guard" if heavy_windup else sword_state
	timing.modulate = Color(1.0, 0.52, 0.35) if heavy_windup else Color.WHITE

func _focused_enemy() -> ValeEnemy:
	if player.selected_target is ValeEnemy and player.selected_target.is_alive():
		return player.selected_target
	for enemy in enemies:
		if enemy.attacking:
			return enemy
	for enemy in enemies:
		if is_instance_valid(enemy.opponent) or enemy.returning:
			return enemy
	if is_instance_valid(last_focused_enemy):
		return last_focused_enemy
	return idle_preview_enemy

func _enemy_status(enemy: ValeEnemy) -> String:
	var display_name := enemy.stats.display_name
	if not enemy.is_alive():
		return "%s defeated" % display_name
	if enemy.returning:
		return "%s returning" % display_name
	if enemy.attacking:
		return "%s %s windup" % [display_name, enemy.attack_name().to_lower()]
	if is_instance_valid(enemy.opponent):
		return "%s pursuing" % display_name if enemy.velocity.length_squared() > 0.05 else "%s recovering" % display_name
	return "%s idle" % display_name

func _physics_process(delta: float) -> void:
	if player.is_alive():
		super._physics_process(delta)
		return
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	status.text = "Returning to %s in %.1fs" % [recovery_location, recovery_remaining]
	if recovery_remaining <= 0.0:
		player.reset_combat()
		status.text = "Recovered at %s" % recovery_location
		_show_hit("You recovered at full health.")

func _unhandled_input(event: InputEvent) -> void:
	if ability_hud.handle_shortcut(event):
		get_viewport().set_input_as_handled()
	elif player.is_alive():
		super._unhandled_input(event)

func _show_hit(message: String) -> void:
	last_hit.text = message
	last_hit.show()

func _start_recovery() -> void:
	recovery_remaining = recovery_delay
	_stop_following_cursor()
	_hide_marker()

func _hide_marker() -> void:
	if marker_tween:
		marker_tween.kill()
	marker.hide()
