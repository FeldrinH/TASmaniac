extends Control

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

var frame := -1

var recording := true
var playback := false

var inputs: Array[String] = []
var inputs_i := 0

func init(level_loader: Node, global: Node):
	self.level_loader = level_loader
	self.global = global
	
	level_loader._level_load.connect(on_level_load)
	global.first_input.connect(on_level_start)
	level_loader._level_complete.connect(on_level_complete)

func _ready():
	visible = false

func on_level_load():
	frame = -1
	
	if recording:
		inputs = []
		inputs_i = 0
	elif playback:
		#  TODO: Add UI to select file
		var filename := "user://lvl%s.txt" % level_loader.get_level_number_string()
		var file := FileAccess.open(filename, FileAccess.READ)
		var contents := file.get_as_text(true)
		if file.get_error() != OK:
			alert("Failed to read recording from file " + filename + ": " + error_string(file.get_error()))
			return
		inputs = contents.split("\n", false)
		inputs_i = 0

func on_level_start():
	if frame == -1:
		frame = 0

func on_level_complete():
	if recording:
		var duration := float(frame) / default_tps
		# TODO: Detect conflicting filenames and add sequence number
		var filename := "user://lvl%s_%05.2f.txt" % [level_loader.get_level_number_string(), duration]
		var file := FileAccess.open(filename, FileAccess.WRITE)
		file.store_string("\n".join(inputs))
		if file.get_error() != OK:
			alert("Failed to write recording to file " + filename + ": " + error_string(file.get_error()))
			return
		print("[TASmaniac] Saved recording to file " + filename)

func _physics_process(delta: float) -> void:
	if recording:
		var parts := PackedStringArray()
		for key in ACTIONS:
			var input_name: StringName = ACTIONS[key]
			if Input.is_action_just_pressed(input_name):
				parts.append("+" + key)
			if Input.is_action_just_released(input_name):
				parts.append("-" + key)
		if len(parts) > 0:
			inputs.append(str(frame) + " " + " ".join(parts))
	elif playback:
		while inputs_i < len(inputs):
			var parts := inputs[inputs_i].split(" ", false)
			var target_frame := int(parts[0])
			if target_frame > frame:
				break
			
			for input in parts.slice(1):
				print("[TASmaniac] " + input)
				var prefix := input.substr(0, 1)
				var key := input.substr(1)
				var input_name: StringName = ACTIONS.get(key, null)
				if input_name == null:
					print("[TASmaniac] WARNING: invalid input " + input)
					continue
				if prefix == "+":
					Input.action_press(input_name)
				elif prefix == "-":
					Input.action_release(input_name)
				else:
					print("[TASmaniac] WARNING: invalid input " + input)
					continue
			
			inputs_i += 1
	
	if frame != -1:
		frame += 1

static func alert(message: String):
	OS.alert(message, "TASmaniac runtime error")
