class_name SaveManager
extends RefCounted
## Saves drawings to and reads them back from the user data folder. Nothing in this
## class (or anywhere in the app) deletes a saved drawing.
## Implements: design/game-brief.md MVP feature 6 and "no action loses a drawing";
## story-005-autosave-gallery.md.
##
## Save format (version 1), one folder per drawing: <drawings_dir>/<id>/
##   <color_file>      PNG, full canvas size, the colour only (no line art). Story 006
##                     bakes stickers into this image, so it needs no extra field.
##   <thumbnail_file>  PNG, thumbnail_width x thumbnail_height, colour with the line
##                     art on top, as displayed. The gallery reads only this file.
##   <meta_file>       JSON: version (int, 1), id (str, = folder name), page_id (str
##                     coloring page id, or null for a blank page), created and
##                     updated (int, Unix time in milliseconds).
## Each file is written to "<name><temp_suffix>" first and renamed over the old file
## only after all three were written, the meta file last, so a crash or a full disk
## mid-save leaves the previous version readable.
##
## Config (res://assets/data/save_config.json, snake_case keys): drawings_dir,
## color_file, thumbnail_file, meta_file, temp_suffix (str); thumbnail_width,
## thumbnail_height (int px); save_failed_message, open_failed_message (str, shown
## to the child); gallery (obj, read by GalleryScreen: columns, spacing, tile_width,
## tile_height in pt, empty_text).
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): DirAccess.open, get_directories, make_dir_recursive_absolute,
## dir_exists_absolute, rename_absolute (assumed to replace an existing target; on
## Unix/mobile this is an atomic rename, on Windows not verified), remove_absolute;
## FileAccess.open, get_open_error, get_file_as_string, flush, get_error;
## Image.save_png_to_buffer, Image.load, Image.resize INTERPOLATE_TRILINEAR;
## Time.get_unix_time_from_system. Confirmed: FileAccess.store_buffer returns bool
## since 4.4 (breaking-changes.md).

## Highest save format version this build reads and writes.
const FORMAT_VERSION: int = 1

## What the meta file says about one saved drawing.
class Record:
	## Folder name; unique.
	var id: String
	## Coloring page id; empty for a blank page.
	var page_id: String
	## Unix time in milliseconds of the first save.
	var created: int
	## Unix time in milliseconds of the latest save.
	var updated: int

## Gallery layout, the raw "gallery" object of the config (schema above).
var gallery: Dictionary
## Message shown when a save fails.
var save_failed_message: String
## Message shown when a saved drawing cannot be read back.
var open_failed_message: String

var _drawings_dir: String
var _color_file: String
var _thumbnail_file: String
var _meta_file: String
var _temp_suffix: String
var _thumbnail_size: Vector2i


