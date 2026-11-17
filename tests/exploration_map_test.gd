extends SceneTree

const MAIN := preload("res://scenes/stonewatch_vale.tscn")
const NAVIGATION := preload("res://tests/navigation_test_support.gd")
var failures := 0
var assertions := 0
var world: Node3D
var player: ValePlayer
var atlas: ValeExplorationMap

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func start() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	atlas = world.exploration_map
	await process_frame
	await NAVIGATION.wait_for_spawn(world, player)

func landmark(label: String) -> Vector3:
	return world.get_node(world.map_landmarks[label]).global_position

func stand_at(point: Vector3) -> void:
	player.clear_combat_target()
	player.global_position = point + Vector3.UP * 0.03
	await process_frame
	await process_frame

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func check_panel_input() -> void:
	var square := landmark("Town Square")
	check(world.click_world(world.camera.unproject_position(square + Vector3(7, 0, 0))),
		"The town accepts a movement command before opening the map")
	var destination := player.destination
	press(KEY_M)
	await process_frame
	check(world.map_panel.visible and player.destination == destination and player.moving,
		"M opens the map and preserves the active movement command")
	var click := InputEventMouseButton.new()
	click.position = world.map_panel.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	check(player.destination == destination and not world.following_cursor,
		"A map click is consumed by the panel")
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	press(KEY_J)
	check(not world.map_panel.visible and world.journal.visible, "Opening the quest log closes the map")
	press(KEY_M)
	check(world.map_panel.visible and not world.journal.visible, "Opening the map closes the quest log")
	press(KEY_ESCAPE)
	check(not world.map_panel.visible, "Escape closes the map")

func discover_meadow() -> void:
	var goal := landmark("Heather Rest")
	await stand_at(goal + Vector3(0, 0, -4))
	check(not atlas.is_explored(goal), "The unvisited Heather Rest cell stays concealed from the adjacent cell")
	var walked: bool = world.click_world(world.camera.unproject_position(goal))
	for frame in 120:
		await physics_frame
		if atlas.is_explored(goal):
			break
	check(walked and atlas.is_explored(goal), "Walking into the Heather Rest cell reveals it")

func run() -> void:
	await start()
	check(atlas.is_explored(landmark("Town Square")) and not atlas.is_explored(landmark("Heather Rest"))
		and not atlas.is_explored(landmark("Timber Bridge")) and not atlas.is_explored(landmark("Signal Ridge")),
		"A fresh run reveals its starting area while distant areas remain concealed")
	await check_panel_input()
	await discover_meadow()
	check(not atlas.is_explored(landmark("Timber Bridge")) and not atlas.is_explored(landmark("Signal Ridge")),
		"Exploring Pine Meadow first leaves Birchwater and Signal Ridge concealed")
	await stand_at(landmark("Timber Bridge"))
	check(atlas.is_explored(landmark("Timber Bridge")) and atlas.is_explored(landmark("Heather Rest")),
		"The bridge reveals independently and the meadow stays revealed after leaving")
	await stand_at(landmark("Heather Rest"))
	check(atlas.is_explored(landmark("Heather Rest")) and atlas.is_explored(landmark("Timber Bridge")),
		"Revisiting the meadow keeps both explored areas visible")
	world.queue_free()
	await process_frame

	await start()
	await stand_at(landmark("Signal Ridge"))
	check(atlas.is_explored(landmark("Signal Ridge")) and not atlas.is_explored(landmark("Timber Bridge"))
		and not atlas.is_explored(landmark("Heather Rest")),
		"A different run can reveal Signal Ridge first with its other areas still hidden")
	await stand_at(landmark("Timber Bridge"))
	check(atlas.is_explored(landmark("Signal Ridge")) and atlas.is_explored(landmark("Timber Bridge"))
		and not atlas.is_explored(landmark("Heather Rest")),
		"Visiting Birchwater next reveals only the cells explored in this run")
	await discover_meadow()
	print("Exploration map checks complete; assertions: ", assertions, "; failures: ", failures)
	quit(1 if failures else 0)
