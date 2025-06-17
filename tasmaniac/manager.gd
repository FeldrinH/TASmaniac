extends Node

const FRAME_STOP := -1024

const ACTIONS := {
	"W": &"up_l",
	"A": &"left_l",
	"D": &"right_l",
	"U": &"up_r",
	"L": &"left_r",
	"R": &"right_r",
}

const collision_drawer_script := preload("res://tasmaniac/collision_drawer.gd")

@onready var settings_container: Container = $SettingsContainer
@onready var time_scale_input: Range = $SettingsContainer/TimeScaleInput
@onready var input_file_input: OptionButton = $SettingsContainer/InputFileInput
@onready var save_recording_button: Button = $SettingsContainer/SaveRecordingButton
@onready var collision_shapes_toggle: Button = $SettingsContainer/CollisionShapesToggle
@onready var timer_label: Label = $TimerLabel
@onready var notification_label: Label = $NotificationLabel
@onready var notification_label_timer: Timer = $NotificationLabel/Timer
@onready var player_info: Container = $PlayerInfo
@onready var coyote_labels: Array[Label] = [$PlayerInfo/CoyoteLeft, $PlayerInfo/CoyoteRight]
@onready var alignment_labels: Array[Label] = [$PlayerInfo/AlignmentLeft, $PlayerInfo/AlignmentRight]
@onready var position_labels: Array[Label] = [$PlayerInfo/PositionLeft, $PlayerInfo/PositionRight]
@onready var velocity_labels: Array[Label] = [$PlayerInfo/VelocityLeft, $PlayerInfo/VelocityRight]

var headless := !DisplayServer.window_can_draw()
var default_tps := Engine.physics_ticks_per_second

var recordings_folder: String

var level_loader: Node
var menu_loader: Node
var global: Node

var input_files_list_level := ""

var level_loaded := false
var frame := FRAME_STOP

var recording := false
var playback := false
var autoload := true

var input_file: String = ""
var inputs: PackedStringArray = []
var inputs_i := 0

func init(recordings_folder: String, level_loader: Node, menu_loader: Node, global: Node):
	self.recordings_folder = recordings_folder
	self.level_loader = level_loader
	self.menu_loader = menu_loader
	self.global = global

func _ready():
	level_loader._level_load.connect(on_level_load)
	level_loader._level_complete.connect(on_level_complete)
	level_loader._level_unload.connect(on_level_unload)
	
	time_scale_input.value_changed.connect(update_time_scale)
	save_recording_button.pressed.connect(func(): if recording and level_loaded and inputs: save_recording(true))
	collision_shapes_toggle.toggled.connect(update_draw_collision_shapes)
	
	notification_label_timer.timeout.connect(func(): notification_label.visible = false)
	
	$VersionLabel.text = "v" + global.version + " / " + get_tree()._VERSION

func update_time_scale(value: float):
	get_tree()._set_delta_multiplier(1.0 / value)

func update_input_file(index: int):
	if index == -1:
		input_file = ""
	elif index == 0:
		input_file = ""
		recording = true
		playback = false
		autoload = true
	else:
		input_file = input_file_input.get_item_text(index)
		recording = false
		playback = true
		autoload = true

func update_draw_collision_shapes(enabled: bool):
	var level_instance: Node = level_loader.current_level_instance
	if !is_instance_valid(level_instance):
		return
	
	if enabled:
		for collision_shape in level_instance.find_children("*", "CollisionShape2D", true, false):
			var parent := collision_shape.get_parent()
			if parent is not CollisionObject2D:
				continue
			
			var color: Color
			if parent.get_collision_layer_value(2):
				color = Color.RED # Damage
			elif parent.name == &"DamageArea":
				color = Color.GREEN # Player damage
			elif parent.name == &"PlayerChara":
				color = Color.CYAN # Player collision
			else:
				continue
			color.a = 0.5
			
			collision_shape.add_child(collision_drawer_script.new(color))
		
		for tile_map in level_instance.find_children("*", "TileMapLayer"):
			var color := Color.RED
			color.a = 0.5
			tile_map.add_child(collision_drawer_script.new(color))
	else:
		for collision_drawer in get_tree().get_nodes_in_group("_collision_drawers"):
			collision_drawer.queue_free()

func show_notification(text: String):
	notification_label.text = text
	notification_label.visible = true
	notification_label_timer.stop()
	notification_label_timer.start()

func start_manual_playback(level: int, level_inputs: PackedStringArray, level_start_positions):
	input_file_input.select(-1)
	recording = false
	playback = true
	autoload = false
	
	inputs = level_inputs
	inputs_i = 0
	
	level_loader.unload_level()
	menu_loader.manage_load_level(level, 1, 0, 0)
	
	if level_start_positions:
		set_player_positions.call_deferred(level_start_positions)

func set_player_positions(positions):
	for i in 2:
		global.player_charas[i].global_position = positions[i] * Vector2(1, -1)

