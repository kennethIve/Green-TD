extends Node2D
class_name Tower

@export var tower_id: String = "archer"
@export var range_px: float = 180.0
@export var damage: int = 8
@export var fire_interval: float = 0.7
@export var cost: int = 50
@export var upgrade_cost: int = 75
@export var sell_refund: int = 25
@export var level: int = 1
@export var slow_mult: float = 1.0
@export var aura_damage_bonus: float = 0.0

var _cooldown: float = 0.0
var _color: Color = Color(0.2, 0.55, 0.35, 1)
var selected: bool = false
var _pulse: float = 0.0
var _sprite: Sprite2D
var _fx_nodes: Array = []

# Fire intervals (s): WC3-like cadence — archer fastest, lightning medium-fast,
# frost medium, cannon slow heavy, support slow aura breathe.
const DEFS := {
	"archer": {"dmg": 7, "range": 200.0, "rate": 0.40, "cost": 50, "up": 70, "sell": 25, "slow": 1.0, "aura": 0.0, "color": Color(0.35, 0.75, 0.45)},
	"cannon": {"dmg": 28, "range": 150.0, "rate": 1.40, "cost": 80, "up": 100, "sell": 40, "slow": 1.0, "aura": 0.0, "color": Color(0.75, 0.45, 0.25)},
	"frost": {"dmg": 5, "range": 170.0, "rate": 0.75, "cost": 60, "up": 80, "sell": 30, "slow": 0.55, "aura": 0.0, "color": Color(0.4, 0.7, 0.95)},
	"lightning": {"dmg": 11, "range": 220.0, "rate": 0.55, "cost": 90, "up": 110, "sell": 45, "slow": 1.0, "aura": 0.0, "color": Color(0.85, 0.85, 0.3)},
	"support": {"dmg": 0, "range": 160.0, "rate": 1.80, "cost": 70, "up": 90, "sell": 35, "slow": 1.0, "aura": 0.25, "color": Color(0.7, 0.4, 0.85)},
}

const ART_ID := {
	"archer": "archer",
	"cannon": "cannon",
	"frost": "frost",
	"lightning": "lightning",
	"support": "support",
}

func apply_id(id: String) -> void:
	tower_id = id
	var d: Dictionary = DEFS.get(id, DEFS["archer"])
	damage = int(d["dmg"])
	range_px = float(d["range"])
	fire_interval = float(d["rate"])
	cost = int(d["cost"])
	upgrade_cost = int(d["up"])
	sell_refund = int(d["sell"])
	slow_mult = float(d["slow"])
	aura_damage_bonus = float(d["aura"])
	_color = d["color"]
	level = 1
	_refresh_sprite()
	queue_redraw()

func upgrade() -> bool:
	if level >= 3:
		return false
	level += 1
	damage = int(maxi(damage, 1) * 1.45) if damage > 0 else 0
	range_px *= 1.08
	fire_interval *= 0.9
	if slow_mult < 1.0:
		slow_mult = maxf(0.35, slow_mult - 0.08)
	if aura_damage_bonus > 0.0:
		aura_damage_bonus += 0.1
	sell_refund = int(sell_refund * 1.4)
	upgrade_cost = int(upgrade_cost * 1.5)
	_refresh_sprite()
	queue_redraw()
	return true

func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()

func focus_data() -> Dictionary:
	return {
		"name": "%s Lv%d" % [tower_id.capitalize(), level],
		"dps": damage if damage > 0 else "aura",
		"range": int(range_px),
		"upgrade_cost": upgrade_cost,
		"sell_refund": sell_refund,
		"dps_delta": int(damage * 0.45) if damage > 0 else int(aura_damage_bonus * 100),
		"range_delta": int(range_px * 0.08),
	}

func _ready() -> void:
	add_to_group("towers")
	_ensure_sprite()
	_refresh_sprite()

func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_sprite = Sprite2D.new()
	_sprite.name = "TierSprite"
	_sprite.centered = true
	_sprite.position = Vector2(0, -4)
	_sprite.z_index = 1
	add_child(_sprite)

func _refresh_sprite() -> void:
	_ensure_sprite()
	var art: String = ART_ID.get(tower_id, "archer")
	var path := "res://assets/towers/%s_lv%d.png" % [art, clampi(level, 1, 3)]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.visible = true
	else:
		_sprite.texture = null
		_sprite.visible = false

