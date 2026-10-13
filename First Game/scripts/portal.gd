extends Area2D
@export_file("*.tscn") var next_scene_path: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if body:
		if next_scene_path != "":
			# Safely wait for the physics frame to finish before changing the scene
			get_tree().change_scene_to_file.call_deferred(next_scene_path)
		else:
			push_warning("next_scene_path is empty!")
