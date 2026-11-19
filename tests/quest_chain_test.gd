extends SceneTree
## Play the Watchpost quest chain and verify both ways of handling the heavy attack.

const NAVIGATION := preload("res://tests/navigation_test_support.gd")
const WATCHPOST_SCENE := preload("res://scenes/watchpost_playtest.tscn")

var assertions := 0
var failures := 0
var world: Node3D
var warrior: ValePlayer

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
	for frame in count:
		await physics_frame
	await process_frame

func until(condition: Callable, limit: int = 360) -> bool:
	for frame in limit:
		await physics_frame
		if condition.call():
			return true
	return false

func click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(2)

func click_world(point: Vector3) -> void:
	await click(world.camera.unproject_position(point))

func walk_to(point: Vector3) -> bool:
	await click_world(point)
	return await until(func(): return not warrior.moving) and warrior.global_position.distance_to(point) < 0.6

func click_button(button: Button) -> void:
	await click(button.get_global_rect().get_center())

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

func start() -> void:
	world = WATCHPOST_SCENE.instantiate()
	root.add_child(world)
	warrior = world.get_node("Player")
	await frames(5)
	await NAVIGATION.wait_for_spawn(world, warrior)

func talk_to_mara() -> bool:
	await click_world(world.mara.global_position + Vector3.UP)
	return await until(func(): return world.journal.visible and world.journal_title.text == "Captain Mara")

func quest_option(label: String) -> Button:
	for button: Button in world.quest_options.get_children():
		if button.text == label and button.is_visible_in_tree():
			return button
	return null

func choose_quest_option(label: String) -> bool:
	var button := quest_option(label)
	if not button:
		return false
	await click_button(button)
	return true

func equip_from_panel(item_name: String) -> bool:
	await press_key(KEY_B)
	for button: Button in world.gear_options.get_children():
		if button.text.begins_with("Equip " + item_name):
			await click_button(button)
			await press_key(KEY_B)
			return true
	await press_key(KEY_B)
	return false

func restart() -> void:
	world.queue_free()
	await process_frame
	await start()

func check_early_wolf_at_watchpost() -> void:
	var wolf: ValeWolf = world.get_node("Wolf")
	var watchpost: Marker3D = world.get_node("Watchpost")
	var pine_road: ValeQuestProgress = world.quest_chain[0]
	wolf.respawn_delay = 4.0
	await click_world(wolf.global_position + Vector3.UP * 0.85)
	await until(func(): return wolf.biting, 220)
	await press_key(KEY_2)
	check(await until(func(): return not wolf.is_alive(), 420) and warrior.is_alive()
		and pine_road.state == ValeQuestProgress.State.AVAILABLE and warrior.experience == 5,
		"The first road wolf can be defeated through gameplay before accepting Clear Pine Road")
	check(await walk_to(watchpost.global_position) and warrior.is_in_refuge()
		and wolf.spawn_position.distance_to(warrior.global_position) <= wolf.leash_range and not wolf.is_alive(),
		"The Warrior can return to the refuge inside the wolf's leash before the delay elapses")
	check(await until(func(): return wolf.is_alive(), 260) and wolf.health.current == wolf.stats.max_health
		and pine_road.state == ValeQuestProgress.State.AVAILABLE,
		"Waiting at the watchpost lets the first wolf respawn while Clear Pine Road is still unaccepted")
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(pine_road.state == ValeQuestProgress.State.ACTIVE and pine_road.kills == 0,
		"Accepting Clear Pine Road after the watchpost wait still starts at zero kills")

