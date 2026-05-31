extends Node

signal generation_completed(new_state, generation)
signal state_updated(history)
signal cell_flipped(cell_index, new_value)

enum RuleMode {
	SINGLE,
	HYBRID,
	ALTERNATING,
	POSITIONAL
}

const DEFAULT_RULE: int = 30
const DEFAULT_WIDTH: int = 121
const PRESET_RULES: Array[int] = [30, 90, 110, 184, 45, 73, 150]

var rule: int = DEFAULT_RULE:
	set(value):
		rule = value
		_update_rule_pattern()

var rule_mode: int = RuleMode.SINGLE
var secondary_rule: int = 90
var hybrid_mix: float = 0.5
var rule_patterns: Dictionary = {}

var width: int = DEFAULT_WIDTH
var current_state: Array[int] = []
var history: Array[Array[int]] = []
var generation: int = 0
var rule_pattern: Array[bool] = []

var max_history: int = 100

func _init() -> void:
	_init_rule_patterns()
	_update_rule_pattern()
	reset()

func _init_rule_patterns() -> void:
	for r in PRESET_RULES:
		rule_patterns[r] = _create_rule_pattern(r)

func _create_rule_pattern(rule_num: int) -> Array[bool]:
	var pattern: Array[bool] = []
	for i in range(8):
		pattern.append(bool(rule_num & (1 << i)))
	return pattern

func _get_rule_pattern_for_cell(cell_index: int, gen: int) -> Array[bool]:
	match rule_mode:
		RuleMode.SINGLE:
			return rule_pattern
		RuleMode.HYBRID:
			if randf() < hybrid_mix:
				return rule_pattern
			else:
				return _get_or_create_pattern(secondary_rule)
		RuleMode.ALTERNATING:
			if gen % 2 == 0:
				return rule_pattern
			else:
				return _get_or_create_pattern(secondary_rule)
		RuleMode.POSITIONAL:
			var mid = width / 2
			if cell_index < mid:
				return rule_pattern
			else:
				return _get_or_create_pattern(secondary_rule)
	return rule_pattern

func _get_or_create_pattern(rule_num: int) -> Array[bool]:
	if not rule_patterns.has(rule_num):
		rule_patterns[rule_num] = _create_rule_pattern(rule_num)
	return rule_patterns[rule_num]

func _update_rule_pattern() -> void:
	rule_pattern = _create_rule_pattern(rule)

func reset(initial_state: Array[int] = []) -> void:
	generation = 0
	history = []
	current_state = []
	
	if initial_state.is_empty():
		for i in range(width):
			current_state.append(1 if i == width / 2 else 0)
	else:
		current_state = initial_state.duplicate()
	
	history.append(current_state.duplicate())
	emit_signal("state_updated", history)

func step() -> void:
	var new_state: Array[int] = []
	
	for i in range(width):
		var left: int = current_state[wrap_index(i - 1)]
		var center: int = current_state[i]
		var right: int = current_state[wrap_index(i + 1)]
		
		var pattern_index: int = (left << 2) | (center << 1) | right
		var current_pattern = _get_rule_pattern_for_cell(i, generation)
		new_state.append(1 if current_pattern[pattern_index] else 0)
	
	current_state = new_state
	generation += 1
	
	history.append(current_state.duplicate())
	if history.size() > max_history:
		history.pop_front()
	
	emit_signal("generation_completed", current_state, generation)
	emit_signal("state_updated", history)

func flip_cell(cell_index: int) -> void:
	if cell_index >= 0 and cell_index < width:
		current_state[cell_index] = 1 - current_state[cell_index]
		history[-1] = current_state.duplicate()
		emit_signal("cell_flipped", cell_index, current_state[cell_index])
		emit_signal("state_updated", history)

func wrap_index(index: int) -> int:
	if index < 0:
		return width + index
	elif index >= width:
		return index - width
	return index

func get_active_cells() -> Array[int]:
	var active: Array[int] = []
	for i in range(width):
		if current_state[i] == 1:
			active.append(i)
	return active

func set_random_rule() -> void:
	rule = randi() % 256

func set_random_rules() -> void:
	rule = randi() % 256
	secondary_rule = randi() % 256

func get_rule_name() -> String:
	match rule_mode:
		RuleMode.SINGLE:
			return _get_single_rule_name(rule)
		RuleMode.HYBRID:
			return "Hybrid: %d + %d" % [rule, secondary_rule]
		RuleMode.ALTERNATING:
			return "Alternating: %d / %d" % [rule, secondary_rule]
		RuleMode.POSITIONAL:
			return "Positional: L=%d R=%d" % [rule, secondary_rule]
	return "Rule %d" % rule

func _get_single_rule_name(rule_num: int) -> String:
	match rule_num:
		30:
			return "Rule 30 (Chaos)"
		90:
			return "Rule 90 (Sierpinski)"
		110:
			return "Rule 110 (Turing Complete)"
		184:
			return "Rule 184 (Traffic)"
		45:
			return "Rule 45 (XOR)"
		73:
			return "Rule 73"
		150:
			return "Rule 150"
		_:
			return "Rule %d" % rule_num
