extends Node3D

# Engine Slot
@onready var token_engine_forest = $TokenEngineForest
@onready var token_engine_desert = $TokenEngineDesert
@onready var token_engine_mountain = $TokenEngineMountain
@onready var token_engine_water = $TokenEngineWater

var token_engine_forest_array = []
var token_engine_desert_array = []
var token_engine_mountain_array = []
var token_engine_water_array = []

var token_placements = []

func _ready():
	get_token_engine_biome_childrens()
	get_token_placement_biome_chidrens()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token Placement 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func get_token_placement_biome_chidrens():
	var token_engine_name = ["TokenEngineForest", "TokenEngineDesert","TokenEngineMountain","TokenEngineWater"]
	for slot in get_children():
		if slot.name not in token_engine_name:
			token_placements.append(slot)
	
	# Engine 
	for slot in token_engine_forest_array:
		token_placements.append(slot)
	for slot in token_engine_desert_array:
		token_placements.append(slot)
	for slot in token_engine_mountain_array:
		token_placements.append(slot)
	for slot in token_engine_water_array:
		token_placements.append(slot)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token Engine 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_token_engine_biome_childrens():
	# Assign children mesh 
	token_engine_forest_array = token_engine_forest.get_children()
	token_engine_desert_array = token_engine_desert.get_children()
	token_engine_mountain_array = token_engine_mountain.get_children()
	token_engine_water_array = token_engine_water.get_children()

	print("token engine forest array : ", token_engine_desert_array)
