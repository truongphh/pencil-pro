class_name FloodFill
extends RefCounted
## Region map for one coloring page: which canvas pixels belong to which closed
## area of the line art. Used for one-tap fill and to keep strokes inside the area
## they started in.
## Implements: design/game-brief.md MVP feature 3; story-004-coloring-pages.md
## (AC "no spill into neighbouring regions", "fill < 1 s").
##
## Approach: the line art is reduced once to a coarse grid (one cell per
## [code]cell_size[/code] x [code]cell_size[/code] canvas pixels, area-averaged). A
## cell whose average darkness reaches the ink threshold is outline. Regions are
## found by a queue flood fill (4-connected) on that grid, lazily, the first time a
## region is touched, and cached for the life of the page. The boundary comes only
## from the line art, never from the current colours, so refilling a coloured region
## works. A region's mask is its own cells plus the outline cells next to them (one
## ring), so colour reaches under the outline and leaves no white gap; the line art
## is drawn on top and hides it. This needs outline strokes at least 3 cells thick.
##
## UNCONFIRMED ON GODOT 4.7.2 (not in docs/engine-reference/godot/, written from
## 4.3-era knowledge): Image.blend_rect semantics (src-over), Image.resize with
## INTERPOLATE_TRILINEAR (area-averaged downscale) and INTERPOLATE_NEAREST,
## Image.clear_mipmaps, Image.get_data layout for FORMAT_RGBA8 (4 bytes per pixel,
## row-major, mip 0 first), Image.create_from_data, PackedByteArray.resize
## zero-filling, Texture2D.get_image on an imported SVG texture.

## Returned by [method region_at] when no region is near the point.
const NO_REGION: int = -1

var _cell_size: int
var _grid_size: Vector2i
# 1 = outline cell, 0 = colourable cell. One byte per grid cell, row-major.
var _boundary: PackedByteArray
# Region id per cell, NO_REGION until that cell's region is first labelled.
# Doubles as the flood fill's visited bitmap.
var _labels: PackedInt32Array
# Per region id: bounds in grid cells (region cells only, no ring), and whether
# the region reaches the edge of the page.
var _region_bounds: Array[Rect2i] = []
var _region_touches_border: Array[bool] = []
# Grid-resolution masks, built once per region on first use.
var _grid_masks: Dictionary[int, Image] = {}
# Full-resolution mask of the most recently used region (the child usually keeps
# colouring the same area).
var _last_mask_region: int = NO_REGION
var _last_mask: Image


## Converts [param texture] to an RGBA8 image of exactly [param size] pixels, the
## form [method _init] and the canvas overlay expect.
static func line_art_image(texture: Texture2D, size: Vector2i) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != size:
		image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	return image


## [param line_art] is the page's line art (RGBA8, see [method line_art_image]);
## its width and height must be multiples of [param cell_size].
## [param ink_threshold] (0..1) is the average darkness at which a cell counts as
## outline. Cost: engine-side blend and resize of the full image, then one GDScript
## pass over the grid (196 608 cells for 2048x1536 at cell size 4).
func _init(line_art: Image, cell_size: int, ink_threshold: float) -> void:
	assert(cell_size >= 1, "region_cell_size must be >= 1")
	assert(line_art.get_width() % cell_size == 0 and line_art.get_height() % cell_size == 0,
			"canvas size must be a multiple of region_cell_size")
	_cell_size = cell_size
	_grid_size = line_art.get_size() / cell_size

	# Line art over white: darkness of a pixel = 1 - brightness, so both alpha and
	# colour count (anti-aliased and non-transparent art both work).
	var flat := Image.create_empty(line_art.get_width(), line_art.get_height(), false, Image.FORMAT_RGBA8)
	flat.fill(Color.WHITE)
	flat.blend_rect(line_art, Rect2i(Vector2i.ZERO, line_art.get_size()), Vector2i.ZERO)
	flat.resize(_grid_size.x, _grid_size.y, Image.INTERPOLATE_TRILINEAR)
	flat.clear_mipmaps()
	var pixels := flat.get_data()

	var cell_count := _grid_size.x * _grid_size.y
	# Outline when (r + g + b) / 3 <= (1 - ink_threshold) * 255.
	var max_light_sum := roundi((1.0 - clampf(ink_threshold, 0.0, 1.0)) * 255.0 * 3.0)
	var boundary := PackedByteArray()
	boundary.resize(cell_count)
	for i in cell_count:
		var p := i * 4
		boundary[i] = 1 if pixels[p] + pixels[p + 1] + pixels[p + 2] <= max_light_sum else 0
	_boundary = boundary
	_labels.resize(cell_count)
	_labels.fill(NO_REGION)


