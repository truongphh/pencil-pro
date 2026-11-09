class_name ColoringLibraryScreen
extends Control
## Grid of big coloring-page thumbnails; tapping one asks AppRoot to open it.
## Implements: design/game-brief.md MVP feature 3; story-004-coloring-pages.md
## (AC "the child picks a page from a library of >= 10").
## Pages and layout come from [member pages_path] (schema in
## src/coloring/coloring_library.gd); the card look comes from the app theme
## (story 007). Home is the top-left IconButton shared by every screen. In a debug build with validate_on_load set,
## every page's closed regions are checked here and problems go to push_error.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): Button.expand_icon, icon_alignment, vertical_icon_alignment,
## GridContainer h_separation/v_separation theme constants, ScrollContainer touch
## drag scrolling over buttons, Image.resize INTERPOLATE_TRILINEAR as an area filter.

## Emitted when the child taps a page: [param page_id] is its id in the data file
## (saved with the drawing, story 005), [param line_art] its texture.
signal page_chosen(page_id: String, line_art: Texture2D)
## Emitted when the child taps Home.
signal home_chosen

const MIN_TOUCH_SIZE: int = 64

## Path of the coloring pages data file.
@export var pages_path: String = "res://assets/data/coloring_pages.json"
## Drawing config, for the region settings the validation shares with the canvas.
@export var drawing_config_path: String = "res://assets/data/drawing_config.json"

@onready var _grid: GridContainer = $Scroll/Center/Grid


func _ready() -> void:
	var library := ColoringLibrary.new(pages_path)
	if library.validate_on_load and OS.is_debug_build():
		for problem in library.validate(drawing_config_path):
			push_error("Coloring page check: " + problem)

	var screen := library.screen
	var thumbnail_size := Vector2i(int(screen["thumbnail_width"]), int(screen["thumbnail_height"]))
	assert(thumbnail_size.x >= MIN_TOUCH_SIZE and thumbnail_size.y >= MIN_TOUCH_SIZE, "thumbnails must be >= 64 pt")
	var spacing := int(screen["spacing"])
	_grid.columns = int(screen["columns"])
	_grid.add_theme_constant_override(&"h_separation", spacing)
	_grid.add_theme_constant_override(&"v_separation", spacing)

	var button_size := Vector2(thumbnail_size.x, thumbnail_size.y + int(screen["label_height"]))

	for page in library.pages:
		var button := Button.new()
		button.text = tr(page.title)
		button.icon = _make_thumbnail(load(page.line_art_path) as Texture2D, thumbnail_size)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = button_size
		button.pressed.connect(_on_page_pressed.bind(page.id, page.line_art_path))
		_grid.add_child(button)


# Small copy of the line art, area-filtered so thick outlines stay solid when
# shrunk; the full-size texture is not kept by the library.
func _make_thumbnail(line_art: Texture2D, thumbnail_size: Vector2i) -> ImageTexture:
	var image := line_art.get_image()
	if image.is_compressed():
		image.decompress()
	image.resize(thumbnail_size.x, thumbnail_size.y, Image.INTERPOLATE_TRILINEAR)
	image.clear_mipmaps()
	return ImageTexture.create_from_image(image)


func _on_page_pressed(page_id: String, line_art_path: String) -> void:
	page_chosen.emit(page_id, load(line_art_path) as Texture2D)


func _on_home_button_pressed() -> void:
	home_chosen.emit()
