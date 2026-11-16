extends "res://scripts/movement_demo.gd"

@onready var wolf: ValeWolf = $Wolf
@onready var combat_hud: VBoxContainer = $HUD/CombatPanel/Margin/VBox

func _ready() -> void:
	super._ready()
	player.combat_message.connect(_show_hit)
	wolf.combat_message.connect(_show_hit)
	player.health.died.connect(_stop_following_cursor)
	$HUD/Panel/Margin/VBox/ResetFight.pressed.connect(reset_fight)
	status.text = "Ready · click the wolf to approach and auto-attack"

func _process(_delta: float) -> void:
	combat_hud.get_node("WarriorHealth").value = player.health.current
	combat_hud.get_node("WarriorHealth").max_value = player.health.maximum
	combat_hud.get_node("WarriorName").text = "Warrior  %d / %d HP" % [player.health.current, player.health.maximum]
	combat_hud.get_node("WolfHealth").value = wolf.health.current
	combat_hud.get_node("WolfHealth").max_value = wolf.health.maximum
	combat_hud.get_node("WolfName").text = "Road wolf  %d / %d HP" % [wolf.health.current, wolf.health.maximum]
	var sword_state := "Sword ready"
	if is_instance_valid(player.swing_target):
		sword_state = "Sword windup"
	elif player.attack_cooldown > 0.0:
		sword_state = "Sword recovery %.1fs" % player.attack_cooldown
	combat_hud.get_node("Timing").text = sword_state + ("  ·  Wolf bite windup" if wolf.biting else "")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reset_fight()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)

func _show_hit(message: String) -> void:
	combat_hud.get_node("LastHit").text = message

func reset_fight() -> void:
	_stop_following_cursor()
	player.reset_combat()
	wolf.reset_combat()
	if marker_tween:
		marker_tween.kill()
	marker.hide()
	status.text = "Ready · click the wolf to approach and auto-attack"
	_show_hit("Fight reset · 8 sword damage / 6 bite damage")
