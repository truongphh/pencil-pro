# Story 007: Giao diện cho bé: nút to, ít chữ, âm thanh

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7 — giao diện cho bé: nút to, ít chữ, biểu tượng rõ

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 7 and its art & audio direction:*

- [ ] Màn hình chính có 3 lối vào rõ ràng: Tô tranh, Vẽ tự do, Phòng triển lãm
- [ ] Mọi nút bấm từ 64×64 pt trở lên và cách nhau đủ để bé chạm không nhầm
- [ ] Mọi chức năng có biểu tượng dễ hiểu; chữ chỉ dùng cho tên rất ngắn
- [ ] Nút quay lại luôn ở cùng một góc ở mọi màn hình
- [ ] Phong cách hiện đại, bo tròn, màu pastel tươi sáng nhất quán ở mọi màn hình
- [ ] Có âm thanh nhẹ khi chọn màu và khi lưu tranh
- [ ] Có nút tắt tiếng dễ thấy
- [ ] Không có liên kết hay nút nào dẫn ra khỏi app

---

## Implementation Notes

- Dùng một Theme của Godot cho toàn app để kiểu dáng nhất quán; giá trị kích thước, màu là dữ liệu.
- Áp dụng cho các màn hình của stories 002, 003, 004, 005, 006.
- Kiểm tra bằng ảnh chụp từng màn hình trên iPad thật.

---

## Out of Scope

- Hoạt hình "tranh sống dậy", kể chuyện (ngoài phạm vi theo brief)
- Đa ngôn ngữ, khả năng tiếp cận nâng cao (chưa thuộc MVP)

---

## Files

- `src/ui/app_theme.gd` — created (theme built from data)
- `src/ui/icon_button.gd`, `src/ui/mute_button.gd`, `src/ui/ui_sounds.gd` — created
- `assets/data/ui_theme.json`, `assets/data/ui_sounds.json`, `assets/audio/README.md` — created
- `assets/art/icons/*.svg` — created (13 placeholder icons)
- `src/screens/*.gd`, `src/screens/*.tscn` — modified (theme, Home top-left, mute, sounds)
- `src/drawing/drawing_canvas.tscn`, `src/ui/tool_panel.gd`, `src/ui/sticker_tray.gd`, `src/coloring/coloring_library.gd` — modified
- `assets/data/drawing_tools.json`, `coloring_pages.json`, `save_config.json` — modified

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

- Depends on: `production/epics/pencil-pro/story-002-palette-and-pens.md`, `story-003-blank-page.md`, `story-004-coloring-pages.md`, `story-005-autosave-gallery.md`, `story-006-stickers-stamps.md`
- Unlocks: None
