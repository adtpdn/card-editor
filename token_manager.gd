# token_manager.gd
class_name TokenManager
extends Node

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TRIANGLE, SQUARE, CIRCLE}

var player_tokens = {}
const TOKENS_PER_PLAYER = 12  # Change from 4 to 12 tokens per player
const MAX_TOKENS_PER_BIOME = 12  # Adjust max tokens per biome

signal token_placed(player_id: int, biome: BiomeType, token_type: TokenType, location: Vector3)

# Token scene reference
var token_scene = preload("res://token_3d.tscn")


func initialize_player_tokens(player_id: int, force_refresh: bool = false):
	# Allow force refresh of tokens if needed
	if player_tokens.has(player_id) and !force_refresh:
		return
		
	player_tokens[player_id] = []
	var token_counts = {}
	
	# Initialize count tracking for each biome-type combination
	for biome in BiomeType.values():
		for type in TokenType.values():
			token_counts[str(biome) + "_" + str(type)] = 0
	
	# First pass: ensure at least one token of each combination
	for biome in BiomeType.values():
		for type in TokenType.values():
			if player_tokens[player_id].size() >= TOKENS_PER_PLAYER:
				break
				
			var token_data = {
				"biome": biome,
				"type": type
			}
			player_tokens[player_id].append(token_data)
			token_counts[str(biome) + "_" + str(type)] += 1
	
	# Second pass: fill remaining slots randomly
	while player_tokens[player_id].size() < TOKENS_PER_PLAYER:
		var biome = randi() % BiomeType.size()
		var type = randi() % TokenType.size()
		
		var token_data = {
			"biome": biome,
			"type": type
		}
		player_tokens[player_id].append(token_data)

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
