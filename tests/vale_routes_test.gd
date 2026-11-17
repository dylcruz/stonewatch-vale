extends SceneTree
## Validate the baked zone and walk the authored connectors through the gameplay camera.

const MAIN_SCENE := preload("res://scenes/stonewatch_vale.tscn")
const WATCHPOST_SCENE := preload("res://scenes/watchpost_playtest.tscn")
const NAVIGATION := preload("res://tests/navigation_test_support.gd")
var world: Node3D
var player: ValePlayer
var region: NavigationRegion3D
var assertions := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func start(scene: PackedScene = MAIN_SCENE) -> void:
	world = scene.instantiate()
	root.add_child(world)
	region = world.get_node("NavigationRegion3D")
	player = world.player
	await frames(5)
	await NAVIGATION.wait_for_spawn(world, player)

func mark(path: NodePath) -> Vector3:
	return region.get_node(path).global_position

func place(point: Vector3) -> void:
	player.clear_combat_target()
	player.global_position = point + Vector3.UP * 0.02
	await frames(5)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := player.agent.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.size() < 2 or path[0].distance_to(from) > 0.55 or path[-1].distance_to(to) > 0.55:
		return PackedVector3Array()
	return path

func connected(from: Vector3, to: Vector3) -> bool:
	return not route(from, to).is_empty() and not route(to, from).is_empty()

func camera_click(point: Vector3) -> bool:
	var viewport_position: Vector2 = world.camera.unproject_position(point)
	return root.get_visible_rect().has_point(viewport_position) and world.click_world(viewport_position)

func walk_to(point: Vector3, limit: int = 600) -> bool:
	if not camera_click(point):
		return false
	for frame in limit:
		await physics_frame
		if not player.moving:
			return player.global_position.distance_to(point) < 0.75
	return false

func walk_steps(points: Array[Vector3]) -> bool:
	for point in points:
		var path := route(player.global_position, point)
		if path.is_empty() or not await walk_path(path):
			print("Could not walk to ", point, " from ", player.global_position)
			return false
	return true

func walk_path(path: PackedVector3Array) -> bool:
	# Keep ground clicks within the follow camera, even for long paths.
	for index in range(1, path.size()):
		var segment := path[index - 1].distance_to(path[index])
		var steps := maxi(1, ceili(segment / 10.0))
		for step in range(1, steps + 1):
			var point := path[index - 1].lerp(path[index], float(step) / steps)
			if player.global_position.distance_to(point) < 0.45:
				continue
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point - Vector3.UP * 0.65, 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or not await walk_to(hit.position):
				print("Could not walk to path waypoint ", point, " from ", player.global_position)
				return false
	return true

func layout() -> Dictionary:
	var snapshot := {}
	for terrain: Node3D in region.find_children("*", "Node3D", true, false):
		snapshot[region.get_path_to(terrain)] = terrain.global_transform
	return snapshot

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(2)

func check_starting_town() -> void:
	var square := Vector3(0, 0, 7)
	check(region.has_node("StartingTown/TownHall") and region.has_node("StartingTown/WestCottage")
		and region.has_node("StartingTown/EastCottage") and player.global_position.distance_to(square) < 0.05
		and world.status.text == "Town square",
		"A fresh game opens in the town square at the original spawn")
	check(world.enemies.is_empty() and world.quest_chain.is_empty()
		and not world.has_node("CaptainMara") and not world.has_node("SupplyCrate"),
		"The main game has no Watchpost encounters or quest fixtures")
	check(region.has_node("StartingTown/NorthCottage") and region.has_node("StartingTown/WestLaneCottage")
		and not region.has_node("WatchpostLandmarks")
		and not world.has_node("AbandonedCampsite") and not world.has_node("QuarryGate")
		and not region.has_node("WatchpostDressing/CartBed") and not region.has_node("WatchpostDressing/CampSignLabel"),
		"Town buildings replace the campsite, supply cart, and Quarry Gate")
	check(not world.enemy_name.visible and not world.enemy_health.visible
		and not world.objective_label.visible and not world.last_hit.visible,
		"The town HUD starts without enemy health, combat tips, or a Watchpost objective")
	await press_key(KEY_J)
	check(world.journal.visible and world.journal_body.text == "No quests accepted",
		"The empty town journal opens with J")
	await press_key(KEY_I)
	check(world.journal.visible and world.journal_title.text == "Character",
		"The town character panel opens with I")
	await press_key(KEY_I)
	check(camera_click(Vector3(8, 0, 7)), "Pine Road accepts a move from the town square")
	var destination := player.destination
	check(not camera_click(Vector3(-1.55, 3.1, -10.3)) and not camera_click(Vector3(-11.6, 3.1, 2.35))
		and player.destination == destination and player.moving,
		"Clicking either new cottage preserves the previous destination")
	check(await walk_steps([Vector3(8, 0, 7), mark("MeadowLoop/SouthConnection")])
		and player.is_alive() and player.experience == 0 and world.tracked_quest == null,
		"The Warrior can walk out to Pine Meadow without taking a quest or fighting")
	player.receive_hit(999, null)
	await frames(150)
	check(player.health.current == player.health.maximum and player.global_position.distance_to(square) < 0.05
		and world.status.text == "Recovered at the town square",
		"Defeat returns the Warrior to the town square")

