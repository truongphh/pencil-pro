# Story 001: Khung vẽ cảm ứng: nét vẽ, Apple Pencil, hoàn tác, tẩy

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — khung vẽ cảm ứng mượt (ngón tay, hỗ trợ Apple Pencil), có hoàn tác và xóa

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 1 and "Player goal & fail state":*

- [ ] Nét vẽ bằng ngón tay xuất hiện liên tục theo ngón tay, không đứt đoạn khi vẽ nhanh
- [ ] Apple Pencil được nhận; nếu đọc được lực nhấn thì nét đổi theo lực, nếu không thì dùng nét cố định; kết quả kiểm chứng (đọc được hay không, trên Godot 4.7.2) được ghi lại trong evidence
- [ ] Phân biệt được Pencil và ngón tay, hoặc ghi lại rằng không phân biệt được
- [ ] Hoàn tác được ít nhất 20 nét liên tiếp
- [ ] Tẩy xóa được nét đã vẽ
- [ ] Nhiều ngón chạm cùng lúc không làm treo app hay mất tranh
- [ ] Giữ ít nhất 55 fps khi vẽ liên tục, đo trên iPad thật
- [ ] Không thao tác nào trong story này làm mất tranh ngoài ý muốn (mọi nét đều hoàn tác được)

---

## Implementation Notes

*Web research 2026-11-08, NOT verified on Godot 4.7.2 — confirm in this story's prototype:*

- Ngón tay và Pencil đều đến qua `InputEventScreenDrag`, có `pressure` (0.0–1.0), `tilt` và `pen_inverted`.
- Một bài đăng diễn đàn (Godot 4.1–4.2.1) nói phân biệt bút với ngón tay bằng `is_nan(event.pressure)`; cần kiểm lại trên 4.7.2.
- Hướng thông thường: vẽ lên một `Image` hoặc `SubViewport`, hiển thị bằng texture. Nội suy giữa các điểm để nét không đứt.
- Tra `docs/engine-reference/godot/modules/input.md` trước khi dùng bất kỳ API input nào.
- Đây là rủi ro lớn nhất của dự án: nếu Pencil không dùng được, ghi lại và báo để cân nhắc đổi engine.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: bảng màu và loại bút (story này dùng một màu và một nét mặc định)
- Story 004: tô tranh có sẵn và đổ màu vùng
- Story 005: lưu tranh

---

## Files

- `src/drawing/canvas.gd` — created
- `src/drawing/stroke_history.gd` — created
- `src/drawing/drawing_canvas.tscn` — created
- `assets/data/drawing_config.json` — created

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained screenshot (and, for the Pencil check, a note of the result) in `production/qa/evidence/` + sign-off in `production/qa/evidence/drawing-canvas-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/pencil-pro/story-002-palette-and-pens.md`, `story-003-blank-page.md`, `story-004-coloring-pages.md`, `story-005-autosave-gallery.md`, `story-006-stickers-stamps.md`
