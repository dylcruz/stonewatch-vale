class_name ValeQuestProgress
extends RefCounted

enum State { AVAILABLE, ACTIVE, READY, COMPLETED }

var definition: ValeQuestDefinition
var state := State.AVAILABLE
var kills := 0

func _init(quest: ValeQuestDefinition) -> void:
	definition = quest

func record_defeat(enemy_id: StringName) -> void:
	if enemy_id != definition.target_enemy or kills >= definition.required_kills:
		return
	kills += 1
	if state == State.ACTIVE and kills == definition.required_kills:
		state = State.READY

func record_interaction(object_id: StringName) -> bool:
	if state != State.ACTIVE or object_id == &"" or object_id != definition.target_object:
		return false
	state = State.READY
	return true

func accept() -> bool:
	if state != State.AVAILABLE:
		return false
	state = State.READY if definition.required_kills > 0 and kills >= definition.required_kills else State.ACTIVE
	return true

func complete() -> bool:
	if state != State.READY:
		return false
	state = State.COMPLETED
	return true
