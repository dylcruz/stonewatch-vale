extends "res://scripts/combat_world.gd"

enum JournalView { CLOSED, DIALOGUE, QUEST_LOG, CHARACTER, BAG }

const ITEM_CATALOG := preload("res://scripts/item_catalog.gd")

@export var quest_definition: ValeQuestDefinition
@export var follow_up_quests: Array[ValeQuestDefinition] = []
@export var chain_completion_text := ""
@onready var mara: ValeInteractable = get_node_or_null("CaptainMara")
@onready var objective_label: Label = $HUD/Panel/Margin/VBox/QuestObjective
@onready var loot_notice: Label = $HUD/Panel/Margin/VBox/LootNotice
@onready var quest_marker: Label3D = get_node_or_null("CaptainMara/QuestMarker")
@onready var journal: PanelContainer = $HUD/Journal
@onready var journal_title: Label = $HUD/Journal/Margin/Content/Title
@onready var journal_body: Label = $HUD/Journal/Margin/Content/Body
@onready var bag_heading: Label = $HUD/Journal/Margin/Content/BagHeading
@onready var bag_scroll: ScrollContainer = $HUD/Journal/Margin/Content/BagScroll
@onready var gear_options: VBoxContainer = $HUD/Journal/Margin/Content/BagScroll/GearOptions
@onready var bag_feedback: Label = $HUD/Journal/Margin/Content/BagFeedback
@onready var quest_options: VBoxContainer = $HUD/Journal/Margin/Content/QuestOptions
@onready var dialogue_action: Button = $HUD/Journal/Margin/Content/Action
var tracked_quest: ValeQuestProgress
var quest_chain: Array[ValeQuestProgress] = []
var quest_objects: Array[ValeInteractable] = []
var sources: Array[ValeInteractable] = []
var speaker: ValeInteractable
var dialogue_quest: ValeQuestProgress
var panel_mode := JournalView.CLOSED
var save_slot: ValeSaveSlot
var pending_checkpoint: Dictionary

func configure_checkpoint(slot: ValeSaveSlot, checkpoint: Dictionary) -> void:
	save_slot = slot
	pending_checkpoint = checkpoint

func _ready() -> void:
	super._ready()
	var is_new_game := pending_checkpoint.is_empty()
	if quest_definition:
		quest_chain.append(ValeQuestProgress.new(quest_definition))
	for follow_up in follow_up_quests:
		quest_chain.append(ValeQuestProgress.new(follow_up))
	if not is_new_game:
		_restore_checkpoint(pending_checkpoint)
		pending_checkpoint = {}
	for enemy in enemies:
		enemy.health.died.connect(_record_defeat.bind(enemy))
		enemy.respawned.connect(_enemy_respawned.bind(enemy))
	for child in find_children("*", "StaticBody3D", true, false):
		if child is ValeInteractable and not child.offered_quests.is_empty():
			sources.append(child)
			child.interacted.connect(_talk_to.bind(child))
		if child is ValeInteractable and child.objective_id != &"":
			quest_objects.append(child)
			child.interacted.connect(_use_quest_object.bind(child))
			if quest_chain.any(func(progress: ValeQuestProgress):
				return progress.definition.target_object == child.objective_id \
					and progress.state >= ValeQuestProgress.State.READY
			):
				child.collect()
	player.health.died.connect(_close_panel)
	player.health.changed.connect(func(_current: int, _maximum: int): _refresh_character_stats())
	player.progression_changed.connect(_refresh_character_stats)
	dialogue_action.pressed.connect(_perform_dialogue_action)
	$HUD/Journal/Margin/Content/Close.pressed.connect(_close_panel)
	player.equipment_changed.connect(_save_checkpoint)
	ability_hud.add_menu_button("Ability Book", "K", _toggle_ability_book)
	ability_hud.add_menu_button("Quest Log", "J", _toggle_panel.bind(JournalView.QUEST_LOG))
	ability_hud.add_menu_button("Character", "I", _toggle_panel.bind(JournalView.CHARACTER))
	ability_hud.add_menu_button("Bag", "B", _toggle_panel.bind(JournalView.BAG))
	ability_hud.layout_changed.connect(_save_checkpoint)
	_refresh_progress()
	if is_new_game:
		_save_checkpoint()

