extends Node

## SaveManager Singleton (Autoload)
## Handles saving and loading game progress using Godot's FileAccess and JSON serialization.
## Decoupled from Player and Level scripts to maintain scalability and clean architecture.

signal game_saved(data: Dictionary)
signal game_loaded(data: Dictionary)
signal save_failed(reason: String)
signal save_deleted

const SAVE_FILE_PATH: String = "user://savegame.json"
const DEFAULT_LEVEL: String = "res://scenes/game.tscn"
const CURRENT_SAVE_VERSION: int = 1

## Default schema template for save data.
## Ensures missing keys from older/corrupted saves are cleanly defaulted.
const DEFAULT_SAVE_DATA: Dictionary = {
	"version": CURRENT_SAVE_VERSION,
	"timestamp": 0,
	"timestamp_readable": "",
	"current_level": DEFAULT_LEVEL,
	"checkpoint_id": "",
	"player_position": null, # Dictionary {"x": float, "y": float} or null
	"score": 0,
	"level_completed": false,
	"extra": {} # Scalable bucket for future stats, coins, inventory, achievements, etc.
}

## Current in-memory save state
var save_data: Dictionary = {}

## Flag indicating we should reposition the player when the scene loads
var pending_respawn_position: Variant = null
var is_continuing: bool = false

func _ready() -> void:
	# Keep SaveManager persistent across scene changes
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to scene tree node additions to seamlessly reposition the player on load/respawn
	get_tree().node_added.connect(_on_node_added)
	
	# Initial memory setup
	if has_save():
		_load_save_data_to_memory()
	else:
		save_data = DEFAULT_SAVE_DATA.duplicate(true)

# ==============================================================================
# PUBLIC API: QUERYING & MANAGEMENT
# ==============================================================================

## Returns true if a valid save file exists on disk
func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	if content.strip_edges().is_empty():
		return false
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		return false
	
	var data = json.data
	if not (data is Dictionary and data.has("current_level")):
		return false
	
	# Save file is considered valid
	return true

## Starts a fresh game: wipes existing save and launches DEFAULT_LEVEL
func start_new_game() -> void:
	delete_save()
	save_data = DEFAULT_SAVE_DATA.duplicate(true)
	save_data["current_level"] = DEFAULT_LEVEL
	pending_respawn_position = null
	is_continuing = false
	
	# Write clean initial state to disk
	save_to_disk()
	
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(DEFAULT_LEVEL)

## Continues from saved game: loads data from disk and switches to the saved level
func continue_game() -> bool:
	if not has_save():
		push_warning("SaveManager: continue_game called but no save exists!")
		return false
	
	if not _load_save_data_to_memory():
		push_error("SaveManager: Failed to load save file during continue_game.")
		return false
	
	var target_level: String = save_data.get("current_level", DEFAULT_LEVEL)
	if target_level.is_empty():
		target_level = DEFAULT_LEVEL
	
	# If a player position or checkpoint position exists, queue it for spawning
	if save_data.get("player_position") != null:
		var pos_dict = save_data["player_position"]
		if pos_dict is Dictionary and pos_dict.has("x") and pos_dict.has("y"):
			pending_respawn_position = Vector2(pos_dict["x"], pos_dict["y"])
	
	is_continuing = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	var error = get_tree().change_scene_to_file(target_level)
	if error != OK:
		push_error("SaveManager: Could not switch to saved scene: %s" % target_level)
		return false
		
	return true

## Permanently removes the save file from disk
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("savegame.json")
	save_data = DEFAULT_SAVE_DATA.duplicate(true)
	pending_respawn_position = null
	save_deleted.emit()

# ==============================================================================
# PUBLIC API: AUTOMATIC SAVING TRIGGERS
# ==============================================================================

## Save trigger: Called when player reaches a checkpoint
func save_at_checkpoint(checkpoint_id: String, world_position: Vector2, extra_info: Dictionary = {}) -> bool:
	var current_scene_path = _get_current_scene_path()
	
	save_data["current_level"] = current_scene_path
	save_data["checkpoint_id"] = checkpoint_id
	save_data["player_position"] = {"x": world_position.x, "y": world_position.y}
	pending_respawn_position = world_position
	
	_merge_extra_data(extra_info)
	return save_to_disk()

## Save trigger: Called when player enters a portal leading to the next level
func save_level_transition(next_level_path: String, extra_info: Dictionary = {}) -> bool:
	# Normalize Godot UID or relative paths to res:// path if possible
	var resolved_path = _resolve_scene_path(next_level_path)
	
	save_data["current_level"] = resolved_path
	# On new level entry, clear previous level's checkpoint ID and spawn position
	save_data["checkpoint_id"] = ""
	save_data["player_position"] = null
	pending_respawn_position = null
	
	_merge_extra_data(extra_info)
	return save_to_disk()

## Save trigger: Called when player completes a level (e.g. Citadel cleared / Win Screen)
func save_level_completed(completed_level_path: String, next_path: String = "", extra_info: Dictionary = {}) -> bool:
	save_data["level_completed"] = true
	if not next_path.is_empty():
		save_data["current_level"] = _resolve_scene_path(next_path)
	else:
		save_data["current_level"] = _resolve_scene_path(completed_level_path)
	
	save_data["checkpoint_id"] = ""
	save_data["player_position"] = null
	pending_respawn_position = null
	
	_merge_extra_data(extra_info)
	return save_to_disk()

# ==============================================================================
# DISK SERIALIZATION & DESERIALIZATION (FILEACCESS + JSON)
# ==============================================================================

