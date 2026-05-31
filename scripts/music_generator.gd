extends Node

signal note_played(pitch, velocity, cell_index)

const BASE_NOTE: float = 48.0
const MAX_ACTIVE_NOTES: int = 12
const MAX_OUTPUT_AMPLITUDE: float = 0.5

const SCALES: Dictionary = {
	"pentatonic_major": [0, 2, 4, 7, 9],
	"pentatonic_minor": [0, 3, 5, 7, 10],
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"blues": [0, 3, 5, 6, 7, 10],
	"whole_tone": [0, 2, 4, 6, 8, 10],
	"chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
}

var current_scale: String = "pentatonic_major"
var octaves: int = 3
var base_note: float = BASE_NOTE
var volume: float = 0.5

var audio_player: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0
var phase: float = 0.0
var active_notes: Dictionary = {}

var last_played_notes: Array = []
var note_cooldown: Dictionary = {}

func _ready() -> void:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.2
	
	var player = AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = linear_to_db(volume)
	add_child(player)
	player.play()
	
	audio_player = player.get_stream_playback()
	_fill_buffer()

func _process(delta: float) -> void:
	if audio_player:
		_fill_buffer()

func _fill_buffer() -> void:
	var to_fill = audio_player.get_frames_available()
	var max_fill = int(sample_rate * 0.05)
	to_fill = min(to_fill, max_fill)
	
	for i in range(to_fill):
		var sample = _generate_sample()
		audio_player.push_frame(Vector2(sample, sample))

func _generate_sample() -> float:
	var output: float = 0.0
	var notes_to_remove: Array = []
	var note_count: int = active_notes.size()
	
	if note_count == 0:
		phase += 1.0 / sample_rate
		return 0.0
	
	var normalization_factor: float = 1.0 / sqrt(max(1.0, float(note_count)))
	
	for note_info in active_notes.values():
		var freq: float = note_info["freq"]
		var env: float = note_info["envelope"]
		var wave_type: int = note_info["wave_type"]
		
		var sample: float = 0.0
		match wave_type:
			0:
				sample = sin(phase * freq * 2.0 * PI)
			1:
				sample = 2.0 * fmod(phase * freq, 1.0) - 1.0
			2:
				sample = 1.0 - 4.0 * abs(round(phase * freq - 0.25) - (phase * freq - 0.25))
		
		output += sample * env * normalization_factor
		
		note_info["envelope"] *= 0.995
		if note_info["envelope"] < 0.005:
			notes_to_remove.append(note_info["pitch"])
	
	for pitch in notes_to_remove:
		active_notes.erase(pitch)
	
	phase += 1.0 / sample_rate
	return clamp(output * 0.4, -MAX_OUTPUT_AMPLITUDE, MAX_OUTPUT_AMPLITUDE)

func play_state(state: Array[int], ca_width: int) -> void:
	var scale_notes = SCALES[current_scale]
	var notes_in_scale = scale_notes.size()
	var total_notes = notes_in_scale * octaves
	
	var new_notes: Array = []
	
	for i in range(ca_width):
		if state[i] == 1:
			var note_position = float(i) / float(ca_width)
			var note_index = int(note_position * total_notes)
			
			var octave = note_index / notes_in_scale
			var scale_degree = note_index % notes_in_scale
			
			var midi_note = base_note + octave * 12 + scale_notes[scale_degree]
			
			if not new_notes.has(midi_note):
				new_notes.append({
					"midi_note": midi_note,
					"velocity": 0.3 + note_position * 0.7,
					"freq": _midi_to_freq(midi_note),
					"cell_index": i
				})
	
	_limit_and_play_notes(new_notes)

func _limit_and_play_notes(new_notes: Array) -> void:
	var notes_added: int = 0
	
	for note in new_notes:
		var midi_note = note["midi_note"]
		var velocity = note["velocity"]
		var freq = note["freq"]
		var cell_index = note["cell_index"]
		
		if notes_added >= MAX_ACTIVE_NOTES:
			break
		
		if active_notes.has(midi_note):
			active_notes[midi_note]["envelope"] = max(active_notes[midi_note]["envelope"], velocity)
			notes_added += 1
		else:
			if active_notes.size() < MAX_ACTIVE_NOTES:
				active_notes[midi_note] = {
					"freq": freq,
					"envelope": velocity,
					"pitch": midi_note,
					"wave_type": randi() % 3
				}
				notes_added += 1
		
		emit_signal("note_played", midi_note, velocity, cell_index)

func _midi_to_freq(midi_note: float) -> float:
	return 440.0 * pow(2.0, (midi_note - 69.0) / 12.0)

func set_scale(scale_name: String) -> void:
	if SCALES.has(scale_name):
		current_scale = scale_name

func get_available_scales() -> Array:
	return SCALES.keys()

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log10(linear)
