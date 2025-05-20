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

var input_files_list_level := ""

@onready var settings_container: Container = $SettingsContainer
@onready var time_scale_input: Range = $SettingsContainer/TimeScaleInput
@onready var input_file_input: OptionButton = $SettingsContainer/InputFileInput
@onready var save_recording_button: Button = $SettingsContainer/SaveRecordingButton
@onready var timer_label: Label = $TimerLabel
@onready var notification_label: Label = $NotificationLabel
@onready var notification_label_timer: Timer = $NotificationLabel/Timer
@onready var coyote_info: Container = $CoyoteInfo
@onready var coyote_left_label: Label = $CoyoteInfo/Left
@onready var coyote_right_label: Label = $CoyoteInfo/Right

var default_tps := Engine.physics_ticks_per_second

var level_loader: Node
var global: Node

var level_loaded := false
var frame := FRAME_STOP

var recording := false
var playback := false

var input_file: String = ""
var inputs: PackedStringArray = []
var inputs_i := 0

#var input_log_level: String
#var input_log: PackedStringArray = []

func init(level_loader: Node, global: Node):
	self.level_loader = level_loader
	self.global = global
	
	level_loader._level_load.connect(on_level_load)
	level_loader._level_complete.connect(on_level_complete)
	level_loader._level_unload.connect(on_level_unload)

func _ready():
	time_scale_input.value_changed.connect(update_time_scale)
	save_recording_button.pressed.connect(func(): if recording and level_loaded and inputs: save_recording(true))
	
	notification_label_timer.timeout.connect(func(): notification_label.visible = false)
	
	$VersionLabel.text = "v" + global.version + " / " + get_tree()._VERSION

func update_time_scale(value: float):
	var tps := roundi(default_tps * value)
	var time_scale := float(tps) / default_tps
	Engine.physics_ticks_per_second = tps
	Engine.time_scale = time_scale
	time_scale_input.set_value_no_signal(time_scale)

func update_input_file(index: int):
	if index == -1:
		input_file = ""
	elif index == 0:
		input_file = ""
		recording = true
		playback = false
	else:
		input_file = input_file_input.get_item_text(index)
		recording = false
		playback = true

func show_notification(text: String):
	notification_label.text = text
	notification_label.visible = true
	notification_label_timer.stop()
	notification_label_timer.start()

func save_recording(incomplete: bool):
	var error := DirAccess.make_dir_absolute("recordings")
	if error != OK and error != ERR_ALREADY_EXISTS:
		alert("Failed to create recordings folder: " + error_string(error))
		return
	
	# TODO: Detect conflicting filenames and add sequence number?
	var level_number = level_loader.get_level_number_string()
	var duration := float(frame) / default_tps
	var filename := ("recordings/lvl%s_incomplete_%05.2f.txt" if incomplete else "recordings/lvl%s_%05.2f.txt") % [level_number, duration]
	
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

# TODO: This should be called even if the player has not moved, but currently it isn't
func on_level_load():
	level_loaded = true
	
	if level_loader.get_level_number_string() != input_files_list_level:
		input_files_list_level = level_loader.get_level_number_string()
		
		var selected := input_file_input.selected
		input_file_input.clear()
		input_file_input.add_item("Record new...")
		
		var dir := DirAccess.open("recordings")
		if DirAccess.get_open_error() == OK:
			var prefix := "lvl%s" % input_files_list_level
			var file_names := dir.get_files()
			for file in file_names:
				if file.begins_with(prefix) and file.ends_with(".txt"):
					input_file_input.add_item(file)
		elif DirAccess.get_open_error() != ERR_INVALID_PARAMETER:
			alert("Failed to read list of recordings from folder recordings: " + error_string(DirAccess.get_open_error()))
		
		input_file_input.select(min(selected, input_file_input.item_count - 1, 1))
	
	update_input_file(input_file_input.selected)
	
	#if input_log_level and input_log:
		#var filename := "user://lvl%s_%s.txt" % [input_log_level, Time.get_datetime_string_from_system().replace(":", ".")]
		#var file := FileAccess.open(filename, FileAccess.WRITE)
		#if FileAccess.get_open_error() != OK:
			#alert("Failed to write input log to file " + filename + ": " + error_string(FileAccess.get_open_error()))
			#return
		#file.store_string("\n".join(input_log))
		#if file.get_error() != OK:
			#alert("Failed to write input log to file " + filename + ": " + error_string(file.get_error()))
			#return
		#print("[TASmaniac] Saved input log to file " + filename)
	#input_log_level = level_loader.get_level_number_string()
	#input_log.clear()
	
	if recording:
		inputs = []
		inputs_i = 0
		
		frame = FRAME_STOP
	elif playback:
		# Reset all inputs
		for key in ACTIONS:
			Input.action_release(ACTIONS[key])
		
		var filename := "recordings/" + input_file
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
		
		# This delay is necessary, because the game refuses to take inputs for the first idle frame after a new level is loaded
		# (the first idle frame is frame -1, because frame -2 is the frame during which loading happens).
		frame = -2
		
		print("[TASmaniac] Loaded " + filename + " for playback")
		show_notification("Loaded " + filename + " for playback")

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
		timer_label.text = "%05.2f" % (0.0 if frame == FRAME_STOP else float(frame) / default_tps)
	else:
		timer_label.text = ""
	
	if is_instance_valid(global.player_charas[0]):
		coyote_info.visible = true
		coyote_left_label.text = "%.3f" % global.player_charas[0].coyote_timer.time_left
		coyote_right_label.text = "%.3f" % global.player_charas[1].coyote_timer.time_left
	else:
		coyote_info.visible = false
	
	if not level_loaded:
		return
	
	if recording:
		var parts := PackedStringArray()
		for key in ACTIONS:
			var input_name: StringName = ACTIONS[key]
			if Input.is_action_just_pressed(input_name):
				parts.append("+" + key)
			if Input.is_action_just_released(input_name):
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
		
		#var parts := PackedStringArray()
		#for key in ACTIONS:
			#var input_name: StringName = ACTIONS[key]
			#if Input.is_action_just_pressed(input_name):
				#parts.append("+" + key)
			#if Input.is_action_just_released(input_name):
				#parts.append("-" + key)
		#if len(parts) > 0:
			#print("DETECTED " + str(frame) + " " + " ".join(parts))

func _physics_process(delta: float):
	if not level_loaded:
		return
	
	#var player_characters: Array[Node] = global.player_charas
	#if player_characters[0]:
		#var dir_l = player_characters[0]._direction
		#var jump_l = !player_characters[0].jump_buffer_timer.is_stopped()
		#var dir_r = player_characters[1]._direction
		#var jump_r = !player_characters[1].jump_buffer_timer.is_stopped()
		#if not input_log.is_empty() or dir_l != 0 or jump_l or dir_r != 0 or jump_r:
			#input_log.append("%d %s %d %s" % [dir_l, jump_l, dir_r, jump_r])
	
	if frame != FRAME_STOP:
		frame += 1

static func alert(message: String):
	push_error("[TASmaniac] ERROR: " + message)
	OS.alert(message, "TASmaniac error")
