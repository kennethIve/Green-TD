extends Node2D
## Waypoint path. Marker2D children = points in order.
class_name CreepPath

func get_points() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for c in get_children():
		if c is Marker2D:
			pts.append((c as Marker2D).global_position)
	return pts
