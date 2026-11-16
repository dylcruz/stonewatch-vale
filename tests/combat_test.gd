extends SceneTree
## Real-scene tests for checkpoint 1. Direct repositioning sets up range edge cases.

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

func stand_in_melee() -> void:
	warrior.global_position = wolf.global_position + Vector3(0, 0, 1.4)
	warrior.velocity = Vector3.ZERO
	await frames(3)
	warrior.request_move(warrior.global_position, wolf)

func run() -> void:
	world = load("res://scenes/combat_demo.tscn").instantiate()
	root.add_child(world)
	warrior = world.get_node("Player")
	wolf = world.get_node("Wolf")
	await frames(5)
	check(warrior.health.current == 60 and wolf.health.current == 40, "Actors start at their tuned maximum health")
	await dispatch_click(world.camera.unproject_position(wolf.global_position + Vector3.UP * 0.8))
	check(warrior.selected_target == wolf and wolf.get_node("SelectionRing").visible, "Viewport click selects the wolf and shows its ring")
	check(wolf.health.current == 40, "Selecting from a distance does not cause remote damage")
	check(await until(func(): return is_instance_valid(warrior.swing_target)), "Warrior navigates into range and begins a sword windup")
	check(ValeMelee.can_hit(warrior, wolf, warrior.stats.melee_range), "Sword windup starts within unobstructed melee range")
	check(wolf.health.current == 40, "Sword windup delays its first damage")
	check(await until(func(): return wolf.health.current < 40, 60), "Sword swing resolves after its windup")
	check(wolf.health.current == 32, "Sword applies exactly 8 damage")
	check(await until(func(): return warrior.health.current < 60, 60), "Engaged wolf retaliates with a timed bite")
	check(warrior.health.current == 54, "Wolf bite applies exactly 6 damage")
	var active_destination: Vector3 = warrior.destination
	await dispatch_click(world.get_node("HUD/Panel/Margin/VBox/UITest").get_global_rect().get_center())
	check(warrior.selected_target == wolf and warrior.destination == active_destination, "HUD input preserves the combat target and movement command")
	check(world.status.text.begins_with("UI click received"), "HUD button receives the combat-scene click")
	var wolf_deaths := [0]
	wolf.health.died.connect(func(): wolf_deaths[0] += 1)
	check(await until(func(): return not wolf.is_alive()), "Auto-attacks complete a fight and defeat the wolf")
	await frames(2)
	check(warrior.is_alive(), "Warrior survives the default first fight")
	check(warrior.selected_target == null and not wolf.get_node("SelectionRing").visible, "Wolf death clears targeting and selection feedback")
	check(wolf.collision_layer == 0 and not warrior.request_move(wolf.global_position, wolf), "Defeated wolf cannot be selected again")
	check(wolf.health.take_damage(999) == 0 and wolf_deaths[0] == 1, "Death is emitted once and defeated health cannot be damaged again")

	world.reset_fight()
	await stand_in_melee()
	check(await until(func(): return is_instance_valid(warrior.swing_target), 10), "A reset fight can start another windup")
	await dispatch_click(world.camera.unproject_position(Vector3(-6, 0, 7)))
	check(warrior.selected_target == null and not is_instance_valid(warrior.swing_target), "Ground click cancels target pursuit and a pending sword swing")
	await frames(40)
	check(wolf.health.current == 40, "Cancelled windup cannot deal delayed damage")
	check(warrior.global_position.distance_to(wolf.global_position) > 2.0, "Ground cancellation lets the Warrior walk out of melee")

	world.reset_fight()
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

	world.reset_fight()
	warrior.global_position = wolf.global_position + Vector3(0, 0, 1.4)
	warrior.health.take_damage(54)
	var warrior_deaths := [0]
	warrior.health.died.connect(func(): warrior_deaths[0] += 1)
	wolf.engage(warrior)
	check(await until(func(): return not warrior.is_alive(), 120), "A fatal wolf bite defeats the Warrior")
	check(warrior.health.current == 0 and warrior_deaths[0] == 1, "Fatal damage clamps health to zero and emits one death")
	check(not warrior.request_move(Vector3(0, 0, 7)) and not warrior.moving, "Defeated Warrior cannot move or start a new command")
	await frames(120)
	check(warrior.health.current == 0 and warrior_deaths[0] == 1 and not wolf.biting, "Wolf stops attacking the defeated Warrior")
	var reset_event := InputEventKey.new()
	reset_event.keycode = KEY_R
	reset_event.pressed = true
	root.push_input(reset_event, true)
	await frames(2)
	check(warrior.health.current == 60 and wolf.health.current == 40, "R restores both actors to full health")
	check(warrior.global_position.distance_to(warrior.spawn_position) < 0.1 and wolf.global_position == wolf.spawn_position, "Reset restores authored starting positions")
	check(warrior.selected_target == null and warrior.attack_cooldown == 0.0 and wolf.opponent == null and wolf.collision_layer == 8, "Reset clears combat state and restores wolf picking")
	print("Combat checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
