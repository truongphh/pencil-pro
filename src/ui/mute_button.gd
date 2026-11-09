class_name MuteButton
extends IconButton
## Toggle that mutes and unmutes the UI sounds: pressed = muted, with the sound_off
## icon; released shows sound_on. Follows mute changes made from any other
## MuteButton, so the home screen and the drawing page always agree.
## Implements: story-007-kid-friendly-ui.md (AC "an easy-to-see mute button").


## Connects the button to [param sounds]. Call once, after the button is ready.
func setup(sounds: UiSounds) -> void:
	toggle_mode = true
	_show_state(sounds.is_muted())
	sounds.muted_changed.connect(_show_state)
	toggled.connect(sounds.set_muted)


func _show_state(muted: bool) -> void:
	set_pressed_no_signal(muted)
	icon = get_theme_icon(&"sound_off" if muted else &"sound_on", AppTheme.ICONS_TYPE)