func check_regular_respawns() -> void:
	var wolf: ValeWolf = world.get_node("Wolf")
	var raider: ValeRaider = world.get_node("CampRaider")
	var pine_road: ValeQuestProgress = world.quest_chain[0]
	wolf.respawn_delay = 0.2
	raider.respawn_delay = 0.6
	var respawns := [0, 0]
	wolf.respawned.connect(func(): respawns[0] += 1)
	raider.respawned.connect(func(): respawns[1] += 1)
	warrior.global_position = wolf.spawn_position + Vector3(0, 0, 2)
	wolf.global_position += Vector3(0, 0, 1)
	raider.global_position += Vector3(0.5, 0, 0)
	wolf.receive_hit(999, warrior)
	raider.receive_hit(999, warrior)
	await frames(20)
	check(not wolf.is_alive() and wolf.collision_layer == 0,
		"A road wolf stays defeated past the delay while the Warrior is within its leash")
	check(not raider.is_alive() and raider.collision_layer == 0,
		"Leaving a camp raider's leash before its delay still requires the full delay")
	warrior.global_position = Vector3(-5, 0.02, 7)
	check(await until(func(): return wolf.is_alive() and raider.is_alive(), 40),
		"Both regular enemies return once the Warrior is outside and the delay has elapsed")
	for enemy: ValeEnemy in [wolf, raider]:
		check(enemy.global_position.distance_to(enemy.spawn_position) < 0.1
			and enemy.health.current == enemy.stats.max_health and enemy.collision_layer == 8
			and enemy.opponent == null and not enemy.attacking and not enemy.returning
			and enemy.attack_cooldown == 0.0 and not enemy.get_node("SelectionRing").visible,
			"%s returns to its authored spawn with full health and reset AI" % enemy.stats.display_name)
	check(warrior.experience == 10 and pine_road.kills == 0,
		"Pre-quest regular defeats grant XP without storing kill credit")
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(pine_road.state == ValeQuestProgress.State.ACTIVE and pine_road.kills == 0,
		"Accepting Clear Pine Road starts at zero after a pre-quest wolf defeat")
	warrior.global_position = Vector3(-5, 0.02, 7)
	wolf.receive_hit(999, warrior)
	raider.receive_hit(999, warrior)
	check(pine_road.kills == 1 and warrior.experience == 20,
		"The respawned wolf credits the active objective and both regular defeats grant XP again")
	check(await until(func(): return wolf.is_alive() and raider.is_alive(), 50) and respawns == [2, 2],
		"Each repeated defeat restores its existing placement exactly once")

