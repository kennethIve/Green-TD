extends Control
## Dark-glass HUD - 3 top pills, build glow, focus costs.

signal build_pressed(id: String)
signal upgrade_pressed
signal sell_pressed
signal pause_pressed
signal settings_pressed
signal wave_pressed

const ACCENT := Color("3DDC84")
const PANEL_BG := Color(0.08, 0.1, 0.09, 0.85)
const SELL_RED := Color(0.9, 0.3, 0.3)
const DIM := Color(0.55, 0.55, 0.55, 0.85)

const TowerScript = preload("res://scripts/tower/tower.gd")
const TRAY_LABELS := {
	"archer": "Arch",
	"cannon": "Cann",
	"frost": "Frost",
	"lightning": "Bolt",
	"support": "Aura",
	"sell": "Sell",
}

@onready var lives_label: Label = %LivesLabel
@onready var gold_label: Label = %GoldLabel
@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var wave_bar: ProgressBar = %WaveBar
@onready var focus_card: PanelContainer = %FocusCard
@onready var focus_name: Label = %FocusName
@onready var focus_dps: Label = %FocusDps
@onready var focus_range: Label = %FocusRange
@onready var focus_upgrade_cost: Label = %FocusUpgradeCost
@onready var focus_sell_refund: Label = %FocusSellRefund
@onready var upgrade_btn: Button = %UpgradeBtn
@onready var sell_btn: Button = %SellBtn
@onready var build_tray: HBoxContainer = %BuildTray

var _build_buttons: Dictionary = {}
var _selected_build: String = ""
var _gold: int = 0

func _ready() -> void:
	_style_panels()
	_wire_buttons()
	_refresh_tray_costs()
	show_tower(null)

func set_resources(lives: int, gold: int, lives_max: int = 40) -> void:
	_gold = gold
	lives_label.text = "HP %d / %d" % [lives, lives_max]
	gold_label.text = "Gold %d" % gold
	_refresh_tray_afford()

func set_wave(n: int, total: int, secs: float, duration: float = -1.0) -> void:
	wave_label.text = "Wave %d / %d" % [n, total]
	var left := maxf(secs, 0.0)
	var secs_i: int = int(floor(left))
	var m: int = int(secs_i / 60.0)
	var s: int = secs_i % 60
	timer_label.text = "%02d:%02d" % [m, s]
	if duration > 0.0:
		wave_bar.max_value = duration
	elif wave_bar.max_value < 1.0:
		wave_bar.max_value = maxf(left, 1.0)
	wave_bar.value = clampf(left, 0.0, wave_bar.max_value)

func show_tower(data) -> void:
	if data == null:
		focus_card.visible = false
		return
	focus_card.visible = true
	focus_name.text = str(data.get("name", "Tower"))
	focus_dps.text = "DPS  %s   (+%s)" % [str(data.get("dps", "-")), str(data.get("dps_delta", 0))]
	focus_range.text = "Range  %s   (+%s)" % [str(data.get("range", "-")), str(data.get("range_delta", 0))]
	focus_upgrade_cost.text = "Upgrade  $%s" % str(data.get("upgrade_cost", "-"))
	focus_sell_refund.text = "Refund  $%s" % str(data.get("sell_refund", "-"))

func set_build_selected(id: String) -> void:
	_selected_build = id
	for btn_id in _build_buttons:
		var btn: Button = _build_buttons[btn_id]
		var on: bool = btn_id == id
		btn.button_pressed = on
		_set_btn_glow(btn, on, btn_id)
	_refresh_tray_afford()

func _tower_cost(id: String) -> int:
	if id == "sell":
		return 0
	var d: Dictionary = TowerScript.DEFS.get(id, {})
	return int(d.get("cost", 0))

func _refresh_tray_costs() -> void:
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]
		var label: String = str(TRAY_LABELS.get(id, id))
		if id == "sell":
			btn.text = label
		else:
			btn.text = "%s\n$%d" % [label, _tower_cost(id)]

func _refresh_tray_afford() -> void:
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]
		var cost: int = _tower_cost(id)
		var can: bool = id == "sell" or _gold >= cost
		# Keep clickable so player can still select; dim to show unaffordable.
		btn.modulate = Color.WHITE if can else DIM
		_set_btn_glow(btn, id == _selected_build, id)

func _set_btn_glow(btn: Button, on: bool, id: String = "") -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.14, 0.95)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if on:
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_color = ACCENT
		sb.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
		sb.shadow_size = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var cost: int = _tower_cost(id) if id != "" else 0
	var can: bool = id == "" or id == "sell" or _gold >= cost
	if on and can:
		btn.add_theme_color_override("font_color", ACCENT)
	elif not can:
		btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		btn.remove_theme_color_override("font_color")

func _wire_buttons() -> void:
	%SettingsBtn.pressed.connect(func() -> void: settings_pressed.emit())
	%PauseBtn.pressed.connect(func() -> void: pause_pressed.emit())
	if has_node("%WaveBtn"):
		%WaveBtn.pressed.connect(func() -> void: wave_pressed.emit())
	upgrade_btn.pressed.connect(func() -> void: upgrade_pressed.emit())
	sell_btn.pressed.connect(func() -> void: sell_pressed.emit())
	upgrade_btn.add_theme_color_override("font_color", ACCENT)
	sell_btn.add_theme_color_override("font_color", SELL_RED)
	var ids := ["archer", "cannon", "frost", "lightning", "support", "sell"]
	for id in ids:
		var node_name := "TowerBtn_%s" % id
		if build_tray.has_node(node_name):
			var b: Button = build_tray.get_node(node_name)
			_build_buttons[id] = b
			b.custom_minimum_size = Vector2(72, 64)
			b.pressed.connect(_on_build.bind(id))
			_set_btn_glow(b, false, id)

func _on_build(id: String) -> void:
	if id == "sell":
		set_build_selected("sell")
		sell_pressed.emit()  # enter sell mode; click tower to confirm
	else:
		set_build_selected(id)
		build_pressed.emit(id)

func _style_panels() -> void:
	for path in ["%ResourcesPill", "%WavePillPanel", "%SysPill", "%Minimap", "%FocusCard", "%BuildTrayPanel"]:
		var n := get_node_or_null(path)
		if n is PanelContainer:
			var sb := StyleBoxFlat.new()
			sb.bg_color = PANEL_BG
			sb.set_corner_radius_all(14)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			(n as PanelContainer).add_theme_stylebox_override("panel", sb)
