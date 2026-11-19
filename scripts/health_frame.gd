class_name ValeHealthFrame
extends PanelContainer

@onready var portrait: TextureRect = %Portrait
@onready var actor_name: Label = %ActorName
@onready var amount: Label = %Amount
@onready var bar: ProgressBar = %HealthBar

func display(stats: ValeCombatStats, health: ValeHealth, caption: String) -> void:
	portrait.texture = stats.portrait
	actor_name.text = caption
	amount.text = "%d / %d HP" % [health.current, health.maximum]
	bar.max_value = health.maximum
	bar.value = health.current