func check_early_captain() -> void:
	var captain: ValeRaider = world.get_node("RaiderCaptain")
	var blockade: ValeQuestProgress = world.quest_chain[2]
	var marker: Label3D = captain.get_node("QuestMarker")
	var crate: ValeInteractable = world.get_node("SupplyCrate")
	captain.respawn_delay = 4.0
	warrior.global_position = captain.spawn_position + Vector3(0, 0, 2)
	captain.receive_hit(999, warrior)
	check(blockade.state == ValeQuestProgress.State.AVAILABLE and blockade.kills == 0
		and warrior.experience == 15 and warrior.owned_items.has(&"wardens_coat") and world.loot_notice.visible,
		"An early Captain defeat grants 15 XP and the coat without banking quest credit")
	world.loot_notice.hide()
	warrior.reset_combat()
	await frames(2)

	await talk_to_mara()
	await click_button(world.dialogue_action)
	for wolf_path in ["Wolf", "WolfSecond", "WolfThird"]:
		world.get_node(wolf_path).receive_hit(999, warrior)
	await talk_to_mara()
	await click_button(world.dialogue_action)
	await choose_quest_option("View Recover the Supplies")
	await click_button(world.dialogue_action)
	warrior.global_position = crate.global_position + Vector3(0, 0, 1)
	await frames(2)
	crate.interacted.emit()
	warrior.reset_combat()
	await frames(2)
	await talk_to_mara()
	await click_button(world.dialogue_action)
	await choose_quest_option("View Break the Blockade")
	await click_button(world.dialogue_action)
	check(blockade.state == ValeQuestProgress.State.ACTIVE and blockade.kills == 0
		and not captain.is_alive() and not marker.visible and world.objective_label.text.contains("0 / 1"),
		"Accepting Break the Blockade after an early defeat leaves the objective open")
	check(await until(func(): return captain.is_alive(), 260) and marker.visible
		and captain.global_position.distance_to(captain.spawn_position) < 0.1
		and captain.health.current == captain.stats.max_health and not captain.telegraph.visible
		and captain.heavy_cooldown_remaining == 0.0,
		"The Captain returns to Quarry Gate with full health, reset attacks, and the active quest marker")
	captain.respawn_delay = 0.2
	warrior.global_position = captain.spawn_position + Vector3(0, 0, 2)
	captain.receive_hit(999, warrior)
	check(blockade.state == ValeQuestProgress.State.READY and blockade.kills == 1 and not marker.visible
		and warrior.experience == 185 and warrior.owned_items.size() == 6 and not world.loot_notice.visible,
		"The rematch grants another 15 XP and readies the quest without a second coat")
	await frames(20)
	check(not captain.is_alive() and captain.collision_layer == 0,
		"The Captain stays down while the Warrior remains at Quarry Gate past the respawn delay")
	warrior.reset_combat()
	check(await until(func(): return captain.is_alive(), 30) and not marker.visible
		and blockade.state == ValeQuestProgress.State.READY and blockade.kills == 1,
		"The credited Captain returns before turn-in without reopening the quest objective")
	captain.respawn_delay = 1.5
	captain.receive_hit(999, warrior)
	check(warrior.experience == 200 and blockade.state == ValeQuestProgress.State.READY and blockade.kills == 1
		and warrior.owned_items.size() == 6 and not world.loot_notice.visible,
		"A further defeat grants kill XP while the turn-in is ready and the coat stays one-time")
	# Use a smaller turn-in reward here so the next defeat's XP is visible below the cap.
	blockade.definition = blockade.definition.duplicate() as ValeQuestDefinition
	blockade.definition.reward_xp = 20
	await frames(2)
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(blockade.state == ValeQuestProgress.State.COMPLETED and warrior.experience == 220 and not captain.is_alive(),
		"Break the Blockade can be turned in while the Captain's respawn timer is running")
	check(await until(func(): return captain.is_alive(), 120) and not marker.visible
		and captain.health.current == captain.stats.max_health and blockade.state == ValeQuestProgress.State.COMPLETED,
		"The Captain returns at full health after the quest is complete")
	captain.receive_hit(999, warrior)
	check(warrior.experience == 235 and blockade.state == ValeQuestProgress.State.COMPLETED and blockade.kills == 1
		and warrior.owned_items.size() == 6 and not world.loot_notice.visible,
		"Defeating the Captain after turn-in still grants kill XP and preserves the completed quest")

