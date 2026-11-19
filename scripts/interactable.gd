class_name ValeInteractable
extends StaticBody3D

signal interacted

@export var display_name: String
@export var interaction_range := 1.75
@export var offered_quests: Array[StringName] = []
@export var objective_id: StringName
@export var interaction_feedback: String
@onready var selection_ring: Node3D = $SelectionRing
@onready var objective_marker: Label3D = get_node_or_null("QuestMarker")

func set_selected(value: bool) -> void:
	selection_ring.visible = value

func is_in_range(actor: Node3D) -> bool:
	return global_position.distance_to(actor.global_position) <= interaction_range and ValeMelee.has_line_of_sight(actor, self)

func set_objective_hint(value: bool) -> void:
	if objective_marker:
		objective_marker.visible = value

func collect() -> void:
	collision_layer = 0
	hide()
