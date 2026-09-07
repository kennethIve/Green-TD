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

const DEFS := {
	"archer": {"dmg": 8, "range": 200.0, "rate": 0.55, "cost": 50, "up": 70, "sell": 25, "slow": 1.0, "aura": 0.0, "color": Color(0.35, 0.75, 0.45)},
	"cannon": {"dmg": 18, "range": 150.0, "rate": 1.1, "cost": 80, "up": 100, "sell": 40, "slow": 1.0, "aura": 0.0, "color": Color(0.75, 0.45, 0.25)},
	"frost": {"dmg": 4, "range": 170.0, "rate": 0.8, "cost": 60, "up": 80, "sell": 30, "slow": 0.55, "aura": 0.0, "color": Color(0.4, 0.7, 0.95)},
	"lightning": {"dmg": 12, "range": 220.0, "rate": 0.9, "cost": 90, "up": 110, "sell": 45, "slow": 1.0, "aura": 0.0, "color": Color(0.85, 0.85, 0.3)},
	"support": {"dmg": 0, "range": 160.0, "rate": 0.5, "cost": 70, "up": 90, "sell": 35, "slow": 1.0, "aura": 0.25, "color": Color(0.7, 0.4, 0.85)},
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
	queue_redraw()
	return true

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

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	if aura_damage_bonus > 0.0:
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
	_cooldown = fire_interval

func _tick_aura() -> void:
	# Support: pulse exists visually; damage towers query aura via _nearby_aura_bonus
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

func _ready() -> void:
	add_to_group("towers")

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
	draw_circle(Vector2.ZERO, 16.0 + level * 2.0, _color)
	var a := 0.22 if aura_damage_bonus > 0.0 else 0.15
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 40, Color(_color.r, _color.g, _color.b, a), 1.0)
