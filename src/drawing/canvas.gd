class_name DrawingCanvas
extends Control
## Touch/mouse drawing canvas: continuous strokes, pressure, undo, eraser. On a
## coloring page it also draws the line art above the colour, keeps each stroke
## inside the region it started in, and fills a whole region with one tap. In sticker
## mode a touch prints a sticker or stamp into the colour image instead (story 006).
## Implements: design/game-brief.md MVP features 1, 3 and 5; story-001-drawing-canvas.md,
## story-004-coloring-pages.md, story-006-stickers-stamps.md.
## All tunable values come from the JSON at [member config_path].
##
## Config keys added by story 004 (res://assets/data/drawing_config.json):
##   region_cell_size          int    canvas px per side of one region-map cell (see
##                                    src/coloring/flood_fill.gd). canvas_width and
##                                    canvas_height must be multiples of it; line art
##                                    outlines must be at least 3 cells thick. Larger =
##                                    faster fill, coarser region edges under the outline.
##   region_ink_threshold      float  0..1 average darkness of a cell at or above which it
##                                    is outline. Lower = anti-aliased edges block sooner.
##   region_seed_search_cells  int    when a touch starts on the outline, how many cells
##                                    away to look for the region to colour; none found =
##                                    the touch draws nothing.
##
## Rendering on a coloring page: the colour image (starts white) is drawn first and
## the line art texture over it, so strokes, fills and the eraser can never cover or
## remove the outline. This is internal, not a user-facing layer.
##
## UNVERIFIED ON GODOT 4.7.2 (hypotheses from web research 2026-11-08, not in
## docs/engine-reference/godot/):
##  - Finger and Pencil both arrive as InputEventScreenTouch / InputEventScreenDrag.
##  - InputEventScreenDrag carries pressure, tilt and pen_inverted.
##  - is_nan(pressure) tells finger from Pencil (forum post, Godot 4.1-4.2.1).
##  - Emulated mouse events from touch have device == InputEvent.DEVICE_ID_EMULATION.
##  - Control._gui_input receives ScreenTouch/ScreenDrag events.
##  - Image.blend_rect / blit_rect clip against the image bounds.
##  - Texture2D.get_image returns an Image this script may modify; Image.is_compressed,
##    decompress, convert and resize behave as in 4.3 (line_art_texture path only).
##  - Image.blit_rect_mask / blend_rect_mask copy/blend only where the mask's alpha
##    is non-zero, require mask size == source size, and clip against the image.
##  - Image.get_region of a rect partly outside the image leaves the outside part
##    transparent (zero).

enum PointerPhase { DOWN, MOVE, UP }

const NO_POINTER: int = -2
const MOUSE_POINTER: int = -1

## Path of the JSON config (res://assets/data/drawing_config.json).
@export var config_path: String = "res://assets/data/drawing_config.json"
## Line art of a coloring page (black outlines on transparent), drawn above the
## colour and scaled to the canvas; read once in _ready. Null is a blank page.
## Strokes, fills, the eraser and undo only ever change the colour beneath it.
@export var line_art_texture: Texture2D
## Optional label that shows the pointer debug readout when the config enables it.
@export var debug_label: Label

var _image: Image
var _texture: ImageTexture
var _history: StrokeHistory

var _background_color: Color
var _letterbox_color: Color
var _pressure_min_scale: float
var _pressure_max_scale: float
var _pressure_curve: float
var _spacing_ratio: float
var _stamp_cache_limit: int
var _debug_enabled: bool

# Current tool, applied to the NEXT stroke only. These are neutral placeholders:
# the tool panel (src/ui/tool_panel.gd) sets the real defaults from
# assets/data/drawing_tools.json in its _ready, before any input arrives.
var _brush_color: Color = Color.BLACK
var _pen_radius: float = 1.0
var _pen_hardness: float = 1.0
var _pen_pressure_scale: float = 0.0
# Colour/pen/stroke state captured at stroke start so a mid-stroke change cannot alter it.
var _stroke_color: Color
var _stroke_radius: float
var _stroke_hardness: float
var _stroke_pressure_scale: float

