extends "res://scripts/world_input.gd"

@export var recovery_delay := 2.0
@export var recovery_location := "the watchpost"
@export var ready_text := "Ready"
@onready var player_frame: ValeHealthFrame = $HUD/PlayerFrame
@onready var target_frame: ValeHealthFrame = $HUD/TargetFrame
@onready var ability_hud: ValeAbilityHUD = $HUD/AbilityHUD
var enemies: Array[ValeEnemy] = []
var recovery_remaining := 0.0

func _ready() -> void:
	super._ready()
	ability_hud.bind_player(player as ValeWarrior)
	for child in find_children("*", "CharacterBody3D", true, false):
		if child is ValeEnemy:
			enemies.append(child)
			child.aggro_target = player
	player.health.died.connect(_start_recovery)
	status.text = ready_text

func _process(_delta: float) -> void:
	player_frame.display(player.stats, player.health, "%s Lv. %d" % [player.stats.display_name, player.level])
	var enemy := player.selected_target as ValeEnemy
	target_frame.visible = is_instance_valid(enemy) and enemy.is_alive()
	if target_frame.visible:
		target_frame.display(enemy.stats, enemy.health, enemy.stats.display_name)

func _physics_process(delta: float) -> void:
	if player.is_alive():
		super._physics_process(delta)
		return
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	status.text = "Returning to %s in %.1fs" % [recovery_location, recovery_remaining]
	if recovery_remaining <= 0.0:
		player.reset_combat()
		status.text = "Recovered at %s" % recovery_location

func _unhandled_input(event: InputEvent) -> void:
	if ability_hud.handle_shortcut(event):
		get_viewport().set_input_as_handled()
	elif player.is_alive():
		super._unhandled_input(event)

func _start_recovery() -> void:
	recovery_remaining = recovery_delay
	_stop_following_cursor()
	_hide_marker()

func _hide_marker() -> void:
	if marker_tween:
		marker_tween.kill()
	marker.hide()
