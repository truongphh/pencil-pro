# Story 002: Bảng màu lớn và 3 loại bút

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 — bảng màu lớn và 3 loại bút (bút chì, cọ, bút dạ)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 2 and its art direction:*

- [ ] Có ít nhất 12 màu, mỗi nút màu từ 64×64 pt trở lên, màu pastel tươi sáng
- [ ] Có 3 loại bút nhìn khác nhau rõ: bút chì (mảnh), cọ (mềm), bút dạ (đậm)
- [ ] Chọn màu chỉ áp dụng cho nét kế tiếp, không đổi màu nét đã vẽ
- [ ] Màu và bút đang chọn luôn hiển thị rõ ràng
- [ ] Khi mở màn hình vẽ lần đầu có sẵn một bút và một màu mặc định
- [ ] Đổi màu hoặc bút không làm mất hay thay đổi tranh đang vẽ

---

## Implementation Notes

- Màu và thuộc tính bút (độ dày, độ mềm) là dữ liệu, đặt trong file cấu hình, không viết cứng trong code.
- Dùng khung vẽ của story 001; không đổi cách nhận input.

---

## Out of Scope

- Story 001: nét vẽ, hoàn tác, tẩy
- Story 007: kiểu dáng hoàn chỉnh, âm thanh khi chọn màu

---

## Files

- `src/ui/tool_panel.gd` — created
- `src/drawing/canvas.gd` — modified (colour and pen setters, stamp hardness, bounded cache)
- `src/drawing/drawing_canvas.tscn` — modified (ToolPanel node)
- `assets/data/drawing_tools.json` — created
- `assets/data/drawing_config.json` — modified (brush keys removed, stamp_cache_limit added)

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

- Depends on: `production/epics/pencil-pro/story-001-drawing-canvas.md`
- Unlocks: `story-003-blank-page.md`, `story-004-coloring-pages.md`, `story-006-stickers-stamps.md`