# Keyed by "<rgba32>_<radius_px>_<hardness percent>"; cleared when it reaches _stamp_cache_limit.
var _stamps: Dictionary[String, Image] = {}

var _erasing: bool = false
var _stroke_erasing: bool = false
var _active_pointer: int = NO_POINTER
var _last_point: Vector2
var _last_radius: float
var _stroke_dirty: Rect2i
var _stroke_has_dirty: bool = false
var _needs_upload: bool = false

# Coloring page state; all null/unused on a blank page.
var _line_art: Image
var _regions: FloodFill
var _seed_search_cells: int
var _filling: bool = false
# The current touch draws nothing more (it was a fill tap, or started off any region).
var _stroke_skipped: bool = false
# Region the current stroke is confined to; null mask = unclipped.
var _clip_mask: Image
var _clip_rect: Rect2i

# Saved colour set by load_color_image before _ready (story 005); null = start white.
var _start_color: Image
# Goes up on every change to the colour image (story 005 autosave skips unchanged pages).
var _revision: int = 0

# Sticker mode (story 006); null = off. Captured at touch start like the pen.
var _sticker: Image
var _sticker_spacing: float = 0.0
var _stroke_sticker: Image
var _stroke_sticker_spacing: float = 0.0


func _ready() -> void:
	var file := FileAccess.open(config_path, FileAccess.READ)
	assert(file != null, "Drawing config not found: " + config_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	_background_color = Color.html(str(data["background_color"]))
	_letterbox_color = Color.html(str(data["letterbox_color"]))
	_pressure_min_scale = float(data["pressure_min_scale"])
	_pressure_max_scale = float(data["pressure_max_scale"])
	_pressure_curve = float(data["pressure_curve"])
	_spacing_ratio = float(data["stamp_spacing_ratio"])
	_stamp_cache_limit = int(data["stamp_cache_limit"])
	_debug_enabled = bool(data["debug_readout"])
	_seed_search_cells = int(data["region_seed_search_cells"])
	var canvas_width := int(data["canvas_width"])
	var canvas_height := int(data["canvas_height"])
	_image = Image.create_empty(canvas_width, canvas_height, false, Image.FORMAT_RGBA8)
	_image.fill(_background_color)
	if _start_color != null:
		if _start_color.get_format() != Image.FORMAT_RGBA8:
			_start_color.convert(Image.FORMAT_RGBA8)
		if _start_color.get_size() != _image.get_size():
			_start_color.resize(canvas_width, canvas_height, Image.INTERPOLATE_BILINEAR)
		_image.blit_rect(_start_color, Rect2i(Vector2i.ZERO, _image.get_size()), Vector2i.ZERO)
		_start_color = null
	if line_art_texture != null:
		_line_art = FloodFill.line_art_image(line_art_texture, _image.get_size())
		_regions = FloodFill.new(_line_art, int(data["region_cell_size"]), float(data["region_ink_threshold"]))
	_texture = ImageTexture.create_from_image(_image)
	_history = StrokeHistory.new(int(data["undo_depth"]), _image)

	if debug_label != null:
		debug_label.visible = _debug_enabled


## Undoes the most recent stroke (drawing or erasing) or region fill; both share one
## history. Ignored while a stroke is in progress.
func undo() -> void:
	if _active_pointer != NO_POINTER:
		return
	if _history.undo(_image):
		_needs_upload = true
		_revision += 1


## Starts the canvas from a saved colour image (everything except the line art), e.g.
## a drawing reopened from the gallery. Call before the canvas enters the tree; the
## image is copied, converted to RGBA8 and resized to the canvas size if it differs.
## Undo history starts empty. Story 005.
func load_color_image(image: Image) -> void:
	assert(_image == null, "load_color_image must be called before the canvas is ready")
	_start_color = image.get_region(Rect2i(Vector2i.ZERO, image.get_size()))


## Returns a copy of the colour image only, without the line art, including any
## stroke in progress. This is what gets saved. Story 005.
func get_color_image() -> Image:
	return _image.get_region(Rect2i(Vector2i.ZERO, _image.get_size()))


## A number that changes whenever the colour image changes (strokes, fills, undo).
## Starts at 0, also after [method load_color_image]. Story 005.
func get_revision() -> int:
	return _revision


## Switches between drawing and erasing for the next stroke.
func set_erasing(value: bool) -> void:
	_erasing = value


## Switches between strokes and one-tap region fill for the next touch. Has no
## effect on a blank page (see [method has_line_art]). With the eraser on, a fill
## paints the region in the background colour.
func set_filling(value: bool) -> void:
	_filling = value


## True on a coloring page (the canvas has line art).
func has_line_art() -> bool:
	return _line_art != null


## Turns sticker mode on for the next touch: [param image] (RGBA8, read but never
## modified) is alpha-blended into the colour image centred on the touch point and
## clipped to the canvas. It is not clipped to a coloring-page region, and the line art
## stays drawn above it. Sticker mode takes priority over the pen, fill and eraser,
## which keep their settings for when it ends. [param repeat_spacing] > 0 also places
## the image along a drag every that many canvas px (stamps); 0 places it once per
## touch. Each touch is one undo step. A null [param image] ends sticker mode.
func set_sticker(image: Image, repeat_spacing: float = 0.0) -> void:
	_sticker = image
	_sticker_spacing = repeat_spacing


## Sets the drawing colour for the next stroke. Existing strokes and a stroke in progress are unaffected.
func set_brush_color(color: Color) -> void:
	_brush_color = color


## Sets the pen for the next stroke; a stroke in progress keeps its pen.
## [param radius] is the base radius in image pixels. [param hardness] is 0..1:
## 1 is a crisp anti-aliased edge, lower values widen the soft edge falloff.
## [param pressure_scale] is 0..1: 0 ignores stylus pressure, 1 applies the full
## pressure range from the config.
func set_pen(radius: float, hardness: float, pressure_scale: float) -> void:
	_pen_radius = radius
	_pen_hardness = clampf(hardness, 0.0, 1.0)
	_pen_pressure_scale = clampf(pressure_scale, 0.0, 1.0)


## Returns true when there is a stroke to undo.
func can_undo() -> bool:
	return _history.can_undo()


## Returns a copy of the drawing at full canvas resolution, including any stroke in
## progress. On a coloring page the line art is composited on top, as displayed.
func get_image() -> Image:
	var image := _image.get_region(Rect2i(Vector2i.ZERO, _image.get_size()))
	if _line_art != null:
		image.blend_rect(_line_art, Rect2i(Vector2i.ZERO, _line_art.get_size()), Vector2i.ZERO)
	return image


func _process(_delta: float) -> void:
	if _needs_upload:
		_texture.update(_image)
		queue_redraw()
		_needs_upload = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _letterbox_color)
	var rect := _display_rect()
	draw_texture_rect(_texture, rect, false)
	if line_art_texture != null:
		draw_texture_rect(line_art_texture, rect, false)


