extends "res://tasmaniac/level_loader_original.gd"

signal _level_load
signal _level_complete
signal _level_unload

func load_level():
	super.load_level()
	_level_load.emit()

func next_level(instantly):
	if !instantly:
		_level_complete.emit()
	super.next_level(instantly)

func unload_level():
	_level_unload.emit()
	super.unload_level()

func save_ending():
	_level_complete.emit()
	super.save_ending()

func _reset_quantum_cubes():
	pass

func _manage_achievements():
	pass

func manage_beat_game_achievements():
	pass
