# Story 005: Tự động lưu và phòng triển lãm

> **Epic**: pencil-pro
> **Status**: In Progress
> **Layer**: N/A (minimal)
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-08

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — tự động lưu và phòng triển lãm xem lại tranh

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the brief's MVP feature 6 and "Player goal & fail state" ("không có thao tác nào làm mất tranh"):*

- [ ] Tranh tự lưu khi bé thoát khỏi màn hình vẽ và khi app chuyển vào nền, không cần bấm nút lưu
- [ ] Đóng hẳn rồi mở lại app, mọi tranh đã lưu còn nguyên, kể cả màu và nét
- [ ] Phòng triển lãm hiển thị ảnh thu nhỏ của mọi tranh, tranh mới nhất đứng đầu
- [ ] Chạm một tranh trong phòng triển lãm thì mở lại và tô tiếp được
- [ ] Phòng triển lãm cuộn mượt với 50 tranh
- [ ] Lưu lỗi (ví dụ đầy bộ nhớ) hiện thông báo thân thiện và không làm mất tranh đang có trong bộ nhớ
- [ ] Không có thao tác nào trong app xóa tranh đã lưu

---

## Implementation Notes

- Định dạng lưu phải ghi được cả tranh tô (nền tranh + lớp màu) và tranh trắng; story 006 sẽ thêm sticker vào cùng định dạng, nên chừa chỗ.
- Lưu vào thư mục dữ liệu người dùng của Godot (`user://`).
- Lưu ảnh thu nhỏ riêng để phòng triển lãm không phải nạp ảnh lớn.
- Mức `minimal`: không có ADR; ghi lại quyết định định dạng lưu trong story khi làm.
- **Định dạng lưu đã chọn (v1, 2026-11-08):** mỗi tranh một thư mục `user://drawings/<id>/` gồm `color.png` (chỉ lớp màu, kích thước canvas, không có viền), `thumbnail.png` (256×192, màu + viền) và `drawing.json` (`version`, `id`, `page_id` hoặc null, `created`/`updated` theo mili giây Unix). Ghi ra `.tmp` rồi đổi tên, `drawing.json` đổi tên sau cùng. Trang mới chưa vẽ gì thì không lưu. Lưu lỗi thì giữ trang mở và báo thân thiện (người dùng chọn). Chi tiết ở đầu `src/save/save_manager.gd`.

---

## Out of Scope

- Chia sẻ, xuất ra ngoài app, tài khoản, đồng bộ đám mây (ngoài phạm vi theo brief)
- Xóa tranh
- Story 006: sticker (chỉ chừa chỗ trong định dạng)

---

## Files

- `src/save/save_manager.gd` — created (save format v1, atomic writes, list/load, no delete)
- `src/screens/gallery_screen.gd`, `.tscn` — created (thumbnail grid, newest first)
- `assets/data/save_config.json` — created
- `src/drawing/canvas.gd` — modified (load_color_image, get_color_image, get_revision)
- `src/screens/drawing_page.gd`, `app_root.gd`, `app_root.tscn`, `home_screen.gd`, `home_screen.tscn`, `coloring_library_screen.gd` — modified (autosave, gallery wiring, page_id)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/pencil-pro/autosave_gallery_test.gd` OR a documented playtest. At `qa.level: minimal` tests are waived (advisory).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/pencil-pro/story-001-drawing-canvas.md`, `story-003-blank-page.md`, `story-004-coloring-pages.md`
- Unlocks: `story-006-stickers-stamps.md`, `story-007-kid-friendly-ui.md`