func _save_checkpoint() -> void:
	if save_slot == null:
		return
	var error := save_slot.write(_build_checkpoint())
	if error != OK:
		status.text = "Could not save progress"
		push_warning("Checkpoint save failed: " + error_string(error))

func _build_checkpoint() -> Dictionary:
	var quests := {}
	for progress in quest_chain:
		quests[progress.definition.id] = {"state": progress.state, "kills": progress.kills}
	var encounters := {}
	for enemy in enemies:
		if enemy.encounter_id != &"":
			encounters[enemy.encounter_id] = enemy.encounter_checkpoint()
	return {
		"level": player.level,
		"experience": player.experience,
		"owned_items": PackedStringArray(player.owned_items.keys()),
		"waiting_rewards": PackedStringArray(player.waiting_rewards.keys()),
		"weapon": player.equipped_weapon.id as StringName,
		"armor": player.equipped_armor.id as StringName,
		"bag": player.equipped_bag.id as StringName,
		"ability_bar": ability_hud.save_layout(),
		"quests": quests,
		"tracked_quest": tracked_quest.definition.id if tracked_quest else &"",
		"encounters": encounters,
	}

func _restore_checkpoint(checkpoint: Dictionary) -> void:
	var quests: Dictionary = checkpoint.quests
	for progress in quest_chain:
		var definition := progress.definition
		var recorded: Variant = quests.get(definition.id)
		if recorded is Dictionary:
			var state: Variant = recorded.get("state")
			var kills: Variant = recorded.get("kills")
			if state is int and state >= ValeQuestProgress.State.AVAILABLE and state <= ValeQuestProgress.State.COMPLETED:
				progress.state = state
			if kills is int:
				progress.kills = clampi(kills, 0, definition.required_kills)
		if definition.id == checkpoint.get("tracked_quest"):
			tracked_quest = progress
	var encounters: Dictionary = checkpoint.encounters
	for enemy in enemies:
		var recorded: Variant = encounters.get(enemy.encounter_id)
		if enemy.encounter_id != &"" and recorded is Dictionary:
			enemy.restore_encounter(recorded)
	_restore_inventory(checkpoint)
	ability_hud.restore_layout(checkpoint.get("ability_bar"))
	player.level = clampi(checkpoint.level, 1, 3)
	player.award_experience(checkpoint.experience)
	player.reset_combat()

func _restore_inventory(checkpoint: Dictionary) -> void:
	var owned: PackedStringArray = checkpoint.owned_items
	var waiting: Variant = checkpoint.get("waiting_rewards")
	for id in owned:
		var item := ITEM_CATALOG.ITEMS.get(id) as ValeItem
		if item:
			player.owned_items[item.id] = item
	if waiting is PackedStringArray:
		for id: String in waiting:
			var item := ITEM_CATALOG.ITEMS.get(id) as ValeItem
			if item and not player.owned_items.has(item.id):
				player.waiting_rewards[item.id] = item
	var saved_weapon := player.owned_items.get(checkpoint.weapon) as ValeItem
	var saved_armor := player.owned_items.get(checkpoint.armor) as ValeItem
	var bag_id: Variant = checkpoint.get("bag")
	var saved_bag := player.owned_items.get(bag_id) as ValeItem if bag_id is StringName else null
	if saved_weapon and saved_weapon.slot == ValeItem.Slot.WEAPON:
		player.equip_item(saved_weapon.id)
	if saved_armor and saved_armor.slot == ValeItem.Slot.ARMOR:
		player.equip_item(saved_armor.id)
	if saved_bag and saved_bag.slot == ValeItem.Slot.BAG:
		player.equip_item(saved_bag.id)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if panel_mode == JournalView.DIALOGUE and not speaker.is_in_range(player):
		_close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quest_log"):
		_toggle_panel(JournalView.QUEST_LOG)
	elif event.is_action_pressed(&"gear"):
		_toggle_panel(JournalView.CHARACTER)
	elif event.is_action_pressed(&"bag"):
		_toggle_panel(JournalView.BAG)
	elif event.is_action_pressed(&"ability_book"):
		_toggle_ability_book()
	elif ability_hud.is_book_open() and event.is_action_pressed(&"ui_cancel"):
		ability_hud.close_book()
	elif panel_mode != JournalView.CLOSED and event.is_action_pressed(&"ui_cancel"):
		_close_panel()
	else:
		super._unhandled_input(event)
		return
	get_viewport().set_input_as_handled()

