class_name StrokeHistory
extends RefCounted
## Bounded undo history for the drawing canvas.
## Implements: design/game-brief.md MVP feature 1 (undo), story-001 AC "undo >= 20 strokes".
## Design choice: each stroke stores only the "before" pixels of the rectangle it touched,
## not a whole-canvas snapshot. A single persistent copy of the last committed canvas
## supplies those pixels, so no full-image copy is made per stroke.

## One undoable stroke: the rectangle it changed and the pixels that were there before.
class Entry:
	var rect: Rect2i
	var before: Image

var _max_depth: int
var _entries: Array[Entry] = []
## The canvas as it was after the last finished stroke (or undo).
var _committed: Image


## [param max_depth] is the number of strokes that can be undone (from the config file).
## [param image] is the canvas in its starting state.
func _init(max_depth: int, image: Image) -> void:
	_max_depth = max_depth
	_committed = image.get_region(Rect2i(Vector2i.ZERO, image.get_size()))


## Returns true when at least one stroke can be undone.
func can_undo() -> bool:
	return not _entries.is_empty()


## Call when a stroke ends. [param dirty_rect] must be the union of every area painted,
## clipped to the image. Evicts the oldest entry when the history is full.
func end_stroke(image: Image, dirty_rect: Rect2i) -> void:
	var entry := Entry.new()
	entry.rect = dirty_rect
	entry.before = _committed.get_region(dirty_rect)
	_committed.blit_rect(image, dirty_rect, dirty_rect.position)
	_entries.append(entry)
	while _entries.size() > _max_depth:
		_entries.pop_front()


## Restores the pixels of the most recent stroke into [param image].
## Returns false when there was nothing to undo.
func undo(image: Image) -> bool:
	if _entries.is_empty():
		return false
	var entry: Entry = _entries.pop_back()
	var source_rect := Rect2i(Vector2i.ZERO, entry.rect.size)
	image.blit_rect(entry.before, source_rect, entry.rect.position)
	_committed.blit_rect(entry.before, source_rect, entry.rect.position)
	return true
