extends CharacterBody2D
class_name Creep

signal leaked
signal died(reward: int)

@export var speed: float = 90.0
@export var max_hp: int = 30
@export var reward: int = 12
@export var creep_type: int = 0

## Distance under which nearby creeps occlude each other's HP labels.
const HP_OCCLUDE_DIST := 34.0
const HP_LABEL_OFFSET_Y := -42.0
const BOSS_TYPE := 5

var hp: int = 30
var _points: PackedVector2Array = []
var _idx: int = 0
var _resolved: bool = false
var _slow_mult: float = 1.0
var _slow_timer: float = 0.0
var _hp_visible_target: float = 1.0

@onready var _hp_label: Label = $HpLabel
@onready var _body: ColorRect = get_node_or_null("Body")
@onready var _boss_bar_bg: ColorRect = get_node_or_null("BossHpBar/Bg")
@onready var _boss_bar_fg: ColorRect = get_node_or_null("BossHpBar/Fg")
@onready var _boss_bar: Node2D = get_node_or_null("BossHpBar")
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("creeps")
	_ensure_sprite()
	_style_hp_label()
	_apply_creep_art()
	_configure_boss_ui()
	if _body:
		_body.visible = false
	_update_hp()

func setup(points: PackedVector2Array, type_id: int = -1) -> void:
	_points = points
	hp = max_hp
	_resolved = false
	_slow_mult = 1.0
	_slow_timer = 0.0
	_hp_visible_target = 1.0
	if type_id >= 0:
		creep_type = type_id
	if _points.size() > 0:
		global_position = _points[0]
		_idx = 1
	_ensure_sprite()
	_style_hp_label()
	_apply_creep_art()
	_configure_boss_ui()
	if _body:
		_body.visible = false
	_update_hp()

func _style_hp_label() -> void:
	if _hp_label == null:
		return
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_hp_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.92))
	_hp_label.add_theme_constant_override("outline_size", 2)
	_hp_label.add_theme_font_size_override("font_size", 14)
	# Sit above the sprite head, not on sprite center.
	_hp_label.position = Vector2(-22.0, HP_LABEL_OFFSET_Y)
	_hp_label.size = Vector2(44.0, 18.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.z_index = 8

func _configure_boss_ui() -> void:
	var is_boss := creep_type == BOSS_TYPE
	if _boss_bar:
		_boss_bar.visible = is_boss
	if is_boss and _hp_label:
		# Number sits just above the short bar.
		_hp_label.position = Vector2(-22.0, HP_LABEL_OFFSET_Y - 6.0)

func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_sprite = get_node_or_null("CreepSprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "CreepSprite"
		_sprite.centered = true
		_sprite.z_index = 1
		add_child(_sprite)

func _apply_creep_art() -> void:
	_ensure_sprite()
	var id := clampi(creep_type, 0, 5)
	var path := "res://assets/creeps/creep_%d.png" % id
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.visible = true
	else:
		_sprite.texture = null
		_sprite.visible = false
		if _body:
			_body.visible = true

func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = minf(_slow_mult, mult)
	_slow_timer = maxf(_slow_timer, duration)

func take_damage(amount: int) -> void:
	if _resolved:
		return
	hp -= amount
	_update_hp()
	_hit_flash()
	if hp <= 0:
		_resolve_death()

func _hit_flash() -> void:
	# Cheap white flash — designer noted prior hit feedback was too pale.
	var node: CanvasItem = _sprite if _sprite != null and is_instance_valid(_sprite) and _sprite.visible else (_body as CanvasItem)
	if node == null or not is_instance_valid(node):
		return
	node.modulate = Color(1.6, 1.6, 1.6, 1.0)
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, 0.12)

func _resolve_death() -> void:
	if _resolved:
		return
	_resolved = true
	set_physics_process(false)
	set_process(false)
	died.emit(reward)
	queue_free()

func _resolve_leak() -> void:
	if _resolved:
		return
	_resolved = true
	set_physics_process(false)
	set_process(false)
	leaked.emit()
	queue_free()

func _physics_process(delta: float) -> void:
	if _resolved:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_mult = 1.0
	if _points.is_empty() or _idx >= _points.size():
		_resolve_leak()
		return
	var target: Vector2 = _points[_idx]
	var dir: Vector2 = target - global_position
	if dir.length() < 4.0:
		_idx += 1
		return
	velocity = dir.normalized() * speed * _slow_mult
	move_and_slide()

func _process(delta: float) -> void:
	if _resolved:
		return
	_update_hp_occlusion(delta)

func _path_progress() -> float:
	# Higher = further along the lane (frontmost).
	var tip := 0.0
	if _idx < _points.size():
		tip = -global_position.distance_to(_points[_idx])
	return float(_idx) * 10000.0 + tip

func _wins_hp_label_vs(other: Creep) -> bool:
	# Prefer highest HP; on tie, prefer frontmost.
	if hp != other.hp:
		return hp > other.hp
	var my_p := _path_progress()
	var their_p := other._path_progress()
	if not is_equal_approx(my_p, their_p):
		return my_p > their_p
	# Stable tie-break so flicker doesn't thrash.
	return get_instance_id() < other.get_instance_id()

func _update_hp_occlusion(delta: float) -> void:
	var show := true
	for n in get_tree().get_nodes_in_group("creeps"):
		if n == self or not (n is Creep):
			continue
		var other := n as Creep
		if other._resolved:
			continue
		if global_position.distance_to(other.global_position) > HP_OCCLUDE_DIST:
			continue
		if not _wins_hp_label_vs(other):
			show = false
			break
	_hp_visible_target = 1.0 if show else 0.0
	var a: float = 1.0
	if _hp_label:
		a = move_toward(_hp_label.modulate.a, _hp_visible_target, delta * 8.0)
		_hp_label.modulate.a = a
		_hp_label.visible = a > 0.02
	if _boss_bar and creep_type == BOSS_TYPE:
		_boss_bar.modulate.a = a
		_boss_bar.visible = a > 0.02 and creep_type == BOSS_TYPE

func _update_hp() -> void:
	if _hp_label:
		_hp_label.text = str(maxi(hp, 0))
	if creep_type == BOSS_TYPE and _boss_bar_fg and _boss_bar_bg:
		var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
		var full_w: float = _boss_bar_bg.size.x
		_boss_bar_fg.size.x = full_w * ratio
