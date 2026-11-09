class_name UiSounds
extends Node
## The app's gentle UI sounds (colour pick, picture saved) and the mute setting.
## Owned by AppRoot and handed to the screens that need it; not an autoload.
## Implements: design/game-brief.md audio direction; story-007-kid-friendly-ui.md
## (AC "gentle sound on colour pick and on save", "mute button").
##
## A sound file that does not exist yet is skipped silently, so the app runs before
## the audio is added (see assets/audio/README.md). Mute is written to the settings
## file so it survives restarts; while muted nothing plays.
##
## Data file schema (res://assets/data/ui_sounds.json, snake_case keys):
##   color_pick     str    res:// path of the colour-pick sound (may not exist yet)
##   saved          str    res:// path of the picture-saved sound (may not exist yet)
##   volume_db      float  playback volume of both sounds
##   settings_path  str    user:// JSON file holding {"muted": bool}
##
## UNCONFIRMED ON GODOT 4.7.2: ResourceLoader.exists for imported audio, AudioStreamPlayer
## defaults (bus "Master"). FileAccess.store_string returning bool is confirmed (4.4,
## docs/engine-reference/godot/breaking-changes.md).

## Emitted when mute is turned on or off.
signal muted_changed(muted: bool)

## Path of the JSON data file. Set before add_child().
@export var data_path: String = "res://assets/data/ui_sounds.json"

var _muted: bool = false
var _settings_path: String
var _color_pick_player: AudioStreamPlayer
var _saved_player: AudioStreamPlayer


func _ready() -> void:
	var file := FileAccess.open(data_path, FileAccess.READ)
	assert(file != null, "UI sounds data not found: " + data_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var volume := float(data["volume_db"])
	_color_pick_player = _make_player(str(data["color_pick"]), volume)
	_saved_player = _make_player(str(data["saved"]), volume)
	_settings_path = str(data["settings_path"])
	_muted = _read_muted()


## Plays the colour-pick sound unless muted or the file is missing.
func play_color_pick() -> void:
	_play(_color_pick_player)


## Plays the picture-saved sound unless muted or the file is missing.
func play_saved() -> void:
	_play(_saved_player)


## Whether the UI sounds are muted.
func is_muted() -> bool:
	return _muted


## Mutes or unmutes, stops anything playing when muting, saves the setting and emits
## [signal muted_changed]. Does nothing if [param muted] is the current state.
func set_muted(muted: bool) -> void:
	if muted == _muted:
		return
	_muted = muted
	if muted:
		_color_pick_player.stop()
		_saved_player.stop()
	var file := FileAccess.open(_settings_path, FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify({"muted": muted})):
		push_warning("Could not save the mute setting to " + _settings_path)
	muted_changed.emit(muted)


func _play(player: AudioStreamPlayer) -> void:
	if not _muted and player.stream != null:
		player.play()


func _make_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	if ResourceLoader.exists(path):
		player.stream = load(path) as AudioStream
	add_child(player)
	return player


# Settings file is user data: a missing or unreadable file means "not muted".
func _read_muted() -> bool:
	if not FileAccess.file_exists(_settings_path):
		return false
	var file := FileAccess.open(_settings_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if parsed is Dictionary and (parsed as Dictionary).get("muted") is bool:
		return (parsed as Dictionary)["muted"]
	push_warning("Settings file unreadable, using defaults: " + _settings_path)
	return false
