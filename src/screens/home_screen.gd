class_name HomeScreen
extends Control
## Home screen: three big pastel cards side by side, each a clear icon with a
## one-word caption (Color, Draw, Gallery), plus the Mute button top-right. Card size,
## gap, colours and icons come from the app theme (src/ui/app_theme.gd).
## Implements: design/game-brief.md core loop step 1; story-003-blank-page.md,
## story-004-coloring-pages.md, story-005-autosave-gallery.md, story-007-kid-friendly-ui.md.
## Entries in home_screen.tscn (Center/Entries):
##   ColoringButton   - opens the coloring library (story 004)
##   BlankPageButton  - opens a blank page for free drawing (story 003)
##   GalleryButton    - opens the gallery of saved drawings (story 005)
##
## UNCONFIRMED ON GODOT 4.7.2: Button.vertical_icon_alignment, expand_icon.

## Emitted when the child taps the free-drawing (blank page) entry.
signal blank_page_chosen
## Emitted when the child taps the coloring pages entry.
signal coloring_pages_chosen
## Emitted when the child taps the gallery entry.
signal gallery_chosen

# Card node -> icon name in the theme's AppIcons.
const _CARD_ICONS: Dictionary = {
	^"Center/Entries/ColoringButton": &"coloring",
	^"Center/Entries/BlankPageButton": &"blank_page",
	^"Center/Entries/GalleryButton": &"gallery",
}


func _ready() -> void:
	var card_size := Vector2(get_theme_constant(&"home_card_width", AppTheme.METRICS_TYPE),
			get_theme_constant(&"home_card_height", AppTheme.METRICS_TYPE))
	$Center/Entries.add_theme_constant_override(&"separation",
			get_theme_constant(&"home_card_spacing", AppTheme.METRICS_TYPE))
	for path: NodePath in _CARD_ICONS:
		var card := get_node(path) as Button
		card.custom_minimum_size = card_size
		card.icon = get_theme_icon(_CARD_ICONS[path], AppTheme.ICONS_TYPE)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP


## Connects the Mute button to [param sounds]. Call once, after the screen is ready.
func set_sounds(sounds: UiSounds) -> void:
	($MuteButton as MuteButton).setup(sounds)


func _on_blank_page_button_pressed() -> void:
	blank_page_chosen.emit()


func _on_coloring_button_pressed() -> void:
	coloring_pages_chosen.emit()


func _on_gallery_button_pressed() -> void:
	gallery_chosen.emit()
