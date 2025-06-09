# PathPointLabel.gd
@tool
extends Label

class_name PathPointLabel

## The persistent data for this path point.
@export var point_data: PathPointData = PathPointData.new()
# PathPointData is globally accessible because it uses `class_name PathPointData`

# You might want to add some _notification or _process logic here later
# if this custom label needs to react to changes in its point_data.
