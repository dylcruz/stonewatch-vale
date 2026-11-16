extends SceneTree
## Play the F5 quest chain and verify both ways of handling the heavy attack.

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

func start(scene_path: String) -> void:
	world = load(scene_path).instantiate()
	root.add_child(world)
	warrior = world.get_node("Player")
	await frames(5)

func talk_to_mara() -> bool:
	await click_world(world.mara.global_position + Vector3.UP)
	return await until(func(): return world.journal.visible and world.journal_title.text == "Captain Mara")

func equip_from_panel(item_name: String) -> bool:
	await press_key(KEY_I)
	for button: Button in world.gear_options.get_children():
		if button.text.begins_with("Equip " + item_name):
			await click_button(button)
			await press_key(KEY_I)
			return true
	await press_key(KEY_I)
	return false

func run() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	await start(main_scene)
	var blockade: ValeQuestProgress = world.quest_chain[2]
	var captain: ValeRaider = world.get_node("RaiderCaptain")
	var boss_marker: Label3D = captain.get_node("QuestMarker")
	var crate: ValeInteractable = world.get_node("SupplyCrate")
	var camp_raider: ValeRaider = world.get_node("CampRaider")
	var other_raider: ValeRaider = world.get_node("CampRaiderSecond")
	var optional_wolf: ValeWolf = world.get_node("WolfNorthwest")
	check(world.quest_chain.size() == 3 and world.quest.definition.id == &"clear_pine_road"
		and blockade.definition.id == &"break_the_blockade" and warrior.level == 1 and not boss_marker.visible,
		"F5 starts the three-quest chain at level 1")

	warrior.global_position = Vector3(6, 0.02, -8.5)
	await frames(3)
	await click_world(crate.global_position + Vector3.UP * 0.45)
	check(await until(func(): return world.status.text.contains("about the supply crate"))
		and crate.visible and not crate.objective_marker.visible, "The crate cannot be collected before accepting its quest")
	warrior.global_position = warrior.spawn_position
	await frames(3)

	await talk_to_mara()
	check(world.journal_body.text.begins_with("Clear Pine Road") and world.dialogue_action.text == "Accept quest",
		"Mara opens the first quest offer")
	await click_button(world.dialogue_action)
	await press_key(KEY_J)
	check(world.journal_body.text.contains("0 / 3"), "The active quest log shows the wolf objective")
	await press_key(KEY_J)
	for wolf_path in ["Wolf", "WolfSecond", "WolfThird"]:
		var wolf: ValeWolf = world.get_node(wolf_path)
		await click_world(wolf.global_position + Vector3.UP * 0.85)
		await until(func(): return wolf.biting, 220)
		await press_key(KEY_2)
		check(await until(func(): return not wolf.is_alive(), 420), "The F5 chain supports the %s fight" % wolf_path)
	await walk_to(Vector3(8, 0, 6.8))
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(warrior.level == 2 and warrior.experience == 100, "Clear Pine Road unlocks level 2 in the full chain")
	await click_button(world.dialogue_action)
	await click_button(world.dialogue_action)
	check(crate.objective_marker.visible, "Accepting Recover the Supplies marks the crate")
	check(await equip_from_panel("Iron Sword") and warrior.sword_damage() == 12, "The Iron Sword equips before the later quests")

	await walk_to(Vector3(8, 0, 6.8))
	await walk_to(Vector3(8, 0, -7.5))
	var crate_pick := crate.global_position + Vector3.UP * 0.45
	await click_world(crate_pick)
	check(await until(func(): return not crate.visible) and crate.collision_layer == 0 and warrior.experience == 100,
		"The crate can be collected without defeating its guards")
	await click_world(crate_pick)
	check(world.quest.state == ValeQuestProgress.State.READY and warrior.experience == 100,
		"A repeated click cannot collect again or grant XP")
	await walk_to(Vector3(8, 0, -7.5))
	await walk_to(Vector3(8, 0, 6.8))
	warrior.receive_hit(999, null)
	check(await until(func(): return warrior.is_alive(), 150) and world.quest.state == ValeQuestProgress.State.READY
		and not crate.visible and warrior.sword_damage() == 12, "Recovery preserves cargo, quest readiness, and equipment")
	await talk_to_mara()
	await click_button(world.dialogue_action)
	check(warrior.experience == 155 and world.quest == blockade and blockade.state == ValeQuestProgress.State.AVAILABLE,
		"The supplies turn-in offers Break the Blockade at 155 XP")
	await click_button(world.dialogue_action)
	check(world.journal_body.text.begins_with("Break the Blockade"), "Mara gives the directions to Quarry Gate")
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
	check(await until(func(): return not captain.heavy_attacking, 90) and warrior.health.current == hp_before_dodge
		and world.combat_hud.get_node("LastHit").text.contains("Heavy attack misses"), "Moving clear avoids the heavy attack")

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
	check(await until(func(): return not captain.heavy_attacking, 90) and warrior.health.current == hp_before_guard - 10
		and world.combat_hud.get_node("LastHit").text.contains("Guard blocked 10"), "Guard halves the heavy hit to 10")
	await press_key(KEY_1)
	check(await until(func(): return not captain.is_alive(), 420) and warrior.is_alive(),
		"The Warrior can defeat the Captain with the earned sword and abilities")
	check(blockade.kills == 1 and blockade.state == ValeQuestProgress.State.READY and not boss_marker.visible
		and warrior.experience == 205, "The Captain grants 50 XP and readies the final turn-in")
	check(warrior.owned_items.has(&"wardens_coat") and warrior.armor_value() == 0 and world.loot_notice.visible
		and world.loot_notice.text.contains("Warden's Coat"), "The coat is awarded on defeat and awaits manual equip")
	captain.receive_hit(999, warrior)
	check(warrior.experience == 205 and warrior.owned_items.size() == 4, "A defeated Captain cannot grant rewards again")
	check(await walk_to(Vector3(-4.8, 0, 6.8)), "The south road connects the quarry to the watchpost")

	warrior.receive_hit(999, null)
	await until(func(): return warrior.is_alive(), 150)
	check(not captain.is_alive() and captain.collision_layer == 0 and blockade.state == ValeQuestProgress.State.READY
		and warrior.owned_items.has(&"wardens_coat") and warrior.experience == 205,
		"Death recovery retains the defeated Captain, coat, and final turn-in")
	check(await talk_to_mara() and world.dialogue_action.text == "Turn in quest", "Mara accepts the Captain's defeat")
	await click_button(world.dialogue_action)
	check(blockade.state == ValeQuestProgress.State.COMPLETED and warrior.experience == 240 and warrior.level == 3
		and warrior.health.maximum == 90 and world.objective_label.text == "Watchpost quest chain complete",
		"The final 35 XP reaches level 3 at 240 XP and completes the quest chain")
	check(camp_raider.is_alive() and other_raider.is_alive() and optional_wolf.is_alive(),
		"The required route reaches level 3 with all optional enemies alive")
	check(await talk_to_mara() and not world.dialogue_action.visible and warrior.experience == 240
		and warrior.owned_items.size() == 4, "The final turn-in has no repeat reward")
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

	print("Quest chain checks complete; assertions: ", assertions, "; failures: ", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
