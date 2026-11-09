class_name StickerLibrary
extends RefCounted
## The stickers and stamps the child can place, read from a JSON data file, and
## their pixels at a given size, rasterised from the SVG art once and cached.
## Implements: design/game-brief.md MVP feature 5; story-006-stickers-stamps.md.
##
## Data file schema (res://assets/data/stickers.json, snake_case keys):
##   art_dir             str    folder the item files are relative to
##   sticker_sizes       [obj]  exactly 3 {label: str (translation key or text),
##                              size: int (canvas px of the sticker's longest side)}
##   default_size_index  int    index into sticker_sizes selected on first open
##   stamp_size          int    canvas px of a stamp's longest side (stamps have one size)
##   stamp_spacing       float  canvas px between stamps placed along one drag (> 0)
##   thumbnail_size      int    px of the longest side of a tray thumbnail
##   item_button_size    int    side of a tray item button, in pt (must be >= 64)
##   cache_limit         int    rasterised images kept; the cache is emptied when full
##                              (keep above the item count so thumbnails fit)
##   items               [obj]  {id: str (unique), file: str (SVG path under art_dir),
##                              kind: "sticker" | "stamp"}; at least 15 stickers and
##                              5 stamps. Art is drawn larger than the largest size so
##                              it is only ever scaled down.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): an imported SVG loads as a Texture2D whose get_image returns a
## new, modifiable Image; Image.generate_mipmaps on a non-power-of-two image;
## Image.resize with INTERPOLATE_TRILINEAR uses the mipmaps when shrinking.

const KIND_STICKER: String = "sticker"
const KIND_STAMP: String = "stamp"
const SIZE_COUNT: int = 3
const MIN_STICKERS: int = 15
const MIN_STAMPS: int = 5
const MIN_TOUCH_SIZE: int = 64

## One sticker or stamp from the data file.
class Item:
	## Unique id from the data file.
	var id: String
	## [constant KIND_STICKER] or [constant KIND_STAMP].
	var kind: String
	## res:// path of the SVG art.
	var path: String

## Every item, stickers and stamps, in data-file order.
var items: Array[Item] = []
## Canvas px of the longest side of a sticker, one per selectable size.
var sticker_sizes: Array[int] = []
## Label (translation key or text) of each entry in [member sticker_sizes].
var size_labels: Array[String] = []
## Index into [member sticker_sizes] selected on first open.
var default_size_index: int
## Canvas px of the longest side of a stamp.
var stamp_size: int
## Canvas px between stamps placed along one drag.
var stamp_spacing: float
## Px of the longest side of a tray thumbnail.
var thumbnail_size: int
## Side of a tray item button, in pt.
var item_button_size: int

var _cache_limit: int
# Keyed by "<id>_<size px>"; cleared when it reaches _cache_limit.
var _cache: Dictionary[String, Image] = {}


## Reads and checks the data file at [param data_path].
func _init(data_path: String) -> void:
	var file := FileAccess.open(data_path, FileAccess.READ)
	assert(file != null, "Sticker data not found: " + data_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var art_dir := str(data["art_dir"])
	var sizes: Array = data["sticker_sizes"]
	assert(sizes.size() == SIZE_COUNT, "sticker_sizes needs exactly 3 entries")
	for size_variant: Variant in sizes:
		var size_entry: Dictionary = size_variant
		sticker_sizes.append(int(size_entry["size"]))
		size_labels.append(str(size_entry["label"]))
	default_size_index = int(data["default_size_index"])
	assert(default_size_index >= 0 and default_size_index < SIZE_COUNT, "default_size_index out of range")
	stamp_size = int(data["stamp_size"])
	stamp_spacing = float(data["stamp_spacing"])
	assert(stamp_spacing > 0.0, "stamp_spacing must be > 0")
	thumbnail_size = int(data["thumbnail_size"])
	item_button_size = int(data["item_button_size"])
	assert(item_button_size >= MIN_TOUCH_SIZE, "item_button_size must be >= 64 pt")
	_cache_limit = int(data["cache_limit"])

	var sticker_count := 0
	var stamp_count := 0
	var ids: Dictionary[String, bool] = {}
	for entry_variant: Variant in data["items"]:
		var entry: Dictionary = entry_variant
		var item := Item.new()
		item.id = str(entry["id"])
		item.kind = str(entry["kind"])
		item.path = art_dir.path_join(str(entry["file"]))
		assert(not ids.has(item.id), "Duplicate sticker id: " + item.id)
		assert(item.kind == KIND_STICKER or item.kind == KIND_STAMP, "Unknown sticker kind: " + item.kind)
		assert(ResourceLoader.exists(item.path), "Sticker file not found: " + item.path)
		ids[item.id] = true
		if item.kind == KIND_STICKER:
			sticker_count += 1
		else:
			stamp_count += 1
		items.append(item)
	assert(sticker_count >= MIN_STICKERS, "Need at least 15 stickers")
	assert(stamp_count >= MIN_STAMPS, "Need at least 5 stamps")


## Returns [param item] as an RGBA8 image whose longest side is [param size_px],
## keeping its aspect ratio. The image is shared through the cache: read it, never
## modify it.
func get_image(item: Item, size_px: int) -> Image:
	var key := "%s_%d" % [item.id, size_px]
	if not _cache.has(key):
		if _cache.size() >= _cache_limit:
			_cache.clear()
		_cache[key] = _rasterise(item.path, size_px)
	return _cache[key]


func _rasterise(path: String, size_px: int) -> Image:
	var texture := load(path) as Texture2D
	assert(texture != null, "Sticker art is not a texture: " + path)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var fit_scale := float(size_px) / maxi(image.get_width(), image.get_height())
	image.generate_mipmaps()
	image.resize(maxi(1, roundi(image.get_width() * fit_scale)), maxi(1, roundi(image.get_height() * fit_scale)),
			Image.INTERPOLATE_TRILINEAR)
	image.clear_mipmaps()
	return image
