class_name AudioServiceNode
extends Node
## Plays sound effects and music on separate buses ("SFX" and "Music",
## defined in default_bus_layout.tres). The sound setting mutes the effects,
## the music setting the music.

const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const SFX_VOICES: int = 8

## Shared UI click, used by TapButton.
var click_sound: AudioStreamWAV = Tones.click()

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	SettingsService.changed.connect(_apply_settings)
	_apply_settings()


func _exit_tree() -> void:
	stop_all()


## Stops every voice. The audio thread frees the playbacks on its next mix.
func stop_all() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
	_music_player.stop()


func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var player: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_bus_volume(bus: StringName, linear: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), linear)


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not SettingsService.is_sound_enabled())
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not SettingsService.is_music_enabled())
