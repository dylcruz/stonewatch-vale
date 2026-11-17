extends SceneTree
## Validate the baked zone and walk the authored connectors through the gameplay camera.

const SCENE := preload("res://scenes/stonewatch_vale.tscn")
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

func start() -> void:
	world = SCENE.instantiate()
	root.add_child(world)
	region = world.get_node("NavigationRegion3D")
	player = world.player
	for enemy: ValeEnemy in world.enemies:
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
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
	for actor: Node3D in world.enemies:
		snapshot[world.get_path_to(actor)] = actor.global_transform
	for actor: Node3D in [world.mara, world.get_node("SupplyCrate")]:
		snapshot[world.get_path_to(actor)] = actor.global_transform
	return snapshot

func check_main_road() -> void:
	var watchpost_point: Vector3 = world.get_node("Watchpost").global_position
	var campsite := Vector3(1.8, 0, -8)
	var quarry := Vector3(-10.8, 0, 5.3)
	check(connected(watchpost_point, campsite) and connected(campsite, quarry)
		and connected(quarry, watchpost_point), "The watchpost, campsite, and Quarry Gate share a two-way network")
	check(await walk_steps([Vector3(8, 0, 7), Vector3(8, 0, -7.5), campsite,
		Vector3(-8.5, 0, -6), quarry, watchpost_point]),
		"The gameplay camera can route from Pine Road through the campsite to the quarry and back")
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
		"Pine Meadow connects the watchpost gate, Heather Rest, and North Road in both directions")
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
	check(await walk_steps([start_point]), "The watchpost entrance reaches Heather Rest entirely on foot")
	var start_frame := Engine.get_physics_frames()
	var length := 0.0
	for destination in [
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
	await check_main_road()
	await check_meadow()
	await check_river()
	await check_ridge()
	if "--pace" in OS.get_cmdline_user_args():
		await time_crossing()
	world.queue_free()
	await process_frame
	await start()
	check(initial_layout == layout(), "Two fresh games load identical terrain, props, quest objects, and encounters")

	print("Vale route checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