## Returns the region under canvas pixel [param point], or the nearest region
## within [param search_cells] grid cells when the point is on the outline.
## Labels the region on first use (one flood fill over it). NO_REGION when none.
func region_at(point: Vector2i, search_cells: int) -> int:
	var cell := (point / _cell_size).clamp(Vector2i.ZERO, _grid_size - Vector2i.ONE)
	for ring in search_cells + 1:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var x := cell.x + dx
				var y := cell.y + dy
				if x < 0 or y < 0 or x >= _grid_size.x or y >= _grid_size.y:
					continue
				var index := y * _grid_size.x + x
				if _boundary[index] == 0:
					return _label_from(index)
	return NO_REGION


## True when [param region] reaches the edge of the page (it is not enclosed by
## the line art).
func region_touches_border(region: int) -> bool:
	return _region_touches_border[region]


## Canvas-pixel rectangle covering [param region] and its outline ring. This is
## the dirty rectangle of a fill and the area of [method get_region_mask].
func get_region_rect(region: int) -> Rect2i:
	var cells := _region_bounds[region].grow(1).intersection(Rect2i(Vector2i.ZERO, _grid_size))
	return Rect2i(cells.position * _cell_size, cells.size * _cell_size)


## RGBA8 mask the size of [method get_region_rect]: alpha 255 where colour may go,
## 0 elsewhere. Shared and cached: callers must not modify it.
func get_region_mask(region: int) -> Image:
	if region == _last_mask_region:
		return _last_mask
	if not _grid_masks.has(region):
		_grid_masks[region] = _build_grid_mask(region)
	var grid_mask: Image = _grid_masks[region]
	var mask := grid_mask.get_region(Rect2i(Vector2i.ZERO, grid_mask.get_size()))
	var rect := get_region_rect(region)
	mask.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	_last_mask_region = region
	_last_mask = mask
	return mask


# Queue flood fill over non-outline cells from [param start]; returns its region id.
func _label_from(start: int) -> int:
	if _labels[start] != NO_REGION:
		return _labels[start]
	var region := _region_bounds.size()
	var width := _grid_size.x
	var height := _grid_size.y
	var boundary := _boundary
	var labels := _labels
	var queue := PackedInt32Array()
	queue.resize(labels.size())
	queue[0] = start
	labels[start] = region
	var head := 0
	var tail := 1
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	while head < tail:
		var index: int = queue[head]
		head += 1
		@warning_ignore("integer_division")
		var y: int = index / width
		var x: int = index - y * width
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)
		if x > 0 and labels[index - 1] == NO_REGION and boundary[index - 1] == 0:
			labels[index - 1] = region
			queue[tail] = index - 1
			tail += 1
		if x < width - 1 and labels[index + 1] == NO_REGION and boundary[index + 1] == 0:
			labels[index + 1] = region
			queue[tail] = index + 1
			tail += 1
		if y > 0 and labels[index - width] == NO_REGION and boundary[index - width] == 0:
			labels[index - width] = region
			queue[tail] = index - width
			tail += 1
		if y < height - 1 and labels[index + width] == NO_REGION and boundary[index + width] == 0:
			labels[index + width] = region
			queue[tail] = index + width
			tail += 1
	_labels = labels
	_region_bounds.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	_region_touches_border.append(min_x == 0 or min_y == 0 or max_x == width - 1 or max_y == height - 1)
	return region


# Region cells plus outline cells 8-adjacent to them, over the region's bounds
# grown by one cell.
func _build_grid_mask(region: int) -> Image:
	var cells := _region_bounds[region].grow(1).intersection(Rect2i(Vector2i.ZERO, _grid_size))
	var width := _grid_size.x
	var height := _grid_size.y
	var labels := _labels
	var boundary := _boundary
	var bytes := PackedByteArray()
	bytes.resize(cells.size.x * cells.size.y * 4)
	bytes.fill(0)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var index := y * width + x
			var inside := labels[index] == region
			if not inside and boundary[index] == 1:
				for ny in range(maxi(y - 1, 0), mini(y + 2, height)):
					for nx in range(maxi(x - 1, 0), mini(x + 2, width)):
						if labels[ny * width + nx] == region:
							inside = true
			if inside:
				var out := ((y - cells.position.y) * cells.size.x + (x - cells.position.x)) * 4
				bytes[out] = 255
				bytes[out + 1] = 255
				bytes[out + 2] = 255
				bytes[out + 3] = 255
	return Image.create_from_data(cells.size.x, cells.size.y, false, Image.FORMAT_RGBA8, bytes)
