# token_manager.gd
class_name TokenManager
extends Node

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

var player_tokens = {}
const TOKENS_PER_PLAYER = 16  # Increased to 16 tokens
const MAX_TOKENS_PER_BIOME = 12

signal token_placed(player_id: int, biome: BiomeType, location: Vector3)

# Token scene reference
var token_scene = preload("res://token_3d.tscn")

# In your TokenManager class:
func initialize_player_tokens(player_id: int, force_reset: bool = false):
	# Check if this is initial setup
	if !player_tokens.has(player_id) or force_reset:
		# Clear existing tokens
		player_tokens[player_id] = []
		
		# Add exactly 16 tokens (4 of each biome)
		for biome in range(BiomeType.size()):
			for i in range(4):  # 4 tokens per biome
				player_tokens[player_id].append({
					"biome": biome
				})
		
		print("Initialized tokens for player ", player_id, " with ", TOKENS_PER_PLAYER, " tokens")

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

func can_place_token(player_id: int, token_index: int) -> bool:
	if not player_tokens.has(player_id) or token_index >= player_tokens[player_id].size():
		return false
	return true

func remove_token(player_id: int, token_index: int):
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

func add_token_to_player(player_id: int, biome_type: int):
	if !player_tokens.has(player_id):
		player_tokens[player_id] = []
	
	# Create a new token data entry
	player_tokens[player_id].append({})
	
	# Force update to clients
	var game = get_tree().get_root().get_node("Game")
	if game and game.multiplayer.is_server():
		var tokens = get_player_tokens(player_id)
		game.rpc_id(player_id, "sync_player_tokens", tokens)