func _toggle_ability_book() -> void:
	if ability_hud.is_book_open():
		ability_hud.close_book()
	else:
		_open_ability_book()

func _open_ability_book() -> void:
	_close_panel()
	_stop_following_cursor()
	ability_hud.open_book()

func _record_defeat(enemy: ValeEnemy) -> void:
	var stats := enemy.stats
	for progress in quest_chain:
		progress.record_defeat(stats.enemy_id)
	player.award_experience(stats.defeat_xp)
	if stats.defeat_item and not enemy.defeat_reward_claimed:
		enemy.defeat_reward_claimed = true
		_grant_reward_item(stats.defeat_item, true)
	_refresh_progress()
	_save_checkpoint()

func _enemy_respawned(enemy: ValeEnemy) -> void:
	_refresh_enemy_marker(enemy)
	if enemy.encounter_id != &"":
		_save_checkpoint()

func _grant_reward_item(item: ValeItem, announce: bool = false) -> void:
	if not item:
		return
	var was_waiting: bool = player.waiting_rewards.has(item.id)
	if player.grant_item(item) and announce:
		loot_notice.text = "%s added to Bag (B)" % item.display_name
		loot_notice.show()
	elif not was_waiting and player.waiting_rewards.has(item.id):
		loot_notice.text = player.bag_feedback
		loot_notice.show()

func _use_quest_object(object: ValeInteractable) -> void:
	if object.collision_layer == 0 or not player.is_alive() or not object.is_in_range(player):
		return
	var credited := false
	for progress in quest_chain:
		if progress.record_interaction(object.objective_id):
			credited = true
	if not credited:
		for progress in quest_chain:
			if progress.definition.target_object == object.objective_id:
				for source in sources:
					if progress.definition.id in source.offered_quests:
						status.text = "Ask %s about the %s" % [source.display_name, object.display_name.to_lower()]
						return
		return
	object.collect()
	status.text = "%s recovered" % object.display_name
	_refresh_progress()
	_save_checkpoint()

func _talk_to_mara() -> void:
	_talk_to(mara)

func _talk_to(source: ValeInteractable) -> void:
	speaker = source
	dialogue_quest = _first_source_quest(source)
	if not dialogue_quest:
		return
	_show_panel(JournalView.DIALOGUE)

func _can_accept_quest(progress: ValeQuestProgress) -> bool:
	if progress.state != ValeQuestProgress.State.AVAILABLE:
		return false
	for prerequisite in progress.definition.prerequisite_quests:
		if not quest_chain.any(func(other: ValeQuestProgress):
			return other.definition.id == prerequisite and other.state == ValeQuestProgress.State.COMPLETED
		):
			return false
	return true

func _first_source_quest(source: ValeInteractable) -> ValeQuestProgress:
	if not source:
		return null
	for state in [ValeQuestProgress.State.READY, ValeQuestProgress.State.AVAILABLE, ValeQuestProgress.State.ACTIVE]:
		for progress in quest_chain:
			if progress.definition.id not in source.offered_quests or progress.state != state:
				continue
			if state != ValeQuestProgress.State.AVAILABLE or _can_accept_quest(progress):
				return progress
	for progress in quest_chain:
		if progress.definition.id in source.offered_quests and progress.state == ValeQuestProgress.State.COMPLETED:
			return progress
	return null

func _perform_dialogue_action() -> void:
	if panel_mode != JournalView.DIALOGUE or not player.is_alive() or not speaker.is_in_range(player):
		return
	if _can_accept_quest(dialogue_quest) and dialogue_quest.accept():
		_close_panel()
	elif dialogue_quest.complete():
		_grant_reward_item(dialogue_quest.definition.reward_item)
		player.award_experience(dialogue_quest.definition.reward_xp)
	else:
		return
	_refresh_progress()
	_save_checkpoint()

func _objective_text(progress: ValeQuestProgress) -> String:
	var definition := progress.definition
	match progress.state:
		ValeQuestProgress.State.AVAILABLE:
			return "Speak to Captain Mara at %s" % recovery_location
		ValeQuestProgress.State.ACTIVE:
			if definition.required_kills > 0:
				return "%s  %d / %d" % [definition.objective, progress.kills, definition.required_kills]
			return definition.objective
		ValeQuestProgress.State.READY:
			return definition.return_objective
		_:
			return "%s complete" % definition.title if chain_completion_text.is_empty() else chain_completion_text

