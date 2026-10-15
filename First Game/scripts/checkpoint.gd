extends Area2D

## Reusable Checkpoint entity
## Automatically detects player, gives visual/sound feedback, and triggers SaveManager.

signal checkpoint_reached(id: String)

@export var checkpoint_id: String = "checkpoint_1"
@export var spawn_offset: Vector2 = Vector2(0, -6)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("SFX")
@onready var status_label: Label = get_node_or_null("StatusLabel")

var is_activated: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if status_label:
		status_label.modulate.a = 0.0
	
	# Start gentle ambient breathing/floating animation
	if sprite:
		var initial_y = sprite.position.y
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(sprite, "position:y", initial_y - 2.5, 1.4)
		tween.tween_property(sprite, "position:y", initial_y + 2.5, 1.4)

func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	
	# Verify player trigger
	if not (body is CharacterBody2D or body.name == "Player"):
		return
	
	activate_checkpoint()

func activate_checkpoint() -> void:
	is_activated = true
	
	# Audio feedback
	if sfx:
		sfx.play()
	
	# Particle activation burst
	if particles:
		particles.emitting = true
		particles.speed_scale = 2.0
	
	# Visual punch on flag / totem
	if sprite:
		var punch_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch_tween.tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.18)
		punch_tween.tween_property(sprite, "scale", Vector2.ONE, 0.18)
		# Light up with a triumphant golden glow
		sprite.modulate = Color(1.2, 1.2, 0.8, 1.0)
	
	# Floating notification popup
	if status_label:
		status_label.text = "CHECKPOINT!"
		status_label.position.y = -26.0
		var label_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		label_tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
		label_tween.tween_property(status_label, "position:y", -38.0, 0.7)
		
		var fade_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_tween.tween_interval(0.8)
		fade_tween.tween_property(status_label, "modulate:a", 0.0, 0.4)
	
	checkpoint_reached.emit(checkpoint_id)
	
	# Trigger automatic save through SaveManager singleton
	if Engine.has_singleton("SaveManager") or get_node_or_null("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var spawn_pos = global_position + spawn_offset
		sm.save_at_checkpoint(checkpoint_id, spawn_pos)
		print("[Checkpoint] Activated checkpoint '%s' at %s" % [checkpoint_id, str(spawn_pos)])
