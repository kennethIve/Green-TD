extends Node2D
## Green Circle TD — 4-corner axis-aligned rings, multi-tower, center leak.

const START_LIVES := 40
const START_GOLD := 220
const PATH_HALF_WIDTH := 18.0
const TowerScript = preload("res://scripts/tower/tower.gd")

@onready var hud: Control = $UI/HUD
@onready var spawner = $WaveSpawner
@onready var towers: Node2D = $Towers
@onready var status_label: Label = $StatusLabel

var lives: int = START_LIVES
var gold: int = START_GOLD
var _ended: bool = false
var _build_id: String = "archer"
var _sell_mode: bool = false
var _selected_tower: Node2D = null
var _wave_time_left: float = 0.0
var _wave_duration: float = 24.0

func _ready() -> void:
	spawner.creep_leaked.connect(_on_leak)
	spawner.creep_killed.connect(_on_kill)
	spawner.wave_started.connect(_on_wave_started)
	spawner.all_waves_cleared.connect(_on_win)
	if hud.has_signal("build_pressed"):
		hud.build_pressed.connect(_on_build_pressed)
	if hud.has_signal("upgrade_pressed"):
		hud.upgrade_pressed.connect(_on_upgrade)
	if hud.has_signal("sell_pressed"):
		hud.sell_pressed.connect(_on_sell_mode)
	if hud.has_signal("pause_pressed"):
		hud.pause_pressed.connect(_on_pause)
	if hud.has_signal("settings_pressed"):
		hud.settings_pressed.connect(func() -> void: status_label.text = "Settings — coming soon")
	if hud.has_method("set_build_selected"):
		hud.set_build_selected("archer")
	_refresh_hud()
	status_label.text = "4-corner circle · Space=wave · Click=build/select · Sell mode then click tower"
	_place_tower(Vector2(420, 260), "archer")
	_place_tower(Vector2(860, 260), "frost")

func _process(delta: float) -> void:
	if _ended or _wave_time_left <= 0.0:
		return
	_wave_time_left = maxf(_wave_time_left - delta, 0.0)
	if hud.has_method("set_wave"):
		hud.set_wave(spawner.wave_index, spawner.total_waves, _wave_time_left, _wave_duration)

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if not spawner.start_next_wave():
				status_label.text = "Wave busy or finished"
		elif event.keycode == KEY_U:
			_on_upgrade()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		var hit := _tower_at(pos)
		if _sell_mode:
			if hit:
				_sell_tower(hit)
			else:
				status_label.text = "Sell mode: click a tower"
			return
		if hit:
			_select_tower(hit)
			return
		_place_tower(pos, _build_id)

func _on_pause() -> void:
	get_tree().paused = not get_tree().paused
	# Keep HUD processable
	if hud:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
	status_label.text = "Paused" if get_tree().paused else "Resumed"

func _tower_at(pos: Vector2) -> Node2D:
	for t in towers.get_children():
		if t.global_position.distance_to(pos) <= 22.0:
			return t
	return null

func _select_tower(t: Node2D) -> void:
	_selected_tower = t
	_sell_mode = false
	if hud.has_method("show_tower") and t.has_method("focus_data"):
		hud.show_tower(t.focus_data())

func _on_path(pos: Vector2) -> bool:
	for path_name in ["PathTL", "PathTR", "PathBR", "PathBL"]:
		var path := get_node_or_null(path_name)
		if path == null:
			continue
		var pts: PackedVector2Array = path.get_points()
		for i in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1]).distance_to(pos) <= PATH_HALF_WIDTH:
				return true
	return false

func _place_tower(pos: Vector2, id: String) -> void:
	var defs: Dictionary = TowerScript.DEFS.get(id, TowerScript.DEFS["archer"])
	var cost: int = int(defs["cost"])
	if gold < cost:
		status_label.text = "Not enough gold"
		return
	if pos.distance_to(Vector2(640, 360)) < 55.0:
		status_label.text = "Cannot build on center"
		return
	if _on_path(pos):
		status_label.text = "Cannot build on path"
		return
	for t in towers.get_children():
		if t.global_position.distance_to(pos) < 36.0:
			status_label.text = "Too close to another tower"
			return
	gold -= cost
	var tower = TowerScript.new()
	tower.apply_id(id)
	tower.position = pos
	towers.add_child(tower)
	_select_tower(tower)
	_refresh_hud()
	status_label.text = "Built %s ($%d)" % [id, cost]

func _on_build_pressed(id: String) -> void:
	_sell_mode = false
	_build_id = id
	status_label.text = "Build: %s" % id

func _on_sell_mode() -> void:
	_sell_mode = true
	status_label.text = "Sell mode ON — click a tower to sell"

func _sell_tower(t: Node2D) -> void:
	gold += int(t.sell_refund)
	if _selected_tower == t:
		_selected_tower = null
		if hud.has_method("show_tower"):
			hud.show_tower(null)
	t.queue_free()
	_sell_mode = false
	_refresh_hud()
	status_label.text = "Sold"

func _on_upgrade() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	var cost: int = int(_selected_tower.upgrade_cost)
	if gold < cost:
		status_label.text = "Need $%d to upgrade" % cost
		return
	if _selected_tower.upgrade():
		gold -= cost
		_select_tower(_selected_tower)
		_refresh_hud()
		status_label.text = "Upgraded"

func _on_leak() -> void:
	if _ended:
		return
	lives = maxi(lives - 1, 0)
	_refresh_hud()
	if lives <= 0:
		_lose()

func _on_kill(reward: int) -> void:
	if _ended:
		return
	gold += reward
	_refresh_hud()

func _on_wave_started(index: int, total: int) -> void:
	_wave_duration = 24.0
	_wave_time_left = _wave_duration
	if hud.has_method("set_wave"):
		hud.set_wave(index, total, _wave_time_left, _wave_duration)
	status_label.text = "Wave %d / %d — 4 corners" % [index, total]

func _on_win() -> void:
	if _ended:
		return
	_ended = true
	status_label.text = "VICTORY"

func _lose() -> void:
	_ended = true
	status_label.text = "DEFEAT"

func _refresh_hud() -> void:
	if hud.has_method("set_resources"):
		hud.set_resources(lives, gold, START_LIVES)