func check_concurrent_turn_ins() -> void:
	var pine_road: ValeQuestProgress = world.quest_chain[0]
	var supplies: ValeQuestProgress = world.quest_chain[1]
	var blockade: ValeQuestProgress = world.quest_chain[2]
	var crate: ValeInteractable = world.get_node("SupplyCrate")
	await talk_to_mara()
	check(await choose_quest_option("View Recover the Supplies") and world.dialogue_quest == supplies
		and world.dialogue_action.text == "Accept quest" and quest_option("View Break the Blockade") == null,
		"Mara offers supplies before Clear Pine Road and keeps Break the Blockade locked")
	await click_button(world.dialogue_action)
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(supplies.state == ValeQuestProgress.State.ACTIVE and pine_road.state == ValeQuestProgress.State.ACTIVE
		and world.tracked_quest == supplies and crate.objective_marker.visible,
		"Accepting both quests retains the first tracked quest and enables the supply marker")

	await click_world(Vector3(8, 0, 6.8))
	var destination := warrior.destination
	await press_key(KEY_J)
	check(world.journal_body.text.contains("Recover the Supplies · In progress · Tracked")
		and world.journal_body.text.contains("Clear Pine Road · In progress") and world.journal_body.text.contains("0 / 3"),
		"The journal shows both active quests with their own objectives")
	check(await choose_quest_option("Track Clear Pine Road") and world.tracked_quest == pine_road
		and world.objective_label.text.contains("0 / 3") and warrior.moving and warrior.destination == destination,
		"Tracking Clear Pine Road changes the HUD while preserving the active movement command")
	world.get_node("Wolf").receive_hit(999, warrior)
	check(pine_road.kills == 1 and supplies.state == ValeQuestProgress.State.ACTIVE,
		"A wolf defeat advances the road objective independently")

	warrior.clear_combat_target()
	warrior.global_position = crate.global_position + Vector3(0, 0, 1)
	await frames(2)
	crate.interacted.emit()
	check(supplies.state == ValeQuestProgress.State.READY and pine_road.state == ValeQuestProgress.State.ACTIVE
		and pine_road.kills == 1 and world.journal_body.text.contains("Recover the Supplies · Ready to turn in")
		and world.objective_label.text.contains("1 / 3") and not crate.visible,
		"Collecting supplies readies the untracked quest and leaves wolf progress on the HUD")
	world.get_node("WolfSecond").receive_hit(999, warrior)
	world.get_node("WolfThird").receive_hit(999, warrior)
	check(world.journal_body.text.count("Ready to turn in") == 2 and world.quest_marker.text == "?",
		"The journal and Mara indicate that both quests are ready")
	check(await choose_quest_option("Track Recover the Supplies") and world.objective_label.text.begins_with("Recover the Supplies")
		and await choose_quest_option("Track Clear Pine Road") and world.objective_label.text.begins_with("Clear Pine Road"),
		"The HUD identifies the tracked quest even when both require a turn-in at Mara")

	warrior.reset_combat()
	await frames(2)
	await press_key(KEY_J)
	await talk_to_mara()
	check(await choose_quest_option("View Recover the Supplies") and world.dialogue_quest == supplies
		and world.dialogue_action.text == "Turn in quest" and quest_option("View Break the Blockade") == null,
		"Mara lets the player choose which ready quest to turn in first")
	await click_button(world.dialogue_action)
	check(supplies.state == ValeQuestProgress.State.COMPLETED and pine_road.state == ValeQuestProgress.State.READY
		and pine_road.kills == 3 and warrior.experience == 70 and not warrior.owned_items.has(&"iron_sword")
		and quest_option("View Break the Blockade") == null,
		"Turning in supplies pays only its reward and keeps Clear Pine Road ready with all three kills")
	await press_key(KEY_J)
	check(world.journal_body.text.contains("Recover the Supplies · Completed")
		and world.journal_body.text.contains("Clear Pine Road · Ready to turn in · Tracked"),
		"The same journal shows a completed quest and the other quest's preserved turn-in state")
	await press_key(KEY_J)
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(pine_road.state == ValeQuestProgress.State.COMPLETED and blockade.state == ValeQuestProgress.State.AVAILABLE
		and warrior.experience == 155 and warrior.owned_items.has(&"iron_sword")
		and quest_option("View Break the Blockade") != null,
		"Break the Blockade becomes eligible after both turn-ins in reverse order")

