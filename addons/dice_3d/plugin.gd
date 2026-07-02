@tool
extends EditorPlugin


const ROLL_BOX_SCRIPT := preload("res://addons/dice_3d/dice_roll_box_3d.gd")
const CINEMATIC_ROLLER_SCRIPT := preload("res://addons/dice_3d/dice_cinematic_roller_3d.gd")
const CINEMATIC_ROLL_PANEL_SCRIPT := preload("res://addons/dice_3d/dice_cinematic_roll_panel.gd")
const DIE_SCRIPT := preload("res://addons/dice_3d/dice_die_3d.gd")

var _roll_box_icon: Texture2D
var _die_icon: Texture2D


func _enter_tree() -> void:
	_roll_box_icon = load("res://addons/dice_3d/icons/dice_roll_box_3d.svg")
	_die_icon = load("res://addons/dice_3d/icons/dice_die_3d.svg")
	add_custom_type("DiceRollBox3D", "Node3D", ROLL_BOX_SCRIPT, _roll_box_icon)
	add_custom_type("DiceCinematicRoller3D", "Node3D", CINEMATIC_ROLLER_SCRIPT, _roll_box_icon)
	add_custom_type("DiceDie3D", "RigidBody3D", DIE_SCRIPT, _die_icon)
	add_custom_type("DiceCinematicRollPanel", "PanelContainer", CINEMATIC_ROLL_PANEL_SCRIPT, _die_icon)


func _exit_tree() -> void:
	remove_custom_type("DiceCinematicRollPanel")
	remove_custom_type("DiceDie3D")
	remove_custom_type("DiceCinematicRoller3D")
	remove_custom_type("DiceRollBox3D")
