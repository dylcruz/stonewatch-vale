class_name ValeQuestDefinition
extends Resource

@export var id: StringName
@export var prerequisite_quests: Array[StringName] = []
@export var title: String
@export_multiline var briefing: String
@export var objective: String
@export var return_objective: String
@export_multiline var turn_in_dialogue: String
@export_multiline var completed_dialogue: String
@export var target_enemy: StringName
@export var target_encounter: StringName
@export var required_kills: int
@export var target_object: StringName
@export var discover_at_objective := false
@export var reward_xp: int
@export var reward_item: ValeItem
