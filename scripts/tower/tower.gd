extends Node2D
## Basic placeholder tower — damages nearest creep in range.
class_name Tower

@export var range_px: float = 180.0
@export var damage: int = 8
@export var fire_interval: float = 0.7
@export var cost: int = 50

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	target.take_damage(damage)
	_cooldown = fire_interval
	queue_redraw()


func _find_target() -> Creep:
	var best: Creep = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("creeps"):
		if n is Creep:
			var c := n as Creep
			var d := global_position.distance_to(c.global_position)
			if d <= best_d:
				best_d = d
				best = c
	return best


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(0.2, 0.55, 0.35, 1))
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 48, Color(0.24, 0.86, 0.52, 0.15), 1.0)
