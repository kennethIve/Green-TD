extends Node2D
## Waypoint path for creeps. Children Marker2D = path points in order.
class_name CreepPath

func get_points() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for c in get_children():
		if c is Node2D:
			pts.append((c as Node2D).global_position)
	return pts
