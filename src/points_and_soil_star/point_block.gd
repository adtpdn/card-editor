# point_block.gd
extends Node3D

var biome_type: String = "forest"
const BLOCK_SIZE = Vector3(1.5, 0.2, 1.5)

const BIOME_COLORS = {
	# Regular biome colors
	"forest": Color(0.2, 0.8, 0.2),    # Green
	"desert": Color(0.8, 0.8, 0.2),    # Yellow
	"mountain": Color(0.5, 0.5, 0.5),  # Gray
	"water": Color(0.2, 0.2, 0.8),     # Blue
	
	# Magic biome colors (slightly brighter/glowing versions)
	"forest_magic": Color(0.4, 1.0, 0.4),    # Bright Green
	"desert_magic": Color(1.0, 1.0, 0.4),    # Bright Yellow
	"mountain_magic": Color(0.7, 0.7, 0.7),  # Bright Gray
	"water_magic": Color(0.4, 0.4, 1.0)      # Bright Blue
}

#func _ready():
	#create_mesh()

#func create_mesh():
	#var mesh_instance = MeshInstance3D.new()
	#add_child(mesh_instance)
	#
	## Create box mesh
	#var mesh = BoxMesh.new()
	#mesh.size = BLOCK_SIZE
	#mesh_instance.mesh = mesh
	#
	## Create material
	#var material = StandardMaterial3D.new()
	#material.albedo_color = BIOME_COLORS[biome_type]
	#material.metallic = 0.4
	#material.roughness = 0.6
	#material.emission_enabled = true
	#material.emission_energy = 0.2
	#
	#mesh_instance.material_override = material
