class_name IconButton
extends Button
## Square, icon-only button: side = the theme's nav_button_size (>= 64 pt), icon =
## the theme icon [member icon_name]. Home, Undo, Eraser and Mute all use it, so
## they have the same size on every screen.
## Implements: story-007-kid-friendly-ui.md (big buttons, clear icons, same back
## button everywhere). Needs the app theme (src/ui/app_theme.gd) from an ancestor.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/): Button.expand_icon,
## icon_alignment, Control.get_theme_icon / get_theme_constant with a custom theme type.

## Key of the icon in the "icons" object of assets/data/ui_theme.json; empty = no icon.
@export var icon_name: StringName


func _ready() -> void:
	var side := get_theme_constant(&"nav_button_size", AppTheme.METRICS_TYPE)
	custom_minimum_size = Vector2(side, side)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not icon_name.is_empty():
		icon = get_theme_icon(icon_name, AppTheme.ICONS_TYPE)
