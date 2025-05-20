extends SceneTree

const _VERSION = "v0.2.0"

var _manager_scene: PackedScene

func _initialize():
	print("[TASmaniac] Bootstrapping TASmaniac " + _VERSION)
	
	# This helps prevent situations where input handling misbehaves 
	# because some frames are skipped during minor lag spikes, especially at the start of levels.
	# TODO: This is kind of unfair, because a player using an unmodified game
	# could not apply inputs during a lag spike, even with perfect timing,
	# and avoiding these lag spikes seems impossible, even with a good computer.
	# It would be good to either obtain proof that the lag spikes can be avoided in some way
	# or remove this and increase the delay before first input.
	Engine.max_physics_steps_per_frame = 1
	
	var refresh_rate := DisplayServer.screen_get_refresh_rate()
	if refresh_rate != -1 and refresh_rate < 59.9:
		OS.alert("You are playing on a monitor with a %.2f Hz refresh rate.\n" % refresh_rate 
			+ "Playing at refresh rates lower than 60 Hz may cause weird inconsistencies. " 
			+ "It is recommended that you increase the refresh rate of your monitor.", "TASmaniac warning")
	
	_manager_scene = load("res://tasmaniac/manager.tscn")
	_assert(_manager_scene != null, "Failed to load tasmaniac/manager.tscn. Make sure that you have copied the entire tasmaniac folder to your install location.")
	
	var packer := PCKPacker.new()
	var result = packer.pck_start("user://_patch.pck")
	_assert(result == OK, "Opening _patch.pck for writing failed: " + error_string(result))
	result = packer.add_file("res://scenes/main/level_loader.gd.remap", "res://tasmaniac/level_loader.gd.remap")
	_assert(result == OK, "Patching level_loader.gd.remap failed: " + error_string(result))
	result = packer.flush()
	_assert(result == OK, "Writing _patch.pck failed: " + error_string(result))
	
	result = ProjectSettings.load_resource_pack("user://_patch.pck")
	_assert(result, "Loading _patch.pck failed")
	
	root.child_entered_tree.connect(_on_scene_load)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

func _on_scene_load(scene: Node):
	if scene.name == "MainScene":
		var level_loader = scene.get_node("LevelLoader")
		var global = root.get_node("Global")
		
		var manager := _manager_scene.instantiate()
		manager.init(level_loader, global)
		scene.add_child(manager)

func _assert(condition: bool, message: String):
	if !condition:
		push_error("[TASmaniac] ERROR: " + message)
		OS.alert(message, "TASmaniac error")
		OS.crash("Assertion failed, exiting...")
