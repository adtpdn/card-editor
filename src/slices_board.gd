extends Node3D

# Enum to make biome mapping clearer and prevent errors.
enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

@onready var mountain_slice = $MountainSlice
@onready var desert_slice = $DesertSlice
@onready var forest_slice = $ForestSlice
@onready var water_slice = $WaterSlice

# An array to easily iterate through all the biome slices
@onready var all_slices = [forest_slice, water_slice, mountain_slice, desert_slice ]

const slice_board_shader = preload("res://assets/materials/slices_board.tres")

"""
Applies the shader to the relevant biome slices based on the token's biome.
This function should now be called from your SigilManager when you are ready
to show the highlight.

Parameters:
- token_biome: The BiomeType enum value of the token that is initiating the move.
"""
func highlight_biomes_after_move(energy_token, selected_token):
	print("HIGHLIGHT BIOMES")
	var energy_token_biome = energy_token.biome_type
	var selected_token_biome = selected_token.biome_type
	
	# Clear the last slice biome 
	clear_biome_highlights()
	
	# Determine the adjacent biomes based on the game's rules.
	# Forest (0) and Mountain (2) are adjacent to Water (1) and Desert (3).
	var adjacent_biomes = []
	if energy_token_biome == BiomeType.FOREST or energy_token_biome == BiomeType.MOUNTAIN:
		adjacent_biomes = [BiomeType.WATER, BiomeType.DESERT]
	else: # WATER or DESERT
		adjacent_biomes = [BiomeType.FOREST, BiomeType.MOUNTAIN]

	# Apply the shader if the slice is the same biome OR an adjacent one.
	if energy_token_biome == selected_token_biome:
		for biome_id in adjacent_biomes:
			var biome_slice = all_slices[biome_id]
			biome_slice.material_override = slice_board_shader
	elif energy_token_biome != selected_token_biome:
		var biome_slice = all_slices[energy_token_biome]
		biome_slice.material_override = slice_board_shader


"""
Sets the material_override of all slices back to null, removing the shader effect.
This should be called from your TokenManager after a token move is successfully completed.
"""
func clear_biome_highlights():
	for slice in all_slices:
		slice.material_override = null
