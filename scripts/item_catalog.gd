extends RefCounted
## Save IDs stay stable when an item's reward source or resource path changes.

const ITEMS: Dictionary[StringName, ValeItem] = {
	&"training_sword": preload("res://data/training_sword.tres"),
	&"iron_sword": preload("res://data/iron_sword.tres"),
	&"travel_coat": preload("res://data/travel_coat.tres"),
	&"wardens_coat": preload("res://data/wardens_coat.tres"),
	&"trail_pack": preload("res://data/trail_pack.tres"),
	&"scout_pouch": preload("res://data/scout_pouch.tres"),
}
