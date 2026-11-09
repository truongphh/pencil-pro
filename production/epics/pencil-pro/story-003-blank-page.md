# Story 003: Trang giấy trắng để vẽ tự do

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — trang giấy trắng để vẽ tự do

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 4 and core loop:*

- [ ] Từ màn hình chọn, bé mở được một trang giấy trắng, nền trắng, vừa màn hình iPad
- [ ] Trên trang trắng dùng được đầy đủ khung vẽ, bảng màu và bút (stories 001, 002)
- [ ] Mở trang trắng mới không còn nét nào của tranh trước
- [ ] Thoát khỏi trang trắng đang vẽ không làm mất nét đã vẽ (kết nối với tự lưu ở story 005)
- [ ] Có đường quay lại màn hình chọn từ trang trắng

---

## Implementation Notes

- Trang trắng dùng chung scene khung vẽ với tranh tô; khác nhau chỉ ở ảnh nền.

---

## Out of Scope

- Story 004: tranh tô có viền
- Story 005: lưu thực sự và phòng triển lãm
- Story 007: kiểu dáng màn hình chọn

---

## Files

- `src/screens/app_root.gd`, `src/screens/app_root.tscn` — created (screen switching, main scene)
- `src/screens/home_screen.gd`, `src/screens/home_screen.tscn` — created (placeholder selection screen)
- `src/screens/drawing_page.gd`, `src/screens/drawing_page.tscn` — created (page wrapping the drawing scene, Home button, drawing_closed signal)
- `src/drawing/canvas.gd` — modified (background_texture, get_image)

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

- Depends on: `production/epics/pencil-pro/story-001-drawing-canvas.md`, `story-002-palette-and-pens.md`
- Unlocks: `story-005-autosave-gallery.md`
