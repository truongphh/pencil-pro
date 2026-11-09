class_name DrawingPage
extends Control
## One drawing page: the shared drawing scene (canvas, undo, eraser, palette, pens)
## plus a Home button (top-left, the same corner and size as on every screen) and a
## Mute button (top-right). The Undo/Eraser toolbar sits right of Home, two theme
## spacings away so a tap meant for Undo does not land on Home. Blank and coloring
## pages are this same scene and differ only in the line art passed to [method setup].
## Implements: design/game-brief.md MVP features 3, 4 and 6; story-003-blank-page.md,
## story-004-coloring-pages.md, story-005-autosave-gallery.md, story-007-kid-friendly-ui.md.

## Emitted when the child taps Home. The page does not free itself; the listener
## saves it (see [method get_color_image]) and frees it.
signal drawing_closed

var _sounds: UiSounds

@onready var _canvas: DrawingCanvas = $Drawing/Canvas
@onready var _home_button: IconButton = $HomeButton


func _ready() -> void:
	var toolbar := $Drawing/Toolbar as Control
	var spacing := get_theme_constant(&"separation", &"HBoxContainer")
	var nav_size := get_theme_constant(&"nav_button_size", AppTheme.METRICS_TYPE)
	toolbar.position = Vector2(_home_button.offset_left + nav_size + spacing * 2, _home_button.offset_top)
	if _sounds != null:
		($Drawing/ToolPanel as ToolPanel).color_picked.connect(_sounds.play_color_pick)
		($MuteButton as MuteButton).setup(_sounds)


## Gives the page the UI sounds: colour taps play the colour-pick sound and the Mute
## button controls them. Call after instantiate() and before add_child().
func set_sounds(sounds: UiSounds) -> void:
	_sounds = sounds


## Sets the page's line art: null is a blank white page, a texture is a coloring
## page drawn above the colour layer. [param color_image] is a saved colour image to
## continue (null starts white). Call after instantiate() and before add_child().
func setup(line_art: Texture2D, color_image: Image = null) -> void:
	var canvas := get_node(^"Drawing/Canvas") as DrawingCanvas
	canvas.line_art_texture = line_art
	if color_image != null:
		canvas.load_color_image(color_image)


## Copy of the colour image only (no line art) at full canvas resolution.
func get_color_image() -> Image:
	return _canvas.get_color_image()


## Copy of the drawing as displayed (line art on top) at full canvas resolution.
func get_image() -> Image:
	return _canvas.get_image()


## Changes whenever the drawing changes; see [method DrawingCanvas.get_revision].
func get_revision() -> int:
	return _canvas.get_revision()


func _on_home_button_pressed() -> void:
	drawing_closed.emit()
