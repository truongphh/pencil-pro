class_name ToolPanel
extends PanelContainer
## Colour palette and pen selector, built from Control nodes at load.
## Implements: design/game-brief.md MVP feature 2; story-002-palette-and-pens.md.
## Applies the choice to [member canvas] through DrawingCanvas.set_brush_color /
## set_pen; the canvas only uses it for the NEXT stroke.
##
## Data file schema (res://assets/data/drawing_tools.json, snake_case keys):
##   swatch_size            int    side of colour and tool buttons, in pt (must be >= 64)
##   spacing                int    gap between buttons, in pt
##   tool_columns           int    tool buttons per row (pens, fill, stickers) left of the colours
##   default_color_index    int    index into palette selected on first open
##   default_pen            str    id of the pen selected on first open
##   palette                [str]  "#RRGGBB" colours, at least 12
##   pens                   [obj]  {id: str, label: str (translation key or text, shown
##                                  as tooltip), icon: str (key in ui_theme.json "icons"),
##                                  radius: float (canvas px), hardness: float 0..1
##                                  (1 crisp, lower softer), pressure_scale: float 0..1
##                                  (0 ignores stylus pressure)}
##   fill_tool              obj    {label: str, icon: str} one-tap region
##                                  fill (story 004). Shown after the pens, in the same
##                                  exclusive group, on coloring pages only; hidden on
##                                  blank pages, which have no regions.
##   sticker_tool           obj    {label: str, icon: str} sticker mode
##                                  (story 006). Last button of the same exclusive group;
##                                  while selected, the sticker tray (src/ui/sticker_tray.gd,
##                                  items from [member stickers_path]) shows above the
##                                  tools. Choosing a pen, the fill, a colour or the eraser
##                                  ends sticker mode; a colour or the eraser re-selects the
##                                  pen or fill used before it.
## Looks come from the app theme (story 007, src/ui/app_theme.gd): tool buttons use the
## ToolButton variation, colour swatches a copy of it filled with their colour, so the
## selected colour, pen and tool all show the same thick dark outline.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): ButtonGroup, StyleBoxFlat, HFlowContainer, GridContainer,
## Button theme style names (normal, hover, pressed, hover_pressed, disabled),
## Button.expand_icon, tooltip_text, Control.get_theme_stylebox with a type variation
## name. Story 007 assumes setting button_pressed from code does not emit pressed.
## Story 006 also assumes: setting button_pressed = true from code on a grouped button
## unpresses the others and emits their toggled(false); setting it on the eraser
## toggle emits toggled (so the scene's connection to DrawingCanvas.set_erasing runs).

## Emitted when the child taps a colour (not for the default colour chosen at load).
signal color_picked

## Canvas that receives the current colour and pen.
@export var canvas: DrawingCanvas
## Path of the JSON tools data.
@export var tools_path: String = "res://assets/data/drawing_tools.json"
## Path of the JSON sticker and stamp data (see src/stickers/sticker_library.gd).
@export var stickers_path: String = "res://assets/data/stickers.json"
## Optional eraser toggle: turning it on ends sticker mode, entering sticker mode turns it off.
@export var eraser_button: Button

const MIN_TOUCH_SIZE: float = 64.0
const MIN_COLORS: int = 12

var _sticker_button: Button
var _tray: StickerTray
# Pen or fill button selected before sticker mode; re-selected when a colour or the eraser ends it.
var _last_tool_button: Button


