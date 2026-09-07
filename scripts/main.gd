extends Node2D
## Green Circle TD - 4-corner axis-aligned rings, multi-tower, center leak.

const START_LIVES := 40
const START_GOLD := 200  # ~4 archers (40); WC3 ref start 1000 on different tower scale
## Line2D path width is 26 → visual half ~13; exclusion uses 26 (ribbon + margin).
## Ghost footprint_r and _on_path BOTH use this — do not fork a second path radius.
const PATH_HALF_WIDTH := 26.0
## Tower sprites ~64px; keep centers far enough that bases do not stack.
## Ghost + _place_tower share this via _can_place.
const TOWER_MIN_SEP := 44.0
const TOWER_PICK_RADIUS := 32.0
const CENTER_BLOCK_RADIUS := 55.0
const GHOST_OK := Color("#3DDC84")
const GHOST_BAD := Color(0.92, 0.22, 0.22)
const TowerScript = preload("res://scripts/tower/tower.gd")

## Follow-cursor placement preview (tier-1 art + legal/illegal tint).
## Validity color MUST mirror Main._can_place only — never a wider local radius.
class PlacementGhost extends Node2D:
	var legal: bool = true
	var flash_t: float = 0.0
	var shake_t: float = 0.0
	var _sprite: Sprite2D
	## Footprint ring matches path exclusion (same constant as _on_path).
	var footprint_r: float = 26.0

	func _ensure_sprite() -> void:
		if _sprite != null and is_instance_valid(_sprite):
			return
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		# Art offset is visual-only; legality uses the ghost/node origin (= cursor).
		_sprite.position = Vector2(0, -4)
		add_child(_sprite)

	func _ready() -> void:
		z_index = 20
		_ensure_sprite()
		visible = false

	func set_art(tower_id: String) -> void:
		_ensure_sprite()
		var art_path := "res://assets/towers/%s_lv1.png" % tower_id
		if ResourceLoader.exists(art_path):
			_sprite.texture = load(art_path)
			_sprite.visible = true
		else:
			_sprite.texture = null
			_sprite.visible = false
		queue_redraw()

	func set_legal(ok: bool) -> void:
		# Becoming legal must clear illegal flash — otherwise _draw stays RED while
		# _can_place is already true and a click would succeed (P0 desync).
		if ok:
			flash_t = 0.0
		if legal == ok:
			queue_redraw()
			return
		legal = ok
		if not ok:
			shake_t = 0.18
		queue_redraw()

	func flash_illegal() -> void:
		legal = false
		flash_t = 0.28
		shake_t = 0.22
		queue_redraw()

	func tick(delta: float, world_pos: Vector2) -> void:
		flash_t = maxf(flash_t - delta, 0.0)
		shake_t = maxf(shake_t - delta, 0.0)
		# Do not shake the checked origin — keep node on cursor; shake sprite only.
		global_position = world_pos
		var shake := Vector2.ZERO
		if shake_t > 0.0:
			shake = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		if _sprite:
			_sprite.position = Vector2(0, -4) + shake
		var tint := GHOST_OK if legal else GHOST_BAD
		var a := 0.55 if flash_t <= 0.0 else 0.95
		if _sprite:
			_sprite.modulate = Color(tint.r, tint.g, tint.b, a * 0.85 if legal else a)
		queue_redraw()

	func _draw() -> void:
		# Never paint red while legal (flash is illegal-only emphasis).
		var col := GHOST_OK if legal else GHOST_BAD
		var border_a := 0.95 if (flash_t > 0.0 and not legal) else 0.85
		var fill_a := 0.55 if (flash_t > 0.0 and not legal) else 0.40
		var fill := Color(col.r, col.g, col.b, fill_a)
		var r := footprint_r
		draw_circle(Vector2.ZERO, r, fill)
		draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 48, Color(col.r, col.g, col.b, border_a), 2.5, true)
		if _sprite == null or _sprite.texture == null:
			draw_circle(Vector2.ZERO, 14.0, Color(col.r, col.g, col.b, 0.7))

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
var _wave_end_msec: int = 0
var _focus_open: bool = false
var _building: bool = true
var _ghost: PlacementGhost
var _ghost_hide_t: float = 0.0

