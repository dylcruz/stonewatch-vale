extends "res://scripts/quest_world.gd"

@export var map_landmarks: Dictionary[String, NodePath] = {}
@onready var map_panel: PanelContainer = $HUD/WorldMap
@onready var exploration_map: ValeExplorationMap = $HUD/WorldMap/Margin/Content/ExplorationMap

func _ready() -> void:
	var landmarks: Dictionary[String, Vector3] = {}
	for label in map_landmarks:
		var marker := get_node(map_landmarks[label]) as Node3D
		landmarks[label] = marker.global_position
	exploration_map.configure($NavigationRegion3D, landmarks)
	exploration_map.restore_cells(pending_checkpoint.get("discovered_cells"))
	exploration_map.reveal(player.global_position)
	super._ready()
	$HUD/WorldMap/Margin/Content/Header/Close.pressed.connect(map_panel.hide)
	ability_hud.add_menu_button("Map", "M", _toggle_map)

func _process(delta: float) -> void:
	super._process(delta)
	if exploration_map.reveal(player.global_position):
		_save_checkpoint()

func _build_checkpoint() -> Dictionary:
	var checkpoint := super._build_checkpoint()
	checkpoint.discovered_cells = exploration_map.discovered_cells()
	return checkpoint

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"world_map"):
		_toggle_map()
		get_viewport().set_input_as_handled()
	elif map_panel.visible and event.is_action_pressed(&"ui_cancel"):
		map_panel.hide()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)

func _toggle_map() -> void:
	if map_panel.visible:
		map_panel.hide()
		return
	_close_panel()
	ability_hud.close_book()
	_stop_following_cursor()
	map_panel.show()

func _show_panel(mode: JournalView) -> void:
	map_panel.hide()
	super._show_panel(mode)

func _open_ability_book() -> void:
	map_panel.hide()
	super._open_ability_book()

func _refresh_progress() -> void:
	super._refresh_progress()
	for progress in quest_chain:
		if progress.definition.id == &"birchwater_delivery":
			$NavigationRegion3D/BirchwaterLoop/Cart/Cargo.visible = progress.state == ValeQuestProgress.State.COMPLETED
		elif progress.definition.id == &"ridge_signal":
			var lit := progress.state >= ValeQuestProgress.State.READY
			$NavigationRegion3D/LookoutRidgeLoop/Beacon/Flame.visible = lit
			$NavigationRegion3D/StartingTown/TownHall/Lantern/Flame.visible = lit
