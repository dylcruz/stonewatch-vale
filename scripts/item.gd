class_name ValeItem
extends Resource

enum Slot { WEAPON, ARMOR }

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.WEAPON
@export var bonus_damage := 0
@export var armor := 0
@export var blade_color := Color(0.83, 0.9, 0.94)
@export var coat_color := Color(0.18, 0.48, 0.72)
