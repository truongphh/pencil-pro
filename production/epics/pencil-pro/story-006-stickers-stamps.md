# Story 006: Kho sticker và con dấu

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — kho sticker và con dấu đơn giản

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 5 ("đơn giản") and out-of-scope list (no layers):*

- [ ] Có ít nhất 15 sticker và 5 con dấu để chọn
- [ ] Chọn một sticker rồi chạm lên tranh thì sticker được đặt đúng chỗ chạm
- [ ] Chọn được một trong 3 cỡ cho sticker
- [ ] Con dấu đặt lặp lại khi chạm nhiều lần
- [ ] Hoàn tác được việc đặt sticker hoặc con dấu (cùng lịch sử hoàn tác với các nét vẽ)
- [ ] Sticker và con dấu được lưu cùng tranh và còn nguyên khi mở lại từ phòng triển lãm
- [ ] Sticker đã đặt trở thành một phần của tranh: không có lớp, không di chuyển lại được

---

## Implementation Notes

- Sticker và con dấu là dữ liệu (asset), không viết cứng.
- Đặt sticker "in" thẳng vào ảnh tranh, đúng với quyết định không dùng lớp.
- Dùng định dạng lưu của story 005.

---

## Out of Scope

- Layer, di chuyển hoặc xoay sticker sau khi đặt (ngoài phạm vi theo brief)
- Story 007: kiểu dáng hoàn chỉnh của kho sticker

---

## Files

- `src/stickers/sticker_library.gd` — created (load, rasterise, bounded cache)
- `src/ui/sticker_tray.gd` — created (size row, thumbnail strip)
- `assets/data/stickers.json` — created (16 stickers, 5 stamps)
- `assets/art/stickers/*.svg`, `assets/art/stamps/*.svg` — created (placeholder art)
- `src/drawing/canvas.gd` — modified (set_sticker, _place_sticker, _mark_dirty)
- `src/ui/tool_panel.gd`, `src/drawing/drawing_canvas.tscn`, `assets/data/drawing_tools.json` — modified (Stickers button, tray, eraser link)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- A retained screenshot of each screen touched, in `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/pencil-pro/story-001-drawing-canvas.md`, `story-002-palette-and-pens.md`, `story-005-autosave-gallery.md`
- Unlocks: `story-007-kid-friendly-ui.md`
