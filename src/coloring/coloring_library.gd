class_name ColoringLibrary
extends RefCounted
## The list of coloring pages, read from a JSON data file, plus the check that every
## page's regions are closed.
## Implements: design/game-brief.md MVP feature 3; story-004-coloring-pages.md
## (AC "library of >= 10 pages", "every page has closed regions").
##
## Data file schema (res://assets/data/coloring_pages.json, snake_case keys):
##   validate_on_load   bool   run [method validate] when the library screen opens
##                             in a debug build (never in release builds)
##   pages_dir          str    folder holding the line-art files
##   screen             obj    library screen layout, read by ColoringLibraryScreen:
##     thumbnail_width, thumbnail_height  int  pt, both >= 64; keep 4:3 like the canvas
##     label_height                       int  pt reserved under the picture for the title
##     columns                            int  thumbnails per row
##     spacing                            int  pt between thumbnails
##                                        (card look comes from the app theme, story 007:
##                                        src/ui/app_theme.gd)
##   pages              [obj]  in display order:
##     id              str    unique
##     file            str    file in pages_dir: black line art on a transparent
##                            background, canvas aspect (4:3), outlines at least
##                            3 x region_cell_size canvas px thick
##     title           str    translation key or text
##     interior_seeds  [[x, y]]  canvas-pixel points (canvas_width x canvas_height
##                            space), at least 2, each well inside a different
##                            closed area of the picture (see [method validate])

## Fewest interior seeds a page may list.
const MIN_SEEDS: int = 2

## One entry of the library.
class Page:
	var id: String
	var title: String
	## res:// path of the line art; loaded on demand so the whole library is never
	## held in memory at once.
	var line_art_path: String
	var interior_seeds: Array[Vector2i] = []

## Pages in display order.
var pages: Array[Page] = []
## Whether the screen should run [method validate] on open (debug builds only).
var validate_on_load: bool
## The raw "screen" object from the data file; schema above.
var screen: Dictionary


## Reads and checks the data file at [param pages_path].
func _init(pages_path: String) -> void:
	var file := FileAccess.open(pages_path, FileAccess.READ)
	assert(file != null, "Coloring pages data not found: " + pages_path)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	validate_on_load = bool(data["validate_on_load"])
	screen = data["screen"]
	var pages_dir := str(data["pages_dir"])
	var ids: Dictionary[String, bool] = {}
	for entry_variant: Variant in data["pages"]:
		var entry: Dictionary = entry_variant
		var page := Page.new()
		page.id = str(entry["id"])
		assert(not ids.has(page.id), "Duplicate coloring page id: " + page.id)
		ids[page.id] = true
		page.title = str(entry["title"])
		page.line_art_path = pages_dir.path_join(str(entry["file"]))
		assert(ResourceLoader.exists(page.line_art_path), "Coloring page file not found: " + page.line_art_path)
		for seed_variant: Variant in entry["interior_seeds"]:
			var pair: Array = seed_variant
			page.interior_seeds.append(Vector2i(int(pair[0]), int(pair[1])))
		assert(page.interior_seeds.size() >= MIN_SEEDS, "Page %s needs at least %d interior_seeds" % [page.id, MIN_SEEDS])
		pages.append(page)


## Checks that every page's regions are closed, using the same region map and
## settings as the canvas (read from [param drawing_config_path]). For each page:
## every interior seed must land on a colourable cell, its region must not reach
## the page edge (an outline gap would let it leak to the outside), and no two
## seeds may share a region (a gap between two areas would merge them).
## Returns one message per problem; empty means every page passed.
## Cost: roughly one page open plus one flood fill per seed, per page.
func validate(drawing_config_path: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var file := FileAccess.open(drawing_config_path, FileAccess.READ)
	assert(file != null, "Drawing config not found: " + drawing_config_path)
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	var canvas_size := Vector2i(int(config["canvas_width"]), int(config["canvas_height"]))
	var cell_size := int(config["region_cell_size"])
	var ink_threshold := float(config["region_ink_threshold"])
	var canvas_rect := Rect2i(Vector2i.ZERO, canvas_size)

	for page in pages:
		var texture := load(page.line_art_path) as Texture2D
		if texture == null:
			problems.append("%s: %s is not a texture" % [page.id, page.line_art_path])
			continue
		var regions := FloodFill.new(FloodFill.line_art_image(texture, canvas_size), cell_size, ink_threshold)
		var seed_of_region: Dictionary[int, int] = {}
		for i in page.interior_seeds.size():
			var point := page.interior_seeds[i]
			if not canvas_rect.has_point(point):
				problems.append("%s: seed %d %s is outside the canvas" % [page.id, i, point])
				continue
			var region := regions.region_at(point, 0)
			if region == FloodFill.NO_REGION:
				problems.append("%s: seed %d %s lies on the outline" % [page.id, i, point])
			elif regions.region_touches_border(region):
				problems.append("%s: seed %d %s is in a region that reaches the page edge (outline not closed)" % [page.id, i, point])
			elif seed_of_region.has(region):
				problems.append("%s: seeds %d and %d share one region (gap in the outline between them)" % [page.id, seed_of_region[region], i])
			else:
				seed_of_region[region] = i
	return problems
