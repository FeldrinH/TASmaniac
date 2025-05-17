extends "res://tasmaniac/level_loader_original.gd"

signal _level_load
signal _level_complete

func load_level():
	_level_load.emit()
	super.load_level()

func next_level(instantly):
	if !instantly:
		_level_complete.emit()
	super.next_level(instantly)
