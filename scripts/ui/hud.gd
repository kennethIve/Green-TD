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
const COST_GOLD := Color(1.0, 0.88, 0.28, 1.0)
const COST_GOLD_DIM := Color(0.92, 0.78, 0.22, 1.0)  # still readable when unaffordable
const NAME_DIM := Color(0.65, 0.68, 0.65, 1.0)

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
	_refresh_tray_afford()
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

func _tray_name_label(btn: Button) -> Label:
	return btn.get_node_or_null("TrayLabels/NameLabel") as Label

func _tray_cost_label(btn: Button) -> Label:
	return btn.get_node_or_null("TrayLabels/CostLabel") as Label

func _ensure_tray_child_labels(btn: Button) -> void:
	## Dedicated child Labels so $cost never clips / fades with Button multiline text.
	btn.text = ""
	btn.clip_text = false
	btn.custom_minimum_size = Vector2(84, 76)
	var vbox: VBoxContainer = btn.get_node_or_null("TrayLabels") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "TrayLabels"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 2)
		btn.add_child(vbox)
	var name_l: Label = vbox.get_node_or_null("NameLabel") as Label
	if name_l == null:
		name_l = Label.new()
		name_l.name = "NameLabel"
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_l)
	var cost_l: Label = vbox.get_node_or_null("CostLabel") as Label
	if cost_l == null:
		cost_l = Label.new()
		cost_l.name = "CostLabel"
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_l.add_theme_font_size_override("font_size", 15)
		cost_l.add_theme_color_override("font_color", COST_GOLD)
		vbox.add_child(cost_l)

func _refresh_tray_costs() -> void:
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]
		_ensure_tray_child_labels(btn)
		var label: String = str(TRAY_LABELS.get(id, id))
		var name_l: Label = _tray_name_label(btn)
		var cost_l: Label = _tray_cost_label(btn)
		if name_l:
			name_l.text = label
		if cost_l:
			if id == "sell":
				cost_l.text = ""
				cost_l.visible = false
			else:
				cost_l.visible = true
				cost_l.text = "$%d" % _tower_cost(id)
				cost_l.add_theme_color_override("font_color", COST_GOLD)

func _refresh_tray_afford() -> void:
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]
		var cost: int = _tower_cost(id)
		var can: bool = id == "sell" or _gold >= cost
		# Never modulate the whole button — that washed out $cost for some clients.
		btn.modulate = Color.WHITE
		var name_l: Label = _tray_name_label(btn)
		var cost_l: Label = _tray_cost_label(btn)
		if name_l:
			if can:
				name_l.remove_theme_color_override("font_color")
			else:
				name_l.add_theme_color_override("font_color", NAME_DIM)
		if cost_l and id != "sell":
			# Keep $ readable even when unaffordable (gold, not faded to grey).
			cost_l.add_theme_color_override("font_color", COST_GOLD if can else COST_GOLD_DIM)
		_set_btn_glow(btn, id == _selected_build, id)

func _set_btn_glow(btn: Button, on: bool, id: String = "") -> void:
	var cost: int = _tower_cost(id) if id != "" else 0
	var can: bool = id == "" or id == "sell" or _gold >= cost
	var sb := StyleBoxFlat.new()
	if can:
		sb.bg_color = Color(0.12, 0.16, 0.14, 0.95)
	else:
		# Dim chrome only — labels keep their own colors.
		sb.bg_color = Color(0.08, 0.09, 0.08, 0.75)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if on:
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_color = ACCENT if can else Color(0.45, 0.5, 0.45)
		sb.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55 if can else 0.25)
		sb.shadow_size = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)
	# Button.text is empty (child labels); keep font overrides clear.
	btn.remove_theme_color_override("font_color")
	var name_l: Label = _tray_name_label(btn)
	if name_l and on and can:
		name_l.add_theme_color_override("font_color", ACCENT)
	elif name_l and not can:
		name_l.add_theme_color_override("font_color", NAME_DIM)
	elif name_l and not on:
		name_l.remove_theme_color_override("font_color")

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
			_ensure_tray_child_labels(b)
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
