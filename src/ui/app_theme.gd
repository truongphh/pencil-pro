class_name AppTheme
extends RefCounted
## Builds the one Theme the whole app uses from the UI style data file, so every
## screen shares the same rounded pastel look and the sizes and colours are data,
## not scene values. AppRoot sets it on itself; every screen inherits it.
## Implements: design/game-brief.md art direction ("modern, rounded, bright pastel,
## big touch targets"); story-007-kid-friendly-ui.md. Replaces the planned
## src/ui/app_theme.tres: a .tres could not read its values from data.
##
## Besides styling the standard Control types (Button, Label, PanelContainer,
## AcceptDialog, box/grid/flow container spacing), the theme carries:
##   type variation [constant TOOL_BUTTON_TYPE] (base Button): tool look, thin outline
##       when idle and a thick dark outline for the pressed (= selected) states
##   one type variation per key of home_card.colors (base Button): home entry cards
##   type [constant METRICS_TYPE]: constants nav_button_size, home_card_width,
##       home_card_height, home_card_spacing, dialog_width; color background
##   type [constant ICONS_TYPE]: one icon per key of "icons"
##
## Data file schema (res://assets/data/ui_theme.json, snake_case keys; colours "#RRGGBB",
## sizes in pt; the project is meant to run with stretch mode canvas_items at a
## 1024x768 base size, where 1 unit is about 1 pt on iPad):
##   background_color   str   app background
##   text_color         str   all text, and the selected outline's default
##   font_size          int   default font size
##   corner_radius      int   button and panel corner radius
##   spacing            int   default gap in box, grid and flow containers
##   nav_button_size    int   side of every icon button (Home, Undo, Eraser, Mute); >= 64
##   dialog_width       int   width of the message dialog
##   button             obj   {fill_color, pressed_fill_color, disabled_fill_color,
##                             border_color, border_width, content_margin}
##   tool_button        obj   {fill_color, border_color, border_width,
##                             selected_border_color, selected_border_width,
##                             corner_radius, content_margin}
##   focus              obj   {color, width} keyboard/gamepad focus ring
##   panel              obj   {fill_color, border_color, border_width, content_margin}
##   home_card          obj   {width, height (both >= 64), spacing, font_size,
##                             corner_radius, pressed_border_width,
##                             colors: {variation name: fill colour}}
##   icons              obj   {icon name: res:// path of a Texture2D}
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): Theme.set_type_variation / set_stylebox / set_constant /
## set_icon / default_font_size, theme item names (Button normal, hover, pressed,
## hover_pressed, disabled, focus, font_*_color, h_separation; AcceptDialog panel;
## BoxContainer separation; GridContainer and FlowContainer h_/v_separation),
## StyleBoxFlat set_content_margin_all / set_expand_margin_all.

const MIN_TOUCH_SIZE: int = 64
## Theme type holding the app's size constants and background colour.
const METRICS_TYPE: StringName = &"AppMetrics"
## Theme type holding the app's icons, by the names used in the data file.
const ICONS_TYPE: StringName = &"AppIcons"
## Type variation for selectable tool buttons (pens, fill, stickers, eraser, swatches).
const TOOL_BUTTON_TYPE: StringName = &"ToolButton"

