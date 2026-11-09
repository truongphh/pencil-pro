class_name AppRoot
extends Control
## Main scene. Keeps the home screen as a permanent child and swaps the coloring
## library, the gallery and drawing pages in and out on top of it (no change_scene).
## Owns the open drawing page and its autosave.
## Implements: design/game-brief.md core loop, MVP feature 6 and "no action loses a
## drawing"; story-003-blank-page.md, story-004-coloring-pages.md,
## story-005-autosave-gallery.md, story-007-kid-friendly-ui.md.
##
## Look and sound (story 007): the one app theme (src/ui/app_theme.gd, data
## [member ui_theme_path]) is set on this node in _enter_tree, before any screen is
## ready, so every screen inherits it. The UI sounds (src/ui/ui_sounds.gd) are a child
## of this node, handed to the home screen and each drawing page. The saved sound plays
## when a changed page is saved because the child tapped Home, not on background
## autosaves (the app is going away then).
##
## Autosave: the open page is saved when the child taps Home, when the app is paused
## or loses focus, and before quitting (close request, Android back). Unchanged pages
## are not saved, so an untouched new page never appears in the gallery. A failed save
## shows a friendly message and keeps the page open: Home and quit wait until a save
## succeeds.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT,
## NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST,
## SceneTree.set_auto_accept_quit, SceneTree.set_quit_on_go_back, AcceptDialog.popup_centered,
## AcceptDialog.dialog_autowrap / get_ok_button, Window.theme / borderless, a theme set in
## _enter_tree reaching the children's _ready.

const DRAWING_PAGE_SCENE: PackedScene = preload("res://src/screens/drawing_page.tscn")
const COLORING_LIBRARY_SCENE: PackedScene = preload("res://src/screens/coloring_library_screen.tscn")
const GALLERY_SCENE: PackedScene = preload("res://src/screens/gallery_screen.tscn")

## Save config (schema in src/save/save_manager.gd).
@export var save_config_path: String = "res://assets/data/save_config.json"
## Coloring pages data, to find a reopened drawing's line art by page id.
@export var pages_path: String = "res://assets/data/coloring_pages.json"
## UI style data (schema in src/ui/app_theme.gd).
@export var ui_theme_path: String = "res://assets/data/ui_theme.json"
## UI sounds data (schema in src/ui/ui_sounds.gd).
@export var ui_sounds_path: String = "res://assets/data/ui_sounds.json"

var _saves: SaveManager
# Created on first use (building thumbnails is not free) and kept afterwards.
var _library: ColoringLibraryScreen
# Built fresh on every open so it lists the latest saves; null while closed.
var _gallery: GalleryScreen
# Read on first reopen of a coloring drawing.
var _pages: ColoringLibrary
# The open drawing page, its save record and the revision last saved; null when none.
var _page: DrawingPage
var _record: SaveManager.Record
var _saved_revision: int = 0
var _message_dialog: AcceptDialog
var _sounds: UiSounds

@onready var _home: HomeScreen = $HomeScreen


func _enter_tree() -> void:
	if theme == null:
		theme = AppTheme.build(ui_theme_path)


func _ready() -> void:
	($Background as ColorRect).color = get_theme_color(&"background", AppTheme.METRICS_TYPE)
	_sounds = UiSounds.new()
	_sounds.data_path = ui_sounds_path
	add_child(_sounds)
	_home.set_sounds(_sounds)
	_saves = SaveManager.new(save_config_path)
	# Quitting waits for the open drawing to be saved (see _notification).
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_save_open_page()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			if _save_open_page():
				get_tree().quit()


func _on_home_screen_blank_page_chosen() -> void:
	_open_page(_saves.new_record(""), null, null)


func _on_home_screen_coloring_pages_chosen() -> void:
	if _library == null:
		_library = COLORING_LIBRARY_SCENE.instantiate() as ColoringLibraryScreen
		_library.page_chosen.connect(_on_library_page_chosen)
		_library.home_chosen.connect(_on_library_home_chosen)
		add_child(_library)
	_library.visible = true
	_home.visible = false