func check_main_road() -> void:
	var town_square: Vector3 = world.get_node("Watchpost").global_position
	var north_lane := Vector3(2.7, 0, -7.8)
	var west_lane := Vector3(-10.8, 0, 6.2)
	check(connected(town_square, north_lane) and connected(north_lane, west_lane)
		and connected(west_lane, town_square), "The streets around the new houses form a two-way network")
	check(await walk_steps([Vector3(8, 0, 7), Vector3(8, 0, -7.5), north_lane,
		Vector3(-8.5, 0, -6), west_lane, town_square]),
		"The gameplay camera can route past the new cottages and back to the square")
	check(not camera_click(Vector3(0, 0, 15)), "A click beyond the south boundary is rejected")
	await place(Vector3(8, 0, -10))
	check(await walk_steps([Vector3(8, 0, -18), Vector3(8, 0, -10)]),
		"Pine Road meets North Road on foot through the north gate in both directions")

func check_meadow() -> void:
	var east_gate := mark("MeadowLoop/SouthConnection")
	var heather_rest := mark("MeadowLoop/HeatherRest")
	var north_gate := mark("MeadowLoop/NorthConnection")
	check(connected(east_gate, heather_rest) and connected(heather_rest, north_gate)
		and connected(north_gate, mark("NorthRoad/MeadowConnection")),
		"Pine Meadow connects the town gate, Heather Rest, and North Road in both directions")
	await place(Vector3(10.5, 0, 7.6))
	check(await walk_steps([east_gate, Vector3(11.2, 0, 7.6)]), "The east gate can be walked in both directions")
	await place(mark("NorthRoad/MeadowConnection"))
	check(await walk_steps([Vector3(25, 0, -72), mark("NorthRoad/MeadowConnection")]),
		"The north meadow junction can be walked in both directions")

func check_river() -> void:
	check(connected(mark("NorthRoad/FordConnection"), mark("BirchwaterLoop/Ford"))
		and connected(mark("BirchwaterLoop/Ford"), mark("BirchwaterLoop/EastBank"))
		and connected(mark("BirchwaterLoop/EastBank"), mark("BirchwaterLoop/Bridge"))
		and connected(mark("BirchwaterLoop/Bridge"), mark("NorthRoad/BridgeConnection")),
		"The ford, east bank, and bridge form a two-way loop off North Road")
	for crossing in [Vector3(48, 0, -123), Vector3(49, 0, -202)]:
		var west := Vector3(32, 0, crossing.z)
		var east := Vector3(65, 0, crossing.z)
		await place(west)
		check(await walk_steps([crossing, east, crossing, west]),
			"Both banks can be reached on foot across Birchwater at z = %d" % int(crossing.z))
	await place(Vector3(32, 0, -132))
	check(camera_click(Vector3(29, 0, -124)), "A move along the west bank is accepted")
	var destination := player.destination
	check(not camera_click(mark("BirchwaterLoop/DeepWaterPool")) and player.destination == destination and player.moving,
		"A deep-water click preserves the active movement command")

