extends Node3D

# Token Placements
@onready var token_placement_forest = $TokenPlacementForest
@onready var token_placement_water = $TokenPlacementWater
@onready var token_placement_mountain = $TokenPlacementMountain
@onready var token_placement_desert = $TokenPlacementDesert

# Engine Slot
@onready var token_engine_forest = $TokenEngineForest
@onready var token_engine_desert = $TokenEngineDesert
@onready var token_engine_mountain = $TokenEngineMountain
@onready var token_engine_water = $TokenEngineWater

# Token Placement
var token_placement_forest_array = []
var token_placement_desert_array = []
var token_placement_mountain_array = []
var token_placement_water_array = []

# Engine Array
var token_engine_forest_array = []
var token_engine_desert_array = []
var token_engine_mountain_array = []
var token_engine_water_array = []

var token_placements = []

func _ready():
	get_token_engine_biome_childrens()
	get_token_placement_biome_chidrens()
	_set_token_placements()

func _set_token_placements():
	# Token Placements
	for slot in token_placement_forest_array:
		token_placements.append(slot)
	for slot in token_placement_desert_array:
		token_placements.append(slot)
	for slot in token_placement_mountain_array:
		token_placements.append(slot)
	for slot in token_placement_water_array:
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
# Token Placement 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func get_token_placement_biome_chidrens():
	token_placement_forest_array = token_placement_forest.get_children()
	token_placement_desert_array = token_placement_desert.get_children()
	token_placement_mountain_array = token_placement_mountain.get_children()
	token_placement_water_array = token_placement_water.get_children()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token Engine 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func get_token_engine_biome_childrens():
	# Assign children mesh 
	token_engine_forest_array = token_engine_forest.get_children()
	token_engine_desert_array = token_engine_desert.get_children()
	token_engine_mountain_array = token_engine_mountain.get_children()
	token_engine_water_array = token_engine_water.get_children()