func _on_home_screen_gallery_chosen() -> void:
	_gallery = GALLERY_SCENE.instantiate() as GalleryScreen
	_gallery.setup(_saves)
	_gallery.drawing_chosen.connect(_on_gallery_drawing_chosen)
	_gallery.home_chosen.connect(_on_gallery_home_chosen)
	add_child(_gallery)
	_home.visible = false


func _on_library_page_chosen(page_id: String, line_art: Texture2D) -> void:
	_open_page(_saves.new_record(page_id), line_art, null)


func _on_library_home_chosen() -> void:
	_library.visible = false
	_home.visible = true


func _on_gallery_home_chosen() -> void:
	_close_gallery()
	_home.visible = true


func _on_gallery_drawing_chosen(drawing_id: String) -> void:
	var record := _saves.load_record(drawing_id)
	var color: Image = _saves.load_color_image(drawing_id) if record != null else null
	if color == null:
		_show_message(_saves.open_failed_message)
		return
	_close_gallery()
	_open_page(record, _line_art_for(record.page_id), color)


func _close_gallery() -> void:
	_gallery.queue_free()
	_gallery = null


# Every open creates a fresh page instance, so a new page never shows old strokes
# or the colours of a previously opened coloring page.
func _open_page(record: SaveManager.Record, line_art: Texture2D, color: Image) -> void:
	var page := DRAWING_PAGE_SCENE.instantiate() as DrawingPage
	page.setup(line_art, color)
	page.set_sounds(_sounds)
	page.drawing_closed.connect(_on_drawing_closed)
	add_child(page)
	_page = page
	_record = record
	_saved_revision = page.get_revision()
	_home.visible = false
	if _library != null:
		_library.visible = false


func _on_drawing_closed() -> void:
	var changed := _page.get_revision() != _saved_revision
	if not _save_open_page():
		return
	if changed:
		_sounds.play_saved()
	_page.queue_free()
	_page = null
	_record = null
	_home.visible = true


# Saves the open page if it changed since its last save. Returns false (after
# telling the child) when the save failed; the page and its drawing stay open.
func _save_open_page() -> bool:
	if _page == null or _page.get_revision() == _saved_revision:
		return true
	var revision := _page.get_revision()
	var err := _saves.save_drawing(_record, _page.get_color_image(), _page.get_image())
	if err != OK:
		push_error("Saving drawing %s failed: %s" % [_record.id, error_string(err)])
		_show_message(_saves.save_failed_message)
		return false
	_saved_revision = revision
	return true


# Line art of coloring page [param page_id]; null for a blank page or a page id this
# build no longer has (the drawing then opens with its colour only).
func _line_art_for(page_id: String) -> Texture2D:
	if page_id.is_empty():
		return null
	if _pages == null:
		_pages = ColoringLibrary.new(pages_path)
	for page in _pages.pages:
		if page.id == page_id:
			return load(page.line_art_path) as Texture2D
	push_warning("Saved drawing refers to unknown coloring page: " + page_id)
	return null


# Friendly message in a rounded themed box with one big OK button and no title bar.
func _show_message(text: String) -> void:
	if _message_dialog == null:
		_message_dialog = AcceptDialog.new()
		_message_dialog.theme = theme
		_message_dialog.borderless = true
		_message_dialog.dialog_autowrap = true
		var side := get_theme_constant(&"nav_button_size", AppTheme.METRICS_TYPE)
		_message_dialog.get_ok_button().custom_minimum_size = Vector2(side * 2, side)
		add_child(_message_dialog)
	_message_dialog.dialog_text = tr(text)
	_message_dialog.popup_centered(Vector2i(get_theme_constant(&"dialog_width", AppTheme.METRICS_TYPE), 0))