# The only place raw input events are interpreted. Everything below works on
# (pointer id, phase, position, pressure).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_report_debug("ScreenTouch pressed=%s index=%d (pressure not read on touch events)" % [touch.pressed, touch.index])
		var phase := PointerPhase.DOWN if (touch.pressed and not touch.canceled) else PointerPhase.UP
		_handle_pointer(touch.index, phase, touch.position, NAN)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_report_pen_state("ScreenDrag", drag.pressure, drag.tilt, drag.pen_inverted)
		_handle_pointer(drag.index, PointerPhase.MOVE, drag.position, drag.pressure)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		# Touch emulated as mouse is already handled through the touch events above.
		if button.device == InputEvent.DEVICE_ID_EMULATION or button.button_index != MOUSE_BUTTON_LEFT:
			return
		_report_debug("MouseButton pressed=%s" % button.pressed)
		var phase := PointerPhase.DOWN if button.pressed else PointerPhase.UP
		_handle_pointer(MOUSE_POINTER, phase, button.position, NAN)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_report_pen_state("MouseMotion", motion.pressure, motion.tilt, motion.pen_inverted)
		# A mouse has no usable pressure: always the fixed brush.
		_handle_pointer(MOUSE_POINTER, PointerPhase.MOVE, motion.position, NAN)


