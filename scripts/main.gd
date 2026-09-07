extends Node2D
## Green TD — main scene entry.

@onready var hud: Control = $UI/HUD


func _ready() -> void:
	print("Green TD running with HUD")
	if hud.has_signal("build_pressed"):
		hud.build_pressed.connect(_on_build_pressed)
	if hud.has_signal("upgrade_pressed"):
		hud.upgrade_pressed.connect(func() -> void: print("upgrade"))
	if hud.has_signal("sell_pressed"):
		hud.sell_pressed.connect(func() -> void: print("sell"))
	if hud.has_signal("pause_pressed"):
		hud.pause_pressed.connect(func() -> void: print("pause"))
	if hud.has_signal("settings_pressed"):
		hud.settings_pressed.connect(func() -> void: print("settings"))


func _on_build_pressed(id: String) -> void:
	print("build_pressed: ", id)
