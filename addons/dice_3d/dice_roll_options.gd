class_name DiceRollOptions
extends Resource


@export_category("Dice Roll Options")
## Resets the die transform and velocities before applying the roll.
@export var reset_before_roll: bool = true
## Places the die at spawn_position, or at the roll box roll source position when spawn_position is zero.
@export var use_spawn_position: bool = true
## Optional explicit world-space spawn position for this roll.
@export var spawn_position: Vector3 = Vector3.ZERO
## Randomizes the die orientation before rolling.
@export var randomize_rotation: bool = true
## Explicit launch impulse for this roll. Leave zero to use die or roll-box defaults.
@export var impulse: Vector3 = Vector3.ZERO
## Explicit spin impulse for this roll. Leave zero to use die or roll-box defaults.
@export var torque: Vector3 = Vector3.ZERO


static func defaults() -> DiceRollOptions:
	return DiceRollOptions.new()
