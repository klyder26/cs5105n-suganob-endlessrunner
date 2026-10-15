extends Control

@onready var title_container: VBoxContainer = %TitleContainer
@onready var continue_button: Button = %ContinueButton
@onready var play_button: Button = %PlayButton
@onready var controls_button: Button = %ControlsButton
@onready var quit_button: Button = %QuitButton

@onready var left_decor: Node2D = %LeftDecor
@onready var right_decor: Node2D = %RightDecor

@onready var how_to_play_modal: Control = %HowToPlayModal
@onready var close_modal_button: Button = %CloseModalButton
@onready var modal_panel: PanelContainer = %ModalPanel
@onready var modal_overlay: ColorRect = %ModalOverlay

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var start_sound: AudioStreamPlayer = $StartSound

var _is_starting: bool = false

func _ready() -> void:
	# Ensure game time and pause state are reset when reaching main menu
	get_tree().paused = false
	Engine.time_scale = 1.0
	
	how_to_play_modal.visible = false
	
	_setup_button(continue_button, _on_continue_pressed)
	_setup_button(play_button, _on_play_pressed)
	_setup_button(controls_button, _on_controls_pressed)
	_setup_button(quit_button, _on_quit_pressed)
	_setup_button(close_modal_button, _on_close_modal_pressed)
	
	# Check if a valid save game exists
	var sm = get_node_or_null("/root/SaveManager")
	var save_exists = sm and sm.has_save()
	
	if save_exists:
		continue_button.visible = true
		continue_button.disabled = false
		continue_button.grab_focus()
	else:
		continue_button.visible = false
		continue_button.disabled = true
		# Fix focus chain for keyboard/controller when continue is hidden
		play_button.focus_neighbor_top = play_button.get_path_to(quit_button)
		quit_button.focus_neighbor_bottom = quit_button.get_path_to(play_button)
		play_button.grab_focus()
	
	# Ambient floating animations
	_start_ambient_animations()

func _unhandled_input(event: InputEvent) -> void:
	if how_to_play_modal.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close_controls_modal()

func _start_ambient_animations() -> void:
	# Gentle floating bob on Title
	if title_container:
		var initial_y = title_container.position.y
		var tween_title = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_title.tween_property(title_container, "position:y", initial_y - 6.0, 1.8)
		tween_title.tween_property(title_container, "position:y", initial_y + 4.0, 1.8)
	
	# Subtle floating on Left Decor (Knight)
	if left_decor:
		var left_y = left_decor.position.y
		var tween_left = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_left.tween_property(left_decor, "position:y", left_y - 8.0, 2.2)
		tween_left.tween_property(left_decor, "position:y", left_y + 8.0, 2.2)
	
	# Subtle floating on Right Decor (Slime)
	if right_decor:
		var right_y = right_decor.position.y
		var tween_right = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_right.tween_property(right_decor, "position:y", right_y + 6.0, 2.0)
		tween_right.tween_property(right_decor, "position:y", right_y - 6.0, 2.0)

func _setup_button(btn: Button, callback: Callable) -> void:
	if not btn:
		return
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func(): _on_button_hover(btn))
	btn.focus_entered.connect(func(): _on_button_hover(btn))
	btn.mouse_exited.connect(func(): _on_button_unhover(btn))
	btn.focus_exited.connect(func(): _on_button_unhover(btn))

func _on_button_hover(btn: Button) -> void:
	if how_to_play_modal.visible and btn != close_modal_button:
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

func _on_continue_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	
	if start_sound:
		start_sound.play()
	
	# Playful button punch effect
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(continue_button, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(continue_button, "scale", Vector2.ONE, 0.1)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await fade_tween.finished
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		sm.continue_game()
	else:
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_play_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	
	if start_sound:
		start_sound.play()
	
	# Playful button punch effect
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(play_button, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(play_button, "scale", Vector2.ONE, 0.1)
	
	# Smooth fade out before scene change
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await fade_tween.finished
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.start_new_game()
	else:
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_controls_pressed() -> void:
	if click_sound:
		click_sound.play()
	
	how_to_play_modal.visible = true
	modal_overlay.modulate.a = 0.0
	modal_panel.modulate.a = 0.0
	modal_panel.pivot_offset = modal_panel.size / 2.0
	modal_panel.scale = Vector2(0.85, 0.85)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(modal_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.25)
	
	close_modal_button.grab_focus()

func _close_controls_modal() -> void:
	if click_sound:
		click_sound.play()
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(modal_overlay, "modulate:a", 0.0, 0.15)
	tween.tween_property(modal_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(modal_panel, "scale", Vector2(0.9, 0.9), 0.15)
	
	await tween.finished
	how_to_play_modal.visible = false
	controls_button.grab_focus()

func _on_close_modal_pressed() -> void:
	_close_controls_modal()

func _on_quit_pressed() -> void:
	if click_sound:
		click_sound.play()
	var timer = get_tree().create_timer(0.18)
	await timer.timeout
	get_tree().quit()
