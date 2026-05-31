extends Control

signal cell_clicked(cell_index)

var cell_size: int = 8
var history: Array[Array[int]] = []
var highlight_cells: Array[int] = []
var highlight_timer: float = 0.0
var flipped_cells: Dictionary = {}
var mouse_down: bool = false

var colors: Array[Color] = [
	Color(0.1, 0.1, 0.15),
	Color(0.4, 0.8, 1.0),
	Color(1.0, 0.5, 0.5),
	Color(0.5, 1.0, 0.5),
	Color(1.0, 1.0, 0.5),
	Color(1.0, 0.5, 1.0)
]

func _ready() -> void:
	queue_redraw()
	mouse_filter = Control.MOUSE_FILTER_STOP

func update_history(new_history: Array[Array[int]]) -> void:
	history = new_history
	queue_redraw()

func highlight_active_cells(active_cells: Array[int]) -> void:
	highlight_cells = active_cells
	highlight_timer = 0.3
	queue_redraw()

func _process(delta: float) -> void:
	if highlight_timer > 0:
		highlight_timer -= delta
		queue_redraw()

func _draw() -> void:
	if history.is_empty():
		return
	
	var ca_width = history[0].size()
	var total_height = history.size() * cell_size
	
	var start_x = (size.x - ca_width * cell_size) / 2
	var start_y = size.y - total_height
	
	for gen_idx in range(history.size()):
		var generation = history[gen_idx]
		var y = start_y + gen_idx * cell_size
		
		for cell_idx in range(ca_width):
			var x = start_x + cell_idx * cell_size
			
			if generation[cell_idx] == 1:
				var color_idx = (gen_idx + cell_idx) % (colors.size() - 1) + 1
				var col = colors[color_idx]
				
				if highlight_timer > 0 and gen_idx == history.size() - 1:
					if highlight_cells.has(cell_idx):
						col = Color(1, 1, 1)
						col = col.lerp(colors[color_idx], 1.0 - highlight_timer * 3.0)
				
				draw_rect(Rect2(x, y, cell_size - 1, cell_size - 1), col)
			else:
				draw_rect(Rect2(x, y, cell_size - 1, cell_size - 1), colors[0])

func set_cell_size(new_size: int) -> void:
	cell_size = new_size
	queue_redraw()

func _get_cell_at_position(position: Vector2) -> int:
	if history.is_empty():
		return -1
	
	var ca_width = history[0].size()
	var total_height = history.size() * cell_size
	
	var start_x = (size.x - ca_width * cell_size) / 2
	var start_y = size.y - total_height
	
	var cell_x = int((position.x - start_x) / cell_size)
	var cell_y = int((position.y - start_y) / cell_size)
	
	if cell_x >= 0 and cell_x < ca_width and cell_y >= 0 and cell_y < history.size():
		return cell_x
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = mb.pressed
			if mb.pressed:
				var cell_idx = _get_cell_at_position(mb.position)
				if cell_idx >= 0:
					emit_signal("cell_clicked", cell_idx)
	
	elif event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		if mouse_down:
			var cell_idx = _get_cell_at_position(mm.position)
			if cell_idx >= 0:
				emit_signal("cell_clicked", cell_idx)