func check_solid_scenery() -> void:
	var tree := mark("BirchwaterLoop/BankPine02")
	var rock := mark("BirchwaterLoop/BankSlab4")
	await place(tree + Vector3(-3, 0, 0))
	var collision := KinematicCollision3D.new()
	check(player.test_move(player.global_transform, Vector3(5, 0, 0), collision)
		and collision.get_collider() == region.get_node("BirchwaterLoop/BankPine02/SolidTrunk"),
		"The Warrior collides with solid tree trunks")
	check(camera_click(tree + Vector3(3, 0, 0)), "The bank accepts a move to the far side of the tree")
	var destination := player.destination
	check(not camera_click(tree + Vector3.UP * 0.7) and player.destination == destination and player.moving,
		"Clicking the tree trunk preserves the active movement command")
	check(await walk_steps([tree + Vector3(3, 0, 0)]), "The baked path routes around the tree")
	await place(rock + Vector3(0, 0, 5))
	check(player.test_move(player.global_transform, Vector3(0, 0, -7), collision)
		and collision.get_collider() == region.get_node("BirchwaterLoop/BankSlab4/SolidRock"),
		"The Warrior collides with the outcrop")
	check(camera_click(rock + Vector3(4, 0, 0)), "A ground click beside the outcrop is accepted")
	destination = player.destination
	check(not camera_click(rock + Vector3.UP * 0.6) and player.destination == destination and player.moving,
		"Clicking the boulder preserves the active movement command")
	check(await walk_steps([rock + Vector3(0, 0, -5)]), "The baked path routes around the outcrop")
	var bridge := mark("BirchwaterLoop/Bridge")
	await place(bridge)
	for side in [-1, 1]:
		check(player.test_move(player.global_transform, Vector3(0, 0, 4 * side), collision)
			and collision.get_collider() == region.get_node("BirchwaterLoop/Railings"),
			"The railing physically blocks the Warrior on bridge side %d" % side)
	check(camera_click(bridge + Vector3(7, 0, 0)), "A move down the bridge is accepted")
	destination = player.destination
	check(not camera_click(Vector3(49, 0.76, -198.83)) and player.destination == destination and player.moving,
		"Clicking the railing preserves the active movement command")

func check_backdrop_edges() -> void:
	check(world.has_node("ValeBackdrop/ForestFloor") and world.has_node("ValeBackdrop/RidgePeaks"),
		"The Vale loads woodland and mountain scenery beyond the routes")
	for edge in [
		[Vector3(0, 0, -67), Vector3(3, 0, -70), Vector3(-11.5, -1.92, -67)],
		[Vector3(217, 0.012, 12), Vector3(211, 0.012, 12), Vector3(238, -1.92, 12)],
		[Vector3(-183, 12, -332), Vector3(-178, 12, -333), Vector3(-206, 7, -330)],
	]:
		await place(edge[0])
		check(camera_click(edge[1]), "Ground next to the scenic boundary accepts a move")
		var destination := player.destination
		check(not camera_click(edge[2]) and player.destination == destination and player.moving,
			"Clicking beyond the scenic boundary preserves movement")

func check_ridge() -> void:
	var lookout := mark("LookoutRidgeLoop/Lookout")
	check(connected(mark("NorthRoad/SouthRidgeConnection"), lookout)
		and connected(lookout, mark("NorthRoad/NorthRidgeConnection")),
		"Both climbs connect North Road with the Signal Ridge overlook")
	for climb in [
		[Vector3(-17, 0, -256), Vector3(-68, 12, -256), Vector3(-71, 12, -256)],
		[Vector3(-17, 0, -336), Vector3(-61, 12, -336), Vector3(-64, 12, -336)],
	]:
		await place(climb[0])
		# Stay on the middle of the trail through the transition between the flat road and the slope.
		var ramp_foot := Vector3(-19.8, 0, climb[0].z)
		var climbed := true
		for weight in [0.17, 0.34, 0.5, 0.67, 0.84, 1.0, 0.84, 0.67, 0.5, 0.34, 0.17]:
			var point: Vector3 = ramp_foot.lerp(climb[1], weight) if weight < 1.0 else climb[2]
			if not await walk_to(point):
				print("Could not walk to ramp waypoint ", point, " from ", player.global_position)
				climbed = false
				break
		check(climbed and await walk_to(climb[0]),
			"The Warrior can climb and descend the ridge approach at z = %d" % int(climb[0].z))
	await place(Vector3(-172, 12, -344))
	check(await walk_to(lookout), "The signal mast overlook is walkable from the gameplay camera")
	var cliff := mark("LookoutRidgeLoop/CliffFace")
	await place(Vector3(-95, 12, -232))
	check(camera_click(Vector3(-105, 12, -237)), "A move along the ridge top is accepted")
	var destination := player.destination
	check(not camera_click(cliff) and player.destination == destination and player.moving,
		"A click on the steep ridge face preserves the active movement command")

