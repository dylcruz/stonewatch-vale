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
	check(world.enemies.has(region.get_node("BirchwaterLoop/BankWolf")) and world.quest_chain.size() == 2
		and world.quest_chain[0].definition.id == &"birchwater_delivery"
		and not world.has_node("CaptainMara") and not world.has_node("SupplyCrate"),
		"The main game has no Watchpost encounters or quest fixtures")
	check(region.has_node("StartingTown/NorthCottage") and region.has_node("StartingTown/WestLaneCottage")
		and not region.has_node("WatchpostLandmarks")
		and not world.has_node("AbandonedCampsite") and not world.has_node("QuarryGate")
		and not region.has_node("WatchpostDressing/CartBed") and not region.has_node("WatchpostDressing/CampSignLabel"),
		"Town buildings replace the campsite, supply cart, and Quarry Gate")
	check(not world.target_frame.visible
		and not world.objective_label.visible,
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
	var ford_sound: AudioStreamPlayer3D = region.get_node("BirchwaterLoop/FordCurrent")
	var bridge_sound: AudioStreamPlayer3D = region.get_node("BirchwaterLoop/BridgeCurrent")
	check((ford_sound.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Running water loops at the crossings")
	check(connected(mark("NorthRoad/FordConnection"), mark("BirchwaterLoop/Ford"))
		and connected(mark("BirchwaterLoop/Ford"), mark("BirchwaterLoop/EastBank"))
		and connected(mark("BirchwaterLoop/EastBank"), mark("BirchwaterLoop/Bridge"))
		and connected(mark("BirchwaterLoop/Bridge"), mark("NorthRoad/BridgeConnection")),
		"The ford, east bank, and bridge form a two-way loop off North Road")
	for crossing in [Vector3(48, 0, -123), Vector3(49, 0, -202)]:
		var west := Vector3(32, 0, crossing.z)
		var east := Vector3(65, 0, crossing.z)
		await place(west)
		check(ford_sound.playing == (crossing.z == -123) and bridge_sound.playing == (crossing.z == -202),
			"Only the nearby crossing plays its river loop")
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

func check_delivery() -> void:
	var zone := region.get_node("BirchwaterLoop")
	var giver: ValeInteractable = zone.get_node("Ferryman")
	var bundle: ValeInteractable = zone.get_node("LostBundle")
	var wolf: ValeEnemy = zone.get_node("BankWolf")
	var cargo: Node3D = zone.get_node("Cart/Cargo")
	var path := OS.get_temp_dir().path_join("birchwater-%d.save" % OS.get_process_id())
	var slot := ValeSaveSlot.new(path)
	world.configure_checkpoint(slot, {})
	check(connected(player.spawn_position, giver.global_position) and connected(giver.global_position, bundle.global_position),
		"The ford offer and bridge bundle connect to town")
	check(giver.global_position.distance_to(mark("BirchwaterLoop/Ford")) < 20.0
		and bundle.global_position.distance_to(mark("BirchwaterLoop/Bridge")) < 20.0,
		"The first crossing offers the delivery and the second holds the bundle")
	var timed := "--pace" in OS.get_cmdline_user_args()
	var started := Engine.get_physics_frames()
	var giver_approach := giver.global_position + Vector3(0, 0, 1.25)
	var bundle_approach := bundle.global_position + Vector3(0, 0, 1.3)
	var east_bridge := Vector3(66, 0, -202)
	var east_ford := Vector3(66, 0, -123)
	if timed:
		check(await walk_steps([Vector3(8, 0, 7), Vector3(8, 0, -10), mark("NorthRoad/FordConnection"), giver_approach]),
			"Walk from town square to the ferryman")
	else:
		await place(giver_approach)
	check(camera_click(giver.global_position + Vector3.UP), "The ferryman can be selected from the gameplay camera")
	await frames(15)
	check(world.journal_title.text == giver.display_name and world.dialogue_action.visible and not cargo.visible,
		"The ferryman offers the delivery beside an empty cart")
	world.dialogue_action.pressed.emit()
	check(world.tracked_quest == world.quest_chain[0] and bundle.objective_marker.visible, "Acceptance tracks the bridge bundle")
	if timed:
		check(await walk_steps([east_ford, east_bridge, Vector3(34, 0, -202), bundle_approach]), "Follow the east bank to the bridge")
	else:
		await place(bundle_approach)
	check(camera_click(bundle.global_position + Vector3.UP * 0.45), "The bridge bundle accepts a world click")
	await frames(15)
	check(not bundle.visible and world.quest_chain[0].state == ValeQuestProgress.State.READY and wolf.is_alive(),
		"The bundle readies the delivery with the bank wolf alive")
	if timed:
		check(await walk_steps([Vector3(34, 0, -202), east_bridge, east_ford, giver_approach]) and player.health.current == player.health.maximum,
			"Return by the quiet bank without taking damage")
	else:
		await place(giver_approach)
	camera_click(giver.global_position + Vector3.UP)
	await frames(15)
	world.dialogue_action.pressed.emit()
	world.dialogue_action.pressed.emit()
	check(cargo.visible and player.experience == 85, "Delivery loads the cart and pays its XP once")
	check(is_equal_approx(world.ability_hud.xp_bar.ratio, 0.85) and world.ability_hud.xp_label.text == "XP 85 / 100",
		"Delivery fills the XP bar to 85 percent")
	if timed:
		print("Town square through quiet-bank delivery: %.1f s of simulation" % (
			float(Engine.get_physics_frames() - started) / Engine.physics_ticks_per_second))
	await continue_in_town(slot)
	check(region.get_node("BirchwaterLoop/Cart/Cargo").visible and not region.get_node("BirchwaterLoop/LostBundle").visible
		and player.experience == 85, "Continue restores the delivered bundle on the cart")
	check(is_equal_approx(world.ability_hud.xp_bar.ratio, 0.85) and world.ability_hud.xp_label.text == "XP 85 / 100",
		"Continue restores the XP bar in town")
	wolf = region.get_node("BirchwaterLoop/BankWolf")
	wolf.respawn_delay = 0.5
	await place(wolf.spawn_position + Vector3(0, 0, 3))
	await frames(15)
	check(wolf.opponent == player, "The west bank wolf initiates combat")
	camera_click(wolf.global_position + Vector3.UP * 0.85)
	for frame in 400:
		await physics_frame
		if not wolf.is_alive():
			break
	check(not wolf.is_alive() and player.experience == 90, "Click-to-attack defeats the wolf and earns 5 XP")
	await frames(40)
	check(not wolf.is_alive(), "The wolf waits for the player to leave its encounter")
	await place(giver_approach)
	await frames(40)
	check(wolf.is_alive() and wolf.health.current == wolf.health.maximum, "The zone wolf respawns on leaving the area")
	check(DirAccess.remove_absolute(path) == OK, "Temporary delivery save was removed")

func continue_in_town(slot: ValeSaveSlot) -> void:
	world.queue_free()
	await process_frame
	var menu := preload("res://scenes/checkpoint_menu.tscn").instantiate()
	menu.slot = slot
	root.add_child(menu)
	menu.continue_game.pressed.emit()
	await process_frame
	world = current_scene
	region = world.get_node("NavigationRegion3D")
	player = world.player
	await frames(5)
	await NAVIGATION.wait_for_spawn(world, player)

func talk_to_keeper() -> void:
	var keeper := mark("StartingTown/SignalKeeper")
	await place(keeper + Vector3.BACK * 1.4)
	check(camera_click(keeper + Vector3.UP), "The signal keeper accepts a click outside town hall")
	await frames(15)

func check_signal(town_first: bool) -> void:
	world.queue_free()
	await process_frame
	await start()
	var path := OS.get_temp_dir().path_join("ridge-%d.save" % OS.get_process_id())
	var slot := ValeSaveSlot.new(path)
	world.configure_checkpoint(slot, {})
	if town_first:
		await talk_to_keeper()
		check(world.dialogue_action.text == "Accept quest" and world.journal_body.text.contains("either signed climb"),
			"The town offer describes both approaches")
		world.dialogue_action.pressed.emit()
	var mast := mark("LookoutRidgeLoop/LightMast")
	var bell: AudioStreamPlayer3D = region.get_node("LookoutRidgeLoop/MastBell")
	check(not bell.playing, "The unlit mast is silent")
	var approach := mast + Vector3.BACK * 2
	var climb := mark("NorthRoad/SouthRidgeConnection" if town_first else "NorthRoad/NorthRidgeConnection")
	check(connected(climb, approach), "The chosen climb reaches the unlit mast")
	check(not region.get_node("StartingTown/TownHall/Lantern/Flame").visible, "The answering lantern starts dark")
	await place(mast + Vector3.BACK * 5)
	check(camera_click(mark("LookoutRidgeLoop/SignalMast") + Vector3.UP), "Clicking the mast starts the approach")
	await frames(120)
	check(bell.playing, "Crediting the mast interaction rings the bell")
	check(region.get_node("LookoutRidgeLoop/Beacon/Flame").visible and player.experience == 0,
		"Lighting the mast records the discovery before turn-in")
	await press_key(KEY_J)
	check(world.journal_body.text.count("A Light on Signal Ridge") == 1 and world.journal_body.text.contains("Ready to turn in"),
		"Either discovery order creates one ready journal entry")
	await continue_in_town(slot)
	check(region.get_node("StartingTown/TownHall/Lantern/Flame").visible and region.get_node("LookoutRidgeLoop/Beacon/Flame").visible,
		"Continue restores the answering lantern and lit mast before turn-in")
	check(not region.get_node("LookoutRidgeLoop/MastBell").playing, "Restoring the lit mast does not replay the bell")
	await talk_to_keeper()
	check(world.journal_body.text.contains("lantern in reply"), "The keeper explains the light on return")
	world.dialogue_action.pressed.emit()
	world.dialogue_action.pressed.emit()
	await continue_in_town(slot)
	await talk_to_keeper()
	check(not region.get_node("LookoutRidgeLoop/MastBell").playing, "The bell stays silent after Continue following the keeper's turn-in")
	check(player.experience == 70 and not world.dialogue_action.visible and world.journal_body.text.contains("keep the answering lantern")
		and not region.get_node("LookoutRidgeLoop/LightMast").visible and region.get_node("StartingTown/TownHall/Lantern/Flame").visible,
		"Continue preserves the keeper's response and exactly one reward")
	check(DirAccess.remove_absolute(path) == OK, "Temporary Signal Ridge save was removed")

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
	await check_delivery()
	await check_signal(false)
	await check_signal(true)
	world.queue_free()
	await process_frame
	await start(WATCHPOST_SCENE)
	check(not region.has_node("StartingTown") and world.status.text == "Watchpost"
		and world.get_node("Watchpost/Label").visible and world.quest_chain.size() == 3
		and world.enemies.size() == 7 and world.has_node("CaptainMara") and world.has_node("SupplyCrate")
		and not world.get_node("HUD/Panel/Margin/VBox/Title").is_visible_in_tree()
		and world.status.is_visible_in_tree(),
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
