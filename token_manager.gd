# token_manager.gd
class_name TokenManager
extends Node

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}

var player_tokens = {}
const TOKENS_PER_PLAYER = 16  # Increased to 16 tokens
const MAX_TOKENS_PER_BIOME = 12

signal token_placed(player_id: int, biome: BiomeType, location: Vector3)

# Token scene reference
var token_scene = preload("res://token_3d.tscn")

func initialize_player_tokens(player_id: int, force_refresh: bool = false):
	# Allow force refresh of tokens if needed
	if player_tokens.has(player_id) and !force_refresh:
		return
		
	player_tokens[player_id] = []
	
	# Simply add 16 generic tokens
	for i in range(TOKENS_PER_PLAYER):
		player_tokens[player_id].append({})
	
	print("Initialized " + str(player_tokens[player_id].size()) + " tokens for player " + str(player_id))

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
