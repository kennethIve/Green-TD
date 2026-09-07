extends Node2D
class_name WaveSpawner

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_waves_cleared
signal creep_leaked
signal creep_killed(reward: int)

@export var creep_scene: PackedScene
@export var path_paths: Array[NodePath] = []
@export var creeps_per_corner: int = 3
@export var spawn_interval: float = 0.45
@export var total_waves: int = 8
@export var hp_per_wave: int = 8

var wave_index: int = 0
var _alive: int = 0
var _spawning: bool = false

func start_next_wave() -> bool:
	if _spawning or _alive > 0:
		return false
	if wave_index >= total_waves:
		return false
	wave_index += 1
	wave_started.emit(wave_index, total_waves)
	_spawn_wave()
	return true

func _spawn_wave() -> void:
	_spawning = true
	var paths: Array = []
	for p in path_paths:
		var n = get_node_or_null(p)
		if n and n.has_method("get_points"):
			paths.append(n.get_points())
	if paths.is_empty():
		_spawning = false
		return
	for i in creeps_per_corner:
		for pts in paths:
			await get_tree().create_timer(spawn_interval).timeout
			var creep = creep_scene.instantiate()
			creep.max_hp = 20 + wave_index * hp_per_wave
			creep.reward = 6 + wave_index * 2
			creep.speed = 80.0 + wave_index * 4.0
			add_child(creep)
			creep.setup(pts)
			creep.leaked.connect(_on_leaked)
			creep.died.connect(_on_died)
			_alive += 1
	_spawning = false
	_check_clear()

func _on_leaked() -> void:
	_alive = maxi(_alive - 1, 0)
	creep_leaked.emit()
	_check_clear()

func _on_died(reward: int) -> void:
	_alive = maxi(_alive - 1, 0)
	creep_killed.emit(reward)
	_check_clear()

func _check_clear() -> void:
	if _spawning or _alive > 0:
		return
	wave_cleared.emit(wave_index)
	if wave_index >= total_waves:
		all_waves_cleared.emit()
