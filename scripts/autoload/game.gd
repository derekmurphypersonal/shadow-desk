extends Node
## Autoload singleton: owns the current GameState and is the only place the UI mutates it.

signal state_changed
signal selection_changed(iso: String)
signal message(text: String)
signal game_ended

const SAVE_DIR := "user://saves"

var map_data: Dictionary = {}
var state: GameState
var events: Array = []
var selected: String = ""


func _ready() -> void:
	map_data = ScenarioLoader.load_map()
	Settings.changed.connect(func():
		if state != null:
			state.auto_minor = bool(Settings.get_value("cabinet_minor")))


func new_game(scenario_id: String, agenda: String, elections: bool, seed_value: int = -1, difficulty: String = "normal") -> void:
	if seed_value < 0:
		seed_value = randi()
	state = ScenarioLoader.new_game(scenario_id, agenda, elections, seed_value, map_data, difficulty)
	state.auto_minor = bool(Settings.get_value("cabinet_minor"))
	events = ScenarioLoader.load_events(scenario_id)
	# Events dated to the opening month fire immediately.
	Events.check(state, events, map_data)
	selected = ""
	state_changed.emit()
	selection_changed.emit("")


func has_game() -> bool:
	return state != null


func select(iso: String) -> void:
	if state == null:
		return
	selected = iso
	selection_changed.emit(iso)


func end_month() -> void:
	if state == null or state.game_over:
		return
	if not state.pending.is_empty():
		message.emit("Answer the open briefing first.")
		return
	Simulation.tick(state, map_data, events)
	if state.game_over:
		delete_save()
	else:
		save_game("slot1", true)
	state_changed.emit()
	if state.game_over:
		game_ended.emit()


func do_action(id: String) -> void:
	if state == null or selected == "":
		return
	var check := Actions.available(state, selected, id)
	if not check["ok"]:
		message.emit(check["reason"])
		return
	var msg := Actions.perform(state, selected, id, map_data)
	message.emit(msg)
	state_changed.emit()
	if state.game_over:
		game_ended.emit()


func stop_op(iso: String, type: String) -> void:
	if state == null:
		return
	message.emit(Actions.stop_op(state, iso, type))
	state_changed.emit()


## End months until something needs the President: a briefing, an election, big news, or max months.
## Returns the first turn skipped so the UI can show one combined digest.
func fast_forward(max_months: int = 6) -> int:
	if state == null or state.game_over or not state.pending.is_empty():
		return -1
	var first := state.turn + 1
	for i in max_months:
		Simulation.tick(state, map_data, events)
		if state.game_over or not state.pending.is_empty():
			break
		if not state.last_election.is_empty() and int(state.last_election.get("turn", -1)) == state.turn:
			break
		var big := false
		for m in state.turn_headlines():
			if GameState.is_big_news(m):
				big = true
		if big:
			break
	if state.game_over:
		delete_save()
	else:
		save_game("slot1", true)
	state_changed.emit()
	if state.game_over:
		game_ended.emit()
	return first


func choose(index: int) -> void:
	if state == null:
		return
	Events.resolve(state, index, map_data)
	state_changed.emit()


func set_budget(line: String, value: float) -> void:
	if state == null:
		return
	state.us["budget"][line] = value
	state_changed.emit()


func delete_save(slot: String = "slot1") -> void:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func save_game(slot: String = "slot1", quiet: bool = false) -> bool:
	if state == null:
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state.to_dict()))
	if not quiet:
		message.emit("Game saved.")
	return true


func has_save(slot: String = "slot1") -> bool:
	return FileAccess.file_exists("%s/%s.json" % [SAVE_DIR, slot])


func load_game(slot: String = "slot1") -> bool:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return false
	state = GameState.from_dict(d, map_data)
	state.auto_minor = bool(Settings.get_value("cabinet_minor"))
	events = ScenarioLoader.load_events(state.scenario["id"])
	selected = ""
	state_changed.emit()
	selection_changed.emit("")
	message.emit("Game loaded.")
	return true