func time_crossing() -> void:
	var start_point := mark("MeadowLoop/HeatherRest")
	var lookout := mark("LookoutRidgeLoop/Lookout")
	await place(mark("MeadowLoop/SouthConnection"))
	# Click on the open trail on both sides of the pine at (124, 0, 28).
	# A click on a navigation corner behind its trunk can be occluded from the follow camera.
	var reached_start := await walk_steps([Vector3(120, 0, 21), Vector3(130, 0, 21), start_point])
	check(reached_start, "The town entrance reaches Heather Rest entirely on foot")
	if not reached_start:
		return
	var start_frame := Engine.get_physics_frames()
	var length := 0.0
	for destination in [
		Vector3(56, 0, -49),
		Vector3(46, 0, -49),
		mark("MeadowLoop/NorthConnection"),
		mark("NorthRoad/SouthRidgeConnection"),
		Vector3(-17, 0, -256),
		mark("LookoutRidgeLoop/SouthRamp"),
		Vector3(-71, 12, -256),
		lookout,
	]:
		var path := route(player.global_position, destination)
		if path.is_empty() or not await walk_path(path):
			check(false, "The timed crossing stalled on the way to %s" % destination)
			return
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
	var elapsed := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	check(player.global_position.distance_to(lookout) < 0.75, "The Warrior walked the full-zone crossing")
	print("Heather Rest to Signal Ridge via North Road: %.1f m of navigation, %.1f s on foot" % [length, elapsed])

func run() -> void:
	await start()
	var initial_layout := layout()
	check(region.navigation_mesh.get_polygon_count() > 27, "The expanded zone has saved baked navigation")
	await check_starting_town()
	await place(world.get_node("Watchpost").global_position)
	await check_main_road()
	await check_meadow()
	await check_river()
	await check_solid_scenery()
	await check_ridge()
	await check_backdrop_edges()
	if "--pace" in OS.get_cmdline_user_args():
		await time_crossing()
	world.queue_free()
	await process_frame
	await start()
	check(initial_layout == layout(), "Two fresh games load identical terrain and props")
	world.queue_free()
	await process_frame
	await start(WATCHPOST_SCENE)
	check(not region.has_node("StartingTown") and world.status.text == "Watchpost"
		and world.get_node("Watchpost/Label").visible and world.quest_chain.size() == 3
		and world.enemies.size() == 7 and world.has_node("CaptainMara") and world.has_node("SupplyCrate")
		and world.get_node("HUD/Panel/Margin/VBox/Title").text == "WATCHPOST PLAYTEST",
		"The separate developer scene opens the original watchpost and its quest and combat fixtures")
	check(region.has_node("WatchpostLandmarks/AbandonedCampsite")
		and region.has_node("WatchpostLandmarks/QuarryGate")
		and region.has_node("WatchpostLandmarks/CartBed") and region.has_node("WatchpostLandmarks/CampSignLabel"),
		"The developer scene keeps the original landmarks and their dressing")
	check(not region.has_node("NorthRoad") and not region.has_node("MeadowLoop")
		and not region.has_node("BirchwaterLoop") and not region.has_node("LookoutRidgeLoop"),
		"The outer Vale routes are absent from the Watchpost developer scene")
	var watchpost_spawn := player.global_position
	check(not connected(watchpost_spawn, Vector3(16.5, 0, 7.5))
		and not connected(watchpost_spawn, Vector3(8, 0, -17)),
		"The old east and north exits terminate at the Watchpost boundary")

	print("Vale route checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
