# DiceManager.gd
extends Node3D

signal roll_completed(result: int, player_id: int, face_name: String)

@onready var dice_mesh: MeshInstance3D = $DiceMesh
@onready var face_label: Label3D = $FaceLabel
var is_rolling: bool = false
var final_result: int = 1

const FACE_NAMES = {
	1: "Forest Guardian",
	2: "Desert Wind",
	3: "Mountain Peak",
	4: "Ocean Deep",
	5: "Sacred Grove",
	6: "Ancient Ruins"
}

const FACE_ROTATIONS = {
	1: Vector3(0, 0, 0),
	2: Vector3(0, 0, -PI/2),
	3: Vector3(-PI/2, 0, 0),
	4: Vector3(PI/2, 0, 0),
	5: Vector3(0, 0, PI/2),
	6: Vector3(PI, 0, 0)
}

const FACE_COLORS = {
	1: Color(0.2, 0.8, 0.2),  # Green for Forest
	2: Color(0.8, 0.8, 0.2),  # Yellow for Desert
	3: Color(0.6, 0.6, 0.6),  # Gray for Mountain
	4: Color(0.2, 0.2, 0.8),  # Blue for Ocean
	5: Color(0.4, 0.8, 0.4),  # Light green for Grove
	6: Color(0.8, 0.6, 0.4)   # Brown for Ruins
}

func _ready():
	if not dice_mesh:
		setup_dice_mesh()
	update_face_label(1)  # Show initial face

func setup_dice_mesh():
	# Create basic cube mesh
	var mesh = BoxMesh.new()
	dice_mesh = MeshInstance3D.new()
	dice_mesh.mesh = mesh
	add_child(dice_mesh)
	
	# Create materials for each face
	for i in range(6):
		var material = StandardMaterial3D.new()
		material.albedo_color = FACE_COLORS[i + 1]
		# You could add textures here if you have them
		material.roughness = 0.4
		material.metallic = 0.1
		
		# Apply material to specific face
		if dice_mesh.get_surface_override_material_count() <= i:
			dice_mesh.set_surface_override_material_count(i + 1)
		dice_mesh.set_surface_override_material(i, material)

func update_face_label(face_number: int):
	if face_label:
		face_label.text = FACE_NAMES[face_number]
		face_label.modulate = FACE_COLORS[face_number]

func roll(player_id: int) -> void:
	if is_rolling:
		return
		
	is_rolling = true
	final_result = randi_range(1, 6)
	_play_roll_animation(player_id)

func _play_roll_animation(player_id: int) -> void:
	var tween = create_tween()
	
	# Hide label during animation
	if face_label:
		face_label.visible = false
	
	# Random spins
	var random_spins = randf_range(2, 4)
	var duration = 1.0
	
	# First part: random spinning
	tween.tween_property(dice_mesh, "rotation", 
		Vector3(randf() * PI * random_spins, 
				randf() * PI * random_spins, 
				randf() * PI * random_spins), 
		duration)
	
	# Second part: align to final result
	tween.tween_property(dice_mesh, "rotation", 
		FACE_ROTATIONS[final_result], 
		0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Connect to tween completion
	tween.finished.connect(func(): _on_roll_animation_completed(player_id))

func _on_roll_animation_completed(player_id: int) -> void:
	is_rolling = false
	if face_label:
		face_label.visible = true
	update_face_label(final_result)
	roll_completed.emit(final_result, player_id, FACE_NAMES[final_result])

@rpc("any_peer", "call_local")
func sync_roll(result: int, player_id: int) -> void:
	final_result = result
	_play_roll_animation(player_id)

@rpc("any_peer")
func request_roll():
	if multiplayer.is_server():
		var player_id = multiplayer.get_remote_sender_id()
		var result = randi_range(1, 6)
		rpc("sync_roll", result, player_id)