func _ready() -> void:
	var file := FileAccess.open(tools_path, FileAccess.READ)
	assert(file != null, "Drawing tools data not found: " + tools_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var palette: Array = data["palette"]
	var pens: Array = data["pens"]
	var swatch_size := float(data["swatch_size"])
	var color_index := int(data["default_color_index"])
	assert(swatch_size >= MIN_TOUCH_SIZE, "swatch_size must be >= 64 pt")
	assert(palette.size() >= MIN_COLORS, "palette needs at least 12 colours")
	assert(color_index >= 0 and color_index < palette.size(), "default_color_index out of range")

	var spacing := int(data["spacing"])
	var tool_size := Vector2(swatch_size, swatch_size)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", spacing)
	add_child(column)

	_tray = StickerTray.new()
	_tray.visible = false
	column.add_child(_tray)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", spacing * 2)
	column.add_child(row)

	var tool_grid := GridContainer.new()
	tool_grid.columns = int(data["tool_columns"])
	tool_grid.add_theme_constant_override(&"h_separation", spacing)
	tool_grid.add_theme_constant_override(&"v_separation", spacing)
	row.add_child(tool_grid)

	var color_flow := HFlowContainer.new()
	color_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_flow.add_theme_constant_override(&"h_separation", spacing)
	color_flow.add_theme_constant_override(&"v_separation", spacing)
	row.add_child(color_flow)

	var pen_group := ButtonGroup.new()
	var default_pen_found := false
	for pen_variant: Variant in pens:
		var pen: Dictionary = pen_variant
		var button := _make_tool_button(pen, tool_size, pen_group)
		button.pressed.connect(_select_pen.bind(pen))
		button.pressed.connect(_remember_tool.bind(button))
		tool_grid.add_child(button)
		if str(pen["id"]) == str(data["default_pen"]):
			default_pen_found = true
			button.button_pressed = true
			_select_pen(pen)
			_last_tool_button = button
	assert(default_pen_found, "default_pen is not in pens")

	if canvas.has_line_art():
		var fill_button := _make_tool_button(data["fill_tool"], tool_size, pen_group)
		fill_button.pressed.connect(canvas.set_filling.bind(true))
		fill_button.pressed.connect(_remember_tool.bind(fill_button))
		tool_grid.add_child(fill_button)

	_sticker_button = _make_tool_button(data["sticker_tool"], tool_size, pen_group)
	_sticker_button.toggled.connect(_on_sticker_toggled)
	tool_grid.add_child(_sticker_button)
	_tray.setup(canvas, StickerLibrary.new(stickers_path), swatch_size, spacing)
	if eraser_button != null:
		eraser_button.toggled.connect(_on_eraser_toggled)

	var swatch_idle := get_theme_stylebox(&"normal", AppTheme.TOOL_BUTTON_TYPE) as StyleBoxFlat
	var swatch_selected := get_theme_stylebox(&"pressed", AppTheme.TOOL_BUTTON_TYPE) as StyleBoxFlat
	assert(swatch_idle != null and swatch_selected != null, "app theme needs StyleBoxFlat ToolButton styles")
	var color_group := ButtonGroup.new()
	for i in palette.size():
		var color := Color.html(str(palette[i]))
		var idle := swatch_idle.duplicate() as StyleBoxFlat
		idle.bg_color = color
		var selected := swatch_selected.duplicate() as StyleBoxFlat
		selected.bg_color = color
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = color_group
		button.theme_type_variation = AppTheme.TOOL_BUTTON_TYPE
		button.custom_minimum_size = tool_size
		for style_name: StringName in [&"normal", &"hover", &"disabled"]:
			button.add_theme_stylebox_override(style_name, idle)
		for style_name: StringName in [&"pressed", &"hover_pressed"]:
			button.add_theme_stylebox_override(style_name, selected)
		button.pressed.connect(_select_color.bind(color))
		button.pressed.connect(color_picked.emit)
		color_flow.add_child(button)
		if i == color_index:
			button.button_pressed = true
			_select_color(color)


# Square, icon-only, selectable tool button in [param group]; [param tool] is a pen,
# fill_tool or sticker_tool entry of the data file.
func _make_tool_button(tool: Dictionary, tool_size: Vector2, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = AppTheme.TOOL_BUTTON_TYPE
	button.icon = get_theme_icon(StringName(str(tool["icon"])), AppTheme.ICONS_TYPE)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tr(str(tool["label"]))
	button.custom_minimum_size = tool_size
	return button


func _select_color(color: Color) -> void:
	canvas.set_brush_color(color)
	_leave_sticker_mode()


func _remember_tool(button: Button) -> void:
	_last_tool_button = button


# Selecting the sticker button shows the tray and starts sticker mode; any other
# button of the group unselects it, which hides the tray and ends sticker mode.
func _on_sticker_toggled(on: bool) -> void:
	_tray.visible = on
	if on:
		if eraser_button != null:
			eraser_button.button_pressed = false
		_tray.apply()
	else:
		canvas.set_sticker(null)


func _on_eraser_toggled(on: bool) -> void:
	if on:
		_leave_sticker_mode()


# Re-selects the pen or fill used before sticker mode; the canvas still holds its settings.
func _leave_sticker_mode() -> void:
	if _sticker_button != null and _sticker_button.button_pressed:
		_last_tool_button.button_pressed = true


func _select_pen(pen: Dictionary) -> void:
	canvas.set_filling(false)
	canvas.set_pen(float(pen["radius"]), float(pen["hardness"]), float(pen["pressure_scale"]))

