extends Control

const FRAME_STOP := -1024

const ACTIONS := {
	"W": &"up_l",
	"A": &"left_l",
	"D": &"right_l",
	"U": &"up_r",
	"L": &"left_r",
	"R": &"right_r",
}

var default_tps := Engine.physics_ticks_per_second

var level_loader: Node
var global: Node

var level_loaded := false
var frame := FRAME_STOP

var recording := false
var playback := true

var inputs: PackedStringArray = []
var inputs_i := 0

#var input_log_level: String
#var input_log: PackedStringArray = []

func init(level_loader: Node, global: Node):
	self.level_loader = level_loader
	self.global = global
	
	level_loader._level_load.connect(on_level_load)
	level_loader._level_complete.connect(on_level_complete)

func _ready():
	visible = false

func on_level_load():
	level_loaded = true
	
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
		
		#  TODO: Add UI to select file
		var filename := "user://lvl%s.txt" % level_loader.get_level_number_string()
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
		
		# TODO: Without this delay the first input gets lost. Why, and can we do something to reduce the delay?
		frame = -10
		
		print("[TASmaniac] Loaded " + filename + " for playback")

func on_level_complete():
	level_loaded = false
	
	if recording:
		var duration := float(frame) / default_tps
		# TODO: Detect conflicting filenames and add sequence number
		var filename := "user://lvl%s.txt" % level_loader.get_level_number_string()
		#var filename := "user://lvl%s_%05.2f.txt" % [level_loader.get_level_number_string(), duration]
		var file := FileAccess.open(filename, FileAccess.WRITE)
		if FileAccess.get_open_error() != OK:
			alert("Failed to write recording to file " + filename + ": " + error_string(FileAccess.get_open_error()))
			return
		file.store_string("\n".join(inputs))
		if file.get_error() != OK:
			alert("Failed to write recording to file " + filename + ": " + error_string(file.get_error()))
			return
		print("[TASmaniac] Saved recording to file " + filename)

func _process(delta: float):
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
	OS.alert(message, "TASmaniac runtime error")
