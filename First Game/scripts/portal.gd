extends Area2D

## Reusable Portal: can load an exported target scene (PackedScene) or a target file path
@export var target_scene: PackedScene
@export_file("*.tscn") var target_scene_path: String = ""

## Legacy support for existing scenes
@export_file("*.tscn") var next_scene_path: String = ""

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var sfx: AudioStreamPlayer = get_node_or_null("SFX")

var _activated: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_start_ambient_fx()

func _start_ambient_fx() -> void:
	if sprite:
		var initial_y = sprite.position.y
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "position:y", initial_y - 4.0, 1.2)
		tween.tween_property(sprite, "position:y", initial_y + 4.0, 1.2)

func _on_body_entered(body: Node2D) -> void:
	if _activated:
		return
	
	# Only player activates the portal
	if not (body is CharacterBody2D or body.name == "Player"):
		return
	
	# Resolve target destination
	var destination_path = target_scene_path
	if destination_path.is_empty():
		destination_path = next_scene_path
	
	if target_scene == null and destination_path.is_empty():
		push_warning("Portal at %s has no target scene or path set!" % str(global_position))
		return
	
	_activated = true
	
	# Play sound effect
	if sfx:
		sfx.play()
	
	# Visual activation burst
	if sprite:
		var punch_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch_tween.tween_property(sprite, "scale", sprite.scale * 1.6, 0.22)
		punch_tween.tween_property(sprite, "rotation", sprite.rotation + PI, 0.22)
	
	if particles:
		particles.speed_scale = 2.5
	
	# Reset Engine time scale and pause states safely before changing scene
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	# Auto-save progress via SaveManager singleton
	var resolved_dest = destination_path
	if target_scene and not target_scene.resource_path.is_empty():
		resolved_dest = target_scene.resource_path
	
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if resolved_dest.contains("win_screen"):
			sm.save_level_completed(get_tree().current_scene.scene_file_path if get_tree().current_scene else "", resolved_dest)
		else:
			sm.save_level_transition(resolved_dest)
	
	# Brief delay for audio/visual punch
	await get_tree().create_timer(0.25).timeout
	
	if target_scene:
		get_tree().change_scene_to_packed.call_deferred(target_scene)
	elif not destination_path.is_empty():
		get_tree().change_scene_to_file.call_deferred(destination_path)
