extends Control

@onready var ca_visualizer: Control = $MainContainer/CAVisualizer
@onready var music_generator: Node = $MusicGenerator
@onready var cellular_automaton: Node = $CellularAutomaton

@onready var rule_label: Label = $ControlPanel/VBoxContainer/TopRow/RuleContainer/RuleLabel
@onready var rule_slider: HSlider = $ControlPanel/VBoxContainer/TopRow/RuleContainer/RuleSlider
@onready var speed_slider: HSlider = $ControlPanel/VBoxContainer/TopRow/SpeedContainer/SpeedSlider
@onready var generation_label: Label = $ControlPanel/VBoxContainer/TopRow/GenerationLabel

@onready var scale_option: OptionButton = $ControlPanel/VBoxContainer/BottomRow/ScaleOption
@onready var rule_mode_option: OptionButton = $ControlPanel/VBoxContainer/MiddleRow/RuleModeOption
@onready var secondary_rule_slider: HSlider = $ControlPanel/VBoxContainer/MiddleRow/SecondaryRuleContainer/SecondaryRuleSlider
@onready var pause_button: Button = $ControlPanel/VBoxContainer/BottomRow/PauseButton
@onready var reset_button: Button = $ControlPanel/VBoxContainer/BottomRow/ResetButton
@onready var random_rule_button: Button = $ControlPanel/VBoxContainer/BottomRow/RandomRuleButton
@onready var mute_button: Button = $ControlPanel/VBoxContainer/BottomRow/MuteButton

var is_paused: bool = false
var is_muted: bool = false
var step_timer: float = 0.0
var step_interval: float = 0.2
var last_flipped_cell: int = -1

func _ready() -> void:
	_setup_connections()
	_populate_scale_options()
	_populate_rule_mode_options()
	_update_ui()

func _setup_connections() -> void:
	cellular_automaton.generation_completed.connect(_on_generation_completed)
	cellular_automaton.state_updated.connect(_on_state_updated)
	cellular_automaton.cell_flipped.connect(_on_cell_flipped)
	
	ca_visualizer.cell_clicked.connect(_on_cell_clicked)
	
	rule_slider.value_changed.connect(_on_rule_changed)
	secondary_rule_slider.value_changed.connect(_on_secondary_rule_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	scale_option.item_selected.connect(_on_scale_selected)
	rule_mode_option.item_selected.connect(_on_rule_mode_selected)
	
	pause_button.pressed.connect(_on_pause_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	random_rule_button.pressed.connect(_on_random_rule_pressed)
	mute_button.pressed.connect(_on_mute_pressed)

func _populate_scale_options() -> void:
	var scales = music_generator.get_available_scales()
	scale_option.clear()
	for scale in scales:
		scale_option.add_item(scale)
	scale_option.select(0)

func _populate_rule_mode_options() -> void:
	rule_mode_option.clear()
	rule_mode_option.add_item("Single Rule")
	rule_mode_option.add_item("Hybrid Mix")
	rule_mode_option.add_item("Alternating")
	rule_mode_option.add_item("Positional")
	rule_mode_option.select(0)

func _process(delta: float) -> void:
	if not is_paused:
		step_timer += delta
		if step_timer >= step_interval:
			step_timer = 0.0
			cellular_automaton.step()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		_on_pause_pressed()
	elif event.is_action_pressed("reset"):
		_on_reset_pressed()

func _on_generation_completed(new_state: Array[int], generation: int) -> void:
	generation_label.text = "Generation: %d" % generation
	
	if not is_muted:
		music_generator.play_state(new_state, cellular_automaton.width)
		ca_visualizer.highlight_active_cells(cellular_automaton.get_active_cells())

func _on_state_updated(history: Array[Array[int]]) -> void:
	ca_visualizer.update_history(history)

func _on_rule_changed(value: float) -> void:
	cellular_automaton.rule = int(value)
	_update_ui()

func _on_speed_changed(value: float) -> void:
	step_interval = 0.5 / value
	_update_ui()

func _on_scale_selected(index: int) -> void:
	var scale_name = scale_option.get_item_text(index)
	music_generator.set_scale(scale_name)

func _on_pause_pressed() -> void:
	is_paused = not is_paused
	pause_button.text = "Resume" if is_paused else "Pause"

func _on_reset_pressed() -> void:
	cellular_automaton.reset()
	step_timer = 0.0
	_update_ui()

func _on_random_rule_pressed() -> void:
	cellular_automaton.set_random_rule()
	rule_slider.value = cellular_automaton.rule
	_update_ui()

func _on_mute_pressed() -> void:
	is_muted = not is_muted
	mute_button.text = "Unmute" if is_muted else "Mute"

func _on_cell_clicked(cell_index: int) -> void:
	if cell_index != last_flipped_cell:
		last_flipped_cell = cell_index
		cellular_automaton.flip_cell(cell_index)

func _on_cell_flipped(cell_index: int, new_value: int) -> void:
	if not is_muted and new_value == 1:
		var state = cellular_automaton.current_state
		music_generator.play_state(state, cellular_automaton.width)

func _play_flip_sound(cell_index: int) -> void:
	if not is_muted:
		var state = cellular_automaton.current_state.duplicate()
		var temp_state: Array[int] = []
		for i in range(cellular_automaton.width):
			temp_state.append(1 if i == cell_index else 0)
		music_generator.play_state(temp_state, cellular_automaton.width)

func _on_secondary_rule_changed(value: float) -> void:
	cellular_automaton.secondary_rule = int(value)
	_update_ui()

func _on_rule_mode_selected(index: int) -> void:
	cellular_automaton.rule_mode = index
	secondary_rule_slider.visible = (index > 0)
	_update_ui()

func _update_ui() -> void:
	rule_label.text = cellular_automaton.get_rule_name()
	generation_label.text = "Generation: %d" % cellular_automaton.generation
