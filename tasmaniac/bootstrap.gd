extends SceneTree

const _VERSION = "v0.7.4"

var _headless := !DisplayServer.window_can_draw()

var _recordings_folder: String
var _manager_scene: PackedScene
var _websocket_server_script: GDScript

var _websocket_server_port = null

var _delta_multiplier := 1.0

var _last_frame_usec := 0
var _last_delay_usec := 0

func _initialize():
	print("[TASmaniac] Bootstrapping TASmaniac " + _VERSION)
	
	var args := []
	var flags := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			flags.append(arg)
		else:
			args.append(arg)
	
	if len(args) == 0:
		_recordings_folder = "recordings"
	elif len(args) == 1:
		_recordings_folder = args[0].replace("\\", "/")
		while _recordings_folder.ends_with("/"):
			_recordings_folder = _recordings_folder.trim_suffix("/")
		print("[TASmaniac] Recordings folder set to " + _recordings_folder)
	else:
		_assert(false, "Expected 0 or 1 command line arguments, but got %s" % len(args))
	
	_manager_scene = load("res://tasmaniac/manager.tscn")
	_assert(_manager_scene != null, "Failed to load tasmaniac/manager.tscn. Make sure that you have copied the entire tasmaniac folder to your install location.")
	
	for flag in flags:
		if flag == "--server":
			_websocket_server_port = 7111
		elif flag.begins_with("--server="):
			var port_string = flag.trim_prefix("--server=")
			_assert(port_string.is_valid_int(), "Invalid server port: %s" % port_string)
			_websocket_server_port = port_string.to_int()
		else:
			_assert(false, "Unrecognized command line flag: %s" % flag)
	
	if _websocket_server_port != null:
		_websocket_server_script = load("res://tasmaniac/websocket_server.gd")
		_assert(_websocket_server_script != null, "Failed to load tasmaniac/websocket_server.gd. Make sure that you have copied the entire tasmaniac folder to your install location.")
	
	var target_files := [
		"res://scenes/trampoline/trampoline.gdc",
		"res://scenes/smasher/smasher.gdc",
		"res://scenes/projectile/projectile.gdc",
		"res://scenes/moving_spikeball/moving_spikeball.gdc",
		"res://scenes/moving_platform/moving_platform_v.gdc",
		"res://scenes/moving_platform/moving_platform.gdc",
		"res://scenes/mace/mace.gdc",
		"res://scenes/lariat_fireball/lariat_fireball.gdc",
		"res://scenes/directional_block/directional_block.gdc",
		"res://scenes/bars/bars_container.gdc",
	]
	
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_MD5)
	for file in target_files:
		var data := FileAccess.get_file_as_bytes(file)
		_assert(FileAccess.get_open_error() == OK, "Reading file " + file + " failed: " + error_string(FileAccess.get_open_error()))
		hasher.update(data)
	var hash := hasher.finish().hex_encode()
	var patch_file := "user://_patch_%s.pck" % hash
	
	if !FileAccess.file_exists(patch_file):
		var packer := PCKPacker.new()
		var result := packer.pck_start(patch_file)
		_assert(result == OK, "Opening " + patch_file + " for writing failed: " + error_string(result))
		
		result = packer.add_file("res://scenes/main/level_loader.gd.remap", "res://tasmaniac/level_loader.gd.remap")
		_assert(result == OK, "Patching level_loader.gd.remap failed: " + error_string(result))
		
		var replace_what := "15000000d1b6b6b6d3b6b6b6c2b6b6b6e9b6b6b6d0b6b6b6c4b6b6b6d7b6b6b6dbb6b6b6d3b6b6b6c5b6b6b6e9b6b6b6c6b6b6b6d3b6b6b6c4b6b6b6e9b6b6b6c5b6b6b6d3b6b6b6d5b6b6b6d9b6b6b6d8b6b6b6d2b6b6b6"
		var replace_forwhat := "0b000000d1b6b6b6d3b6b6b6c2b6b6b6e9b6b6b6dbb6b6b6d7b6b6b6ceb6b6b6e9b6b6b6d0b6b6b6c6b6b6b6c5b6b6b6"
		
		for i in len(target_files):
			var file: String = target_files[i]
			var tmp_file := "user://_patch_%s.tmp" % i
			
			var data := FileAccess.get_file_as_bytes(file)
			_assert(FileAccess.get_open_error() == OK, "Reading file " + file + " failed: " + error_string(FileAccess.get_open_error()))
			
			var length := data.decode_u32(8)
			var payload := data.slice(12)
			if length != 0:
				payload = payload.decompress(length, FileAccess.COMPRESSION_ZSTD)
			_assert(len(payload) != 0, "Decompressing file " + file + " failed")
			
			var payload_out := payload.hex_encode().replace(replace_what, replace_forwhat).hex_decode()
			
			var file_out := FileAccess.open(tmp_file, FileAccess.WRITE)
			_assert(FileAccess.get_open_error() == OK, "Opening " + tmp_file + " for writing failed")
			file_out.store_buffer(data.slice(0, 8))
			file_out.store_32(len(payload_out))
			file_out.store_buffer(payload_out.compress(FileAccess.COMPRESSION_ZSTD))
			file_out.close()
			_assert(file_out.get_error() == OK, "Writing " + tmp_file + " failed")
			
			result = packer.add_file(file, tmp_file)
			_assert(result == OK, "Patching " + file + " failed: " + error_string(result))
		
		result = packer.flush()
		_assert(result == OK, "Writing " + patch_file + " failed: " + error_string(result))
		
		for i in len(target_files):
			DirAccess.remove_absolute("user://_patch_%s.tmp" % i)
	
	var result := ProjectSettings.load_resource_pack(patch_file)
	_assert(result, "Loading " + patch_file + " failed")
	
	root.child_entered_tree.connect(_on_scene_load)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

