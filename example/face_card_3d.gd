class_name FaceCard3D
extends Card3D

var card_id : int = -1
var card_on_biome = -1
var card_name : String = ""
var card_type


#@export var data: Dictionary:
	#set(data):
		#if data.has("card_id"):
			#card_resource.card_id  = data["card_id"]
			
		#if data.has("front_material_path"):
			#front_material_path = data["front_material_path"]
			#
		#if data.has("back_material_path"):
			#back_material_path = data["back_material_path"]

#@export var front_material_path: String:
	#set(path):
		#if path:
			#var material = load(path)
			#
			#if material:
				#$CardMesh/CardFrontMesh.set_surface_override_material(0, material)
		#
#@export var back_material_path: String:
	#set(path):
		#if path:
			#var material = load(path)
			#
			#if material:
				#$CardMesh/CardBackMesh.set_surface_override_material(0, material)


#func _to_string():
	#return str(rank) + " of " + str(suit)
