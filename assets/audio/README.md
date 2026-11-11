# App audio

Paths and volumes are set in `assets/data/ui_sounds.json`; a missing file is skipped
silently. All three files are synthesized placeholders, regenerated with
`python3 tools/audio/generate_sounds.py` (needs numpy).

| File | When it plays | Feel |
|---|---|---|
| `music_loop.wav` | from app start, looping, until muted | gentle music-box tune, C major, ~21 s |
| `color_pick.wav` | the child taps a colour | short (0.15 s) bubble blip |
| `saved.wav` | a changed picture is saved when the child taps Home | happy chime, ~1 s |

The one Mute button silences all three. To swap in real audio, drop the file here
(`.ogg`, `.wav` or `.mp3`), open the project in the Godot editor once so it is imported,
and change the path in `ui_sounds.json` if the name or format differs.
