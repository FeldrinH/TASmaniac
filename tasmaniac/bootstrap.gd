extends SceneTree

const _VERSION = "v0.3.4"

var _recordings_folder: String
var _manager_scene: PackedScene

var last_frame_usec := 0
var last_delay_usec := 0

func _initialize():	
	print("[TASmaniac] Bootstrapping TASmaniac " + _VERSION)
	
	var args := OS.get_cmdline_user_args()
	if len(args) == 0:
		_recordings_folder = "recordings"
	elif len(args) == 1:
		_recordings_folder = args[0].replace("\\", "/")
		while _recordings_folder.ends_with("/"):
			_recordings_folder = _recordings_folder.trim_suffix("/")
		print("[TASmaniac] Recordings folder set to " + _recordings_folder)
	else:
		_assert(false, "Expected 0 or 1 command line arguments, but got %s" % len(args))
	
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

func _process(delta: float):
	var target_delta_usec := roundi(delta * 1_000_000)
	var new_frame_usec := Time.get_ticks_usec()
	var new_delay_usec := target_delta_usec - (new_frame_usec - last_frame_usec - last_delay_usec)
	last_frame_usec = new_frame_usec
	last_delay_usec = new_delay_usec
	OS.delay_usec(maxi(0, new_delay_usec))

func _on_scene_load(scene: Node):
	if scene.name == "MainScene":
		var level_loader = scene.get_node("LevelLoader")
		var global = root.get_node("Global")
		
		var manager := _manager_scene.instantiate()
		manager.init(_recordings_folder, level_loader, global)
		scene.add_child(manager)

func _assert(condition: bool, message: String):
	if !condition:
		push_error("[TASmaniac] ERROR: " + message)
		OS.alert(message, "TASmaniac error")
		OS.crash("Assertion failed, exiting...")
