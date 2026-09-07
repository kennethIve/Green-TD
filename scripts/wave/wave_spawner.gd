extends Node2D
class_name WaveSpawner

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_waves_cleared
signal creep_leaked
signal creep_killed(reward: int)

@export var creep_scene: PackedScene
@export var path_paths: Array[NodePath] = []
## Fallback if a wave is missing from WAVE_DENSITY (kept for editor/compat).
@export var creeps_per_corner: int = 4
@export var spawn_interval: float = 0.40
@export var total_waves: int = 8
@export var hp_per_wave: int = 8

# Designer sheet mapping (creep_0 early … creep_5 late/boss):
# W1–2→0 紅方塊, W3–4→1 橙甲蟲, W5→2 紫刺獸, W6→3 石魔, W7→4 飛蟲, W8→5 boss 魔眼
const TYPE_BY_WAVE := {
	1: 0, 2: 0,
	3: 1, 4: 1,
	5: 2,
	6: 3,
	7: 4,
	8: 5,
}

# Per-type multipliers stacked on wave baseline (hp / speed / reward).
const TYPE_STATS := {
	0: {"hp": 1.00, "spd": 1.00, "rew": 1.00},  # 紅方塊
	1: {"hp": 1.15, "spd": 1.05, "rew": 1.10},  # 橙甲蟲
	2: {"hp": 1.35, "spd": 0.95, "rew": 1.25},  # 紫刺獸
	3: {"hp": 1.70, "spd": 0.80, "rew": 1.45},  # 石魔 tank
	4: {"hp": 1.20, "spd": 1.30, "rew": 1.55},  # 飛蟲 fast
	5: {"hp": 2.40, "spd": 0.90, "rew": 2.80},  # boss 魔眼
}

# Late-wave readability: keep W1–4 punchy; thin W5+ and space W6–8.
# creeps = per corner (×4 paths); interval = seconds between corner ticks.
const WAVE_DENSITY := {
	1: {"creeps": 4, "interval": 0.40},
	2: {"creeps": 4, "interval": 0.40},
	3: {"creeps": 4, "interval": 0.40},
	4: {"creeps": 4, "interval": 0.40},
	5: {"creeps": 3, "interval": 0.42},
	6: {"creeps": 3, "interval": 0.45},
	7: {"creeps": 2, "interval": 0.45},
	8: {"creeps": 2, "interval": 0.45},
}

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

func _creep_type_for_wave(w: int) -> int:
	return int(TYPE_BY_WAVE.get(w, mini(5, maxi(0, w - 1))))

func _density_for_wave(w: int) -> Dictionary:
	if WAVE_DENSITY.has(w):
		return WAVE_DENSITY[w]
	return {"creeps": creeps_per_corner, "interval": spawn_interval}

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
	var ctype := _creep_type_for_wave(wave_index)
	var ts: Dictionary = TYPE_STATS.get(ctype, TYPE_STATS[0])
	var dens: Dictionary = _density_for_wave(wave_index)
	var count: int = int(dens.get("creeps", creeps_per_corner))
	var interval: float = float(dens.get("interval", spawn_interval))
	var base_hp := 20 + wave_index * hp_per_wave
	# WC3 GiveJB=8 + LVL/3; solo 8-wave uses +1.5/wave for readable scaling
	var base_rew := 8 + int((wave_index - 1) * 1.5)
	# WC3 SpawnWaves1 period=0.40; all corners fire together each tick.
	# Solo 8-wave: slower early, modest late ramp (avoid teleport-fast W7–8).
	var base_spd := 72.0 + wave_index * 3.5
	for i in count:
		for pts in paths:
			var creep = creep_scene.instantiate()
			creep.max_hp = maxi(1, int(round(base_hp * float(ts["hp"]))))
			creep.reward = maxi(1, int(round(base_rew * float(ts["rew"]))))
			creep.speed = base_spd * float(ts["spd"])
			add_child(creep)
			creep.setup(pts, ctype)
			creep.leaked.connect(_on_leaked)
			creep.died.connect(_on_died)
			_alive += 1
		if i + 1 < count:
			await get_tree().create_timer(interval).timeout
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
