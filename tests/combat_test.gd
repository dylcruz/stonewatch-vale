extends SceneTree
## Real-scene combat tests. Direct repositioning sets up range and terrain cases.

var failures := 0
var assertions := 0
var world: Node3D
var warrior: ValePlayer
var wolf: ValeWolf

func _initialize() -> void:
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

func until(condition: Callable, limit: int = 600) -> bool:
	for i in limit:
		await physics_frame
		if condition.call():
			return true
	return false

func dispatch_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func dispatch_click(position: Vector2) -> void:
	dispatch_mouse_button(position, true)
	await frames(1)
	dispatch_mouse_button(position, false)

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func stand_in_melee() -> void:
	warrior.global_position = wolf.global_position + Vector3(0, 0, 1.4)
	warrior.velocity = Vector3.ZERO
	await frames(3)
	warrior.request_move(warrior.global_position, wolf)

func reset_pair() -> void:
	warrior.reset_combat()
	wolf.reset_combat()

func run() -> void:
	world = load("res://scenes/stonewatch_vale.tscn").instantiate()
	root.add_child(world)
	warrior = world.get_node("Player")
	wolf = world.get_node("Wolf")
	for enemy in world.enemies:
		if enemy != wolf:
			enemy.set_physics_process(false)
			enemy.collision_layer = 0
	await frames(5)
	check(warrior.health.current == 60 and wolf.health.current == 40, "Actors start at their tuned maximum health")
	press_key(KEY_1)
	check(not warrior.has_cleave() and warrior.cleave_cooldown_remaining == 0.0,
		"Level 1 Warrior cannot cast Cleave")
	check(wolf.opponent == null and warrior.is_in_refuge(), "The wolf starts idle and the Warrior starts at the watchpost")
	await dispatch_click(world.camera.unproject_position(Vector3(8, 0, 4.5)))
	check(await until(func(): return wolf.opponent == warrior and wolf.global_position.distance_to(wolf.spawn_position) > 0.5, 175)
		and warrior.selected_target == null, "Walking into proximity starts wolf pursuit without targeting or attacking it")

	reset_pair()
	await frames(3)
	await dispatch_click(world.camera.unproject_position(wolf.global_position + Vector3.UP * 0.8))
	check(warrior.selected_target == wolf and wolf.get_node("SelectionRing").visible, "Viewport click selects the wolf and shows its ring")
	check(wolf.health.current == 40, "Selecting from a distance does not cause remote damage")
	var original_approach: Vector3 = warrior.destination
	check(await until(func(): return original_approach.distance_to(warrior.destination) > 0.4, 150)
		and warrior.selected_target == wolf, "The Warrior updates its approach as the selected wolf moves")
	check(await until(func(): return is_instance_valid(warrior.swing_target)), "Warrior navigates into range and begins a sword windup")
	check(ValeMelee.can_hit(warrior, wolf, warrior.stats.melee_range), "Sword windup starts within unobstructed melee range")
	check(wolf.health.current == 40, "Sword windup delays its first damage")
	check(await until(func(): return wolf.health.current < 40, 60), "Sword swing resolves after its windup")
	check(wolf.health.current == 32, "Sword applies exactly 8 damage")
	check(await until(func(): return warrior.health.current < 60, 60), "Engaged wolf retaliates with a timed bite")
	check(warrior.health.current == 54, "Wolf bite applies exactly 6 damage")
	var active_destination: Vector3 = warrior.destination
	var hud_panel: PanelContainer = world.get_node("HUD/Panel")
	await dispatch_click(hud_panel.get_global_rect().position + Vector2(12, 12))
	check(warrior.selected_target == wolf and warrior.destination == active_destination, "HUD input preserves the combat target and movement command")
	var wolf_deaths := [0]
	wolf.health.died.connect(func(): wolf_deaths[0] += 1)
	check(await until(func(): return not wolf.is_alive()), "Auto-attacks complete a fight and defeat the wolf")
	await frames(2)
	check(warrior.is_alive(), "Warrior survives the default first fight")
	check(warrior.selected_target == null and not wolf.get_node("SelectionRing").visible, "Wolf death clears targeting and selection feedback")
	check(wolf.collision_layer == 0 and not warrior.request_move(wolf.global_position, wolf), "Defeated wolf cannot be selected again")
	check(wolf.health.take_damage(999) == 0 and wolf_deaths[0] == 1, "Death is emitted once and defeated health cannot be damaged again")

	reset_pair()
	await stand_in_melee()
	check(await until(func(): return is_instance_valid(warrior.swing_target), 10), "A reset fight can start another windup")
	await dispatch_click(world.camera.unproject_position(Vector3(-6, 0, 7)))
	check(warrior.selected_target == null and not is_instance_valid(warrior.swing_target), "Ground click cancels target pursuit and a pending sword swing")
	await frames(40)
	check(wolf.health.current == 40, "Cancelled windup cannot deal delayed damage")
	check(warrior.global_position.distance_to(wolf.global_position) > 2.0, "Ground cancellation lets the Warrior walk out of melee")

	reset_pair()
	await stand_in_melee()
	await until(func(): return is_instance_valid(warrior.swing_target), 10)
	wolf.global_position += Vector3(5, 0, 0)
	await frames(40)
	check(wolf.health.current == 40, "Sword rechecks range when damage resolves")
	check(warrior.health.current == 60, "Wolf bite also rechecks range when damage resolves")
	warrior.clear_combat_target()
	warrior.global_position = Vector3(-3, 0.01, 0)
	wolf.global_position = Vector3(3, 0.01, 0)
	await frames(2)
	check(not ValeMelee.can_hit(warrior, wolf, 10.0), "Blocking scenery prevents melee damage even inside a supplied range")

	reset_pair()
	warrior.global_position = wolf.global_position + Vector3(0, 0, 1.4)
	check(await until(func(): return wolf.biting, 30), "Wolf starts a bite against an untargeting Warrior")
	press_key(KEY_2)
	check(await until(func(): return world.guard_status.text.contains("Guard active"), 10)
		and warrior.guard_ring.visible, "Pressing 2 activates Guard and shows its HUD and world cues")
	var guard_time: float = warrior.guard_remaining
	press_key(KEY_2)
	check(warrior.guard_remaining == guard_time, "Pressing 2 again does not extend active Guard")
	check(await until(func(): return warrior.health.current < 60, 40), "A bite lands during the Guard window")
	check(warrior.health.current == 57 and world.combat_hud.get_node("LastHit").text.contains("Guard blocked 3"),
		"Guard halves the bite damage and reports the blocked amount")
	check(await until(func(): return world.guard_status.text.contains("Guard cooldown"), 90)
		and not warrior.guard_ring.visible, "Guard expires and the HUD switches to its cooldown")
	press_key(KEY_2)
	check(warrior.guard_remaining == 0.0, "Guard cannot activate a second time during cooldown")
	var guarded_health: int = warrior.health.current
	check(await until(func(): return warrior.health.current < guarded_health, 110)
		and warrior.health.current == guarded_health - 6, "Bite damage returns to normal once Guard expires")
	check(await until(func(): return world.guard_status.text.contains("Guard ready"), 400), "Guard becomes ready when its cooldown finishes")
	press_key(KEY_2)
	check(warrior.guard_remaining > 0.0, "Guard can be activated again after cooldown")

	reset_pair()
	check(warrior.guard_remaining == 0.0 and warrior.guard_cooldown_remaining == 0.0 and not warrior.guard_ring.visible,
		"Reset clears active Guard and its cooldown")
	warrior.global_position = Vector3(6, 0.02, 4.5)
	check(await until(func(): return wolf.opponent == warrior, 15), "Wolf acquires a visible Warrior within its aggro range")
	warrior.global_position = Vector3(-3.25, 0.02, 1)
	check(await until(func(): return absf(wolf.global_position.x) < 2.5 and absf(wolf.global_position.z) > 3.3, 180),
		"An engaged wolf navigates around the ruin to follow the Warrior")
	check(await until(func(): return wolf.biting and wolf.global_position.x < -2.5, 180),
		"Wolf reaches biting range on the far side of the ruin")
	wolf.health.take_damage(8)
	var health_before_leash: int = warrior.health.current
	warrior.global_position = Vector3(-10, 0.02, 1)
	check(await until(func(): return wolf.returning, 10) and wolf.opponent == null and not wolf.biting,
		"Leaving the leash drops aggro and cancels the pending bite")
	check(wolf.global_position.distance_to(wolf.spawn_position) > 4.0 and wolf.health.current == 32,
		"Leashing starts a walk home from the current position")
	check(await until(func(): return not wolf.returning and wolf.global_position.distance_to(wolf.spawn_position) <= 0.3, 360),
		"Wolf navigates back to its authored spawn")
	check(wolf.health.current == 40 and warrior.health.current == health_before_leash, "Returning restores wolf health without further attacks")
	warrior.global_position = Vector3(6, 0.02, 4.5)
	check(await until(func(): return wolf.opponent == warrior, 15), "The wolf can aggro again after returning")
	warrior.global_position = warrior.recovery_point.global_position
	check(warrior.global_position.distance_to(wolf.spawn_position) < wolf.leash_range
		and await until(func(): return wolf.returning, 10), "The watchpost breaks pursuit even within the wolf's leash distance")

	reset_pair()
	warrior.global_position = wolf.global_position + Vector3(0, 0, 1.4)
	warrior.health.take_damage(54)
	var warrior_deaths := [0]
	warrior.health.died.connect(func(): warrior_deaths[0] += 1)
	wolf.engage(warrior)
	check(await until(func(): return not warrior.is_alive(), 120), "A fatal wolf bite defeats the Warrior")
	check(warrior.health.current == 0 and warrior_deaths[0] == 1, "Fatal damage clamps health to zero and emits one death")
	check(not warrior.request_move(Vector3(0, 0, 7)) and not warrior.moving, "Defeated Warrior cannot move or start a new command")
	press_key(KEY_2)
	var dead_click: Vector2 = world.camera.unproject_position(Vector3(7, 0, 7))
	dispatch_mouse_button(dead_click, true)
	await frames(20)
	check(not world.following_cursor and warrior.guard_remaining == 0.0, "Defeated Warrior cannot Guard or start a held movement gesture")
	dispatch_mouse_button(dead_click, false)
	check(warrior.health.current == 0 and warrior_deaths[0] == 1 and not wolf.biting, "Wolf stops attacking the defeated Warrior")
	check(await until(func(): return warrior.is_alive(), 150), "Warrior automatically recovers after defeat")
	check(warrior.health.current == 60 and warrior.is_in_refuge() and warrior.selected_target == null and not warrior.moving,
		"Automatic recovery returns the Warrior to the watchpost at full health without a stale command")
	await frames(20)
	check(warrior.health.current == 60 and wolf.opponent == null, "The Warrior stays safe at the watchpost after recovery")
	await test_cleave()
	await test_raider_attacks()
	print("Combat checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func test_cleave() -> void:
	var raider: ValeRaider = world.get_node("CampRaider")
	var other_raider: ValeRaider = world.get_node("CampRaiderSecond")
	wolf.set_physics_process(false)
	warrior.level = 2
	warrior.reset_combat()
	warrior.global_position = Vector3(-6.5, 0.02, 6.5)
	warrior.visual.rotation.y = PI
	raider.global_position = Vector3(-6, 0.02, 4.5)
	other_raider.global_position = Vector3(-7, 0.02, 4.5)
	wolf.global_position = Vector3(-6.5, 0.02, 8)
	await frames(2)
	press_key(KEY_1)
	check(raider.health.current == 16 and other_raider.health.current == 16, "Cleave hits both enemies in front for 12 damage")
	check(wolf.health.current == 40, "Cleave skips enemies behind the Warrior")
	check(warrior.cleave_arc.visible and world.combat_hud.get_node("LastHit").text == "Cleave hits 2 enemies",
		"Cleave displays its arc and reports targets hit")
	press_key(KEY_1)
	check(raider.health.current == 16 and other_raider.health.current == 16, "Cleave deals no damage during cooldown")
	check(await until(func(): return world.cleave_status.text.contains("Cleave cooldown"), 10), "Cleave shows cooldown")
	check(await until(func(): return world.cleave_status.text == "1 · Cleave ready", 260)
		and not warrior.cleave_arc.visible, "Cleave becomes ready and the arc clears")

	warrior.global_position = Vector3(-1.7, 0.02, 3.7)
	raider.global_position = Vector3(-3.1, 0.02, 2.1)
	var toward_raider := raider.global_position - warrior.global_position
	warrior.visual.rotation.y = atan2(toward_raider.x, toward_raider.z)
	await frames(2)
	press_key(KEY_1)
	check(raider.health.current == 16 and world.combat_hud.get_node("LastHit").text == "Cleave misses",
		"Cleave respects blocking scenery and its range")

func test_raider_attacks() -> void:
	var raider: ValeRaider = world.get_node("CampRaider")
	var captain: ValeRaider = world.get_node("RaiderCaptain")
	warrior.reset_combat()
	raider.reset_combat()
	raider.set_physics_process(true)
	warrior.global_position = raider.spawn_position + Vector3(0, 0, 1.6)
	check(await until(func(): return raider.attacking and raider.windup_remaining > 0.5, 60),
		"A camp raider winds up a basic swing")
	check(await until(func(): return warrior.health.current < 75, 70)
		and warrior.health.current == 68, "A raider swing deals 7 damage")

	raider.set_physics_process(false)
	raider.reset_combat()
	warrior.reset_combat()
	captain.reset_combat()
	captain.set_physics_process(true)
	warrior.global_position = captain.spawn_position + Vector3(0, 0, 1.6)
	check(await until(func(): return captain.heavy_attacking and captain.telegraph.visible, 30),
		"The Captain telegraphs the first heavy attack")
	check(await until(func(): return warrior.health.current < 75, 100)
		and warrior.health.current == 55, "An unguarded heavy attack deals 20 damage")
	check(await until(func(): return warrior.health.current < 55, 145)
		and warrior.health.current == 46, "The Captain uses a 9-damage swing between heavy attacks")
