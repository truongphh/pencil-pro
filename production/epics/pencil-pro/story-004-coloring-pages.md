# Story 004: Thư viện 10 tranh tô, tô không tràn viền

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — thư viện khoảng 10 tranh tô có sẵn, tô không tràn viền

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 3 and "Player goal & fail state":*

- [ ] Thư viện có ít nhất 10 tranh nét viền đen trên nền trắng, bé chọn được một tranh để mở
- [ ] Tô trong một vùng kín không làm màu tràn sang vùng bên cạnh
- [ ] Viền đen luôn hiển thị trên cùng, không bị màu tô che
- [ ] Đổ màu cả một vùng bằng một chạm, mất dưới 1 giây trên iPad thật
- [ ] Mọi tranh trong thư viện có các vùng kín (kiểm tra bằng test trên dữ liệu tranh), để đổ màu không tràn cả tranh
- [ ] Hoàn tác được thao tác đổ màu (cùng lịch sử hoàn tác với story 001)
- [ ] Mở một tranh tô khác không còn màu của tranh trước

---

## Implementation Notes

*Web research 2026-11-08, NOT verified on Godot 4.7.2 — measure on a real iPad:*

- Đổ màu bằng CPU trong GDScript là chậm nhưng dùng được; một nhà phát triển báo dưới 1 giây ở trường hợp xấu nhất.
- Chậm nhất là gọi `get_pixel`/`set_pixel` từng điểm. Dùng hàng đợi và bản đồ "đã duyệt", giữ canvas ở kích thước vừa phải.
- Shader không hợp với flood fill (đó là thuật toán tìm kiếm); chỉ dùng shader để hiển thị.
- Viền bị răng cưa có thể làm màu rò: thử ngưỡng màu khi so điểm ảnh.
- Tranh tô là dữ liệu (asset), không viết cứng.

---

## Out of Scope

- Story 001/002: nét vẽ tự do, bảng màu, bút
- Story 005: lưu tranh đã tô

---

## Files

- `src/coloring/flood_fill.gd` — created (region grid, region masks)
- `src/coloring/coloring_library.gd` — created (page list, closed-region validate())
- `src/screens/coloring_library_screen.gd`, `.tscn` — created (thumbnail grid)
- `assets/data/coloring_pages.json` — created
- `assets/art/coloring_pages/*.svg` — created (10 placeholder pages)
- `src/drawing/canvas.gd` — modified (line-art overlay, fill, clipped strokes)
- `src/screens/drawing_page.gd`, `app_root.gd`, `app_root.tscn`, `home_screen.gd`, `home_screen.tscn` — modified (library wiring)
- `src/ui/tool_panel.gd` — modified (Fill button)
- `assets/data/drawing_config.json`, `assets/data/drawing_tools.json` — modified (region and fill keys)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/pencil-pro/coloring_pages_test.gd` — must exist (`/story-done` checks it EXISTS; pass/fail is established later by `/gate-check` and `/smoke-check`). At `qa.level: minimal` tests are waived (advisory).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/pencil-pro/story-001-drawing-canvas.md`, `story-002-palette-and-pens.md`
- Unlocks: `story-005-autosave-gallery.md`
