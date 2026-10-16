extends CanvasLayer

@onready var control: Control = $Control
@onready var btn_left: Button = $Control/LeftContainer/BtnLeft
@onready var btn_right: Button = $Control/LeftContainer/BtnRight
@onready var btn_jump: Button = $Control/RightContainer/BtnJump
@onready var btn_pause: Button = $Control/TopContainer/BtnPause

func _ready() -> void:
	# Show on touch-enabled devices, mobile, web, or when debug testing
	_update_visibility()
	
	btn_left.button_down.connect(func(): Input.action_press("move_left"))
	btn_left.button_up.connect(func(): Input.action_release("move_left"))
	
	btn_right.button_down.connect(func(): Input.action_press("move_right"))
	btn_right.button_up.connect(func(): Input.action_release("move_right"))
	
	btn_jump.button_down.connect(func(): Input.action_press("jump"))
	btn_jump.button_up.connect(func(): Input.action_release("jump"))
	
	btn_pause.pressed.connect(_on_pause_pressed)

func _process(_delta: float) -> void:
	var current_scene = get_tree().current_scene
	if current_scene and (current_scene.name == "Menu" or current_scene.name == "WinScreen"):
		control.visible = false
	else:
		_update_visibility()

func _update_visibility() -> void:
	var should_show: bool = (
		OS.has_feature("web") or 
		OS.has_feature("mobile") or 
		DisplayServer.is_touchscreen_available() or
		OS.is_debug_build()
	)
	control.visible = should_show

func _on_pause_pressed() -> void:
	var ev = InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
