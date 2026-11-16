extends SceneTree

var failures := 0
var world: Node3D
var player: ValePlayer

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func click_at(point: Vector3) -> bool:
	return world.click_world(world.camera.unproject_position(point))

func move_cursor(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)

func hold_button(position: Vector2, pressed: bool) -> void:
	move_cursor(position)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func dispatch_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func wait_for_stop() -> void:
	for i in 600:
		await physics_frame
		if not player.moving:
			return

func run() -> void:
	world = load("res://scenes/movement_demo.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	await frames(5)
	check(world.get_node("NavigationRegion3D").navigation_mesh.get_polygon_count() > 0, "Scene contains saved baked navigation")
	await dispatch_click(world.camera.unproject_position(Vector3(0, 0, -9)))
	check(player.moving and player.destination.distance_to(Vector3(0, 0, -9)) < 0.4, "Viewport ground click dispatches a movement command")
	var path := NavigationServer3D.map_get_path(player.agent.get_navigation_map(), player.global_position, player.destination, true)
	var routed_around := false
	for point in path:
		if absf(point.x) > 2.9:
			routed_around = true
	check(routed_around, "Path bends around the blocking ruin")
	await wait_for_stop()
	check(not player.moving and player.global_position.distance_to(Vector3(0, 0, -9)) < 0.4, "Player reaches far side and stops (position: %s)" % player.global_position)
	var stopped_position := player.global_position
	await frames(30)
	check(player.global_position.distance_to(stopped_position) < 0.02, "Arrival remains stable without jitter")
	check(click_at(Vector3(0, 0, 8)), "Ground click starts a new command")
	var original := player.destination
	check(not click_at(Vector3(19, 0, -5)), "Disconnected island is rejected")
	check(not click_at(Vector3(17, 0, 0)), "Void click is rejected")
	check(not click_at(Vector3(0, 2.5, 0)), "Obstacle top click is rejected")
	check(player.destination == original and player.moving, "Invalid clicks preserve the current command")
	# Exercise real viewport dispatch so Control input consumption is covered.
	var button: Button = world.get_node("HUD/Panel/Margin/VBox/UITest")
	await dispatch_click(button.get_global_rect().get_center())
	await frames(2)
	check(player.destination == original, "HUD click preserves movement destination")
	check(world.status.text.begins_with("UI click received"), "HUD button receives and consumes the click")
	await wait_for_stop()
	check(click_at(Vector3(0, 1, -7)), "Ray selects practice target across the obstacle")
	check(player.selected_target == world.get_node("NavigationRegion3D/PracticeTarget"), "Practice target selected")
	await frames(20)
	check(click_at(Vector3(6, 0, 7)), "Ground click cancels target pursuit")
	check(player.selected_target == null and not world.get_node("NavigationRegion3D/PracticeTarget/SelectionRing").visible, "Ground clears selection and target ring")
	await wait_for_stop()
	check(click_at(Vector3(0, 1, -7)), "Target can be selected again")
	await wait_for_stop()
	check(not player.moving and player.global_position.distance_to(Vector3(0, 0, -7)) < 1.7, "Target approach stops within interaction range")
	check(world.get_node("DestinationMarker").visible == false, "Destination marker expires")
	var map := player.agent.get_navigation_map()
	check(NavigationServer3D.map_get_closest_point(map, player.global_position).distance_to(player.global_position) < 0.25, "Player remains on walkable terrain")
	# Holding uses the same viewport input and ray picking as ordinary clicks.
	var start := player.global_position
	hold_button(world.camera.unproject_position(Vector3(6, 0, -7)), true)
	await frames(2)
	check(world.following_cursor, "World press starts cursor following")
	move_cursor(world.camera.unproject_position(Vector3(7, 0, 1)))
	await frames(8)
	check(player.destination.x > 6.5 and player.destination.z > 0.5, "Held mouse motion updates the destination")
	check(player.selected_target == null, "Held ground movement clears target pursuit")
	var held_destination := player.destination
	move_cursor(world.camera.unproject_position(Vector3(19, 0, -5)))
	await frames(8)
	check(player.destination == held_destination, "Held movement rejects unreachable ground")
	move_cursor(button.get_global_rect().get_center())
	await frames(8)
	check(player.destination == held_destination, "Held movement pauses destination updates over HUD")
	hold_button(button.get_global_rect().get_center(), false)
	check(not world.following_cursor, "Release over HUD ends cursor following")
	move_cursor(world.camera.unproject_position(Vector3(-7, 0, 1)))
	await frames(8)
	check(player.destination == held_destination, "Mouse movement after release preserves last destination")
	await wait_for_stop()
	check(not player.moving and player.global_position.distance_to(start) > 1.0, "Player finishes the last held destination after release")
	hold_button(button.get_global_rect().get_center(), true)
	move_cursor(world.camera.unproject_position(Vector3(-7, 0, 1)))
	await frames(8)
	check(not world.following_cursor and player.destination == held_destination, "Press begun on HUD cannot start world dragging")
	hold_button(Vector2(640, 600), false)
	# A stationary destination must not continually restart movement after arrival.
	player.global_position = Vector3(0, 0.01, 7)
	await frames(2)
	hold_button(world.camera.unproject_position(Vector3(0.05, 0, 7)), true)
	await frames(30)
	check(not player.moving, "Holding at the player's feet settles without restarting movement")
	world.get_window().focus_exited.emit()
	check(not world.following_cursor, "Losing window focus ends cursor following")
	hold_button(Vector2(640, 600), false)
	print("Movement checks complete; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
