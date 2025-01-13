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


func initialize_player_tokens(player_id: int, force_refresh: bool = false):
	# Allow force refresh of tokens if needed
	if player_tokens.has(player_id) and !force_refresh:
		return
		
	player_tokens[player_id] = []
	var tokens_per_biome = {}
	
	# Get tokens already on board for this player
	var placed_tokens = get_placed_tokens_for_player(player_id)
	
	# Initialize counters for each biome, considering placed tokens
	for biome in BiomeType.values():
		tokens_per_biome[biome] = 0
		for token in placed_tokens:
			if token.biome_type == biome:
				tokens_per_biome[biome] += 1
	
	# First pass: ensure at least one token of each biome if not maxed out
	for biome in BiomeType.values():
		if tokens_per_biome[biome] >= MAX_TOKENS_PER_BIOME:
			continue
			
		if player_tokens[player_id].size() >= TOKENS_PER_PLAYER:
			break
			
		var token_data = {
			"biome": biome,
			"type": randi() % TokenType.size()
		}
		player_tokens[player_id].append(token_data)
		tokens_per_biome[biome] += 1
	
	# Second pass: fill remaining slots
	while player_tokens[player_id].size() < TOKENS_PER_PLAYER:
		var available_biomes = []
		for biome in BiomeType.values():
			if tokens_per_biome[biome] < MAX_TOKENS_PER_BIOME:
				available_biomes.append(biome)
		
		if available_biomes.is_empty():
			break
			
		var selected_biome = available_biomes[randi() % available_biomes.size()]
		var token_data = {
			"biome": selected_biome,
			"type": randi() % TokenType.size()
		}
		player_tokens[player_id].append(token_data)
		tokens_per_biome[selected_biome] += 1

func get_placed_tokens_for_player(player_id: int) -> Array:
	var game = get_tree().get_root().get_node("Game")
	if !game:
		return []
		
	var placed_tokens = []
	var tokens_node = game.get_node("Tokens")
	if tokens_node:
		for token in tokens_node.get_children():
			if token.owner_id == player_id:
				placed_tokens.append(token)
	
	return placed_tokens

func can_place_token(player_id: int, token_index: int, biome_type: BiomeType = -1) -> bool:
	if not player_tokens.has(player_id) or token_index >= player_tokens[player_id].size():
		return false
		
	if biome_type != -1:
		# Check if the token matches the required biome
		return player_tokens[player_id][token_index].biome == biome_type
		
	return true

func remove_token(player_id: int, token_index: int):
	#print("Removing token ", token_index, " from player ", player_id)
	if player_tokens.has(player_id) and token_index >= 0 and token_index < player_tokens[player_id].size():
		player_tokens[player_id].remove_at(token_index)
		return true
	return false

func set_player_tokens(player_id: int, tokens: Array):
	if tokens == null:
		tokens = []
	player_tokens[player_id] = tokens.duplicate()

func get_player_tokens(player_id: int) -> Array:
	if !player_tokens.has(player_id):
		player_tokens[player_id] = []
	return player_tokens[player_id].duplicate()
