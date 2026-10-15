extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var score_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScoreLabel
@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MenuButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound

var _is_animating: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_setup_button(resume_button, _on_resume_pressed)
	_setup_button(restart_button, _on_restart_pressed)
	_setup_button(menu_button, _on_menu_pressed)
	_setup_button(quit_button, _on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle_pause()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		get_viewport().set_input_as_handled()
		toggle_pause()

func toggle_pause() -> void:
	if visible:
		resume()
	else:
		pause()

func pause() -> void:
	_update_score_display()
	visible = true
	get_tree().paused = true
	
	# Focus first button for keyboard / controller navigation
	resume_button.grab_focus()
	
	if hover_sound:
		hover_sound.play()
	
	# Entrance animation
	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.85, 0.85)
	panel_container.modulate.a = 0.0
	overlay.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.25)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.2)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)

func resume() -> void:
	if _is_animating:
		return
	_is_animating = true
	
	if click_sound:
		click_sound.play()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.15)
	tween.tween_property(panel_container, "modulate:a", 0.0, 0.15)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
	
	await tween.finished
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	_is_animating = false

func restart() -> void:
	if click_sound:
		click_sound.play()
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func go_to_main_menu() -> void:
	if click_sound:
		click_sound.play()
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func quit_game() -> void:
	if click_sound:
		click_sound.play()
	get_tree().quit()

func _update_score_display() -> void:
	var gm = null
	if owner and owner.has_node("GameManager"):
		gm = owner.get_node("GameManager")
	elif get_tree().current_scene and get_tree().current_scene.has_node("GameManager"):
		gm = get_tree().current_scene.get_node("GameManager")
	elif get_parent() and "score" in get_parent():
		gm = get_parent()
	
	if gm and "score" in gm:
		score_label.text = "COINS COLLECTED: " + str(gm.score)
	else:
		score_label.text = "TAKE A BREATHER, HERO!"

func _setup_button(btn: Button, callback: Callable) -> void:
	if not btn:
		return
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func(): _on_button_hover(btn))
	btn.focus_entered.connect(func(): _on_button_hover(btn))
	btn.mouse_exited.connect(func(): _on_button_unhover(btn))
	btn.focus_exited.connect(func(): _on_button_unhover(btn))

func _on_button_hover(btn: Button) -> void:
	if not visible:
		return
	if hover_sound:
		hover_sound.play()
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	restart()

func _on_menu_pressed() -> void:
	go_to_main_menu()

func _on_quit_pressed() -> void:
	quit_game()