func _ready() -> void:
	spawner.creep_leaked.connect(_on_leak)
	spawner.creep_killed.connect(_on_kill)
	spawner.wave_started.connect(_on_wave_started)
	spawner.all_waves_cleared.connect(_on_win)
	if hud.has_signal("build_pressed"):
		hud.build_pressed.connect(_on_build_pressed)
	if hud.has_signal("upgrade_pressed"):
		hud.upgrade_pressed.connect(_on_upgrade_btn)
	if hud.has_signal("sell_pressed"):
		hud.sell_pressed.connect(_on_sell_mode)
	if hud.has_signal("pause_pressed"):
		hud.pause_pressed.connect(_on_pause)
	if hud.has_signal("settings_pressed"):
		hud.settings_pressed.connect(func() -> void: status_label.text = "Settings - coming soon")
	if hud.has_signal("wave_pressed"):
		hud.wave_pressed.connect(_start_wave)
	if hud.has_method("set_build_selected"):
		hud.set_build_selected("archer")
	if hud.has_method("show_tower"):
		hud.show_tower(null)
	_focus_open = false
	_building = true
	_ghost = PlacementGhost.new()
	_ghost.name = "PlacementGhost"
	_ghost.footprint_r = PATH_HALF_WIDTH
	add_child(_ghost)
	_ghost.set_art(_build_id)
	_refresh_hud()
	status_label.text = "Click tower = select | U = upgrade menu | Upgrade btn = upgrade"
	# Legal empty ground (off w3x path ribbon); prior (420/860,260) sat on vertical path arms.
	_place_tower(Vector2(360, 280), "archer")
	_place_tower(Vector2(920, 300), "frost")
	# Web-friendly: auto-start wave 1; Wave button / Space also work
	await get_tree().create_timer(1.2).timeout
	_start_wave()

func _process(delta: float) -> void:
	_update_placement_ghost(delta)
	if _ended or _wave_end_msec <= 0:
		return
	_wave_time_left = maxf(float(_wave_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	if hud.has_method("set_wave"):
		hud.set_wave(spawner.wave_index, spawner.total_waves, _wave_time_left, _wave_duration)
	if _wave_time_left <= 0.0:
		_wave_end_msec = 0

func _start_wave() -> void:
	if _ended:
		return
	if not spawner.start_next_wave():
		status_label.text = "Wave busy or finished"

func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_start_wave()
		elif event.keycode == KEY_U:
			_on_u_key()
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
		_deselect_tower()
		_place_tower(pos, _build_id, true)

func _on_pause() -> void:
	get_tree().paused = not get_tree().paused
	if hud:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
	status_label.text = "Paused" if get_tree().paused else "Resumed"

func _tower_at(pos: Vector2) -> Node2D:
	for t in towers.get_children():
		if t.global_position.distance_to(pos) <= TOWER_PICK_RADIUS:
			return t
	return null

func _clear_selection_rings() -> void:
	for t in towers.get_children():
		if t.has_method("set_selected"):
			t.set_selected(false)

## Click tower → selection ring ONLY. Do NOT auto-open FocusCard.
func _select_tower(t: Node2D) -> void:
	_clear_selection_rings()
	_selected_tower = t
	_sell_mode = false
	_focus_open = false
	if t.has_method("set_selected"):
		t.set_selected(true)
	if hud.has_method("show_tower"):
		hud.show_tower(null)
	status_label.text = "Selected %s (press U for upgrade menu)" % str(t.get("tower_id"))

func _deselect_tower() -> void:
	_clear_selection_rings()
	_selected_tower = null
	_focus_open = false
	if hud.has_method("show_tower"):
		hud.show_tower(null)

## U opens panel first if closed; when already open, U also upgrades (optional convenience).
## Prefer: U opens panel first if closed; UpgradeBtn upgrades.
func _on_u_key() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		status_label.text = "Select a tower first"
		return
	if not _focus_open:
		_open_focus_panel()
		return
	# Panel already open: keep focus refreshed; do not upgrade on U (UpgradeBtn does that)
	_open_focus_panel()
	status_label.text = "Use Upgrade button to upgrade"

func _open_focus_panel() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	_focus_open = true
	if hud.has_method("show_tower") and _selected_tower.has_method("focus_data"):
		hud.show_tower(_selected_tower.focus_data())

func _on_upgrade_btn() -> void:
	# UpgradeBtn upgrades (opens panel if needed so costs stay visible)
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if not _focus_open:
		_open_focus_panel()
	_do_upgrade()

func _do_upgrade() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	var cost: int = int(_selected_tower.upgrade_cost)
	if gold < cost:
		status_label.text = "Need $%d to upgrade" % cost
		return
	if _selected_tower.upgrade():
		gold -= cost
		if _selected_tower.has_method("set_selected"):
			_selected_tower.set_selected(true)
		_open_focus_panel()
		_refresh_hud()
		status_label.text = "Upgraded to Lv%d" % int(_selected_tower.level)

func _path_points(path: Node) -> PackedVector2Array:
	# Prefer CreepPath.get_points() (Marker2D waypoints = Line2D). Fallback to child Line2D.
	if path != null and path.has_method("get_points"):
		var pts: PackedVector2Array = path.get_points()
		if pts.size() >= 2:
			return pts
	var line := path.get_node_or_null("Line") if path != null else null
	if line is Line2D:
		var local_pts: PackedVector2Array = (line as Line2D).points
		var out: PackedVector2Array = []
		for p in local_pts:
			out.append((line as Line2D).to_global(p))
		return out
	return PackedVector2Array()

func _on_path(pos: Vector2) -> bool:
	for path_name in ["PathTL", "PathTR", "PathBR", "PathBL"]:
		var path := get_node_or_null(path_name)
		var pts := _path_points(path)
		for i in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1]).distance_to(pos) <= PATH_HALF_WIDTH:
				return true
	return false