# Single entry point for all pointers. Only one pointer draws at a time; others are ignored.
func _handle_pointer(pointer_id: int, phase: PointerPhase, local_pos: Vector2, pressure: float) -> void:
	match phase:
		PointerPhase.DOWN:
			if _active_pointer != NO_POINTER or not _display_rect().has_point(local_pos):
				return
			_active_pointer = pointer_id
			_stroke_erasing = _erasing
			_stroke_color = _brush_color
			_stroke_radius = _pen_radius
			_stroke_hardness = _pen_hardness
			_stroke_pressure_scale = _pen_pressure_scale
			_stroke_has_dirty = false
			_stroke_skipped = false
			_clip_mask = null
			_stroke_sticker = _sticker
			_stroke_sticker_spacing = _sticker_spacing
			_last_point = _to_image_point(local_pos)
			if _stroke_sticker != null:
				_place_sticker(_last_point)
				return
			_last_radius = _radius_for(pressure)
			if _regions != null:
				var region := _regions.region_at(Vector2i(_last_point.floor()), _seed_search_cells)
				if region == FloodFill.NO_REGION or _filling:
					# The pointer stays captured until UP so a drag cannot start a stroke.
					_stroke_skipped = true
					if region != FloodFill.NO_REGION:
						_fill(region)
					return
				_clip_rect = _regions.get_region_rect(region)
				_clip_mask = _regions.get_region_mask(region)
			_stamp(_last_point, _last_radius)
		PointerPhase.MOVE:
			if pointer_id != _active_pointer or _stroke_skipped:
				return
			var point := _to_image_point(local_pos)
			if _stroke_sticker != null:
				# Stamps repeat along the drag at a fixed spacing; stickers ignore drags.
				if _stroke_sticker_spacing > 0.0:
					while _last_point.distance_to(point) >= _stroke_sticker_spacing:
						_last_point = _last_point.move_toward(point, _stroke_sticker_spacing)
						_place_sticker(_last_point)
				return
			var radius := _radius_for(pressure)
			var spacing := maxf(1.0, minf(_last_radius, radius) * _spacing_ratio)
			var steps: int = ceili(_last_point.distance_to(point) / spacing)
			for i in range(1, steps + 1):
				var t := float(i) / steps
				_stamp(_last_point.lerp(point, t), lerpf(_last_radius, radius, t))
			_last_point = point
			_last_radius = radius
		PointerPhase.UP:
			if pointer_id != _active_pointer:
				return
			if _stroke_has_dirty:
				_history.end_stroke(_image, _stroke_dirty)
			_active_pointer = NO_POINTER


# NaN or non-positive pressure means "unavailable": use the fixed brush.
func _radius_for(pressure: float) -> float:
	if is_nan(pressure) or pressure <= 0.0:
		return _stroke_radius
	var t := pow(clampf(pressure, 0.0, 1.0), _pressure_curve)
	var full_scale := lerpf(_pressure_min_scale, _pressure_max_scale, t)
	return _stroke_radius * lerpf(1.0, full_scale, _stroke_pressure_scale)


# Replaces the whole region with the stroke colour (background colour when erasing)
# in one undoable step whose dirty rect is the region's bounds.
func _fill(region: int) -> void:
	var rect := _regions.get_region_rect(region)
	var solid := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	solid.fill(_background_color if _stroke_erasing else _stroke_color)
	_image.blit_rect_mask(solid, _regions.get_region_mask(region), Rect2i(Vector2i.ZERO, rect.size), rect.position)
	_history.end_stroke(_image, rect)
	_needs_upload = true
	_revision += 1


