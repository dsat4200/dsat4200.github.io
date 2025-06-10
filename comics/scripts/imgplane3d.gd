# image_plane.gd
# Version 2: With Unshaded, Transparency, and clean UVs.
@tool
extends MeshInstance3D

## The texture to apply to the plane.
## Assign a texture here to automatically generate the plane and material.
@export var image_texture: Texture2D:
	set(value):
		image_texture = value
		if is_instance_valid(self):
			_update_plane()

func _ready():
	# Ensure the plane is updated when the scene loads in the editor.
	if image_texture:
		_update_plane()

func _update_plane():
	# Do nothing if the texture isn't set.
	if not image_texture:
		self.mesh = null # Clear the mesh if texture is removed
		return

	# Get texture dimensions.
	var img_width = float(image_texture.get_width())
	var img_height = float(image_texture.get_height())

	# Prevent division by zero if the image is invalid.
	if img_width == 0 or img_height == 0:
		return

	# Create the necessary resources.
	var plane_mesh = PlaneMesh.new()
	var material = StandardMaterial3D.new()

	# --- Configure the Material ---
	
	# 1. Set the texture.
	material.albedo_texture = image_texture

	# 2. Set shading to Unshaded for a flat, original look.
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	# 3. Enable transparency for PNGs with alpha channels.
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	# Note: We don't need to set UVs. The default PlaneMesh UVs map the
	# texture perfectly from edge to edge without repeating.

	# Assign the configured mesh and material to this node.
	self.mesh = plane_mesh
	self.set_surface_override_material(0, material)

	# --- Auto-resize the plane based on aspect ratio ---
	# We set the plane's size while keeping the aspect ratio correct.
	# Here, we fix the width to 1.0 and adjust the height accordingly.
	plane_mesh.size.x = 1.0
	plane_mesh.size.y = img_height / img_width
