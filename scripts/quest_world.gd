extends "res://scripts/combat_world.gd"

enum JournalView { CLOSED, DIALOGUE, QUEST_LOG, GEAR }

@export var quest_definition: ValeQuestDefinition
@export var follow_up_quests: Array[ValeQuestDefinition] = []
@export var chain_completion_text := ""
@onready var mara: ValeInteractable = get_node_or_null("CaptainMara")
@onready var objective_label: Label = $HUD/Panel/Margin/VBox/QuestObjective
@onready var progression_label: Label = $HUD/Panel/Margin/VBox/Progression
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
var dialogue_quest: ValeQuestProgress
var panel_mode := JournalView.CLOSED

func _ready() -> void:
	super._ready()
	if quest_definition:
		quest_chain.append(ValeQuestProgress.new(quest_definition))
	for follow_up in follow_up_quests:
		quest_chain.append(ValeQuestProgress.new(follow_up))
	for enemy in enemies:
		enemy.health.died.connect(_record_defeat.bind(enemy))
		enemy.respawned.connect(_refresh_enemy_marker.bind(enemy))
	for child in get_children():
		if child is ValeInteractable and child.objective_id != &"":
			quest_objects.append(child)
			child.interacted.connect(_use_quest_object.bind(child))
	if mara and not quest_chain.is_empty():
		mara.interacted.connect(_talk_to_mara)
	player.health.died.connect(_close_panel)
	player.health.changed.connect(func(_current: int, _maximum: int): _refresh_character_stats())
	player.progression_changed.connect(_on_progression_changed)
	dialogue_action.pressed.connect(_perform_dialogue_action)
	$HUD/Journal/Margin/Content/Close.pressed.connect(_close_panel)
	_refresh_progress()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if panel_mode == JournalView.DIALOGUE and not mara.is_in_range(player):
		_close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quest_log"):
		_toggle_panel(JournalView.QUEST_LOG)
	elif event.is_action_pressed(&"gear"):
		_toggle_panel(JournalView.GEAR)
	elif panel_mode != JournalView.CLOSED and event.is_action_pressed(&"ui_cancel"):
		_close_panel()
	else:
		super._unhandled_input(event)
		return
	get_viewport().set_input_as_handled()

func _record_defeat(enemy: ValeEnemy) -> void:
	var stats := enemy.stats
	for progress in quest_chain:
		progress.record_defeat(stats.enemy_id)
	player.award_experience(stats.defeat_xp)
	_grant_reward_item(stats.defeat_item, true)
	_refresh_progress()

func _grant_reward_item(item: ValeItem, announce: bool = false) -> void:
	if not item:
		return
	var was_waiting: bool = player.waiting_rewards.has(item.id)
	if player.grant_item(item) and announce:
		loot_notice.text = "%s added to Character (I)" % item.display_name
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
		status.text = "Ask Captain Mara about the %s" % object.display_name.to_lower()
		return
	object.collect()
	status.text = "%s recovered" % object.display_name
	_refresh_progress()

func _talk_to_mara() -> void:
	dialogue_quest = _first_mara_quest()
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

func _first_mara_quest() -> ValeQuestProgress:
	if quest_chain.is_empty():
		return null
	for state in [ValeQuestProgress.State.READY, ValeQuestProgress.State.AVAILABLE, ValeQuestProgress.State.ACTIVE]:
		for progress in quest_chain:
			if progress.state == state and (state != ValeQuestProgress.State.AVAILABLE or _can_accept_quest(progress)):
				return progress
	return quest_chain.back()

func _perform_dialogue_action() -> void:
	if panel_mode != JournalView.DIALOGUE or not player.is_alive() or not mara.is_in_range(player):
		return
	if _can_accept_quest(dialogue_quest) and dialogue_quest.accept():
		_close_panel()
	elif dialogue_quest.complete():
		_grant_reward_item(dialogue_quest.definition.reward_item)
		player.award_experience(dialogue_quest.definition.reward_xp)
	_refresh_progress()

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
	var mara_quest := _first_mara_quest()
	var objective := tracked_quest if tracked_quest else mara_quest
	objective_label.visible = objective != null
	if objective:
		objective_label.text = _objective_text(objective)
		if objective == tracked_quest and objective.state == ValeQuestProgress.State.READY:
			objective_label.text = "%s · %s" % [objective.definition.title, objective_label.text]
	_refresh_xp()
	for object in quest_objects:
		object.set_objective_hint(quest_chain.any(func(progress: ValeQuestProgress):
			return progress.state == ValeQuestProgress.State.ACTIVE and progress.definition.target_object == object.objective_id
		))
	for enemy in enemies:
		_refresh_enemy_marker(enemy)
	if quest_marker and mara_quest:
		quest_marker.text = ""
		if mara_quest.state == ValeQuestProgress.State.READY:
			quest_marker.text = "?"
		elif _can_accept_quest(mara_quest):
			quest_marker.text = "!"
	_refresh_panel()

func _on_progression_changed() -> void:
	_refresh_xp()
	_refresh_character_stats()

func _refresh_xp() -> void:
	var next_xp: int = player.next_level_experience()
	if next_xp > 0:
		progression_label.text = "XP %d / %d" % [player.experience, next_xp]
	else:
		progression_label.text = "XP %d · Max level" % player.experience

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
	panel_mode = mode
	if mode == JournalView.GEAR:
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
	bag_heading.visible = panel_mode == JournalView.GEAR
	bag_scroll.visible = panel_mode == JournalView.GEAR
	bag_feedback.hide()
	match panel_mode:
		JournalView.DIALOGUE:
			_show_dialogue()
		JournalView.QUEST_LOG:
			_show_quest_log()
		JournalView.GEAR:
			_show_gear()

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

func _select_dialogue_quest(progress: ValeQuestProgress) -> void:
	dialogue_quest = progress
	_refresh_panel()

func _show_dialogue() -> void:
	journal_title.text = mara.display_name
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
				journal_body.text += "\nOpen Character (I) to manage your reward."
	for progress in quest_chain:
		if progress != dialogue_quest and (progress.is_in_progress() or _can_accept_quest(progress)):
			_add_quest_option("View " + progress.definition.title, _select_dialogue_quest.bind(progress))

func _refresh_character_stats() -> void:
	if panel_mode != JournalView.GEAR:
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

func _show_gear() -> void:
	journal_title.text = "Character"
	_refresh_character_stats()
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
	player.claim_reward(item_id)
	_refresh_panel()
