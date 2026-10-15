extends Control

@onready var title_container: VBoxContainer = %TitleContainer
@onready var play_again_button: Button = %PlayAgainButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var victory_sound: AudioStreamPlayer = $VictorySound

func _ready() -> void:
	# Guarantee engine states are normal
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	_setup_button(play_again_button, _on_play_again_pressed)
	_setup_button(main_menu_button, _on_main_menu_pressed)
	_setup_button(quit_button, _on_quit_pressed)
	
	play_again_button.grab_focus()
	
	if victory_sound:
		victory_sound.play()
	
	_start_ambient_animations()

func _start_ambient_animations() -> void:
	if title_container:
		var initial_y = title_container.position.y
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(title_container, "position:y", initial_y - 6.0, 1.8)
		tween.tween_property(title_container, "position:y", initial_y + 4.0, 1.8)

func _setup_button(btn: Button, callback: Callable) -> void:
	if not btn:
		return
	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func(): _on_button_hover(btn))
	btn.focus_entered.connect(func(): _on_button_hover(btn))
	btn.mouse_exited.connect(func(): _on_button_unhover(btn))
	btn.focus_exited.connect(func(): _on_button_unhover(btn))

func _on_button_hover(btn: Button) -> void:
	if hover_sound:
		hover_sound.play()
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _on_play_again_pressed() -> void:
	if click_sound:
		click_sound.play()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager"):
		get_node("/root/SaveManager").start_new_game()
	else:
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu_pressed() -> void:
	if click_sound:
		click_sound.play()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_quit_pressed() -> void:
	if click_sound:
		click_sound.play()
	var timer = get_tree().create_timer(0.2)
	await timer.timeout
	get_tree().quit()
