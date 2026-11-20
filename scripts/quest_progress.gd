class_name ValeQuestProgress
extends RefCounted

enum State { AVAILABLE, ACTIVE, READY, COMPLETED }

var definition: ValeQuestDefinition
var state := State.AVAILABLE
var kills := 0

func _init(quest: ValeQuestDefinition) -> void:
	definition = quest

func is_in_progress() -> bool:
	return state == State.ACTIVE or state == State.READY

func needs_enemy(enemy_id: StringName, encounter_id: StringName) -> bool:
	return state == State.ACTIVE and kills < definition.required_kills and enemy_id == definition.target_enemy \
		and (definition.target_encounter == &"" or encounter_id == definition.target_encounter)

func record_defeat(enemy_id: StringName, encounter_id: StringName = &"") -> bool:
	if not needs_enemy(enemy_id, encounter_id):
		return false
	kills += 1
	if kills == definition.required_kills:
		state = State.READY
	return true

func record_interaction(object_id: StringName) -> bool:
	if state != State.ACTIVE or object_id == &"" or object_id != definition.target_object:
		return false
	state = State.READY
	return true

func accept() -> bool:
	if state != State.AVAILABLE:
		return false
	state = State.ACTIVE
	return true

func complete() -> bool:
	if state != State.READY:
		return false
	state = State.COMPLETED
	return true
