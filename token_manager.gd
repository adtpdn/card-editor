# token_manager.gd
class_name TokenManager
extends Node

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TRIANGLE, SQUARE, CIRCLE}
enum TokenStatus {COMMON, ENGINE}

var player_tokens = {}  # Unplaced tokens (in hand)
var placed_tokens = {}  # Placed tokens
const TOKENS_PER_PLAYER = 12
const MAX_TOKENS_PER_BIOME = 12

signal token_placed(player_id: int, biome: BiomeType, token_type: TokenType, location: Vector3)

var token_scene = preload("res://token_3d.tscn")

func initialize_player_tokens(player_id: int, force_refresh: bool = false):
	# Allow force refresh of tokens if needed
	if player_tokens.has(player_id) and !force_refresh:
		return
		
	player_tokens[player_id] = []
	placed_tokens[player_id] = []  # Initialize placed tokens array
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
				"type": type,
				"status": TokenStatus.COMMON
			}
			player_tokens[player_id].append(token_data)
			token_counts[str(biome) + "_" + str(type)] += 1
	
	# Second pass: fill remaining slots randomly
	while player_tokens[player_id].size() < TOKENS_PER_PLAYER:
		var biome = randi() % BiomeType.size()
		var type = randi() % TokenType.size()
		
		var token_data = {
			"biome": biome,
			"type": type,
			"status": TokenStatus.COMMON
		}
		player_tokens[player_id].append(token_data)

func add_placed_token(player_id: int, token_data: Dictionary, position: Vector3):
	if !placed_tokens.has(player_id):
		placed_tokens[player_id] = []
	
	var placed_token = token_data.duplicate()
	placed_token["position"] = position
	placed_tokens[player_id].append(placed_token)
	emit_signal("token_placed", player_id, token_data.biome, token_data.type, position)

func remove_token(player_id: int, token_index: int) -> Dictionary:
	if player_tokens.has(player_id) and token_index >= 0 and token_index < player_tokens[player_id].size():
		var token_data = player_tokens[player_id][token_index]
		player_tokens[player_id].remove_at(token_index)
		return token_data
	return {}

func get_placed_tokens_for_player(player_id: int) -> Array:
	return placed_tokens.get(player_id, []).duplicate()

func get_player_tokens(player_id: int) -> Array:
	if !player_tokens.has(player_id):
		player_tokens[player_id] = []
	return player_tokens[player_id].duplicate()

func get_all_player_tokens(player_id: int) -> Array:
	var all_tokens = []
	all_tokens.append_array(get_player_tokens(player_id))
	all_tokens.append_array(get_placed_tokens_for_player(player_id))
	return all_tokens

func can_place_token(player_id: int, token_index: int, biome_type: BiomeType = -1) -> bool:
	if not player_tokens.has(player_id) or token_index >= player_tokens[player_id].size():
		return false
		
	if biome_type != -1:
		# Check if the token matches the required biome
		return player_tokens[player_id][token_index].biome == biome_type
		
	return true

func set_player_tokens(player_id: int, tokens: Array):
	if tokens == null:
		tokens = []
	player_tokens[player_id] = tokens.duplicate()

# Helper function to get token counts
func get_token_counts(player_id: int) -> Dictionary:
	var counts = {
		"placed": placed_tokens.get(player_id, []).size(),
		"unplaced": player_tokens.get(player_id, []).size(),
		"total": 0
	}
	counts.total = counts.placed + counts.unplaced
	return counts
