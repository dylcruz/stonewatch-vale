extends "res://scripts/combat_world.gd"

enum JournalView { CLOSED, DIALOGUE, QUEST_LOG, GEAR }

@export var quest_definition: ValeQuestDefinition
@export var follow_up_quests: Array[ValeQuestDefinition] = []
@export var chain_completion_text := ""
@onready var mara: ValeInteractable = $CaptainMara
@onready var objective_label: Label = $HUD/Panel/Margin/VBox/QuestObjective
@onready var progression_label: Label = $HUD/Panel/Margin/VBox/Progression
@onready var loot_notice: Label = $HUD/Panel/Margin/VBox/LootNotice
@onready var quest_marker: Label3D = $CaptainMara/QuestMarker
@onready var journal: PanelContainer = $HUD/Journal
@onready var journal_title: Label = $HUD/Journal/Margin/Content/Title
@onready var journal_body: Label = $HUD/Journal/Margin/Content/Body
@onready var gear_options: VBoxContainer = $HUD/Journal/Margin/Content/GearOptions
@onready var dialogue_action: Button = $HUD/Journal/Margin/Content/Action
var quest: ValeQuestProgress
var quest_chain: Array[ValeQuestProgress] = []
var quest_objects: Array[ValeInteractable] = []
var dialogue_quest: ValeQuestProgress
var panel_mode := JournalView.CLOSED

func _ready() -> void:
	super._ready()
	quest = ValeQuestProgress.new(quest_definition)
	quest_chain.append(quest)
	for follow_up in follow_up_quests:
		quest_chain.append(ValeQuestProgress.new(follow_up))
	for enemy in enemies:
		enemy.health.died.connect(_record_defeat.bind(enemy))
		enemy.respawned.connect(_refresh_enemy_marker.bind(enemy))
	for child in get_children():
		if child is ValeInteractable and child.objective_id != &"":
			quest_objects.append(child)
			child.interacted.connect(_use_quest_object.bind(child))
	mara.interacted.connect(_talk_to_mara)
	player.health.died.connect(_close_panel)
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
	if player.grant_item(stats.defeat_item):
		loot_notice.text = "%s added to Gear (I)" % stats.defeat_item.display_name
		loot_notice.show()
	_refresh_progress()

func _use_quest_object(object: ValeInteractable) -> void:
	if object.collision_layer == 0 or not player.is_alive() or not object.is_in_range(player):
		return
	if not quest.record_interaction(object.objective_id):
		status.text = "Ask Captain Mara about the %s" % object.display_name.to_lower()
		return
	object.collect()
	status.text = "%s recovered" % object.display_name
	_refresh_progress()

func _talk_to_mara() -> void:
	dialogue_quest = quest
	_show_panel(JournalView.DIALOGUE)

func _perform_dialogue_action() -> void:
	if panel_mode != JournalView.DIALOGUE or not player.is_alive() or not mara.is_in_range(player):
		return
	if dialogue_quest.state == ValeQuestProgress.State.COMPLETED and dialogue_quest != quest:
		dialogue_quest = quest
	elif dialogue_quest.accept():
		_close_panel()
	elif dialogue_quest.complete():
		player.grant_item(dialogue_quest.definition.reward_item)
		player.award_experience(dialogue_quest.definition.reward_xp)
		var next_index := quest_chain.find(dialogue_quest) + 1
		if next_index < quest_chain.size():
			quest = quest_chain[next_index]
	_refresh_progress()

func _objective_text() -> String:
	var definition := quest.definition
	match quest.state:
		ValeQuestProgress.State.AVAILABLE:
			return "Speak to Captain Mara at the watchpost"
		ValeQuestProgress.State.ACTIVE:
			if definition.required_kills > 0:
				return "%s  %d / %d" % [definition.objective, quest.kills, definition.required_kills]
			return definition.objective
		ValeQuestProgress.State.READY:
			return definition.return_objective
		_:
			return "%s complete" % definition.title if chain_completion_text.is_empty() else chain_completion_text

func _refresh_progress() -> void:
	objective_label.text = _objective_text()
	var next_xp: int = player.next_level_experience()
	if next_xp > 0:
		progression_label.text = "XP %d / %d" % [player.experience, next_xp]
	else:
		progression_label.text = "XP %d · Max level" % player.experience
	for object in quest_objects:
		object.set_objective_hint(quest.state == ValeQuestProgress.State.ACTIVE
			and quest.definition.target_object == object.objective_id)
	for enemy in enemies:
		_refresh_enemy_marker(enemy)
	match quest.state:
		ValeQuestProgress.State.AVAILABLE:
			quest_marker.text = "!"
		ValeQuestProgress.State.READY:
			quest_marker.text = "?"
		_:
			quest_marker.text = ""
	_refresh_panel()

func _refresh_enemy_marker(enemy: ValeEnemy) -> void:
	var marker := enemy.get_node_or_null("QuestMarker") as Label3D
	if marker:
		marker.visible = quest.state == ValeQuestProgress.State.ACTIVE and enemy.is_alive() \
			and quest.definition.target_enemy == enemy.stats.enemy_id

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
	gear_options.visible = panel_mode == JournalView.GEAR
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
		elif progress == quest:
			entries.append("%s\n%s" % [progress.definition.title, _objective_text()])
	journal_body.text = "\n\n".join(entries)

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
			dialogue_action.show()
		ValeQuestProgress.State.ACTIVE:
			journal_body.text = "%s\n\n%s\n\n%s" % [definition.title, definition.briefing, _objective_text()]
		ValeQuestProgress.State.READY:
			journal_body.text = "%s\n\nReward · %s" % [definition.turn_in_dialogue, reward]
			dialogue_action.text = "Turn in quest"
			dialogue_action.show()
		ValeQuestProgress.State.COMPLETED:
			journal_body.text = "%s complete\n\nReward earned · %s" % [definition.title, reward]
			if definition.reward_item:
				journal_body.text += "\nOpen Gear (I) to equip your reward."
			if dialogue_quest != quest:
				dialogue_action.text = "View next quest"
				dialogue_action.show()

func _show_gear() -> void:
	journal_title.text = "Gear"
	journal_body.text = "%s equipped\n%s equipped\n\nSword damage  %d\nArmor  %d" % [
		player.equipped_weapon.display_name, player.equipped_armor.display_name,
		player.sword_damage(), player.armor_value()]
	for option in gear_options.get_children():
		gear_options.remove_child(option)
		option.queue_free()
	for item: ValeItem in player.owned_items.values():
		if item == player.equipped_weapon or item == player.equipped_armor:
			continue
		var option := Button.new()
		var effect := "%d armor" % item.armor
		if item.slot == ValeItem.Slot.WEAPON:
			effect = "%d sword damage" % (player.stats.damage + item.bonus_damage)
		option.text = "Equip %s · %s" % [item.display_name, effect]
		option.pressed.connect(_equip.bind(item.id))
		gear_options.add_child(option)

func _equip(item_id: StringName) -> void:
	if player.equip_item(item_id):
		_refresh_panel()
