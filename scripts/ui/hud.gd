extends Control
## Green TD HUD — dark glass + #3DDC84 accent (UI/UX handoff stubs).

signal build_pressed(id: String)
signal upgrade_pressed
signal sell_pressed
signal pause_pressed
signal settings_pressed

const ACCENT := Color("3DDC84")
const PANEL_BG := Color(0.08, 0.1, 0.09, 0.85)

@onready var lives_label: Label = %LivesLabel
@onready var gold_label: Label = %GoldLabel
@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var wave_bar: ProgressBar = %WaveBar
@onready var focus_card: PanelContainer = %FocusCard
@onready var focus_name: Label = %FocusName
@onready var focus_dps: Label = %FocusDps
@onready var focus_range: Label = %FocusRange
@onready var build_tray: HBoxContainer = %BuildTray

var _build_buttons: Dictionary = {}
var _demo_seeded: bool = false


func _ready() -> void:
	_style_panels()
	_wire_buttons()
	# Demo seed only if game never pushed real resources this frame
	await get_tree().process_frame
	if not _demo_seeded:
		# Leave blank-ish defaults; main.gd owns live values
		pass


func set_resources(lives: int, gold: int) -> void:
	_demo_seeded = true
	lives_label.text = "♥ %d" % lives
	gold_label.text = "🪙 %d" % gold


func set_wave(n: int, total: int, secs: float) -> void:
	_demo_seeded = true
	wave_label.text = "Wave %d / %d" % [n, total]
	var m := int(secs) / 60
	var s := int(secs) % 60
	timer_label.text = "%02d:%02d" % [m, s]
	wave_bar.max_value = 30.0
	wave_bar.value = clampf(secs, 0.0, 30.0)


func show_tower(data) -> void:
	if data == null:
		focus_card.visible = false
		return
	focus_card.visible = true
	focus_name.text = str(data.get("name", "Tower"))
	focus_dps.text = "DPS  %s" % str(data.get("dps", "—"))
	focus_range.text = "Range  %s" % str(data.get("range", "—"))


func set_build_selected(id: String) -> void:
	for btn_id in _build_buttons:
		var btn: Button = _build_buttons[btn_id]
		btn.button_pressed = (btn_id == id)
		if btn_id == id:
			btn.add_theme_color_override("font_color", ACCENT)
		else:
			btn.remove_theme_color_override("font_color")


func _wire_buttons() -> void:
	%SettingsBtn.pressed.connect(func() -> void: settings_pressed.emit())
	%PauseBtn.pressed.connect(func() -> void: pause_pressed.emit())
	%UpgradeBtn.pressed.connect(func() -> void: upgrade_pressed.emit())
	%SellBtn.pressed.connect(func() -> void: sell_pressed.emit())
	var ids := ["archer", "cannon", "frost", "lightning", "support", "sell"]
	for i in ids.size():
		var node_name := "TowerBtn_%s" % ids[i]
		if build_tray.has_node(node_name):
			var b: Button = build_tray.get_node(node_name)
			b.set_meta("tower_id", ids[i])
			_build_buttons[ids[i]] = b
			b.pressed.connect(_on_build.bind(ids[i]))


func _on_build(id: String) -> void:
	if id == "sell":
		sell_pressed.emit()
	else:
		set_build_selected(id)
		build_pressed.emit(id)


func _style_panels() -> void:
	for path in ["%TopBarPanel", "%Minimap", "%FocusCard", "%BuildTrayPanel"]:
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
