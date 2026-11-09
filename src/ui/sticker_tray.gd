class_name StickerTray
extends VBoxContainer
## Picker for stickers and stamps, shown above the tool panel while sticker mode is
## on: a row of the 3 sticker sizes (shown only while a sticker, not a stamp, is
## chosen; each shows the chosen sticker drawn small, medium or large, no text) and a
## scrollable strip of big thumbnails, exactly one selected at a time.
## Sends the choice to the canvas with [method DrawingCanvas.set_sticker].
## Implements: design/game-brief.md MVP feature 5; story-006-stickers-stamps.md.
## Buttons use the app theme's ToolButton look (story 007). Built by [ToolPanel]: call [method setup]
## once, then [method apply] each time sticker mode starts.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): ScrollContainer scroll modes and touch drag-to-scroll over
## buttons whose mouse_filter is PASS; Button.icon / icon_alignment / expand_icon;
## ImageTexture.create_from_image.

# Share of a size button the largest size's icon covers (presentation only).
const SIZE_ICON_FILL: float = 0.8

var _canvas: DrawingCanvas
var _library: StickerLibrary
var _item: StickerLibrary.Item
var _size_index: int
var _size_row: HBoxContainer
var _size_buttons: Array[Button] = []
var _size_button_side: float


## Builds the size row and thumbnail strip. [param button_side] is the size buttons'
## side in pt, [param spacing] the gap in pt. Selects the first item and the data's
## default size.
func setup(target: DrawingCanvas, library: StickerLibrary, button_side: float, spacing: int) -> void:
	_canvas = target
	_library = library
	_size_button_side = button_side
	add_theme_constant_override(&"separation", spacing)

	_size_row = HBoxContainer.new()
	_size_row.add_theme_constant_override(&"separation", spacing)
	add_child(_size_row)
	var size_group := ButtonGroup.new()
	_size_index = library.default_size_index
	for i in library.sticker_sizes.size():
		var size_button := Button.new()
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.theme_type_variation = AppTheme.TOOL_BUTTON_TYPE
		size_button.tooltip_text = tr(library.size_labels[i])
		size_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		size_button.custom_minimum_size = Vector2(button_side, button_side)
		size_button.button_pressed = i == _size_index
		size_button.pressed.connect(_select_size.bind(i))
		_size_row.add_child(size_button)
		_size_buttons.append(size_button)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Room below the buttons for the horizontal scroll bar.
	scroll.custom_minimum_size = Vector2(0.0, library.item_button_size + spacing * 3)
	add_child(scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", spacing)
	scroll.add_child(strip)
	var item_group := ButtonGroup.new()
	for item in library.items:
		var item_button := Button.new()
		item_button.toggle_mode = true
		item_button.button_group = item_group
		item_button.icon = ImageTexture.create_from_image(library.get_image(item, library.thumbnail_size))
		item_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_button.custom_minimum_size = Vector2(library.item_button_size, library.item_button_size)
		# Lets a drag that starts on a thumbnail reach the ScrollContainer.
		item_button.mouse_filter = Control.MOUSE_FILTER_PASS
		item_button.theme_type_variation = AppTheme.TOOL_BUTTON_TYPE
		item_button.pressed.connect(_select_item.bind(item))
		strip.add_child(item_button)
		if _item == null:
			_item = item
			item_button.button_pressed = true
	_show_sizes_for(_item)


## Puts the canvas in sticker mode with the selected item: a sticker at the selected
## size placed once per touch, or a stamp at its one size, also repeated along a drag.
func apply() -> void:
	if _item.kind == StickerLibrary.KIND_STAMP:
		_canvas.set_sticker(_library.get_image(_item, _library.stamp_size), _library.stamp_spacing)
	else:
		_canvas.set_sticker(_library.get_image(_item, _library.sticker_sizes[_size_index]), 0.0)


func _select_item(item: StickerLibrary.Item) -> void:
	_item = item
	_show_sizes_for(item)
	apply()


# Shows the size row only for a sticker, each button holding [param item] drawn in
# proportion to its size (the largest fills most of the button).
func _show_sizes_for(item: StickerLibrary.Item) -> void:
	_size_row.visible = item.kind == StickerLibrary.KIND_STICKER
	if not _size_row.visible:
		return
	var largest := float(_library.sticker_sizes.max())
	for i in _size_buttons.size():
		var side := maxi(1, roundi(_size_button_side * SIZE_ICON_FILL * _library.sticker_sizes[i] / largest))
		_size_buttons[i].icon = ImageTexture.create_from_image(_library.get_image(item, side))


func _select_size(index: int) -> void:
	_size_index = index
	apply()