## Reads the config at [param config_path].
func _init(config_path: String) -> void:
	var file := FileAccess.open(config_path, FileAccess.READ)
	assert(file != null, "Save config not found: " + config_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	_drawings_dir = str(data["drawings_dir"])
	_color_file = str(data["color_file"])
	_thumbnail_file = str(data["thumbnail_file"])
	_meta_file = str(data["meta_file"])
	_temp_suffix = str(data["temp_suffix"])
	_thumbnail_size = Vector2i(int(data["thumbnail_width"]), int(data["thumbnail_height"]))
	save_failed_message = str(data["save_failed_message"])
	open_failed_message = str(data["open_failed_message"])
	gallery = data["gallery"]


## A record for a drawing that has not been saved yet, with a fresh unused id.
## [param page_id] is the coloring page id, or empty for a blank page. Nothing is
## written until [method save_drawing].
func new_record(page_id: String) -> Record:
	var record := Record.new()
	record.page_id = page_id
	record.created = _now_ms()
	record.updated = record.created
	record.id = "%d_%04d" % [record.created, randi() % 10000]
	while DirAccess.dir_exists_absolute(_drawings_dir.path_join(record.id)):
		record.id = "%d_%04d" % [record.created, randi() % 10000]
	return record


## Writes the drawing of [param record]: [param color] is the colour-only canvas image,
## [param composite] the same with line art on top (used for the thumbnail; it is
## resized in place). Overwrites the drawing's earlier version, if any. On success
## sets record.updated and returns OK; on failure returns the error and the earlier
## version, if any, is still intact.
func save_drawing(record: Record, color: Image, composite: Image) -> Error:
	var folder := _drawings_dir.path_join(record.id)
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		return err

	composite.resize(_thumbnail_size.x, _thumbnail_size.y, Image.INTERPOLATE_TRILINEAR)
	var updated := _now_ms()
	var meta := {
		"version": FORMAT_VERSION,
		"id": record.id,
		"page_id": record.page_id if not record.page_id.is_empty() else null,
		"created": record.created,
		"updated": updated,
	}
	# Meta last: it is what makes a folder count as a saved drawing.
	var files: Array[String] = [folder.path_join(_color_file), folder.path_join(_thumbnail_file), folder.path_join(_meta_file)]
	var contents: Array[PackedByteArray] = [color.save_png_to_buffer(), composite.save_png_to_buffer(), JSON.stringify(meta, "\t").to_utf8_buffer()]

	for i in files.size():
		err = _write_file(files[i] + _temp_suffix, contents[i])
		if err != OK:
			for path in files:
				DirAccess.remove_absolute(path + _temp_suffix)
			return err
	for path in files:
		err = DirAccess.rename_absolute(path + _temp_suffix, path)
		if err != OK:
			return err
	record.updated = updated
	return OK


## Every saved drawing that can be read, newest (latest save) first.
func list_drawings() -> Array[Record]:
	var records: Array[Record] = []
	var dir := DirAccess.open(_drawings_dir)
	if dir == null:
		return records
	for id in dir.get_directories():
		var record := load_record(id)
		if record != null:
			records.append(record)
	records.sort_custom(func(a: Record, b: Record) -> bool:
		return a.updated > b.updated or (a.updated == b.updated and a.id > b.id))
	return records


## The record of drawing [param id], or null when its meta file is missing, unreadable
## or from a newer format version (the files are left untouched).
func load_record(id: String) -> Record:
	var path := _drawings_dir.path_join(id).path_join(_meta_file)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Skipping unreadable drawing: " + path)
		return null
	var meta: Dictionary = data
	var page_id: Variant = meta.get("page_id")
	if int(meta.get("version", 0)) < 1 or int(meta.get("version", 0)) > FORMAT_VERSION \
			or str(meta.get("id", "")) != id \
			or not (meta.get("created") is float or meta.get("created") is int) \
			or not (meta.get("updated") is float or meta.get("updated") is int) \
			or not (page_id == null or page_id is String):
		push_warning("Skipping drawing with an unknown or invalid meta file: " + path)
		return null
	var record := Record.new()
	record.id = id
	record.page_id = "" if page_id == null else str(page_id)
	record.created = int(meta["created"])
	record.updated = int(meta["updated"])
	return record


## The full-size colour image of drawing [param id], or null when it cannot be read.
func load_color_image(id: String) -> Image:
	return _load_png(_drawings_dir.path_join(id).path_join(_color_file))


## The thumbnail of drawing [param id], or null when it cannot be read.
func load_thumbnail(id: String) -> Image:
	return _load_png(_drawings_dir.path_join(id).path_join(_thumbnail_file))


func _load_png(path: String) -> Image:
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		push_warning("Could not read image: " + path)
		return null
	return image


func _write_file(path: String, bytes: PackedByteArray) -> Error:
	if bytes.is_empty():
		return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	if not file.store_buffer(bytes):
		return ERR_FILE_CANT_WRITE
	file.flush()
	var err := file.get_error()
	file.close()
	return OK if err == OK or err == ERR_FILE_EOF else err


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