func _refresh_tracked_quest() -> void:
	if tracked_quest and tracked_quest.is_in_progress():
		return
	tracked_quest = null
	for progress in quest_chain:
		if progress.is_in_progress():
			tracked_quest = progress
			break

func _refresh_progress() -> void:
	_refresh_tracked_quest()
	var mara_quest := _first_source_quest(mara)
	var objective := tracked_quest if tracked_quest else mara_quest
	objective_label.visible = objective != null
	if objective:
		objective_label.text = _objective_text(objective)
		if objective == tracked_quest and objective.state == ValeQuestProgress.State.READY:
			objective_label.text = "%s · %s" % [objective.definition.title, objective_label.text]
	for object in quest_objects:
		object.set_objective_hint(quest_chain.any(func(progress: ValeQuestProgress):
			return progress.state == ValeQuestProgress.State.ACTIVE and progress.definition.target_object == object.objective_id
		))
	for enemy in enemies:
		_refresh_enemy_marker(enemy)
	for source in sources:
		var offer := _first_source_quest(source)
		var marker := source.objective_marker
		if marker:
			marker.text = ""
			if offer and offer.state == ValeQuestProgress.State.READY:
				marker.text = "?"
			elif offer and _can_accept_quest(offer):
				marker.text = "!"
	_refresh_panel()

func _refresh_enemy_marker(enemy: ValeEnemy) -> void:
	var marker := enemy.get_node_or_null("QuestMarker") as Label3D
	if marker:
		marker.visible = enemy.is_alive() and quest_chain.any(func(progress: ValeQuestProgress):
			return progress.state == ValeQuestProgress.State.ACTIVE and progress.definition.target_enemy == enemy.stats.enemy_id
		)

func _toggle_panel(mode: JournalView) -> void:
	if panel_mode == mode:
		_close_panel()
	else:
		_show_panel(mode)

func _show_panel(mode: JournalView) -> void:
	ability_hud.close_book()
	panel_mode = mode
	if mode == JournalView.BAG:
		loot_notice.hide()
	_stop_following_cursor()
	_refresh_panel()
	journal.show()

func _close_panel() -> void:
	panel_mode = JournalView.CLOSED
	journal.hide()

func _refresh_panel() -> void:
	if panel_mode == JournalView.CLOSED:
		return
	dialogue_action.hide()
	quest_options.hide()
	for option in quest_options.get_children():
		quest_options.remove_child(option)
		option.queue_free()
	bag_heading.visible = panel_mode == JournalView.BAG
	bag_scroll.visible = panel_mode == JournalView.BAG
	bag_feedback.hide()
	match panel_mode:
		JournalView.DIALOGUE:
			_show_dialogue()
		JournalView.QUEST_LOG:
			_show_quest_log()
		JournalView.CHARACTER:
			journal_title.text = "Character"
			_refresh_character_stats()
		JournalView.BAG:
			_show_bag()

func _show_quest_log() -> void:
	journal_title.text = "Quest log"
	var entries := PackedStringArray()
	for progress in quest_chain:
		if progress.state == ValeQuestProgress.State.COMPLETED:
			entries.append("%s · Completed" % progress.definition.title)
		elif progress.is_in_progress():
			var progress_text := "Ready to turn in" if progress.state == ValeQuestProgress.State.READY else "In progress"
			if progress == tracked_quest:
				progress_text += " · Tracked"
			else:
				_add_quest_option("Track " + progress.definition.title, _track_quest.bind(progress))
			entries.append("%s · %s\n%s" % [progress.definition.title, progress_text, _objective_text(progress)])
	journal_body.text = "No quests accepted" if entries.is_empty() else "\n\n".join(entries)

func _add_quest_option(label: String, action: Callable) -> void:
	var option := Button.new()
	option.text = label
	option.pressed.connect(action)
	quest_options.add_child(option)
	quest_options.show()

func _track_quest(progress: ValeQuestProgress) -> void:
	tracked_quest = progress
	_refresh_progress()
	_save_checkpoint()

func _select_dialogue_quest(progress: ValeQuestProgress) -> void:
	dialogue_quest = progress
	_refresh_panel()

