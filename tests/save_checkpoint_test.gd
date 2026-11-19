extends SceneTree

const MENU := preload("res://scenes/checkpoint_menu.tscn")
const TOWN := preload("res://scenes/stonewatch_vale.tscn")
const WATCHPOST := preload("res://scenes/watchpost_playtest.tscn")

var slot: ValeSaveSlot
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func open_menu(scene: PackedScene) -> Control:
	var menu := MENU.instantiate()
	menu.gameplay_scene = scene
	menu.slot = slot
	root.add_child(menu)
	current_scene = menu
	return menu

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2:
		slot = ValeSaveSlot.new(args[1])
		await run_checkpoint(args[0])
		quit(1 if failures else 0)
		return

	var path := OS.get_temp_dir().path_join("stonewatch-test-%d.save" % OS.get_process_id())
	for phase in ["fresh_town", "continue_town", "explored_town", "reset_town", "early_defeat", "resume_early",
		"resume_mid_quest", "resume_credited", "resume_completed",
		"bag_waiting", "resume_waiting_town", "resume_claimed_town"]:
		var output := []
		var code := OS.execute(OS.get_executable_path(), [
			"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/save_checkpoint_test.gd", "--", phase, path,
		], output, true)
		for line: String in output:
			print(line.strip_edges())
		check(code == 0 and not "\n".join(output).contains("SCRIPT ERROR"),
			"Separate Godot process passed: " + phase)
	check(DirAccess.remove_absolute(path) == OK, "Temporary save was removed")
	quit(1 if failures else 0)

