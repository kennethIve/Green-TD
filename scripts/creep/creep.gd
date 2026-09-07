extends CharacterBody2D
class_name Creep

signal leaked
signal died(reward: int)

@export var speed: float = 90.0
@export var max_hp: int = 30
@export var reward: int = 12

var hp: int = 30
var _points: PackedVector2Array = []
var _idx: int = 0
var _resolved: bool = false

@onready var _hp_label: Label = $HpLabel

func _ready() -> void:
	add_to_group("creeps")

func setup(points: PackedVector2Array) -> void:
	_points = points
	hp = max_hp
	_resolved = false
	if _points.size() > 0:
		global_position = _points[0]
		_idx = 1
	_update_hp()

func take_damage(amount: int) -> void:
	if _resolved:
		return
	hp -= amount
	_update_hp()
	if hp <= 0:
		_resolve_death()

func _resolve_death() -> void:
	if _resolved:
		return
	_resolved = true
	set_physics_process(false)
	died.emit(reward)
	queue_free()

func _resolve_leak() -> void:
	if _resolved:
		return
	_resolved = true
	set_physics_process(false)
	leaked.emit()
	queue_free()

func _physics_process(_delta: float) -> void:
	if _resolved:
		return
	if _points.is_empty() or _idx >= _points.size():
		_resolve_leak()
		return
	var target: Vector2 = _points[_idx]
	var dir: Vector2 = target - global_position
	if dir.length() < 4.0:
		_idx += 1
		return
	velocity = dir.normalized() * speed
	move_and_slide()

func _update_hp() -> void:
	if _hp_label:
		_hp_label.text = str(maxi(hp, 0))
