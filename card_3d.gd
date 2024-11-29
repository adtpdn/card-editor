# card_3d.gd
extends Node3D

var card_resource: CardResource

@onready var front_face = $CardMesh/FrontFace
@onready var card_name_label = $CardMesh/FrontFace/CardName
@onready var card_type_label = $CardMesh/FrontFace/CardType
@onready var cost_label = $CardMesh/FrontFace/Cost
@onready var effects_label = $CardMesh/FrontFace/Effects

func set_card_data(resource: CardResource):
	card_resource = resource
	update_card_display()

func update_card_display():
	if card_resource:
		card_name_label.text = card_resource.card_name
		card_type_label.text = "Type: " + ("Action" if card_resource.card_type == CardResource.CardType.ACTION else "Area")
		cost_label.text = "Cost: " + str(card_resource.cost_to_draw)
		effects_label.text = card_resource.effect1 + "\n" + card_resource.effect2