func run_checkpoint(phase: String) -> void:
	var target := TOWN if phase.ends_with("town") else WATCHPOST
	var menu := open_menu(target)
	if phase == "fresh_town":
		check(ProjectSettings.get_setting("application/run/main_scene") == MENU.resource_path,
			"The project starts at the checkpoint menu")
		check(menu.continue_game.disabled and not menu.new_game.disabled, "Missing save offers New Game")
		var invalid := FileAccess.open(slot.path, FileAccess.WRITE)
		invalid.store_string("broken")
		invalid.close()
		menu.refresh_slot()
		check(menu.continue_game.disabled and menu.message.text.contains("could not be read"),
			"Unreadable save gives feedback and leaves New Game available")
		menu.new_game.pressed.emit()
	elif phase in ["reset_town", "early_defeat", "bag_waiting"]:
		menu.new_game.pressed.emit()
		check(menu.get_node("%ReplaceSave").visible and slot.exists(),
			"New Game asks before replacing an existing checkpoint")
		menu.get_node("%ReplaceSave").confirmed.emit()
	else:
		check(not menu.continue_game.disabled, "Continue is enabled after relaunch")
		menu.continue_game.pressed.emit()
	await process_frame
	var world := current_scene
	var warrior: ValePlayer = world.player
	check(warrior.global_position.distance_to(world.get_node("Watchpost").global_position) < 0.1,
		"The player starts at the scene's recovery point")
	match phase:
		"fresh_town":
			check(warrior.level == 1 and warrior.experience == 0 and slot.exists(),
				"New Game creates a fresh town checkpoint")
			var legacy := slot.read()
			legacy.erase("discovered_cells")
			legacy.erase("bag")
			legacy.erase("waiting_rewards")
			legacy.erase("ability_bar")
			legacy.owned_items = PackedStringArray(["training_sword", "travel_coat"])
			check(slot.write(legacy) == OK, "Write a checkpoint from before bags were introduced")
		"continue_town":
			check(warrior.equipped_weapon.id == &"training_sword" and warrior.equipped_armor.id == &"travel_coat",
				"Town Continue restores the starter equipment")
			check(warrior.equipped_bag.id == &"trail_pack" and warrior.free_bag_slots() == 5,
				"Continuing a checkpoint from before bags were introduced gives the starter inventory")
			check(world.ability_hud.save_layout() == PackedStringArray(["cleave", "guard", "", ""]),
				"Continuing a checkpoint from before the ability bar gives the default shortcuts")
			var meadow: Vector3 = world.get_node(world.map_landmarks["Heather Rest"]).global_position
			check(world.exploration_map.discovered_cells().size() == 1, "Legacy saves reveal only the town spawn")
			await preload("res://tests/navigation_test_support.gd").wait_for_spawn(world, warrior)
			warrior.global_position = meadow + Vector3(0, 0.03, -4)
			for frame in 5:
				await physics_frame
			check(not world.exploration_map.is_explored(meadow), "Heather Rest starts concealed")
			check(world.click_world(world.camera.unproject_position(meadow)), "A ground click starts the exploration trip")
			for frame in 120:
				await physics_frame
				if world.exploration_map.is_explored(meadow):
					break
			check(world.exploration_map.is_explored(meadow), "Walking discovers Heather Rest")
		"explored_town":
			var meadow: Vector3 = world.get_node(world.map_landmarks["Heather Rest"]).global_position
			var ridge: Vector3 = world.get_node(world.map_landmarks["Signal Ridge"]).global_position
			check(world.exploration_map.is_explored(meadow) and not world.exploration_map.is_explored(ridge),
				"Continue in a new process restores exploration alone and keeps untouched cells concealed")
		"reset_town":
			check(world.exploration_map.discovered_cells().size() == 1 and world.exploration_map.is_explored(warrior.global_position),
				"New Game resets previous discoveries to the town spawn")
		"early_defeat":
			var captain: ValeEnemy = world.get_node("RaiderCaptain")
			captain.receive_hit(captain.health.current, warrior)
			check(warrior.equip_item(&"wardens_coat") and warrior.experience == 15,
				"The early defeat grants XP and the coat, which the player equips")
			check(slot.read().encounters[&"watchpost_quarry_captain"].reward_claimed,
				"One-time encounter loot and gear are written with the kill snapshot")
		"resume_early":
			verify_early_defeat(world, warrior)
			dialogue_action(world, 0)
			var wolf: ValeEnemy = world.get_node("Wolf")
			wolf.receive_hit(wolf.health.current, warrior)
		"resume_mid_quest":
			check(world.quest_chain[0].state == ValeQuestProgress.State.ACTIVE
				and world.quest_chain[0].kills == 1 and warrior.experience == 20,
				"Continue restores partial objective progress and the same XP")
			await reach_credited_defeat(world, warrior)
		"resume_credited":
			verify_credited_defeat(world, warrior)
		"resume_completed":
			check(world.quest_chain[2].state == ValeQuestProgress.State.COMPLETED
				and warrior.level == 3 and warrior.experience == 240,
				"Continue restores the completed chain and final level")
			dialogue_action(world, 2)
			check(not world.dialogue_action.visible, "The completed Captain turn-in remains unavailable")
		"bag_waiting":
			press_menu_key(KEY_B)
			await click_bag_action(world, "Equip Scout Pouch")
			dialogue_action(world, 0)
			for wolf_name in ["Wolf", "WolfSecond", "WolfThird"]:
				var wolf: ValeEnemy = world.get_node(wolf_name)
				wolf.receive_hit(wolf.health.current, warrior)
			dialogue_action(world, 0)
			press_menu_key(KEY_B)
			await click_bag_action(world, "Equip Iron Sword")
			var captain: ValeEnemy = world.get_node("RaiderCaptain")
			captain.receive_hit(captain.health.current, warrior)
			check(world.bag_heading.text.contains("2 / 2 used") and world.bag_feedback.is_visible_in_tree()
				and world.bag_feedback.text.contains("Bag is full"), "The Bag shows why the coat is waiting")
			var saved := slot.read()
			check(saved.bag == &"scout_pouch" and saved.waiting_rewards == PackedStringArray(["wardens_coat"])
				and saved.encounters[&"watchpost_quarry_captain"].reward_claimed,
				"The full-bag reward and Captain claim are written with the same checkpoint")
		"resume_waiting_town":
			# Load the Watchpost inventory where neither the sword quest nor the coat encounter exists.
			press_menu_key(KEY_B)
			check(warrior.equipped_bag.id == &"scout_pouch" and warrior.sword_damage() == 12
				and warrior.free_bag_slots() == 0 and warrior.waiting_rewards.has(&"wardens_coat")
				and not warrior.owned_items.has(&"wardens_coat"),
				"Continue restores the equipped bag, stored gear, and unclaimed reward")
			check(world.journal.visible and world.journal_title.text == "Bag" and world.journal_body.text == "Scout Pouch"
				and world.bag_heading.text.contains("0 free"), "The reopened Bag shows the restored pouch is full")
			await click_bag_action(world, "Claim Warden's Coat")
			check(world.bag_feedback.is_visible_in_tree() and world.bag_feedback.text.contains("Bag is full")
				and warrior.waiting_rewards.has(&"wardens_coat"), "A failed claim keeps the reward and explains why")
			await click_bag_action(world, "Equip Trail Pack")
			check(world.bag_heading.text.contains("2 / 6 used"), "Switching packs makes room for the waiting reward")
			await click_bag_action(world, "Claim Warden's Coat")
			var claimed := slot.read()
			check(claimed.waiting_rewards.is_empty() and "wardens_coat" in claimed.owned_items,
				"Claiming the reward autosaves the updated inventory")
			await click_bag_action(world, "Equip Warden's Coat")
		"resume_claimed_town":
			check(warrior.equipped_bag.id == &"trail_pack" and warrior.sword_damage() == 12
				and warrior.armor_value() == 2 and warrior.waiting_rewards.is_empty()
				and warrior.free_bag_slots() == 3, "Continue restores the claimed and equipped coat exactly once")
			press_menu_key(KEY_B)
			check(world.journal_body.text == "Trail Pack" and world.bag_heading.text.contains("3 / 6 used"),
				"The Bag displays the restored pack and used capacity")
			var stored_items: Array[ValeItem] = warrior.stored_items()
			await click_bag_action(world, "Equip Scout Pouch")
			check(world.bag_feedback.is_visible_in_tree() and world.bag_feedback.text.contains("Your stored items need 3")
				and world.journal_body.text == "Trail Pack" and warrior.stored_items() == stored_items,
				"The Bag rejects the undersized pouch and keeps the stored items")
			press_menu_key(KEY_I)
			check(world.journal_title.text == "Character" and world.journal_body.text.contains("Warden's Coat")
				and world.journal_body.text.contains("Sword damage 12") and world.journal_body.text.contains("Armor 2"),
				"Character displays the equipped coat and effective stats after Continue")