func save_recording(incomplete: bool):
	var error := DirAccess.make_dir_absolute(recordings_folder)
	if error != OK and error != ERR_ALREADY_EXISTS:
		alert("Failed to create recordings folder: " + error_string(error))
		return
	
	# TODO: Detect conflicting filenames and add sequence number?
	var level_number = level_loader.get_level_number_string()
	var duration := float(frame) / default_tps
	var filename := recordings_folder + ("/lvl%s_incomplete_%05.2f.txt" if incomplete else "/lvl%s_%05.2f.txt") % [level_number, duration]
	
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		alert("Failed to write recording to file " + filename + ": " + error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_string("\n".join(inputs))
	if file.get_error() != OK:
		alert("Failed to write recording to file " + filename + ": " + error_string(file.get_error()))
		return file.get_error()
	
	if incomplete:
		print("[TASmaniac] Saved incomplete recording to file " + filename)
		show_notification("Saved incomplete recording to file " + filename)
	else:
		print("[TASmaniac] Saved recording to file " + filename)
		show_notification("Saved recording to file " + filename)

# TODO: This should be called even if the player has not moved, but currently it isn't.
func on_level_load():
	level_loaded = true
	
	if collision_shapes_toggle.button_pressed:
		(func(): update_draw_collision_shapes(collision_shapes_toggle.button_pressed)).call_deferred()
	
	if autoload and level_loader.get_level_number_string() != input_files_list_level:
		input_files_list_level = level_loader.get_level_number_string()
		
		var selected := input_file_input.selected
		input_file_input.clear()
		input_file_input.add_item("Record new...")
		
		var dir := DirAccess.open(recordings_folder)
		if DirAccess.get_open_error() == OK:
			var prefix := "lvl%s" % input_files_list_level
			var file_names := dir.get_files()
			for file in file_names:
				if file.begins_with(prefix) and file.ends_with(".txt"):
					input_file_input.add_item(file)
		elif DirAccess.get_open_error() != ERR_INVALID_PARAMETER:
			alert("Failed to read list of recordings from recordings folder: " + error_string(DirAccess.get_open_error()))
		
		input_file_input.select(min(selected, input_file_input.item_count - 1, 1))
	
	update_input_file(input_file_input.selected)
	
	if recording:
		inputs = []
		inputs_i = 0
		
		frame = FRAME_STOP
	elif playback:
		# Reset all inputs
		for key in ACTIONS:
			Input.action_release(ACTIONS[key])
		
		if autoload:
			var filename := recordings_folder + "/" + input_file
			var file := FileAccess.open(filename, FileAccess.READ)
			if FileAccess.get_open_error() != OK:
				alert("Failed to read recording from file " + filename + ": " + error_string(FileAccess.get_open_error()))
				return
			var contents := file.get_as_text(true)
			if file.get_error() != OK:
				alert("Failed to read recording from file " + filename + ": " + error_string(file.get_error()))
				return
			inputs = contents.split("\n", false)
			inputs_i = 0
			
			print("[TASmaniac] Loaded " + filename + " for playback")
			show_notification("Loaded " + filename + " for playback")
		
		# Only start the clock if we have freshly loaded inputs.
		if inputs and inputs_i == 0:
			# This delay is necessary, because the game refuses to take inputs for the first idle frame after a new level is loaded
			# (the first idle frame is frame -1, because frame -2 is the frame during which loading happens).
			frame = -2
		else:
			frame = FRAME_STOP

func on_level_complete():
	level_loaded = false
	
	if recording:
		save_recording(false)

func on_level_unload():
	level_loaded = false
	frame = FRAME_STOP
	
	input_files_list_level = ""
	
	var selected := input_file_input.selected
	input_file_input.clear()
	input_file_input.add_item("Record new...")
	input_file_input.add_item("First matching recording")
	input_file_input.select(min(selected, 1))

func _process(delta: float):
	if level_loaded or frame != FRAME_STOP:
		var timer_frame := 0 if frame == FRAME_STOP else frame
		timer_label.text = "%05.2f / %d" % [float(timer_frame) / default_tps, timer_frame]
	else:
		timer_label.text = ""
	
	if is_instance_valid(global.player_charas[0]):
		player_info.visible = true
		for i in 2:
			coyote_labels[i].text = "%.3f" % global.player_charas[i].coyote_timer.time_left
			alignment_labels[i].text = "%.3f" % fposmod(global.player_charas[i].global_position.x, (130.0 / 60.0))
			position_labels[i].text = "%7.2v" % (global.player_charas[i].global_position * Vector2(1, -1))
			velocity_labels[i].text = "%7.2v" % (global.player_charas[i].velocity * Vector2(1, -1))
	else:
		player_info.visible = false
	
	if not level_loaded:
		return
	
	if recording:
		var parts := PackedStringArray()
		for key in ACTIONS:
			var input_name: StringName = ACTIONS[key]
			if Input.is_action_just_pressed(input_name):
				parts.append("+" + key)
			if Input.is_action_just_released(input_name) and (inputs or parts):
				parts.append("-" + key)
		if parts:
			if frame == FRAME_STOP:
				frame = 0
			inputs.append(str(frame) + " " + " ".join(parts))
	elif playback:
		while inputs_i < len(inputs):
			var parts := inputs[inputs_i].split(" ", false)
			var target_frame := int(parts[0])
			if target_frame > frame:
				break
			
			if !headless:
				print("[TASmaniac] " + inputs[inputs_i])
			for input in parts.slice(1):
				var prefix := input.substr(0, 1)
				var key := input.substr(1)
				if key not in ACTIONS:
					print("[TASmaniac] WARNING: invalid input " + input)
					continue
				if prefix == "+":
					Input.action_press(ACTIONS[key])
				elif prefix == "-":
					Input.action_release(ACTIONS[key])
				else:
					print("[TASmaniac] WARNING: invalid input " + input)
					continue
			
			inputs_i += 1

func _physics_process(delta: float):
	if not level_loaded:
		return
	
	if frame != FRAME_STOP:
		frame += 1

static func alert(message: String):
	push_error("[TASmaniac] ERROR: " + message)
	OS.alert(message, "TASmaniac error")
