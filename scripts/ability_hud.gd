class_name ValeAbilityHUD
extends Control

signal layout_changed

const SLOT_ACTIONS: Array[StringName] = [&"ability_slot_1", &"ability_slot_2", &"ability_slot_3", &"ability_slot_4"]
const ABILITY_NAMES: Dictionary[StringName, String] = {&"cleave": "Cleave", &"guard": "Guard"}
const MUTED := Color(0.65, 0.70, 0.68)
const READY := Color(0.91, 0.94, 0.87)
const COOLING := Color(0.94, 0.76, 0.48)
const ACTIVE := Color(0.56, 0.85, 0.96)

@onready var book: PanelContainer = %Book
@onready var slots_row: HBoxContainer = %Slots
@onready var menu_buttons: HBoxContainer = %MenuButtons
@onready var entries: VBoxContainer = %Entries
@onready var slot_summary: Label = %SlotSummary
@onready var clear_slot: Button = %ClearSlot

var _player: ValeWarrior
var _layout: Array[StringName] = [&"cleave", &"guard", &"", &""]
var _slot_buttons: Array[Button] = []
var _assign_buttons: Dictionary[StringName, Button] = {}
var _selected_slot := 0

func bind_player(player: ValeWarrior) -> void:
	_player = player
	%CloseBook.pressed.connect(close_book)
	clear_slot.pressed.connect(_clear_selected_slot)
	_player.progression_changed.connect(_refresh_book)
	_player.health.died.connect(close_book)
	for index in SLOT_ACTIONS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(94, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_press_slot.bind(index))
		slots_row.add_child(button)
		_slot_buttons.append(button)
	_add_entry(&"cleave", "Strike enemies in a frontal arc for %d damage within %.1f m." % [
		_player.cleave_damage, _player.cleave_range],
		"Level %d unlock  ·  %.1fs cooldown" % [ValeWarrior.CLEAVE_UNLOCK_LEVEL, _player.cleave_cooldown])
	_add_entry(&"guard", "Reduce incoming damage by %d%% for %.2fs." % [
		roundi(_player.guard_reduction * 100.0), _player.guard_duration],
		"Available at level 1  ·  %.1fs cooldown" % _player.guard_cooldown)
	_refresh_book()
	_update_slots()

func add_menu_button(label: String, shortcut: String, toggle_menu: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = "%s (%s)" % [label, shortcut]
	button.custom_minimum_size.y = 27
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(toggle_menu)
	menu_buttons.add_child(button)

func open_book() -> void:
	book.show()
	_refresh_book()

func close_book() -> void:
	book.hide()
	_refresh_book()

func is_book_open() -> bool:
	return book.visible

func save_layout() -> PackedStringArray:
	return PackedStringArray(_layout)

func restore_layout(saved: Variant) -> void:
	if not saved is PackedStringArray or saved.size() != _layout.size():
		return
	var restored: Array[StringName] = []
	for entry: String in saved:
		var ability := StringName(entry)
		if ability != &"" and (not ABILITY_NAMES.has(ability) or ability in restored):
			ability = &""
		restored.append(ability)
	_layout = restored
	_refresh_book()
	_update_slots()

func handle_shortcut(event: InputEvent) -> bool:
	for index in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[index]):
			_activate_slot(index)
			return true
	return false

func _process(_delta: float) -> void:
	if _player:
		_update_slots()

func _add_entry(ability: StringName, description: String, details: String) -> void:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 5)
	entries.add_child(entry)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.text = ABILITY_NAMES[ability]
	entry.add_child(name_label)
	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = description
	entry.add_child(description_label)
	var details_label := Label.new()
	details_label.modulate = MUTED
	details_label.text = details
	entry.add_child(details_label)
	var assign := Button.new()
	assign.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	assign.pressed.connect(_assign_selected_slot.bind(ability))
	entry.add_child(assign)
	_assign_buttons[ability] = assign

func _unlocked(ability: StringName) -> bool:
	return ability == &"guard" or (ability == &"cleave" and _player.has_cleave())

func _activate_slot(index: int) -> void:
	match _layout[index]:
		&"cleave":
			_player.activate_cleave()
		&"guard":
			_player.activate_guard()

func _press_slot(index: int) -> void:
	if is_book_open():
		_selected_slot = index
		_refresh_book()
	else:
		_activate_slot(index)

func _assign_selected_slot(ability: StringName) -> void:
	if not _unlocked(ability):
		return
	var old_slot := _layout.find(ability)
	if old_slot == _selected_slot:
		return
	if old_slot >= 0:
		_layout[old_slot] = _layout[_selected_slot]
	_layout[_selected_slot] = ability
	_layout_updated()

func _clear_selected_slot() -> void:
	if _layout[_selected_slot] != &"":
		_layout[_selected_slot] = &""
		_layout_updated()

func _layout_updated() -> void:
	_refresh_book()
	_update_slots()
	layout_changed.emit()

func _refresh_book() -> void:
	var selected := _layout[_selected_slot]
	var name_in_slot: String = ABILITY_NAMES.get(selected, "Empty")
	slot_summary.text = "Editing slot %d  ·  %s" % [_selected_slot + 1, name_in_slot]
	clear_slot.disabled = selected == &""
	for ability in _assign_buttons:
		var button := _assign_buttons[ability]
		var slot := _layout.find(ability)
		var unlocked := _unlocked(ability)
		button.disabled = not unlocked or slot == _selected_slot
		if not unlocked:
			button.text = "Locked"
		elif slot == _selected_slot:
			button.text = "Assigned here"
		else:
			button.text = "Assign to slot %d" % (_selected_slot + 1)
		button.tooltip_text = "Currently in slot %d" % (slot + 1) if slot >= 0 else ""
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		button.toggle_mode = is_book_open()
		button.set_pressed_no_signal(is_book_open() and index == _selected_slot)

func _update_slots() -> void:
	for index in _slot_buttons.size():
		var ability := _layout[index]
		var name_in_slot: String = ABILITY_NAMES.get(ability, "Empty")
		var state := ""
		var color := MUTED
		if ability != &"":
			if not _unlocked(ability):
				state = "Locked"
			elif not _player.is_alive():
				state = "Unavailable"
			elif ability == &"guard" and _player.guard_remaining > 0.0:
				state = "Active %.1fs" % _player.guard_remaining
				color = ACTIVE
			else:
				var remaining := _player.guard_cooldown_remaining if ability == &"guard" else _player.cleave_cooldown_remaining
				state = "%.1fs left" % remaining if remaining > 0.0 else "Ready"
				color = COOLING if remaining > 0.0 else READY
		var label := "%d  ·  %s" % [index + 1, name_in_slot]
		if not state.is_empty():
			label += "\n" + state
		var button := _slot_buttons[index]
		if button.text != label:
			button.text = label
			button.add_theme_color_override("font_color", color)
