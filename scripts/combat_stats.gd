class_name ValeCombatStats
extends Resource
## Initial combat tuning shared by actors; timings are in seconds.

@export var display_name := "Combatant"
@export var portrait: Texture2D
@export var enemy_id: StringName
@export var defeat_xp := 0
@export var defeat_item: ValeItem
@export var max_health: int = 60
@export var damage: int = 8
@export var melee_range: float = 1.8
@export var windup: float = 0.3
@export var attack_interval: float = 1.1
