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
	for phase in ["fresh_town", "continue_town", "early_defeat", "resume_early",
		"resume_mid_quest", "resume_credited", "resume_completed"]:
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
	elif phase == "early_defeat":
		menu.new_game.pressed.emit()
		check(menu.get_node("%ReplaceSave").visible and slot.read().experience == 0,
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
		"continue_town":
			check(warrior.equipped_weapon.id == &"training_sword" and warrior.equipped_armor.id == &"travel_coat",
				"Town Continue restores the starter equipment")
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
		and world.quest_chain[2].kills == 1 and player.owned_items.size() == 4
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
