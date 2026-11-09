# Epic: pencil-pro

> **Source**: `design/game-brief.md` (minimal tier — no GDD, ADRs or control manifest)
> **Engine**: Godot 4.7.2 (GDScript) · **Platform**: iPad · **Risk**: HIGH (post-cutoff engine, per `docs/engine-reference/godot/VERSION.md`)

## Goal

Một xưởng tô màu và vẽ tự do trên iPad, nơi bé tô tranh có sẵn hoặc tự vẽ bằng ngón tay hay Apple Pencil, rồi trưng bày mọi tác phẩm trong phòng triển lãm riêng của mình.

## Scope

The brief's MVP list, one story per item:

- Khung vẽ cảm ứng mượt (ngón tay, Apple Pencil), hoàn tác và tẩy
- Bảng màu lớn và 3 loại bút
- Thư viện khoảng 10 tranh tô có sẵn, tô không tràn viền
- Trang giấy trắng để vẽ tự do
- Kho sticker và con dấu đơn giản
- Tự động lưu và phòng triển lãm
- Giao diện cho bé: nút to, ít chữ, biểu tượng rõ

Out of scope: see the brief (no accounts or sharing, no ads or purchases, no animation or storytelling, no layers, iPad only).

## Build order

Follows the brief: drawing feel first (riskiest: Apple Pencil input and fill speed), then coloring pages, save and gallery, stickers, then UI polish.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Khung vẽ cảm ứng: nét vẽ, Apple Pencil, hoàn tác, tẩy | Visual/Feel | Ready | N/A |
| 002 | Bảng màu lớn và 3 loại bút | UI | Ready | N/A |
| 003 | Trang giấy trắng để vẽ tự do | UI | Ready | N/A |
| 004 | Thư viện 10 tranh tô, tô không tràn viền | Logic | Ready | N/A |
| 005 | Tự động lưu và phòng triển lãm | Integration | Ready | N/A |
| 006 | Kho sticker và con dấu | UI | Ready | N/A |
| 007 | Giao diện cho bé: nút to, ít chữ, âm thanh | UI | Ready | N/A |
