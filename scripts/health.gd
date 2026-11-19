class_name ValeHealth
extends Node

signal changed(current: int, maximum: int)
signal died

var maximum: int = 1
var current: int = 1

func reset(max_health: int) -> void:
	maximum = maxi(1, max_health)
	current = maximum
	changed.emit(current, maximum)

func increase_maximum(max_health: int) -> void:
	var increase := max_health - maximum
	if increase <= 0:
		return
	maximum = max_health
	if current > 0:
		current += increase
	changed.emit(current, maximum)

func heal(amount: int) -> void:
	if current > 0 and current < maximum and amount > 0:
		current = mini(current + amount, maximum)
		changed.emit(current, maximum)

func take_damage(amount: int) -> int:
	if current <= 0:
		return 0
	var applied := mini(current, maxi(0, amount))
	if applied == 0:
		return 0
	current -= applied
	changed.emit(current, maximum)
	if current == 0:
		died.emit()
	return applied