const _BUTTON_FONT_COLORS: Array[StringName] = [&"font_color", &"font_hover_color",
		&"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]


## Reads the data file at [param data_path] and returns the app theme. A missing data
## file or a touch size under 64 pt fails the assert; a missing icon file is reported
## with push_error and left out (the engine's fallback icon shows instead).
static func build(data_path: String) -> Theme:
	var file := FileAccess.open(data_path, FileAccess.READ)
	assert(file != null, "UI theme data not found: " + data_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())

	var theme := Theme.new()
	var text_color := Color.html(str(data["text_color"]))
	var radius := int(data["corner_radius"])
	var spacing := int(data["spacing"])
	var focus_data: Dictionary = data["focus"]
	var focus_width := int(focus_data["width"])
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color.html(str(focus_data["color"]))
	focus.set_border_width_all(focus_width)
	focus.set_corner_radius_all(radius)
	focus.set_expand_margin_all(focus_width)
	theme.default_font_size = int(data["font_size"])
	theme.set_color(&"font_color", &"Label", text_color)

	var button: Dictionary = data["button"]
	var border := Color.html(str(button["border_color"]))
	var border_width := int(button["border_width"])
	var margin := int(button["content_margin"])
	var idle := _make_box(Color.html(str(button["fill_color"])), border, border_width, radius, margin)
	var pressed := _make_box(Color.html(str(button["pressed_fill_color"])), border, border_width, radius, margin)
	var disabled := _make_box(Color.html(str(button["disabled_fill_color"])), border, border_width, radius, margin)
	_set_button_looks(theme, &"Button", idle, pressed, disabled, focus)
	for color_name in _BUTTON_FONT_COLORS:
		theme.set_color(color_name, &"Button", text_color)
	theme.set_color(&"font_disabled_color", &"Button", Color(text_color, 0.4))
	theme.set_constant(&"h_separation", &"Button", spacing / 2)

	var tool: Dictionary = data["tool_button"]
	var tool_fill := Color.html(str(tool["fill_color"]))
	var tool_radius := int(tool["corner_radius"])
	var tool_margin := int(tool["content_margin"])
	var tool_idle := _make_box(tool_fill, Color.html(str(tool["border_color"])), int(tool["border_width"]), tool_radius, tool_margin)
	var tool_selected := _make_box(tool_fill, Color.html(str(tool["selected_border_color"])),
			int(tool["selected_border_width"]), tool_radius, tool_margin)
	theme.set_type_variation(TOOL_BUTTON_TYPE, &"Button")
	_set_button_looks(theme, TOOL_BUTTON_TYPE, tool_idle, tool_selected, tool_idle, focus)

	var card: Dictionary = data["home_card"]
	var card_size := Vector2i(int(card["width"]), int(card["height"]))
	assert(card_size.x >= MIN_TOUCH_SIZE and card_size.y >= MIN_TOUCH_SIZE, "home cards must be >= 64 pt")
	var card_radius := int(card["corner_radius"])
	var card_colors: Dictionary = card["colors"]
	for variation: String in card_colors:
		var card_fill := Color.html(str(card_colors[variation]))
		var card_idle := _make_box(card_fill, border, border_width, card_radius, margin)
		var card_pressed := _make_box(card_fill, text_color, int(card["pressed_border_width"]), card_radius, margin)
		theme.set_type_variation(variation, &"Button")
		_set_button_looks(theme, variation, card_idle, card_pressed, card_idle, focus)
		theme.set_font_size(&"font_size", variation, int(card["font_size"]))

	var panel: Dictionary = data["panel"]
	var panel_box := _make_box(Color.html(str(panel["fill_color"])), Color.html(str(panel["border_color"])),
			int(panel["border_width"]), radius, int(panel["content_margin"]))
	theme.set_stylebox(&"panel", &"PanelContainer", panel_box)
	theme.set_stylebox(&"panel", &"AcceptDialog", panel_box)

	for box_type: StringName in [&"BoxContainer", &"HBoxContainer", &"VBoxContainer"]:
		theme.set_constant(&"separation", box_type, spacing)
	for grid_type: StringName in [&"GridContainer", &"FlowContainer", &"HFlowContainer", &"VFlowContainer"]:
		theme.set_constant(&"h_separation", grid_type, spacing)
		theme.set_constant(&"v_separation", grid_type, spacing)

	var nav_size := int(data["nav_button_size"])
	assert(nav_size >= MIN_TOUCH_SIZE, "nav_button_size must be >= 64 pt")
	theme.set_constant(&"nav_button_size", METRICS_TYPE, nav_size)
	theme.set_constant(&"home_card_width", METRICS_TYPE, card_size.x)
	theme.set_constant(&"home_card_height", METRICS_TYPE, card_size.y)
	theme.set_constant(&"home_card_spacing", METRICS_TYPE, int(card["spacing"]))
	theme.set_constant(&"dialog_width", METRICS_TYPE, int(data["dialog_width"]))
	theme.set_color(&"background", METRICS_TYPE, Color.html(str(data["background_color"])))

	var icons: Dictionary = data["icons"]
	for icon_name: String in icons:
		var path := str(icons[icon_name])
		var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture == null:
			push_error("UI icon '%s' not found: %s" % [icon_name, path])
			continue
		theme.set_icon(icon_name, ICONS_TYPE, texture)
	return theme


# Idle look for normal/hover/disabled, [param pressed] for the pressed states (the
# selected state of toggle buttons); touch has no hover, so hover never differs.
static func _set_button_looks(theme: Theme, type: StringName, idle: StyleBox, pressed: StyleBox,
		disabled: StyleBox, focus: StyleBox) -> void:
	theme.set_stylebox(&"normal", type, idle)
	theme.set_stylebox(&"hover", type, idle)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, pressed)
	theme.set_stylebox(&"disabled", type, disabled)
	theme.set_stylebox(&"focus", type, focus)


static func _make_box(fill: Color, border: Color, border_width: int, corner_radius: int, content_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style
