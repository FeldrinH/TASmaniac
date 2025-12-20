extends Node

var headless := !DisplayServer.window_can_draw()

var port: int
var manager: Node

var tcp_server := TCPServer.new()
var socket := WebSocketPeer.new()

var busy := false
signal level_finished(completed: bool)

func _init(port: int, manager: Node):
	self.port = port
	self.manager = manager
	
	# Important: These connections must be made before the ones in manager, 
	# otherwise frames are reset by the time these trigger.
	manager.level_loader._level_load.connect(func(): level_finished.emit(false))
	manager.level_loader._level_complete.connect(func(): level_finished.emit(true))
	manager.level_loader._level_unload.connect(func(): level_finished.emit(false))
	
	var error := tcp_server.listen(port, "0.0.0.0")
	_assert(error == OK, "Failed to start WebSocket server on port %s: %s" % [port, error_string(error)])
	print("[TASmaniac] WebSocket server started on port %s" % port)

func _process(_delta: float):
	while tcp_server.is_connection_available():
		var conn := tcp_server.take_connection()
		var error := socket.accept_stream(conn)
		if error != OK:
			push_error("[TASmaniac] ERROR: Failed to accept WebSocket connection: %s" % error_string(error))
	
	socket.poll()
	
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var message := socket.get_packet().get_string_from_ascii()
			receive_message(message)

func _exit_tree():
	socket.close()
	tcp_server.stop()

func receive_message(raw_message: String):
	var message = JSON.parse_string(raw_message)
	if message is not Dictionary:
		send_message({"status": "error", "message": "invalid message"})
		return
	if busy:
		send_message({"status": "error", "message": "server busy"})
		return
	match message["command"]:
		"play_level":
			busy = true
			var response := await command_play_level(message)
			busy = false
			send_message(response)
		_:
			send_message({"status": "error", "message": "unknown command: %s" % message["command"]})

func send_message(message: Dictionary):
	var error := socket.send_text(JSON.stringify(message))
	if error != OK:
		push_error("[TASmaniac] ERROR: Failed to send message: %s" % error_string(error))

func command_play_level(command: Dictionary) -> Dictionary:
	if command["level"] is not float or command["level"] != int(command["level"]):
		return {"status": "error", "message": "missing or invalid parameter 'level'"}
	if command["inputs"] is not Array:
		return {"status": "error", "message": "missing or invalid parameter 'inputs'"}
	if command.get("start_positions") != null and command.get("start_positions") is not Array:
		return {"status": "error", "message": "invalid parameter 'start_positions'"}
	var level: int = command["level"]
	var inputs: PackedStringArray = command["inputs"]
	var start_positions = command["start_positions"]
	for input in inputs:
		if input.lstrip(" ").begins_with("-"):
			return {"status": "error", "message": "invalid input '%s'" % input}
	if start_positions != null:
		if len(start_positions) != 2:
			return {"status": "error", "message": "expected 2 start positions, but got %s" % len(start_positions)}
		for i in 2:
			var position = start_positions[i]
			if position is not Array or len(position) != 2 or !position.all(func(v): return v is float):
				return {"status": "error", "message": "invalid start position %s" % str(position)}
			start_positions[i] = Vector2(position[0], position[1])
	
	var original_delta_multiplier = get_tree()._delta_multiplier
	if headless:
		get_tree()._set_delta_multiplier(0.0)
	
	manager.start_manual_playback(level, inputs, start_positions)
	var completed: bool = await level_finished
	
	if headless:
		get_tree()._set_delta_multiplier(original_delta_multiplier)
	
	return {"status": "executed", "level_completed": completed, "duration_ticks": manager.frame}

func _assert(condition: bool, message: String):
	if !condition:
		push_error("[TASmaniac] ERROR: " + message)
		OS.alert(message, "TASmaniac error")
		OS.crash("Assertion failed, exiting...")
