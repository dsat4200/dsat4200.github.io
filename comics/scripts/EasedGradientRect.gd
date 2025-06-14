# EasedGradientRect
# A custom Control node for Godot 4 that draws a smooth, adjustable gradient.
# The transition is controlled by a single midpoint, and the direction can be changed.
# Includes options to extend the start and end colors past the gradient's boundaries.
# This script is designed to work in the editor thanks to the @tool annotation.

@tool
class_name EasedGradientRect
extends Control


## Defines the gradient's orientation.
enum Direction { VERTICAL, HORIZONTAL }


## The starting color of the gradient.
@export var color_from: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(new_color):
		if color_from == new_color:
			return
		color_from = new_color
		# The gradient texture needs to be regenerated for a new color.
		_update_gradient()
		# The solid-colored extended area also needs to be redrawn.
		queue_redraw()

## The ending color of the gradient. Defaults to transparent.
@export var color_to: Color = Color.BLACK:
	set(new_color):
		if color_to == new_color:
			return
		color_to = new_color
		# The gradient texture needs to be regenerated for a new color.
		_update_gradient()
		# The solid-colored extended area also needs to be redrawn.
		queue_redraw()

## The center of the gradient's transition, from 0.0 to 1.0.
## A value of 0.5 is linear. Values closer to 0 create an "ease-out" effect,
## while values closer to 1 create an "ease-in" effect.
@export_range(0.001, 0.999) var midpoint: float = 0.5:
	set(new_midpoint):
		if is_equal_approx(midpoint, new_midpoint):
			return
		midpoint = new_midpoint
		_update_gradient()

## The direction of the gradient. Can be Vertical or Horizontal.
@export var direction: Direction = Direction.VERTICAL:
	set(new_direction):
		if direction == new_direction:
			return
		direction = new_direction
		_update_gradient()

## The fraction of the control to fill with 'color_from' before the gradient begins.
@export_range(0.0, 1.0) var extend_from: float = 0.0:
	set(new_value):
		var clamped_value = clampf(new_value, 0.0, 1.0)
		if is_equal_approx(extend_from, clamped_value):
			return
		extend_from = clamped_value
		# Ensure the other handle adjusts to prevent the total from exceeding 1.0
		if extend_from + extend_to > 1.0:
			extend_to = 1.0 - extend_from
			notify_property_list_changed()
		queue_redraw()

## The fraction of the control to fill with 'color_to' after the gradient ends.
@export_range(0.0, 1.0) var extend_to: float = 0.0:
	set(new_value):
		var clamped_value = clampf(new_value, 0.0, 1.0)
		if is_equal_approx(extend_to, clamped_value):
			return
		extend_to = clamped_value
		# Ensure the other handle adjusts to prevent the total from exceeding 1.0
		if extend_from + extend_to > 1.0:
			extend_from = 1.0 - extend_to
			notify_property_list_changed()
		queue_redraw()


# We store the texture and gradient resources to avoid recreating them.
var _gradient_texture: GradientTexture2D
var _gradient: Gradient


func _init() -> void:
	# Initialize the resources when the object is first created.
	_gradient = Gradient.new()
	_gradient_texture = GradientTexture2D.new()
	_gradient_texture.gradient = _gradient
	
	# Set the initial state of the gradient from the exported variables.
	_update_gradient()


func _draw() -> void:
	if _gradient_texture == null:
		return

	var full_rect_size: Vector2 = size

	# Draw using 3 parts: a start rect, the gradient rect, and an end rect.
	# The size of these parts is determined by the extend_from and extend_to values.
	match direction:
		Direction.VERTICAL:
			var from_height: float = full_rect_size.y * extend_from
			var to_height: float = full_rect_size.y * extend_to
			var gradient_height: float = full_rect_size.y - from_height - to_height

			# 1. Draw start color rect if it has any size
			if from_height > 0.0:
				draw_rect(Rect2(0, 0, full_rect_size.x, from_height), color_from)

			# 2. Draw the gradient in the remaining space
			if gradient_height > 0.0:
				var gradient_rect = Rect2(0, from_height, full_rect_size.x, gradient_height)
				draw_texture_rect(_gradient_texture, gradient_rect, false)
			
			# 3. Draw end color rect if it has any size
			if to_height > 0.0:
				var to_rect_pos_y = from_height + gradient_height
				draw_rect(Rect2(0, to_rect_pos_y, full_rect_size.x, to_height), color_to)

		Direction.HORIZONTAL:
			var from_width: float = full_rect_size.x * extend_from
			var to_width: float = full_rect_size.x * extend_to
			var gradient_width: float = full_rect_size.x - from_width - to_width

			# 1. Draw start color rect if it has any size
			if from_width > 0.0:
				draw_rect(Rect2(0, 0, from_width, full_rect_size.y), color_from)

			# 2. Draw the gradient in the remaining space
			if gradient_width > 0.0:
				var gradient_rect = Rect2(from_width, 0, gradient_width, full_rect_size.y)
				draw_texture_rect(_gradient_texture, gradient_rect, false)

			# 3. Draw end color rect if it has any size
			if to_width > 0.0:
				var to_rect_pos_x = from_width + gradient_width
				draw_rect(Rect2(to_rect_pos_x, 0, to_width, full_rect_size.y), color_to)


func _update_gradient() -> void:
	# This logic remains the same. It rebuilds the gradient texture itself,
	# which is then used by the _draw() function.
	if _gradient == null or _gradient_texture == null:
		return

	# Update the gradient direction based on the enum.
	match direction:
		Direction.VERTICAL:
			_gradient_texture.fill_from = Vector2(0, 0)
			_gradient_texture.fill_to = Vector2(0, 1)
		Direction.HORIZONTAL:
			_gradient_texture.fill_from = Vector2(0, 0)
			_gradient_texture.fill_to = Vector2(1, 0)

	# Generate the gradient points with easing.
	var new_offsets := PackedFloat32Array()
	var new_colors := PackedColorArray()

	if abs(midpoint - 0.5) < 0.001:
		new_offsets = [0.0, 1.0]
		new_colors = [color_from, color_to]
	else:
		var p = log(0.5) / log(midpoint)
		const NUM_STEPS = 16
		for i in range(NUM_STEPS + 1):
			var linear_offset: float = float(i) / NUM_STEPS
			var eased_factor: float = pow(linear_offset, p)
			var interpolated_color: Color = color_from.lerp(color_to, eased_factor)
			new_offsets.append(linear_offset)
			new_colors.append(interpolated_color)
			
	_gradient.offsets = new_offsets
	_gradient.colors = new_colors
	
	# Schedule a redraw to show the updated gradient texture.
	queue_redraw()
