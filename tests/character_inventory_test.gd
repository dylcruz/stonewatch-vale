extends SceneTree

const WATCHPOST := preload("res://scenes/watchpost_playtest.tscn")
const IRON_SWORD := preload("res://data/iron_sword.tres")
var world: Node3D
var player: ValePlayer
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

func press_menu_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key, true)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key, true)

func press_inventory_button(prefix: String) -> void:
	for option in world.gear_options.get_children():
		if option is Button and option.text.begins_with(prefix):
			option.pressed.emit()
			return
	check(false, "Inventory action was missing: " + prefix)

func run() -> void:
	world = WATCHPOST.instantiate()
	root.add_child(world)
	player = world.player
	await physics_frame
	press_menu_key(KEY_I)
	check(world.journal.visible and world.journal_title.text == "Character"
		and world.journal_body.text.contains("Level 1") and world.journal_body.text.contains("0 / 100 XP")
		and world.journal_body.text.contains("Training Sword") and world.journal_body.text.contains("Travel Coat"),
		"I opens the character loadout and current progression")
	player.health.take_damage(7)
	check(world.journal_body.text.contains("Health   53 / 60"), "Damage updates health while the panel is open")
	player.award_experience(100)
	check(world.journal_body.text.contains("Level 2") and world.journal_body.text.contains("100 / 240 XP")
		and world.journal_body.text.contains("Health   68 / 75") and world.journal_body.text.contains("Cleave 12")
		and world.ability_hud.xp_label.text == "XP 100 / 240" and world.ability_hud.xp_bar.ratio == 0.0,
		"Leveling immediately updates XP, maximum health, and effective ability stats")

	press_menu_key(KEY_B)
	check(world.journal_title.text == "Bag" and world.bag_heading.text.contains("1 / 6 used")
		and world.bag_heading.text.contains("5 free"), "B opens the bag and shows used and free slots")
	press_inventory_button("Equip Scout Pouch")
	check(player.equipped_bag.id == &"scout_pouch" and world.bag_heading.text.contains("1 / 2 used")
		and player.stored_items()[0].id == &"trail_pack",
		"Switching to the two-slot pouch stores the old bag")
	var rations := ValeItem.new()
	rations.id = &"test_rations"
	rations.display_name = "Trail Rations"
	rations.slot = ValeItem.Slot.MISC
	check(player.grant_item(rations) and player.free_bag_slots() == 0,
		"A non-equipment item uses the last bag slot")
	var captain: ValeEnemy = world.get_node("RaiderCaptain")
	captain.receive_hit(captain.health.current, player)
	check(player.waiting_rewards.has(&"wardens_coat") and not player.owned_items.has(&"wardens_coat")
		and world.bag_feedback.text.contains("Bag is full") and world.bag_heading.text.contains("2 / 2 used"),
		"A Captain reward waits when the bag is full and the panel explains why")
	press_inventory_button("Claim Warden's Coat")
	check(player.waiting_rewards.size() == 1 and player.free_bag_slots() == 0,
		"Trying to claim with a full bag preserves the waiting reward")
	captain.reset_combat()
	captain.receive_hit(captain.health.current, player)
	check(player.waiting_rewards.size() == 1, "Repeated defeats do not duplicate the waiting reward")
	press_inventory_button("Equip Trail Pack")
	check(world.bag_heading.text.contains("2 / 6 used"), "The larger bag immediately increases available slots")
	press_inventory_button("Claim Warden's Coat")
	check(player.waiting_rewards.is_empty() and world.bag_heading.text.contains("3 / 6 used"),
		"The waiting reward moves into inventory when claimed with free slots")
	press_inventory_button("Equip Warden's Coat")
	check(player.armor_value() == 2 and world.bag_heading.text.contains("3 / 6 used"),
		"Equipping the stored coat updates effective armor and returns the old coat to storage")
	check(player.grant_item(IRON_SWORD), "The larger bag holds another piece of gear")
	world._refresh_panel()
	press_inventory_button("Equip Iron Sword")
	press_menu_key(KEY_I)
	check(player.sword_damage() == 12 and world.journal_body.text.contains("Sword damage 12")
		and world.journal_body.text.contains("Iron Sword") and world.journal_body.text.contains("Warden's Coat")
		and world.journal_body.text.contains("Armor 2"), "The character sheet reflects gear changes made in the bag")
	press_menu_key(KEY_B)
	var items_before: Array[ValeItem] = player.stored_items()
	press_inventory_button("Equip Scout Pouch")
	check(player.equipped_bag.id == &"trail_pack" and player.stored_items() == items_before
		and world.bag_feedback.text.contains("Your stored items need 4"),
		"An undersized bag change is rejected with its capacity explained and every item preserved")
	print("Character inventory checks complete; assertions: ", assertions, "; failures: ", failures)
	quit(1 if failures else 0)
