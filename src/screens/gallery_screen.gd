class_name GalleryScreen
extends Control
## Grid of thumbnails of every saved drawing, newest first; tapping one asks AppRoot
## to reopen it. There is deliberately no delete action.
## Implements: design/game-brief.md MVP feature 6; story-005-autosave-gallery.md.
## Layout comes from the "gallery" object of the save config (see
## src/save/save_manager.gd); tile look from the app theme (story 007), Home is the
## top-left IconButton shared by every screen. Only thumbnails are loaded, never full drawings.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/): Button.expand_icon,
## GridContainer h_separation/v_separation theme constants, ScrollContainer touch drag
## scrolling over buttons.

## Emitted when the child taps a drawing.
signal drawing_chosen(drawing_id: String)
## Emitted when the child taps Home.
signal home_chosen

const MIN_TOUCH_SIZE: int = 64

var _saves: SaveManager

@onready var _grid: GridContainer = $Scroll/Center/Grid
@onready var _empty_label: Label = $EmptyLabel


## Gives the screen the save manager to list and read drawings from. Call before add_child().
func setup(saves: SaveManager) -> void:
	_saves = saves


func _ready() -> void:
	assert(_saves != null, "GalleryScreen.setup must be called before add_child")
	var layout := _saves.gallery
	var tile_size := Vector2(int(layout["tile_width"]), int(layout["tile_height"]))
	assert(tile_size.x >= MIN_TOUCH_SIZE and tile_size.y >= MIN_TOUCH_SIZE, "gallery tiles must be >= 64 pt")
	var spacing := int(layout["spacing"])
	_grid.columns = int(layout["columns"])
	_grid.add_theme_constant_override(&"h_separation", spacing)
	_grid.add_theme_constant_override(&"v_separation", spacing)

	var records := _saves.list_drawings()
	_empty_label.text = tr(str(layout["empty_text"]))
	_empty_label.visible = records.is_empty()
	for record in records:
		var button := Button.new()
		# A drawing with an unreadable thumbnail still gets a (blank) tile so it can be opened.
		var thumbnail := _saves.load_thumbnail(record.id)
		if thumbnail != null:
			button.icon = ImageTexture.create_from_image(thumbnail)
		button.expand_icon = true
		button.custom_minimum_size = tile_size
		button.pressed.connect(drawing_chosen.emit.bind(record.id))
		_grid.add_child(button)


func _on_home_button_pressed() -> void:
	home_chosen.emit()
