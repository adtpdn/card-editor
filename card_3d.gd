# card_3d.gd
extends Node3D

var card_resource: CardResource

@onready var front_face = $CardMesh/FrontFace
@onready var card_name_label = $CardMesh/FrontFace/CardName
@onready var card_type_label = $CardMesh/FrontFace/CardType
@onready var cost_label = $CardMesh/FrontFace/Cost
@onready var effects_label = $CardMesh/FrontFace/Effects

@onready var CARD_MESH : MeshInstance3D = $CardMesh
@onready var tex_3d : CompressedTexture2D

func set_card_data(resource: CardResource):
	card_resource = resource
	update_card_display()

func update_card_display():
	if card_resource and card_resource.tex3D_path:
		# Ensure the texture is loaded on all clients
		if ResourceLoader.exists(card_resource.tex3D_path):
			tex_3d = ResourceLoader.load(card_resource.tex3D_path)
			var card_mat = StandardMaterial3D.new()
			
			card_name_label.text = card_resource.card_name
			card_type_label.text = "Type: " + ("Action" if card_resource.card_type == CardResource.CardType.ACTION else "Area")
			cost_label.text = "Cost: " + str(card_resource.cost_to_draw)
			effects_label.text = card_resource.effect1 + "\n" + card_resource.effect2
			
			if tex_3d:
				card_mat.albedo_texture = tex_3d
				CARD_MESH.set_surface_override_material(0, card_mat)
		else:
			push_warning("Texture not found: " + card_resource.tex3D_path)
	
	# Unreveal the card if the condition of card not revealed
	if card_resource and not card_resource.revealed:
		CARD_MESH.rotation.x = PI 
	else:
		CARD_MESH.rotation.x = 0
