extends SceneTree

const TOWN := preload("res://scenes/stonewatch_vale.tscn")
const NAVIGATION := preload("res://tests/navigation_test_support.gd")

var failures := 0
var assertions := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	var path := OS.get_temp_dir().path_join("stonewatch-abilities-%d.save" % OS.get_process_id())
	var slot := ValeSaveSlot.new(path)
	var world := TOWN.instantiate()
	world.configure_checkpoint(slot, {})
	root.add_child(world)
	var player: ValeWarrior = world.player
	var hud: ValeAbilityHUD = world.ability_hud
	var book_button: Button = hud.menu_buttons.get_child(0)
	var quest_button: Button = hud.menu_buttons.get_child(1)
	var character_button: Button = hud.menu_buttons.get_child(2)
	var bag_button: Button = hud.menu_buttons.get_child(3)
	var map_button: Button = hud.menu_buttons.get_child(4)
	var first: Button = hud.slots_row.get_child(0)
	var second: Button = hud.slots_row.get_child(1)
	var third: Button = hud.slots_row.get_child(2)
	await NAVIGATION.wait_for_spawn(world, player)
	await process_frame
	check(hud.slots_row.get_child_count() == 4 and hud.menu_buttons.get_child_count() == 5
		and hud.menu_buttons.get_global_rect().position.y > hud.slots_row.get_global_rect().end.y,
		"The ability slots and menu buttons occupy separate rows")
	check(not hud.is_book_open() and first.text.contains("Locked") and second.text.ends_with("Ready"),
		"A fresh bar has locked Cleave on 1 and ready Guard on 2")
	press(KEY_1)
	check(player.cleave_cooldown_remaining == 0.0, "A locked spell cannot be activated by its slot")
	press(KEY_K)
	await process_frame
	var cleave_assignment: Button = hud.entries.get_child(0).get_child(3)
	var guard_assignment: Button = hud.entries.get_child(1).get_child(3)
	check(hud.is_book_open() and cleave_assignment.disabled and not guard_assignment.disabled
		and hud.entries.get_child(0).get_child(2).text.contains("Level 2 unlock"),
		"K opens the book with tuned details and disables assignment for locked Cleave")
	press(KEY_ESCAPE)
	check(not hud.is_book_open(), "Escape closes the ability book")
	check(world.click_world(world.camera.unproject_position(Vector3(8, 0, 7))),
		"Town accepts a movement command")
	var destination := player.destination
	click(book_button)
	await process_frame
	check(hud.is_book_open() and player.destination == destination and not world.following_cursor,
		"Clicking Book opens it while preserving the active destination")
	click(first)
	click(guard_assignment)
	check(hud.save_layout() == PackedStringArray(["guard", "cleave", "", ""])
		and player.destination == destination and not world.following_cursor,
		"Assigning Guard to an occupied slot swaps the abilities without a movement click")
	press(KEY_1)
	check(player.guard_remaining > 0.0, "The shortcut follows Guard to its new slot")
	press(KEY_2)
	check(player.cleave_cooldown_remaining == 0.0, "Rearranging locked Cleave preserves its level restriction")
	player.award_experience(100)
	check(not cleave_assignment.disabled, "Reaching level 2 unlocks Cleave in the open book")
	click(third)
	click(cleave_assignment)
	click(first)
	click(hud.clear_slot)
	check(hud.save_layout() == PackedStringArray(["", "", "cleave", ""])
		and slot.read().ability_bar == hud.save_layout(), "Moving and clearing slots autosaves the arrangement")
	click(map_button)
	check(world.map_panel.visible and not hud.is_book_open(), "Opening the map closes the ability book")
	click(book_button)
	check(hud.is_book_open() and not world.map_panel.visible, "Opening the ability book with its button closes the map")
	click(quest_button)
	check(world.journal.visible and not hud.is_book_open(), "The quest log opens independently from the book")
	click(character_button)
	check(world.journal_title.text == "Character" and not world.bag_scroll.visible,
		"The Character button opens the sheet without inventory controls")
	click(bag_button)
	check(world.journal_title.text == "Bag" and world.bag_scroll.visible,
		"The Bag button opens a separate inventory view")
	press(KEY_ESCAPE)
	player.reset_combat()
	press(KEY_1)
	check(player.guard_remaining == 0.0, "A cleared slot no longer activates Guard")
	press(KEY_3)
	check(player.cleave_cooldown_remaining > 0.0, "Cleave activates on its reassigned shortcut")

	var checkpoint := slot.read()
	world.queue_free()
	await process_frame
	world = TOWN.instantiate()
	world.configure_checkpoint(slot, checkpoint)
	root.add_child(world)
	hud = world.ability_hud
	check(hud.save_layout() == PackedStringArray(["", "", "cleave", ""])
		and world.player.has_cleave(), "Restoring the checkpoint keeps custom slots and the ability unlock")
	await process_frame
	click(hud.slots_row.get_child(2))
	check(world.player.cleave_cooldown_remaining > 0.0, "Clicking a slot casts its ability with the book closed")
	check(DirAccess.remove_absolute(path) == OK, "Temporary checkpoint was removed")
	print("Ability UI checks complete; assertions: ", assertions, "; failures: ", failures)
	quit(1 if failures else 0)