func _stamp(center: Vector2, radius: float) -> void:
	var radius_px: int = maxi(1, roundi(radius))
	var stamp := _get_stamp(radius_px)
	var top_left := Vector2i(floori(center.x), floori(center.y)) - Vector2i(radius_px, radius_px)
	var stamp_rect := Rect2i(top_left, stamp.get_size())
	var source_rect := Rect2i(Vector2i.ZERO, stamp.get_size())
	if _clip_mask == null:
		_image.blend_rect(stamp, source_rect, top_left)
	else:
		# Coloring page: only the part of the stamp inside the stroke's region.
		stamp_rect = stamp_rect.intersection(_clip_rect)
		if not stamp_rect.has_area():
			return
		var mask := _clip_mask.get_region(Rect2i(top_left - _clip_rect.position, stamp.get_size()))
		_image.blend_rect_mask(stamp, mask, source_rect, top_left)
	_mark_dirty(stamp_rect)


# Prints the touch's sticker centred on [param center], unclipped by regions; it
# becomes part of the colour image (no layer) and is undone with the touch.
func _place_sticker(center: Vector2) -> void:
	var sticker_size := _stroke_sticker.get_size()
	var top_left := Vector2i((center - Vector2(sticker_size) * 0.5).round())
	_image.blend_rect(_stroke_sticker, Rect2i(Vector2i.ZERO, sticker_size), top_left)
	_mark_dirty(Rect2i(top_left, sticker_size))


# Adds the changed area (clipped to the image) to the current touch's undo rect and
# schedules the texture upload and autosave.
func _mark_dirty(rect: Rect2i) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
	if clipped.has_area():
		_stroke_dirty = _stroke_dirty.merge(clipped) if _stroke_has_dirty else clipped
		_stroke_has_dirty = true
	_needs_upload = true
	_revision += 1


func _get_stamp(radius_px: int) -> Image:
	# The eraser stamps in the background colour and ignores the selected colour.
	var color := _background_color if _stroke_erasing else _stroke_color
	var key := "%d_%d_%d" % [color.to_rgba32(), radius_px, roundi(_stroke_hardness * 100.0)]
	if not _stamps.has(key):
		if _stamps.size() >= _stamp_cache_limit:
			_stamps.clear()
		_stamps[key] = _make_stamp(radius_px, color, _stroke_hardness)
	return _stamps[key]


# Filled circle, diameter 2 * radius_px + 1, built once per colour/radius/hardness.
# Alpha falls from 1 to 0 over a falloff band ending at the rim: 1 px wide at
# hardness 1 (crisp anti-aliased edge), the whole radius at hardness 0 (soft).
func _make_stamp(radius_px: int, color: Color, hardness: float) -> Image:
	var stamp_size := radius_px * 2 + 1
	var stamp := Image.create_empty(stamp_size, stamp_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius_px + 0.5, radius_px + 0.5)
	var falloff := maxf(1.0, (1.0 - hardness) * (radius_px + 0.5))
	for y in stamp_size:
		for x in stamp_size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			stamp.set_pixel(x, y, Color(color, clampf((radius_px + 0.5 - distance) / falloff, 0.0, 1.0)))
	return stamp


# Largest rectangle with the image's aspect ratio that fits the control, centred.
func _display_rect() -> Rect2:
	var image_size := Vector2(_image.get_size())
	var fit_scale := minf(size.x / image_size.x, size.y / image_size.y)
	var display_size := image_size * fit_scale
	return Rect2((size - display_size) * 0.5, display_size)


func _to_image_point(local_position: Vector2) -> Vector2:
	var rect := _display_rect()
	return (local_position - rect.position) * Vector2(_image.get_size()) / rect.size


func _report_pen_state(event_type: String, pressure: float, tilt: Vector2, pen_inverted: bool) -> void:
	_report_debug("%s pressure=%.3f is_nan=%s tilt=%s pen_inverted=%s" % [event_type, pressure, is_nan(pressure), tilt, pen_inverted])


func _report_debug(text: String) -> void:
	if _debug_enabled and debug_label != null:
		debug_label.text = text