func _on_scene_load(scene: Node):
	if scene.name == "MainScene":
		if _headless:
			# Viewport resolution affects out of bounds detection in final level.
			# We use a square aspect ratio if there is no display, because that is optimal for the final level.
			root.size = Vector2i(1080, 1080)
		
		var level_loader := scene.get_node("LevelLoader")
		var menu_loader := scene.get_node("MenuLoader")
		var global := root.get_node("Global")
		
		var manager := _manager_scene.instantiate()
		manager.init(_recordings_folder, level_loader, menu_loader, global)
		scene.add_child(manager)
		
		if _websocket_server_port != null:
			var websocket_server: Node = _websocket_server_script.new(_websocket_server_port, manager)
			scene.add_child(websocket_server)
		
		root.child_entered_tree.disconnect(_on_scene_load)

# TODO: Process is in the middle of the game loop, so adding a delay here increases the input latency.
# It would be good to add the delay somewhere else, but currently there seems to be no other suitable location.
func _process(delta: float):
	var target_delta_usec := roundi(delta * _delta_multiplier * 1_000_000)
	var new_frame_usec := Time.get_ticks_usec()
	var new_delay_usec := maxi(0, target_delta_usec - (new_frame_usec - _last_frame_usec - _last_delay_usec))
	_last_frame_usec = new_frame_usec
	_last_delay_usec = new_delay_usec
	# 2000 us is the shortest possible sleep time with delay_usec on Windows.
	# For shorter delays we accumulate sleep over multiple frames.
	if new_delay_usec >= 2000:
		OS.delay_usec(new_delay_usec)

func _set_delta_multiplier(multiplier: float):
	_delta_multiplier = multiplier

func _assert(condition: bool, message: String):
	if !condition:
		push_error("[TASmaniac] ERROR: " + message)
		OS.alert(message, "TASmaniac error")
		OS.crash("Assertion failed, exiting...")
