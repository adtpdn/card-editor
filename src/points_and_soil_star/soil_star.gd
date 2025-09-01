extends Control

signal soil_star_changed(new_count)

@onready var game = get_node("/root/Game")
@onready var soil_star_label = $HBoxContainer/SoilStarLabel
@onready var soil_star_texture = $HBoxContainer/SoilStarTexture

@export var current_soil_star : int = 0 

# Shader
const soil_star_shader = preload("res://assets/materials/shaders/soil_star.gdshader")

#func _ready():
	## Create the purchase button if not already in the scene
	#if not purchase_button:
		#purchase_button = Button.new()
		#purchase_button.text = "Buy Elemental Card"
		#$HBoxContainer.add_child(purchase_button)
		#purchase_button.pressed.connect(_on_purchase_button_pressed)

#func _on_purchase_button_pressed():
	#var game = get_node("/root/Game")
	#var table = game.get_node("Deck/Table")
	#if table and game.game_state_manager.is_valid_player_turn(multiplayer.get_unique_id()):
		#if multiplayer.is_server():
			#table.purchase_elemental_card()
		#else:
			#rpc_id(1, "request_purchase_elemental_card", multiplayer.get_unique_id())


# This function is now ONLY called by the server to increase stars for a player.
# The domination_manager (server-only) will call this.
func increase_soil_star(count: int) -> void:
	if not multiplayer.is_server(): return

	var new_count = current_soil_star + count
	# Clamp the value between 0 and 5
	new_count = clampi(new_count, 0, 5)
	
	# The server calls the sync RPC on all clients (including itself)
	# to inform them of the new authoritative value.
	rpc("sync_star_count", new_count)

# This is the public function that should be called when a player wants to spend stars.
func decrease_soil_star(count: int) -> void:
	# This function now handles the client/server logic.
	if multiplayer.is_server():
		# If we are the server, we process the change directly.
		var new_count = current_soil_star - count
		new_count = clampi(new_count, 0, 5)
		rpc("sync_star_count", new_count)
	else:
		# If we are a client, we send a request to the server to do it for us.
		var player_id = multiplayer.get_unique_id()
		rpc_id(1, "request_server_decrease_stars", player_id, count)

# SERVER-ONLY: This RPC is called by clients to request a star deduction.
@rpc("any_peer")
func request_server_decrease_stars(player_id: int, count: int):
	if not multiplayer.is_server(): return
	
	# The server finds the correct SoilStar node for the player who made the request.
	var player_ui_path = "/root/Game/PlayerUIs/Player_%d_UI" % player_id
	var player_ui = get_node_or_null(player_ui_path)
	if player_ui:
		var soil_star_node = player_ui.get_node_or_null("SoilStar")
		if soil_star_node:
			# The server calls the node's internal logic to decrease and sync the value.
			soil_star_node.decrease_soil_star(count)

# This RPC is called by the server on ALL clients to set the final, correct star count.
@rpc("any_peer", "call_local")
func sync_star_count(new_count: int):
	current_soil_star = new_count
	soil_star_label.text = str(current_soil_star)
	
	# Emit the signal so the SoilStarActions panel can update its button states.
	soil_star_changed.emit(new_count)

func checking_available_soils_star(_used_soil_star: int) -> bool:
	return current_soil_star >= _used_soil_star

# Temporary RPC

@rpc("any_peer", "call_local")
func sync_soil_stars():
	soil_star_label.text = str(current_soil_star)
	if current_soil_star == 0:
		soil_star_texture.material = null

# Shader Setup
func setup_shader_material() -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	shader_material.shader = soil_star_shader
	
	return shader_material

@rpc("any_peer")
func request_purchase_elemental_card(player_id: int):
	if multiplayer.is_server():
		var game = get_node("/root/Game")
		if game.game_state_manager.is_valid_player_turn(player_id):
			var table = game.get_node("Deck/Table")
			table.purchase_elemental_card()
