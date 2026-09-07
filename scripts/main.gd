extends Node2D
## Game loop aligned to Green Circle TD: leak at CENTER loses a life.

const START_LIVES := 40
const START_GOLD := 200
const TOWER_COST := 50

@onready var hud: Control = $UI/HUD
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var path: CreepPath = $CreepPath
@onready var towers: Node2D = $Towers
@onready var status_label: Label = $StatusLabel

var lives: int = START_LIVES
var gold: int = START_GOLD
var _ended: bool = false
var _build_id: String = "archer"


func _ready() -> void:
	spawner.creep_leaked.connect(_on_leak)
	spawner.creep_killed.connect(_on_kill)
	spawner.wave_started.connect(_on_wave_started)
	spawner.all_waves_cleared.connect(_on_win)
	if hud.has_signal("build_pressed"):
		hud.build_pressed.connect(_on_build_pressed)
	_refresh_hud()
	status_label.text = "Circle path → center leak. Space = wave · Click = tower ($%d)" % TOWER_COST
	_place_tower(Vector2(500, 280))


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not spawner.start_next_wave():
			status_label.text = "Wave busy or finished"
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _build_id == "sell":
			return
		_place_tower(get_global_mouse_position())


func _place_tower(pos: Vector2) -> void:
	if gold < TOWER_COST:
		status_label.text = "Not enough gold"
		return
	# Soft block placing on the green center goal
	if pos.distance_to(Vector2(640, 360)) < 50.0:
		status_label.text = "Cannot build on center"
		return
	gold -= TOWER_COST
	var t := Tower.new()
	t.position = pos
	towers.add_child(t)
	_refresh_hud()
	status_label.text = "Tower placed · gold %d" % gold


func _on_build_pressed(id: String) -> void:
	_build_id = id
	status_label.text = "Build: %s" % id


func _on_leak() -> void:
	if _ended:
		return
	lives = maxi(lives - 1, 0)
	_refresh_hud()
	if lives <= 0:
		_lose()


func _on_kill(reward: int) -> void:
	gold += reward
	_refresh_hud()


func _on_wave_started(index: int, total: int) -> void:
	if hud.has_method("set_wave"):
		hud.set_wave(index, total, 0.0)
	status_label.text = "Wave %d / %d" % [index, total]


func _on_win() -> void:
	if _ended:
		return
	_ended = true
	status_label.text = "VICTORY — all waves cleared"


func _lose() -> void:
	_ended = true
	status_label.text = "DEFEAT — lives depleted"


func _refresh_hud() -> void:
	if hud.has_method("set_resources"):
		hud.set_resources(lives, gold)
		if hud.get_node_or_null("%LivesLabel"):
			hud.get_node("%LivesLabel").text = "♥ %d / %d" % [lives, START_LIVES]
