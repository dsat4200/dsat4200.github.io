@tool
extends Node2D

# This script runs in the Godot editor thanks to the "@tool" annotation.
# It loads a 4x4 grid of images and arranges them to look like one large image.
# The images should be named like "row-1-column-1.png", "row-1-column-2.png", etc.
#
# To refresh the view in the editor if you change the images, you can either:
# 1. Right-click the script in the FileSystem dock and choose "Reload".
# 2. Toggle the script on/off in the Inspector.

func _ready():
	# We call our setup function here.
	_assemble_image()

func _assemble_image():
	# --- Cleanup for Editor ---
	# First, remove any sprites that were previously created by this script.
	# This is important for @tool scripts to prevent creating duplicate nodes.
	# We loop backwards because we are removing items from the array we're iterating.
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		# A check to make sure we only remove sprites, in case you add other nodes.
		if child is Sprite2D:
			child.queue_free()

	# The folder where your split images are stored.
	var image_folder = "res://images/"

	# The base name of your image files.
	var base_name = "row-%d-column-%d.png"
	
	# --- Image Loading and Positioning ---
	# We need to get the size of the tiles to position them correctly.
	# We'll load the first texture to determine the size.
	var first_image_path = image_folder + base_name % [1, 1]
	
	# Important: Use ResourceLoader.exists() to prevent errors in the editor
	# if the file doesn't exist yet or is named incorrectly.
	if not ResourceLoader.exists(first_image_path):
		print("Error: Cannot find the first image tile at '", first_image_path, "'. Please check the path and file names.")
		return
		
	var texture = load(first_image_path)
	var tile_size = texture.get_size()

	# Loop through a 4x4 grid to create and place each sprite.
	for row in range(1, 5):
		for col in range(1, 5):
			# Construct the full path for the current image.
			var image_path = image_folder + base_name % [row, col]

			if not ResourceLoader.exists(image_path):
				print("Warning: Could not find image '", image_path, "'. Skipping.")
				continue

			# Create a new Sprite2D node for this part of the image.
			var sprite = Sprite2D.new()

			# Load the texture and assign it to the sprite.
			sprite.texture = load(image_path)

			# Calculate the position of the sprite.
			# The position is based on its grid location and the size of each tile.
			# We subtract 1 from row and col because the loop starts at 1.
			sprite.position = Vector2((col - 1) * tile_size.x, (row - 1) * tile_size.y)

			# Add the new sprite as a child of this Node2D.
			add_child(sprite)
