extends "res://scripts/quest_world.gd"

@export var map_landmarks: Dictionary[String, NodePath] = {}
@onready var map_panel: PanelContainer = $HUD/WorldMap
@onready var exploration_map: ValeExplorationMap = $HUD/WorldMap/Margin/Content/ExplorationMap

func _ready() -> void:
	super._ready()
	var landmarks: Dictionary[String, Vector3] = {}
	for label in map_landmarks:
		var marker := get_node(map_landmarks[label]) as Node3D
		landmarks[label] = marker.global_position
	exploration_map.configure($NavigationRegion3D, landmarks)
	exploration_map.reveal(player.global_position)
	$HUD/WorldMap/Margin/Content/Header/Close.pressed.connect(map_panel.hide)

func _process(delta: float) -> void:
	super._process(delta)
	exploration_map.reveal(player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"world_map"):
		if map_panel.visible:
			map_panel.hide()
		else:
			_close_panel()
			_stop_following_cursor()
			map_panel.show()
		get_viewport().set_input_as_handled()
	elif map_panel.visible and event.is_action_pressed(&"ui_cancel"):
		map_panel.hide()
		get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed(&"quest_log") or event.is_action_pressed(&"gear"):
			map_panel.hide()
		super._unhandled_input(event)
