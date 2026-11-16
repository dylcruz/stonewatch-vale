extends SceneTree

var failures := 0
var assertions := 0
var world: Node3D
var player: ValePlayer
var trail: MultiMeshInstance3D

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Breadcrumb draw-buffer checks need a graphical renderer; omit --headless")
		quit(2)
		return
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in trail.multimesh.visible_instance_count:
		result.append(trail.to_global(trail.multimesh.get_instance_transform(i).origin))
	return result

func click(point: Vector3) -> bool:
	return world.click_world(world.camera.unproject_position(point))

func run() -> void:
	world = load("res://scenes/movement_demo.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	trail = world.get_node("PathBreadcrumbs")
	await frames(5)
	check(trail.enabled and points().is_empty(), "Breadcrumbs default to enabled and are empty while idle")
	check(click(Vector3(0, 0, -9)), "Ground command accepts a route past the ruin")
	await frames(2)
	var initial := points()
	check(initial.size() > 15, "A long movement command displays breadcrumbs")
	check(not initial.is_empty() and initial[0].distance_to(player.destination) < 0.1, "Breadcrumb route ends at the accepted destination")
	var bends_around := false
	var clear_of_ruin := true
	var on_navigation := true
	for point in initial:
		bends_around = bends_around or absf(point.x) > 2.9
		clear_of_ruin = clear_of_ruin and not (absf(point.x) < 2.5 and absf(point.z) < 3.0)
		var nav_point := NavigationServer3D.map_get_closest_point(player.agent.get_navigation_map(), point)
		on_navigation = on_navigation and nav_point.distance_to(point) < 0.3
	check(bends_around and clear_of_ruin, "Visible breadcrumbs bend around the ruin instead of crossing it")
	check(on_navigation, "Breadcrumbs stay on the walkable navigation route")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/playtest/breadcrumb-route.png")
	await frames(30)
	check(points().size() < initial.size(), "Passed breadcrumbs disappear as the player advances")
	var endpoint: Vector3 = points()[0]
	check(not click(Vector3(19, 0, -5)), "Unreachable destination is still rejected")
	await frames(2)
	check(not points().is_empty() and points()[0] == endpoint, "Rejected click preserves the accepted trail endpoint")
	# Real UI dispatch must preserve the route as well as the command.
	var button: Button = world.get_node("HUD/Panel/Margin/VBox/UITest")
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(2)
	check(not points().is_empty() and points()[0] == endpoint, "HUD click preserves the breadcrumb route")
	check(click(Vector3(7, 0, 7)), "Replacement ground click is accepted")
	await frames(2)
	check(not points().is_empty() and points()[0].distance_to(player.destination) < 0.1 and points()[0].distance_to(endpoint) > 5.0, "Replacement click replaces the visible route")
	trail.enabled = false
	await frames(2)
	check(points().is_empty() and player.moving, "Visibility flag hides breadcrumbs without cancelling movement")
	trail.enabled = true
	await frames(2)
	check(not points().is_empty(), "Visibility can be restored during an active route")
	for i in 600:
		await physics_frame
		if not player.moving:
			break
	await frames(2)
	check(not player.moving and points().is_empty(), "Arrival clears the trail")
	world.queue_free()
	await process_frame

	world = load("res://scenes/combat_demo.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	trail = world.get_node("PathBreadcrumbs")
	await frames(5)
	check(click(Vector3(6, 0.8, 1)), "Clicking the wolf accepts an approach route")
	await frames(2)
	check(not points().is_empty(), "Combat approach also displays breadcrumbs")
	for i in 300:
		await physics_frame
		if not player.moving:
			break
	await frames(2)
	check(player.selected_target == world.wolf and points().is_empty(), "Entering melee clears movement breadcrumbs while preserving the combat target")
	click(Vector3(0, 0, 8))
	await frames(2)
	check(not points().is_empty(), "Ground cancellation displays a new movement trail")
	player.receive_hit(999, world.wolf)
	await frames(2)
	check(points().is_empty(), "Player death clears the trail")
	world.reset_fight()
	click(Vector3(7, 0, 7))
	await frames(2)
	world.reset_fight()
	await frames(2)
	check(points().is_empty() and trail.enabled, "Reset clears the route and keeps breadcrumbs enabled")
	print("Breadcrumb checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