func _show_dialogue() -> void:
	journal_title.text = speaker.display_name
	var definition := dialogue_quest.definition
	var reward := "%d XP" % definition.reward_xp
	if definition.reward_item:
		reward += " and " + definition.reward_item.display_name
	match dialogue_quest.state:
		ValeQuestProgress.State.AVAILABLE:
			journal_body.text = "%s\n\n%s\n\nReward · %s" % [definition.title, definition.briefing, reward]
			dialogue_action.text = "Accept quest"
			dialogue_action.visible = _can_accept_quest(dialogue_quest)
		ValeQuestProgress.State.ACTIVE:
			journal_body.text = "%s\n\n%s\n\n%s" % [definition.title, definition.briefing, _objective_text(dialogue_quest)]
		ValeQuestProgress.State.READY:
			journal_body.text = "%s\n\n%s\n\nReward · %s" % [definition.title, definition.turn_in_dialogue, reward]
			dialogue_action.text = "Turn in quest"
			dialogue_action.show()
		ValeQuestProgress.State.COMPLETED:
			journal_body.text = "%s complete\n\nReward earned · %s" % [definition.title, reward]
			if definition.reward_item:
				journal_body.text += "\nOpen Bag (B) to manage your reward."
	for progress in quest_chain:
		if progress.definition.id in speaker.offered_quests and progress != dialogue_quest and (progress.is_in_progress() or _can_accept_quest(progress)):
			_add_quest_option("View " + progress.definition.title, _select_dialogue_quest.bind(progress))

func _refresh_character_stats() -> void:
	if panel_mode != JournalView.CHARACTER:
		return
	var next_xp: int = player.next_level_experience()
	var xp_status := "%d / %d XP" % [player.experience, next_xp] if next_xp else "%d XP · Max level" % player.experience
	var weapon := player.equipped_weapon as ValeItem
	var coat := player.equipped_armor as ValeItem
	var bag := player.equipped_bag as ValeItem
	var cleave := "Cleave %d damage" % player.cleave_damage if player.has_cleave() else "Cleave unlocks at Lv. 2"
	journal_body.text = "\n".join([
		"Level %d   ·   %s" % [player.level, xp_status],
		"Health   %d / %d" % [player.health.current, player.health.maximum],
		"",
		"Weapon   %s" % (weapon.display_name if weapon else "Empty"),
		"Armor     %s" % (coat.display_name if coat else "Empty"),
		"Bag        %s" % (bag.display_name if bag else "Empty"),
		"",
		"Sword damage %d   ·   Armor %d" % [player.sword_damage(), player.armor_value()],
		"%s   ·   Guard %d%%" % [cleave, roundi(player.guard_reduction * 100.0)],
	])

func _show_bag() -> void:
	journal_title.text = "Bag"
	journal_body.text = player.equipped_bag.display_name
	var available: int = player.free_bag_slots()
	var capacity: int = player.bag_capacity()
	bag_heading.text = "Inventory   %d / %d used   ·   %d free" % [capacity - available, capacity, available]
	bag_feedback.text = player.bag_feedback
	bag_feedback.visible = not bag_feedback.text.is_empty()
	for option in gear_options.get_children():
		gear_options.remove_child(option)
		option.queue_free()
	for item: ValeItem in player.stored_items():
		if item.slot == ValeItem.Slot.MISC:
			var label := Label.new()
			label.text = item.display_name
			gear_options.add_child(label)
			continue
		var effect := "%d armor" % item.armor
		if item.slot == ValeItem.Slot.WEAPON:
			effect = "%d sword damage" % (player.stats.damage + item.bonus_damage)
		elif item.slot == ValeItem.Slot.BAG:
			effect = "%d slots" % item.bag_slots
		_add_inventory_button("Equip %s · %s" % [item.display_name, effect], _equip.bind(item.id))
	for item: ValeItem in player.waiting_rewards.values():
		_add_inventory_button("Claim %s · Waiting reward" % item.display_name, _claim.bind(item.id))

func _add_inventory_button(label: String, action: Callable) -> void:
	var option := Button.new()
	option.text = label
	option.pressed.connect(action)
	gear_options.add_child(option)

func _equip(item_id: StringName) -> void:
	player.equip_item(item_id)
	_refresh_panel()

func _claim(item_id: StringName) -> void:
	if player.claim_reward(item_id):
		_save_checkpoint()
	_refresh_panel()
