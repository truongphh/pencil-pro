# UI sounds

The app plays two gentle sounds. Their paths are set in `assets/data/ui_sounds.json`;
until a file exists the app simply stays silent for that sound.

| File | When it plays | Suggested feel |
|---|---|---|
| `color_pick.ogg` | the child taps a colour | short (under 0.3 s), soft "blip" or bubble pop |
| `saved.ogg` | a changed picture is saved when the child taps Home | short (under 1 s), happy chime |

Format: Ogg Vorbis (`.ogg`), mono or stereo, 44.1 or 48 kHz, peak around -6 dBFS,
no silence at the start. Open the project in the Godot editor once after adding a
file so it is imported (the app checks `ResourceLoader.exists`, which needs the import).
To use another name or format (e.g. `.wav`), change the path in `ui_sounds.json`.
