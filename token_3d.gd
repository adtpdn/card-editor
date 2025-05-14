extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

var biome_type: BiomeType
@onready var outline_mesh: MeshInstance3D = $OutlineMesh  # Outer ring mesh
@onready var token_mesh: MeshInstance3D = $TokenMesh  # Inner token mesh
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var game = get_node("/root/Game")

var owner_id: int = -1

var token_placement = null
var is_energy: bool = false
var is_blighted: bool = false

func set_token_data(b_type: BiomeType, p_id: int = -1, energy: bool = false):
	print("Setting token data - Biome: ", b_type, " Owner: ", p_id, " Energy: ", energy)
	biome_type = b_type
	owner_id = p_id
	is_energy = energy
	is_blighted = false  # Initialize as not blighted
	
	update_token_display()

func set_blighted(blighted: bool):
	is_blighted = blighted
	update_token_display()

func update_token_display():
	var outline_material = StandardMaterial3D.new()
	var token_material = StandardMaterial3D.new()
	var mesh_material = StandardMaterial3D.new()
	
	# First, set the outline color based on player
	if game && game.player_colors.has(owner_id):
		outline_material.albedo_color = game.player_colors[owner_id]
		print("Setting token color for player ", owner_id, ": ", game.player_colors[owner_id])
	else:
		print("No color found for player ", owner_id)
		outline_material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray default
	
	# Apply outline material
	outline_mesh.material_override = outline_material
	
	if is_blighted:
		# If blighted, both inner meshes are black
		token_material.albedo_color = Color(0, 0, 0)  # Black
		mesh_material.albedo_color = Color(0, 0, 0)  # Black
	else:
		# If not blighted, inner meshes match the player color
		token_material.albedo_color = outline_material.albedo_color  # Same as outline
		mesh_material.albedo_color = outline_material.albedo_color  # Same as outline
		
		# Optional: make mesh_instance slightly darker for visual distinction
		mesh_material.albedo_color = mesh_material.albedo_color.darkened(0.2)
	
	# Apply the materials
	token_mesh.material_override = token_material
	mesh_instance.material_override = mesh_material
	
	# Apply any additional visual effects for energy tokens if needed
	if is_energy:
		# Example: Add emission to the token for energy tokens
		token_material.emission_enabled = true
		token_material.emission = token_material.albedo_color.lightened(0.3)
		token_material.emission_energy = 0.5
		token_mesh.material_override = token_material

func remove_token():
	# Mark the placement as unoccupied
	if token_placement:
		token_placement.set_occupied(false)
		token_placement.current_token = null
		token_placement.set_highlight(false)
	# Remove the token itself
	queue_free()