func _process(delta: float) -> void:
	_pulse += delta
	if selected:
		queue_redraw()
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	if aura_damage_bonus > 0.0:
		_play_attack_fx(null)
		_tick_aura()
		_cooldown = fire_interval
		return
	var target = _find_target()
	if target == null:
		return
	var dmg := damage
	dmg = int(dmg * (1.0 + _nearby_aura_bonus()))
	if target.has_method("take_damage") and dmg > 0:
		target.take_damage(dmg)
	if slow_mult < 1.0 and target.has_method("apply_slow"):
		target.apply_slow(slow_mult, 1.2)
	_play_attack_fx(target)
	_cooldown = fire_interval

func _tick_aura() -> void:
	queue_redraw()

func _nearby_aura_bonus() -> float:
	var bonus := 0.0
	for n in get_tree().get_nodes_in_group("towers"):
		if n == self or not is_instance_valid(n):
			continue
		if float(n.get("aura_damage_bonus")) <= 0.0:
			continue
		if global_position.distance_to(n.global_position) <= float(n.get("range_px")):
			bonus += float(n.get("aura_damage_bonus"))
	return bonus

func _find_target():
	var best = null
	var best_d := range_px
	for n in get_tree().get_nodes_in_group("creeps"):
		if not is_instance_valid(n):
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= best_d:
			best_d = d
			best = n
	return best

func _draw() -> void:
	# Subtle range arc when selected (or support aura always faint)
	var range_a := 0.0
	if selected:
		range_a = 0.18
	elif aura_damage_bonus > 0.0:
		range_a = 0.10
	if range_a > 0.0:
		draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, range_a), 1.2, true)
	# Selection ring: green dashed + light pulse
	if selected:
		var pulse := 0.55 + 0.35 * sin(_pulse * 4.0)
		var r := 28.0 + 2.0 * sin(_pulse * 3.0)
		_draw_dashed_circle(Vector2.ZERO, r, Color(0.24, 0.86, 0.52, pulse), 2.0, 16, 10)
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 40, Color(0.5, 1.0, 0.7, pulse * 0.25), 1.0, true)
	# Fallback body if no texture
	if _sprite == null or _sprite.texture == null:
		draw_circle(Vector2.ZERO, 16.0 + level * 2.0, _color)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float, dashes: int, gap_deg: float) -> void:
	var step := TAU / float(dashes)
	var gap := deg_to_rad(gap_deg)
	for i in dashes:
		var a0 := i * step + gap * 0.5
		var a1 := (i + 1) * step - gap * 0.5
		if a1 <= a0:
			continue
		draw_arc(center, radius, a0, a1, 8, color, width, true)

func _play_attack_fx(target) -> void:
	match tower_id:
		"archer":
			_fx_arch_trail(target)
		"cannon":
			_fx_cann_flash(target)
		"frost":
			_fx_frost_pulse()
		"lightning":
			_fx_bolt_arc(target)
		"support":
			_fx_aura_breathe()
		_:
			pass

func _fx_arch_trail(target) -> void:
	if target == null or not is_instance_valid(target):
		return
	var line := Line2D.new()
	line.width = 2.6
	line.default_color = Color(0.55, 1.0, 0.65, 1.0)
	line.z_index = 5
	var to: Vector2 = to_local(target.global_position)
	line.points = PackedVector2Array([Vector2(0, -8), to * 0.35, to])
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.22)
	tw.tween_callback(line.queue_free)

func _fx_cann_flash(target) -> void:
	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.85, 0.35, 1.0)
	flash.z_index = 5
	var dir := Vector2.RIGHT
	if target != null and is_instance_valid(target):
		dir = (target.global_position - global_position).normalized()
	var tip := dir * 22.0
	flash.polygon = PackedVector2Array([
		tip + dir.rotated(0.6) * 10.0,
		tip + dir * 16.0,
		tip + dir.rotated(-0.6) * 10.0,
		dir * 10.0,
	])
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.15)
	tw.tween_callback(flash.queue_free)

func _fx_frost_pulse() -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.55, 0.95, 1.0, 1.0)
	ring.z_index = 5
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 27.0
		pts.append(Vector2(cos(a), sin(a)) * 12.0)
	ring.points = pts
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.28)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)

func _fx_bolt_arc(target) -> void:
	if target == null or not is_instance_valid(target):
		return
	var line := Line2D.new()
	line.width = 2.8
	line.default_color = Color(1.0, 1.0, 0.55, 1.0)
	line.z_index = 5
	var to: Vector2 = to_local(target.global_position)
	var mid := to * 0.5 + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	var mid2 := to * 0.75 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	line.points = PackedVector2Array([Vector2(0, -10), mid, mid2, to])
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)

func _fx_aura_breathe() -> void:
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.85, 0.55, 1.0, 0.9)
	ring.z_index = 4
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 31.0
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	ring.points = pts
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.4)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ring.queue_free)