## Writes the current in-memory save_data to disk in JSON format
func save_to_disk() -> bool:
	save_data["version"] = CURRENT_SAVE_VERSION
	save_data["timestamp"] = int(Time.get_unix_time_from_system())
	save_data["timestamp_readable"] = Time.get_datetime_string_from_system(false, true)
	
	# Sync score if a GameManager is in the active scene tree
	var active_score = _find_active_score()
	if active_score >= 0:
		save_data["score"] = active_score
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		var err_code = FileAccess.get_open_error()
		var err_msg = "Failed to open save file for writing! Error code: %d" % err_code
		push_error("SaveManager: " + err_msg)
		save_failed.emit(err_msg)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	game_saved.emit(save_data.duplicate(true))
	print("[SaveManager] Successfully saved game state to %s" % SAVE_FILE_PATH)
	return true

## Reads and parses the save file into save_data, merging with defaults
func _load_save_data_to_memory() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		var err_msg = "Could not open save file for reading. Error code: %d" % FileAccess.get_open_error()
		push_error("SaveManager: " + err_msg)
		save_failed.emit(err_msg)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		var err_msg = "JSON parse error: %s (at line %d)" % [json.get_error_message(), json.get_error_line()]
		push_error("SaveManager: " + err_msg)
		save_failed.emit(err_msg)
		return false
	
	var loaded_data = json.data
	if not (loaded_data is Dictionary):
		save_failed.emit("Save data root is not a Dictionary.")
		return false
	
	# Merge loaded data with defaults to ensure robustness against missing fields
	var merged = DEFAULT_SAVE_DATA.duplicate(true)
	for key in loaded_data.keys():
		merged[key] = loaded_data[key]
	
	save_data = merged
	game_loaded.emit(save_data.duplicate(true))
	print("[SaveManager] Successfully loaded game state for level: %s" % save_data.get("current_level"))
	return true

# ==============================================================================
# EXTENSIBILITY & HELPER METHODS
# ==============================================================================

## Sets a custom key in the scalable 'extra' dictionary
func set_extra(key: String, value: Variant, auto_save: bool = false) -> void:
	if not save_data.has("extra") or not (save_data["extra"] is Dictionary):
		save_data["extra"] = {}
	save_data["extra"][key] = value
	if auto_save:
		save_to_disk()

## Retrieves a custom key from the 'extra' dictionary with a default fallback
func get_extra(key: String, default: Variant = null) -> Variant:
	if save_data.has("extra") and save_data["extra"] is Dictionary and save_data["extra"].has(key):
		return save_data["extra"][key]
	return default

## Updates the in-memory score
func set_score(value: int) -> void:
	save_data["score"] = value

## Gets current saved score
func get_score() -> int:
	return int(save_data.get("score", 0))

func _merge_extra_data(extra_dict: Dictionary) -> void:
	if extra_dict.is_empty():
		return
	if not save_data.has("extra") or not (save_data["extra"] is Dictionary):
		save_data["extra"] = {}
	for k in extra_dict.keys():
		if k == "score":
			save_data["score"] = int(extra_dict["score"])
		else:
			save_data["extra"][k] = extra_dict[k]

func _get_current_scene_path() -> String:
	var current = get_tree().current_scene
	if current and not current.scene_file_path.is_empty():
		return current.scene_file_path
	return DEFAULT_LEVEL

func _resolve_scene_path(path: String) -> String:
	if path.begins_with("uid://"):
		var resolved = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
		if not resolved.is_empty():
			return resolved
	return path

func _find_active_score() -> int:
	var current = get_tree().current_scene
	if not current:
		return -1
	var gm = current.get_node_or_null("GameManager")
	if gm and "score" in gm:
		return int(gm.score)
	return -1

# ==============================================================================
# DECOUPLED PLAYER POSITIONING & SCORE RESTORATION
# ==============================================================================

## Called automatically when any node enters the scene tree.
## Positions the player if respawn/load position is pending, without altering player logic.
func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D and (node.name == "Player" or node.is_in_group("player")):
		# Defer positioning so collision shapes and tilemap are fully initialized
		_apply_player_spawn.call_deferred(node)
	elif node.name == "GameManager":
		_apply_game_manager_score.call_deferred(node)

func _apply_player_spawn(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	
	var target_pos: Variant = null
	
	if pending_respawn_position != null and pending_respawn_position is Vector2:
		target_pos = pending_respawn_position
	elif save_data.get("player_position") != null:
		var current_path = _get_current_scene_path()
		var saved_level = str(save_data.get("current_level", ""))
		if current_path == saved_level or _resolve_scene_path(saved_level) == current_path:
			var pos_dict = save_data["player_position"]
			if pos_dict is Dictionary and pos_dict.has("x") and pos_dict.has("y"):
				target_pos = Vector2(pos_dict["x"], pos_dict["y"])
	
	if target_pos != null and target_pos is Vector2:
		player.global_position = target_pos
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		print("[SaveManager] Positioned player at checkpoint: %s" % str(target_pos))
		pending_respawn_position = null
		is_continuing = false

func _apply_game_manager_score(gm: Node) -> void:
	if not is_instance_valid(gm):
		return
	var saved_score = get_score()
	if saved_score > 0 and "score" in gm:
		gm.score = saved_score
		if "score_label" in gm and gm.score_label:
			gm.score_label.text = "You collected " + str(saved_score) + " coins."
		print("[SaveManager] Restored GameManager score to: %d" % saved_score)