func _over_ui(pos: Vector2) -> bool:
	# Block leaked clicks on HUD chrome (tray / top bar / minimap / open focus card).
	if pos.y < 84.0:
		return true
	if pos.y > 620.0 and pos.x > 320.0 and pos.x < 960.0:
		return true
	if pos.x < 184.0 and pos.y > 280.0 and pos.y < 440.0:
		return true
	if _focus_open and pos.x > 1000.0 and pos.y > 230.0 and pos.y < 490.0:
		return true
	return false

## Shared placement gate used by ghost + click. Returns {ok, reason}.
func _can_place(pos: Vector2, id: String = "") -> Dictionary:
	if id == "":
		id = _build_id
	var defs: Dictionary = TowerScript.DEFS.get(id, TowerScript.DEFS["archer"])
	var cost: int = int(defs["cost"])
	if gold < cost:
		return {"ok": false, "reason": "Not enough gold"}
	if _over_ui(pos):
		return {"ok": false, "reason": "Cannot build on UI"}
	if pos.distance_to(Vector2(640, 360)) < CENTER_BLOCK_RADIUS:
		return {"ok": false, "reason": "Cannot build on center"}
	if _on_path(pos):
		return {"ok": false, "reason": "Cannot build on path"}
	for t in towers.get_children():
		if t.global_position.distance_to(pos) < TOWER_MIN_SEP:
			return {"ok": false, "reason": "Too close to another tower"}
	return {"ok": true, "reason": ""}

func _place_tower(pos: Vector2, id: String, from_player: bool = false) -> bool:
	var check: Dictionary = _can_place(pos, id)
	if not bool(check["ok"]):
		if from_player:
			if _ghost:
				_ghost.flash_illegal()
			status_label.text = str(check["reason"])
		return false
	var defs: Dictionary = TowerScript.DEFS.get(id, TowerScript.DEFS["archer"])
	var cost: int = int(defs["cost"])
	gold -= cost
	var tower = TowerScript.new()
	tower.apply_id(id)
	tower.position = pos
	towers.add_child(tower)
	_select_tower(tower)
	_refresh_hud()
	status_label.text = "Built %s ($%d)" % [id, cost]
	# After place, cursor sits on the new tower footprint — hide ghost briefly so it
	# does not immediately flip RED via TOWER_MIN_SEP against the tower we just built.
	if from_player and _ghost:
		_ghost_hide_t = 0.35
		_ghost.visible = false
		_ghost.set_legal(true)
	return true

func _on_build_pressed(id: String) -> void:
	_sell_mode = false
	_building = true
	_build_id = id
	if _ghost:
		_ghost.set_art(id)
	status_label.text = "Build: %s" % id

func _on_sell_mode() -> void:
	_sell_mode = true
	_building = false
	if _ghost:
		_ghost.visible = false
	status_label.text = "Sell mode ON - click a tower to sell"

func _sell_tower(t: Node2D) -> void:
	gold += int(t.sell_refund)
	if _selected_tower == t:
		_selected_tower = null
		_focus_open = false
		if hud.has_method("show_tower"):
			hud.show_tower(null)
	t.queue_free()
	_sell_mode = false
	_building = true
	_refresh_hud()
	status_label.text = "Sold"

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
	_wave_end_msec = Time.get_ticks_msec() + int(_wave_duration * 1000.0)
	if hud.has_method("set_wave"):
		hud.set_wave(index, total, _wave_time_left, _wave_duration)
	status_label.text = "Wave %d / %d - 4 corners" % [index, total]

func _on_win() -> void:
	if _ended:
		return
	_ended = true
	status_label.text = "VICTORY"

func _lose() -> void:
	_ended = true
	status_label.text = "DEFEAT"

func _update_placement_ghost(delta: float) -> void:
	if _ghost == null:
		return
	_ghost_hide_t = maxf(_ghost_hide_t - delta, 0.0)
	# Primary feedback is the ghost; hide in sell / not building / ended / over UI.
	if _ended or _sell_mode or not _building:
		_ghost.visible = false
		return
	if _ghost_hide_t > 0.0:
		_ghost.visible = false
		return
	# Same cursor space as _unhandled_input → _place_tower (no sprite-offset pos).
	var pos := get_global_mouse_position()
	if _over_ui(pos):
		_ghost.visible = false
		return
	_ghost.visible = true
	# One function, one radii set — identical gate to click-to-place.
	var check: Dictionary = _can_place(pos, _build_id)
	_ghost.set_legal(bool(check["ok"]))
	_ghost.tick(delta, pos)

func _refresh_hud() -> void:
	if hud.has_method("set_resources"):
		hud.set_resources(lives, gold, START_LIVES)
