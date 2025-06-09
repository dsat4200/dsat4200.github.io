@tool
extends GridContainer

@export var textures: Array[Texture2D] = []:
	set(value):
		textures = value
		_update_grid() # Call update whenever the 'textures' array changes

func _ready():
	# Ensure the grid is updated when the scene loads (especially in game mode)
	if Engine.is_editor_hint():
		_update_grid()

func _update_grid():
	# Clear existing children to rebuild the grid
	for child in get_children():
		child.queue_free()

	if textures.is_empty():
		return

	# Determine grid dimensions from texture names
	var max_row = 0
	var max_col = 0
	var texture_map = {} # To store textures by their parsed row/column

	for texture in textures:
		if texture != null and texture.resource_path != "":
			var file_name = texture.resource_path.get_file().get_basename()
			var parts = file_name.split("-")
			if parts.size() == 4 and parts[0] == "row" and parts[2] == "column":
				var row_str = parts[1]
				var col_str = parts[3]
				if row_str.is_valid_int() and col_str.is_valid_int():
					var row = row_str.to_int()
					var col = col_str.to_int()

					max_row = maxi(max_row, row)
					max_col = maxi(max_col, col)

					if not texture_map.has(row):
						texture_map[row] = {}
					texture_map[row][col] = texture
				else:
					push_warning("Invalid row or column number in filename: %s" % file_name)
			else:
				push_warning("Texture filename does not match expected format 'row-X-column-Y': %s" % file_name)

	if max_row == 0 or max_col == 0:
		push_warning("Could not determine grid dimensions from texture names. Make sure names are 'row-X-column-Y'.")
		return

	# Set the number of columns for the GridContainer
	columns = max_col

	# Populate the grid with TextureRects in the correct order
	for r in range(1, max_row + 1):
		for c in range(1, max_col + 1):
			var texture_to_display: Texture2D = null
			if texture_map.has(r) and texture_map[r].has(c):
				texture_to_display = texture_map[r][c]
			else:
				push_warning("Missing texture for row %d, column %d. Placeholder will be used." % [r, c])

			var texture_rect = TextureRect.new()
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_TILE # This makes it seamless!
			texture_rect.texture = texture_to_display
			texture_rect.custom_minimum_size = Vector2(32, 32) # Set a default size or base it on image size
			texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # For pixel art, good for tiling

			add_child(texture_rect)

	# Request a redraw in the editor to ensure immediate visual update
	if Engine.is_editor_hint():
		queue_redraw()