func run() -> void:
	await start()
	await check_early_wolf_at_watchpost()
	await restart()
	var pine_road: ValeQuestProgress = world.quest_chain[0]
	var supplies: ValeQuestProgress = world.quest_chain[1]
	var blockade: ValeQuestProgress = world.quest_chain[2]
	var captain: ValeRaider = world.get_node("RaiderCaptain")
	var boss_marker: Label3D = captain.get_node("QuestMarker")
	var crate: ValeInteractable = world.get_node("SupplyCrate")
	var camp_raider: ValeRaider = world.get_node("CampRaider")
	var other_raider: ValeRaider = world.get_node("CampRaiderSecond")
	var optional_wolf: ValeWolf = world.get_node("WolfNorthwest")
	check(world.quest_chain.size() == 3 and pine_road.definition.id == &"clear_pine_road"
		and blockade.definition.id == &"break_the_blockade" and warrior.level == 1 and not boss_marker.visible,
		"The Watchpost starts the three-quest chain at level 1")

	warrior.global_position = Vector3(6, 0.02, -8.5)
	await frames(3)
	await click_world(crate.global_position + Vector3.UP * 0.45)
	check(await until(func(): return world.status.text.contains("about the supply crate"))
		and crate.visible and not crate.objective_marker.visible, "The crate cannot be collected before accepting its quest")
	warrior.global_position = warrior.spawn_position
	await frames(3)

	await talk_to_mara()
	check(world.journal_body.text.begins_with("Clear Pine Road") and world.dialogue_action.text == "Accept quest"
		and quest_option("View Recover the Supplies") != null, "Mara presents both starter offers at the first meeting")
	await click_button(world.dialogue_action)
	check(await talk_to_mara() and world.dialogue_quest == supplies and world.dialogue_action.text == "Accept quest",
		"Mara offers Recover the Supplies while Clear Pine Road is active")
	await click_button(world.dialogue_action)
	check(crate.objective_marker.visible and world.tracked_quest == pine_road,
		"Accepting Recover the Supplies marks the crate while the HUD tracks Clear Pine Road")
	await press_key(KEY_J)
	check(world.journal_body.text.contains("0 / 3"), "The active quest log shows the wolf objective")
	await press_key(KEY_J)
	for wolf_path in ["Wolf", "WolfSecond", "WolfThird"]:
		var wolf: ValeWolf = world.get_node(wolf_path)
		await click_world(wolf.global_position + Vector3.UP * 0.85)
		await until(func(): return wolf.biting, 220)
		await press_key(KEY_2)
		check(await until(func(): return not wolf.is_alive(), 420), "The Watchpost chain supports the %s fight" % wolf_path)
	check(warrior.experience == 15 and warrior.level == 1, "The required road wolves award 15 XP before turn-in")
	await walk_to(Vector3(8, 0, 6.8))
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(warrior.level == 2 and warrior.experience == 100 and pine_road.state == ValeQuestProgress.State.COMPLETED,
		"Clear Pine Road unlocks level 2 in the full chain")
	check(supplies.state == ValeQuestProgress.State.ACTIVE and world.tracked_quest == supplies and crate.objective_marker.visible,
		"Turning in Clear Pine Road switches the HUD to the remaining active quest")
	check(await equip_from_panel("Iron Sword") and warrior.sword_damage() == 12, "The Iron Sword equips before the later quests")

	await walk_to(Vector3(8, 0, 6.8))
	await walk_to(Vector3(8, 0, -7.5))
	var crate_pick := crate.global_position + Vector3.UP * 0.45
	await click_world(crate_pick)
	check(await until(func(): return not crate.visible) and crate.collision_layer == 0 and warrior.experience == 100,
		"The crate can be collected without defeating its guards")
	await click_world(crate_pick)
	check(supplies.state == ValeQuestProgress.State.READY and warrior.experience == 100,
		"A repeated click cannot collect again or grant XP")
	await walk_to(Vector3(8, 0, -7.5))
	await walk_to(Vector3(8, 0, 6.8))
	warrior.receive_hit(999, null)
	check(await until(func(): return warrior.is_alive(), 150) and supplies.state == ValeQuestProgress.State.READY
		and not crate.visible and warrior.sword_damage() == 12, "Recovery preserves cargo, quest readiness, and equipment")
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(warrior.experience == 155 and quest_option("View Break the Blockade") != null,
		"The supplies turn-in offers Break the Blockade at 155 XP")
	check(await choose_quest_option("View Break the Blockade") and world.journal_body.text.begins_with("Break the Blockade"),
		"Mara gives the directions to Quarry Gate")
	await click_button(world.dialogue_action)
	check(blockade.state == ValeQuestProgress.State.ACTIVE and boss_marker.visible
		and world.objective_label.text.contains("Quarry Gate"), "Accepting the quest marks the Captain and the quarry objective")

	var quarry_approach := Vector3(-8.6, 0, 6.8)
	check(await walk_to(quarry_approach), "The south road reaches Quarry Gate")
	await click_world(captain.global_position + Vector3.UP)
	check(warrior.selected_target == captain and await until(func(): return captain.heavy_attacking, 180),
		"Clicking the Captain starts the quarry fight and heavy windup")
	var hp_before_dodge: int = warrior.health.current
	var danger_center := captain.telegraph.global_position
	var dodge_point := warrior.global_position + Vector3(3.6, 0, 0.4)
	dodge_point.y = 0
	await click_world(dodge_point)
	check(captain.heavy_attacking and captain.telegraph.global_position == danger_center,
		"The danger circle stays anchored while the Warrior moves")
	check(await until(func(): return not captain.heavy_attacking, 90) and warrior.health.current == hp_before_dodge, "Moving clear avoids the heavy attack")

	# Start a second attempt at full health to check mitigation independently.
	warrior.receive_hit(999, null)
	check(await until(func(): return warrior.is_alive(), 150) and blockade.state == ValeQuestProgress.State.ACTIVE,
		"Defeat during an attempt retains the active Captain quest")
	await until(func(): return not captain.returning, 300)
	await walk_to(quarry_approach)
	await click_world(captain.global_position + Vector3.UP)
	check(await until(func(): return captain.heavy_attacking, 180), "The Captain telegraphs again after returning to the quarry")
	await frames(32)
	var hp_before_guard: int = warrior.health.current
	await press_key(KEY_2)
	check(await until(func(): return not captain.heavy_attacking, 90) and warrior.health.current == hp_before_guard - 10, "Guard halves the heavy hit to 10")
	await press_key(KEY_1)
	check(await until(func(): return not captain.is_alive(), 420) and warrior.is_alive(),
		"The Warrior can defeat the Captain with the earned sword and abilities")
	check(blockade.kills == 1 and blockade.state == ValeQuestProgress.State.READY and not boss_marker.visible
		and warrior.experience == 170, "The Captain grants 15 XP and readies the final turn-in")
	check(warrior.owned_items.has(&"wardens_coat") and warrior.armor_value() == 0 and world.loot_notice.visible
		and world.loot_notice.text.contains("Warden's Coat"), "The coat is awarded on defeat and awaits manual equip")
	captain.receive_hit(999, warrior)
	check(warrior.experience == 170 and warrior.owned_items.size() == 6, "Hitting the defeated Captain cannot grant kill rewards again")
	check(await walk_to(Vector3(-4.8, 0, 6.8)), "The south road connects the quarry to the watchpost")

	warrior.receive_hit(999, null)
	await until(func(): return warrior.is_alive(), 150)
	check(not captain.is_alive() and captain.collision_layer == 0 and blockade.state == ValeQuestProgress.State.READY
		and warrior.owned_items.has(&"wardens_coat") and warrior.experience == 170,
		"Death recovery retains the coat and final turn-in during the Captain's respawn delay")
	check(await talk_to_mara() and world.dialogue_action.text == "Turn in quest", "Mara accepts the Captain's defeat")
	await click_button(world.dialogue_action)
	check(blockade.state == ValeQuestProgress.State.COMPLETED and warrior.experience == 240 and warrior.level == 3
		and warrior.health.maximum == 90 and world.objective_label.text == "Watchpost quest chain complete",
		"The final 70 XP reaches level 3 at 240 XP and completes the quest chain")
	check(camp_raider.is_alive() and other_raider.is_alive() and optional_wolf.is_alive(),
		"The required route reaches level 3 with all optional enemies alive")
	check(await talk_to_mara() and not world.dialogue_action.visible and warrior.experience == 240
		and warrior.owned_items.size() == 6, "The final turn-in has no repeat reward")
	await press_key(KEY_J)
	check(world.journal_body.text.count("· Completed") == 3 and world.progression_label.text.contains("Max level"),
		"The log records all three completed quests and the HUD shows the level cap")
	await press_key(KEY_J)
	check(await equip_from_panel("Warden's Coat") and warrior.armor_value() == 2 and warrior.sword_damage() == 12
		and warrior.body_material.albedo_color.is_equal_approx(warrior.equipped_armor.coat_color),
		"Equipping the coat changes the appearance and adds 2 armor alongside the Iron Sword")

	await walk_to(Vector3(-7, 0, 6))
	await click_world(Vector3(-7, 0, -3))
	var hp_before_bite: int = warrior.health.current
	check(await until(func(): return warrior.health.current < hp_before_bite, 300)
		and warrior.health.current == hp_before_bite - 4, "The equipped coat reduces a live wolf bite from 6 to 4 damage")
	optional_wolf.receive_hit(999, warrior)
	check(warrior.level == 3 and warrior.experience == 240, "More kill XP respects the prototype cap")

	await restart()
	await check_regular_respawns()
	await restart()
	await check_early_captain()
	await restart()
	await check_concurrent_turn_ins()

	print("Quest chain checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