func press_menu_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func click_bag_action(world: Node, label: String) -> void:
	await process_frame
	for option in world.gear_options.get_children():
		if option is Button and option.is_visible_in_tree() and option.text.begins_with(label):
			var event := InputEventMouseButton.new()
			event.position = option.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			root.push_input(event, true)
			event = event.duplicate()
			event.pressed = false
			root.push_input(event, true)
			return
	check(false, "Bag action was missing: " + label)

func verify_early_defeat(world: Node, player: ValePlayer) -> void:
	var captain: ValeEnemy = world.get_node("RaiderCaptain")
	var blockade: ValeQuestProgress = world.quest_chain[2]
	check(not captain.is_alive() and captain.defeat_reward_claimed and player.experience == 15
		and blockade.state == ValeQuestProgress.State.AVAILABLE and blockade.kills == 0
		and player.equipped_armor.id == &"wardens_coat" and player.armor_value() == 2,
		"Continue restores the early defeat, equipped coat, and uncredited objective")

func dialogue_action(world: Node, index: int) -> void:
	world.player.global_position = world.mara.global_position + Vector3(0, 0, 1.0)
	world._talk_to_mara()
	world._select_dialogue_quest(world.quest_chain[index])
	world.dialogue_action.pressed.emit()

func reach_credited_defeat(world: Node, player: ValePlayer) -> void:
	var captain: ValeEnemy = world.get_node("RaiderCaptain")
	for wolf_name in ["WolfSecond", "WolfThird"]:
		var wolf: ValeEnemy = world.get_node(wolf_name)
		wolf.receive_hit(wolf.health.current, player)
	dialogue_action(world, 0)
	check(player.equip_item(&"iron_sword"), "A completed quest grants the sword")
	dialogue_action(world, 1)
	var crate: ValeInteractable = world.get_node("SupplyCrate")
	player.global_position = crate.global_position + Vector3(0, 0, 0.5)
	crate.interacted.emit()
	dialogue_action(world, 1)
	dialogue_action(world, 2)
	await process_frame
	check(world.quest_chain[2].state == ValeQuestProgress.State.ACTIVE and world.quest_chain[2].kills == 0,
		"The player can accept Break the Blockade with zero credited kills")
	player.reset_combat()
	for frame in 1820:
		if captain.is_alive():
			break
		await physics_frame
	check(captain.is_alive(), "Captain returns after the restored respawn delay")
	captain.receive_hit(captain.health.current, player)
	check(world.quest_chain[2].state == ValeQuestProgress.State.READY
		and world.quest_chain[2].kills == 1 and player.owned_items.size() == 6
		and not world.loot_notice.visible,
		"The second defeat credits the active quest without awarding the coat twice")

func verify_credited_defeat(world: Node, player: ValePlayer) -> void:
	var captain: ValeEnemy = world.get_node("RaiderCaptain")
	var blockade: ValeQuestProgress = world.quest_chain[2]
	check(not captain.is_alive() and player.level == 2 and player.experience == 185
		and blockade.state == ValeQuestProgress.State.READY and blockade.kills == 1
		and player.sword_damage() == 12 and player.armor_value() == 2
		and not world.get_node("SupplyCrate").visible,
		"Continue restores earned XP, equipped stats, crate collection, and the credited defeat")
	check(world.quest_chain[0].state == ValeQuestProgress.State.COMPLETED
		and world.quest_chain[0].kills == 3 and world.quest_chain[1].state == ValeQuestProgress.State.COMPLETED,
		"Completed quests retain their state and objective counts")
	dialogue_action(world, 0)
	check(player.experience == 185, "A completed turn-in cannot pay a second time")
	dialogue_action(world, 2)
	check(blockade.state == ValeQuestProgress.State.COMPLETED and slot.read().experience == 240
		and player.level == 3, "The final turn-in saves the new level and XP")
