# token_manager.gd
class_name TokenManager
extends Node

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TYPE1, TYPE2, TYPE3}

var player_tokens = {}
const TOKENS_PER_PLAYER = 4
const MAX_TOKENS_PER_BIOME = 8  # Adjust this value as needed

signal token_placed(player_id: int, biome: BiomeType, token_type: TokenType, location: Vector3)

# Token scene reference
var token_scene = preload("res://token_3d.tscn")


func initialize_player_tokens(player_id: int):
	print("Starting token initialization for player: ", player_id)
	
	if player_tokens.has(player_id):
		print("Player ", player_id, " already has tokens: ", player_tokens[player_id])
		return
		
	player_tokens[player_id] = []
	var tokens_per_biome = {}
	
	# Initialize counters for each biome
	for biome in BiomeType.values():
		tokens_per_biome[biome] = 0
		print("Initialized counter for biome ", BiomeType.keys()[biome])
	
	# First pass: ensure at least one token of each biome
	for biome in BiomeType.values():
		if player_tokens[player_id].size() >= TOKENS_PER_PLAYER:
			print("Reached max tokens during first pass")
			break
			
		var token_data = {
			"biome": biome,
			"type": randi() % TokenType.size()
		}
		player_tokens[player_id].append(token_data)
		tokens_per_biome[biome] += 1
		print("First pass: Added token of biome ", BiomeType.keys()[biome], " for player ", player_id)
	
	# Second pass: fill remaining slots while respecting MAX_TOKENS_PER_BIOME
	while player_tokens[player_id].size() < TOKENS_PER_PLAYER:
		var available_biomes = []
		for biome in BiomeType.values():
			if tokens_per_biome[biome] < MAX_TOKENS_PER_BIOME:
				available_biomes.append(biome)
		
		if available_biomes.is_empty():
			print("No more available biomes for additional tokens")
			break
			
		var selected_biome = available_biomes[randi() % available_biomes.size()]
		var token_data = {
			"biome": selected_biome,
			"type": randi() % TokenType.size()
		}
		player_tokens[player_id].append(token_data)
		tokens_per_biome[selected_biome] += 1
		print("Second pass: Added token of biome ", BiomeType.keys()[selected_biome], " for player ", player_id)
	
	# Final debug output
	print("Finished initializing tokens for player ", player_id)
	print("Final token distribution:")
	for biome in tokens_per_biome.keys():
		print("- Biome ", BiomeType.keys()[biome], ": ", tokens_per_biome[biome], " tokens")
	print("Total tokens: ", player_tokens[player_id].size())
	print("Token details: ", player_tokens[player_id])

func can_place_token(player_id: int, token_index: int, biome_type: BiomeType = -1) -> bool:
	if not player_tokens.has(player_id) or token_index >= player_tokens[player_id].size():
		return false
		
	if biome_type != -1:
		# Check if the token matches the required biome
		return player_tokens[player_id][token_index].biome == biome_type
		
	return true

func remove_token(player_id: int, token_index: int):
	print("Removing token ", token_index, " from player ", player_id)
	if player_tokens.has(player_id) and token_index >= 0 and token_index < player_tokens[player_id].size():
		player_tokens[player_id].remove_at(token_index)
		print("Updated tokens for player ", player_id, ": ", player_tokens[player_id])
		return true
	return false

func set_player_tokens(player_id: int, tokens: Array):
	print("Setting tokens for player ", player_id, ": ", tokens)
	player_tokens[player_id] = tokens

func get_player_tokens(player_id: int) -> Array:
	return player_tokens.get(player_id, [])
